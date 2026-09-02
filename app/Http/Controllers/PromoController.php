<?php

namespace App\Http\Controllers;

use App\Models\Promocode;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PromoController extends Controller
{

    /**
     * Предварительная проверка промокода (preview, НЕ применяет лимит).
     *
     * Этот эндпоинт только показывает скидку — он НЕ инкрементирует `used`.
     * Это намеренно: пользователь может ввести промокод несколько раз до оплаты.
     *
     * Атомарный захват лимита (под параллельностью) происходит в OrderController::store():
     *   UPDATE promocodes SET used = used + 1 WHERE id = ? AND used < max_uses
     * affectedRows=0 → промокод исчерпан, скидка не применяется.
     *
     * Скидку всегда считает сервер — данным от клиента не доверяем.
     */
    public function validate(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code'   => 'required|string|max:50',
            'amount' => 'required|integer|min:1',
        ]);

        $code = strtoupper(trim($data['code']));

        $promo = Promocode::where('code', $code)->first();

        if (!$promo) {
            return response()->json(['valid' => false, 'error' => 'Промокод не найден'], 422);
        }

        if ($promo->used >= $promo->max_uses) {
            return response()->json(['valid' => false, 'error' => 'Промокод исчерпал лимит'], 422);
        }

        // Считаем скидку на сервере
        $discount = $promo->type === Promocode::TYPE_PERCENT
            ? (int) round($data['amount'] * $promo->value / 100)
            : min($promo->value, $data['amount']);

        return response()->json([
            'valid'       => true,
            'promo_id'    => $promo->id,
            'type'        => $promo->type,
            'value'       => $promo->value,
            'discount'    => $discount,
            'final_amount'=> $data['amount'] - $discount,
        ]);
    }
}
