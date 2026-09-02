<?php

namespace App\Http\Controllers;

use App\Jobs\DeliverKeyJob;
use App\Models\Order;
use App\Models\ProductKey;
use Illuminate\Http\JsonResponse;

class AdminController extends Controller
{
    /**
     * Статистика для дашборда.
     */
    public function stats(): JsonResponse
    {
        return response()->json([
            'total'          => Order::count(),
            'delivered'      => Order::where('status', Order::STATUS_DELIVERED)->count(),
            'stuck'          => Order::whereIn('status', Order::RECOVERABLE_STATUSES)->count(),
            'keys_available' => ProductKey::where('status', ProductKey::STATUS_AVAILABLE)->count(),
        ]);
    }

    /**
     * Список заказов, требующих внимания: out_of_stock + delivery_failed.
     */
    public function stuckOrders(): JsonResponse
    {
        $orders = Order::whereIn('status', Order::RECOVERABLE_STATUSES)
            ->orderByDesc('created_at')
            ->get(['id', 'sku', 'email', 'amount', 'status', 'created_at']);

        return response()->json($orders);
    }

    /**
     * Повторная выдача (идемпотентна).
     *
     * Если заказ уже доставлен — вернуть ключ без повторной выдачи.
     * Если нет — диспатчнуть DeliverKeyJob заново.
     */
    public function retry(int $orderId): JsonResponse
    {
        $order = Order::with('key')->find($orderId);

        if (!$order) {
            return response()->json(['error' => 'Order not found'], 404);
        }

        // Идемпотентность: уже выдан
        if ($order->status === Order::STATUS_DELIVERED) {
            return response()->json([
                'already_delivered' => true,
                'key'               => $order->key?->key_code,
            ]);
        }

        // Можно ретраить только recoverable статусы
        if (!$order->isRecoverable()) {
            return response()->json([
                'error'  => 'Cannot retry order in status: ' . $order->status,
            ], 422);
        }

        DeliverKeyJob::dispatch($order->id);

        return response()->json([
            'already_delivered' => false,
            'message'           => "DeliverKeyJob dispatched for order #{$orderId}",
        ]);
    }

    /**
     * Действия с БД для эмуляции сбоев и тестирования.
     */
    public function dbAction(string $action): JsonResponse
    {
        switch ($action) {
            case 'reset':
                // Используем TRUNCATE вместо migrate:fresh, чтобы не убивать PDO-соединение воркера
                \Illuminate\Support\Facades\DB::statement('TRUNCATE TABLE orders, webhook_events, provider_requests, product_keys, promocodes RESTART IDENTITY CASCADE');
                \Illuminate\Support\Facades\Artisan::call('db:seed', ['--force' => true]);
                return response()->json(['message' => 'База данных очищена (TRUNCATE) и заполнена тестовыми данными. Воркер жив!']);
            case 'empty':
                ProductKey::whereNull('order_id')->delete();
                return response()->json(['message' => 'Свободные ключи удалены. Склад пуст.']);
            case 'add_keys':
                $skus = ProductKey::select('sku')->distinct()->pluck('sku');
                foreach ($skus as $sku) {
                    for ($i = 0; $i < 5; $i++) {
                        ProductKey::create([
                            'sku' => $sku,
                            'key_code' => 'TEST-KEY-' . strtoupper(\Illuminate\Support\Str::random(8))
                        ]);
                    }
                }
                return response()->json(['message' => 'Добавлено по 5 новых ключей для ВСЕХ товаров.']);
            default:
                return response()->json(['error' => 'Unknown action'], 400);
        }
    }
}
