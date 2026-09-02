<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\Promocode;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class OrderController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'sku'    => 'required|string|max:50',
            'email'  => 'nullable|email|max:255',
            'amount' => 'required|integer|min:1',
            'promo'  => 'nullable|string|max:50',
        ]);

        $discount = 0;
        $promoId  = null;

        // Применяем промокод если передан
        if (!empty($data['promo'])) {
            $promo = Promocode::where('code', strtoupper(trim($data['promo'])))->first();
            if ($promo) {
                // Атомарный захват лимита промокода при создании заказа
                $affected = \Illuminate\Support\Facades\DB::affectingStatement(
                    'UPDATE promocodes SET used = used + 1 WHERE id = ? AND used < max_uses',
                    [$promo->id]
                );

                if ($affected > 0) {
                    $promoId  = $promo->id;
                    $discount = $promo->type === Promocode::TYPE_PERCENT
                        ? (int) round($data['amount'] * $promo->value / 100)
                        : min($promo->value, $data['amount']);
                }
            }
        }

        $order = Order::create([
            'sku'      => $data['sku'],
            'email'    => $data['email'] ?? null,
            'amount'   => $data['amount'] - $discount,
            'currency' => 'RUB',
            'status'   => Order::STATUS_CREATED,
            'promo_id' => $promoId,
            'discount' => $discount,
        ]);

        Log::info("Order #{$order->id} created for sku={$order->sku}");

        return response()->json([
            'id'       => $order->id,
            'sku'      => $order->sku,
            'amount'   => $order->amount,
            'discount' => $order->discount,
            'status'   => $order->status,
        ], 201);
    }

    public function show(int $id): JsonResponse
    {
        $order = Order::with('key')->find($id);

        if (!$order) {
            return response()->json(['error' => 'Not found'], 404);
        }

        return response()->json([
            'id'        => $order->id,
            'sku'       => $order->sku,
            'amount'    => $order->amount,
            'status'    => $order->status,
            'key_code'  => $order->key?->key_code,
            'email'     => $order->email,
            'created_at'=> $order->created_at,
        ]);
    }
}
