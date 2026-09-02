<?php

namespace App\Jobs;

use App\Models\Order;
use App\Services\KeyService;
use App\Services\ProviderStub;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * DeliverKeyJob — воркер выдачи ключа.
 *
 * Запускается после подтверждения оплаты.
 * tries=3, backoff=5s → 3 попытки с паузой 5 сек.
 *
 * Схема:
 *   1. Берём ключ из пула (SELECT FOR UPDATE SKIP LOCKED)
 *   2. Нотифицируем провайдера (ProviderStub)
 *   3. Если пул пуст → status=out_of_stock (не Exception, не retry!)
 *   4. Если провайдер A упал → пробуем B
 *   5. Если оба упали → throw → Laravel повторит (до tries раз)
 */
class DeliverKeyJob implements ShouldQueue
{
    use InteractsWithQueue, Queueable, SerializesModels;

    public int $tries   = 3;
    public int $backoff = 5;

    public function __construct(private int $orderId) {}

    public function handle(KeyService $keyService, ProviderStub $provider): void
    {
        $order = Order::find($this->orderId);

        if (!$order) {
            Log::error("DeliverKeyJob: order #{$this->orderId} not found");
            return;
        }

        // Идемпотентность: уже выдан → ничего не делаем
        if ($order->status === Order::STATUS_DELIVERED) {
            Log::info("DeliverKeyJob: order #{$this->orderId} already delivered");
            return;
        }

        // Только оплаченные заказы обрабатываем
        if (!in_array($order->status, [Order::STATUS_PAID, Order::STATUS_DELIVERING,
                                        Order::STATUS_OUT_OF_STOCK, Order::STATUS_DELIVERY_FAILED])) {
            Log::warning("DeliverKeyJob: order #{$this->orderId} wrong status: {$order->status}");
            return;
        }

        $order->update(['status' => Order::STATUS_DELIVERING]);

        // === ШАГ 1: Взять ключ из пула ===
        $key = $keyService->assignToOrder($order);

        if (!$key) {
            // Пул пуст — не падаем, фиксируем статус для ручного retry
            $order->update(['status' => Order::STATUS_OUT_OF_STOCK]);
            Log::warning("DeliverKeyJob: order #{$this->orderId} out_of_stock for sku={$order->sku}");
            return; // НЕ бросаем Exception — не нужен retry, это штатная ситуация
        }

        // === ШАГ 2: Уведомить провайдера (с fallback A → B) ===
        $attempt   = $this->attempts();
        $requestId = "req_{$this->orderId}-{$attempt}";

        $result = $provider->request('A', $requestId . '_A', $order->sku);

        if ($result['status'] !== 'ok') {
            Log::warning("DeliverKeyJob: provider A failed, trying B");
            $result = $provider->request('B', $requestId . '_B', $order->sku);
        }

        if ($result['status'] !== 'ok') {
            // Оба провайдера упали → откатываем ключ и бросаем исключение (retry)
            $key->update(['status' => 'available', 'order_id' => null]);
            $order->update(['status' => Order::STATUS_DELIVERY_FAILED, 'key_id' => null]);
            throw new \RuntimeException("Both providers failed for order #{$this->orderId}");
        }

        Log::info("DeliverKeyJob: order #{$this->orderId} delivered, key={$key->key_code}");
    }

    public function failed(\Throwable $e): void
    {
        Log::error("DeliverKeyJob permanently failed for order #{$this->orderId}: {$e->getMessage()}");
        Order::where('id', $this->orderId)->update(['status' => Order::STATUS_DELIVERY_FAILED]);
    }
}
