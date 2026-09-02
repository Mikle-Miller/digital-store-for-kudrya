<?php

use App\Http\Controllers\AdminController;
use App\Http\Controllers\OrderController;
use App\Http\Controllers\PromoController;
use App\Http\Controllers\WebhookController;
use Illuminate\Support\Facades\Route;

// ===================== ORDERS =====================
Route::post('/orders', [OrderController::class, 'store']);
Route::get('/orders/{id}', [OrderController::class, 'show']);

// ===================== WEBHOOK =====================
Route::post('/webhook/payment', [WebhookController::class, 'handle'])
    ->withoutMiddleware(['api']); // без throttle — платёжки шлют много запросов

// ===================== ADMIN =====================
Route::prefix('admin')->group(function () {
    Route::get('/stuck-orders', [AdminController::class, 'stuckOrders']);
    Route::get('/stats', [AdminController::class, 'stats']);
    Route::post('/retry/{orderId}', [AdminController::class, 'retry']);
    Route::post('/db/{action}', [AdminController::class, 'dbAction']);
});

// ===================== PROMO (этап 4) =====================
Route::post('/promo/validate', [PromoController::class, 'validate']);
