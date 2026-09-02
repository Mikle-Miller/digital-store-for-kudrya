<?php

namespace App\Http\Controllers;

use App\Jobs\DeliverKeyJob;
use App\Models\WebhookEvent;
use App\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * WebhookController — обработка платёжных вебхуков.
 *
 * Ключевое решение — двухуровневая идемпотентность:
 *
 * Уровень 1 (этот файл):
 *   INSERT INTO webhook_events (event_id, ...) ON CONFLICT DO NOTHING
 *   → из 50 параллельных запросов с одним event_id ровно ОДИН получит
 *     affected_rows=1 и пойдёт дальше. Остальные вернут 200 без действий.
 *
 * Уровень 2 (DeliverKeyJob):
 *   SELECT FOR UPDATE SKIP LOCKED — защита на уровне выдачи ключа.
 */
class WebhookController extends Controller
{
    public function handle(Request $request): JsonResponse
    {
        $data = $request->validate([
            'event_id'   => 'required|string|max:100',
            'order_id'   => 'required',
            'status'     => 'required|string|in:paid,failed',
            'amount'     => 'required|numeric',
            'currency'   => 'sometimes|string|size:3',
            'created_at' => 'sometimes|string',
        ]);

        // === ИДЕМПОТЕНТНОСТЬ (уровень 1) ===
        // INSERT ON CONFLICT DO NOTHING — атомарная операция PostgreSQL.
        // affectedRows=0 означает: этот event_id уже обрабатывался → дубль.
        $inserted = DB::affectingStatement(
            'INSERT INTO webhook_events (event_id, order_id, status, processed_at)
             VALUES (?, ?, ?, NOW())
             ON CONFLICT (event_id) DO NOTHING',
            [$data['event_id'], $data['order_id'], $data['status']]
        );

        if ($inserted === 0) {
            // Дублирующий вебхук — отдаём 200 чтобы платёжка не ретраила
            Log::info("Webhook duplicate: event_id={$data['event_id']}");
            return response()->json(['status' => 'duplicate'], 200);
        }

        // === ОБРАБОТКА ===
        $order = Order::find($data['order_id']);

        if (!$order) {
            // ВАЖНО: возвращаем 503 (не 404), чтобы платёжная система повторила доставку.
            // Вебхук мог прийти раньше, чем заказ был создан (out-of-order delivery).
            // При 404 платёжка считает вебхук обработанным и не ретраит — событие теряется.
            // При 5xx платёжка повторит запрос, и мы обработаем его когда заказ появится.
            Log::warning("Webhook: order #{$data['order_id']} not found yet, returning 503 for retry");
            return response()->json(['error' => 'Order not ready, please retry'], 503);
        }

        // Защита от повторной обработки уже финальных заказов
        if ($order->isFinal()) {
            Log::info("Webhook: order #{$order->id} already in final status {$order->status}");
            return response()->json(['status' => 'already_final'], 200);
        }

        if ($data['status'] === 'paid') {
            $order->update(['status' => Order::STATUS_PAID]);
            // Диспатч джоба выдачи ключа в очередь Redis
            DeliverKeyJob::dispatch($order->id);
            Log::info("Webhook: order #{$order->id} paid → DeliverKeyJob dispatched");
        } else {
            $order->update(['status' => Order::STATUS_PAYMENT_FAILED]);
            Log::info("Webhook: order #{$order->id} payment_failed");
        }

        return response()->json(['status' => 'ok'], 200);
    }
}
