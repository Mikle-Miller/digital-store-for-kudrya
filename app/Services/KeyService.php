<?php

namespace App\Services;

use App\Models\Order;
use App\Models\ProductKey;
use Illuminate\Support\Facades\DB;

/**
 * KeyService — атомарная однократная выдача ключа.
 *
 * Ключевое решение: SELECT FOR UPDATE SKIP LOCKED
 *   - Несколько воркеров могут работать параллельно
 *   - Каждый видит только незаблокированные строки
 *   - Один и тот же ключ физически невозможно выдать дважды
 */
class KeyService
{
    /**
     * Атомарно взять ключ из пула и привязать к заказу.
     *
     * @return ProductKey|null  null = пул пуст (→ out_of_stock)
     */
    public function assignToOrder(Order $order): ?ProductKey
    {
        return DB::transaction(function () use ($order) {

            // SELECT FOR UPDATE SKIP LOCKED:
            // Если другой воркер уже lock-нул эту строку — мы её пропускаем,
            // а не ждём (как при обычном FOR UPDATE).
            // Это устраняет race condition при параллельных вебхуках.
            $rows = DB::select(<<<SQL
                SELECT id
                FROM product_keys
                WHERE sku    = ?
                  AND status = ?
                LIMIT 1
                FOR UPDATE SKIP LOCKED
            SQL, [$order->sku, ProductKey::STATUS_AVAILABLE]);

            if (empty($rows)) {
                // Пул пуст — не падаем, переходим в out_of_stock
                return null;
            }

            $key = ProductKey::find($rows[0]->id);

            // Атомарно обновляем и ключ и заказ в одной транзакции
            $key->update([
                'status'   => ProductKey::STATUS_DELIVERED,
                'order_id' => $order->id,
            ]);

            $order->update([
                'status' => Order::STATUS_DELIVERED,
                'key_id' => $key->id,
            ]);

            return $key;
        });
    }

    /**
     * Идемпотентный retry — если ключ уже выдан, вернуть его.
     */
    public function retryForOrder(Order $order): ?ProductKey
    {
        // Уже выдан — возвращаем без повторного поиска
        if ($order->status === Order::STATUS_DELIVERED && $order->key_id) {
            return ProductKey::find($order->key_id);
        }

        // Снова пробуем взять из пула
        $order->update(['status' => Order::STATUS_DELIVERING]);
        return $this->assignToOrder($order);
    }
}
