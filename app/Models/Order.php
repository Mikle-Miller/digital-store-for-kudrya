<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Order extends Model
{
    protected $fillable = [
        'sku', 'email', 'amount', 'currency',
        'status', 'key_id', 'promo_id', 'discount',
    ];

    // Статусы
    const STATUS_CREATED          = 'created';
    const STATUS_PAID             = 'paid';
    const STATUS_DELIVERING       = 'delivering';
    const STATUS_DELIVERED        = 'delivered';
    const STATUS_PAYMENT_FAILED   = 'payment_failed';
    const STATUS_OUT_OF_STOCK     = 'out_of_stock';
    const STATUS_DELIVERY_FAILED  = 'delivery_failed';

    const FINAL_STATUSES = [
        self::STATUS_DELIVERED,
        self::STATUS_PAYMENT_FAILED,
    ];

    const RECOVERABLE_STATUSES = [
        self::STATUS_OUT_OF_STOCK,
        self::STATUS_DELIVERY_FAILED,
    ];

    public function key(): BelongsTo
    {
        return $this->belongsTo(ProductKey::class, 'key_id');
    }

    public function promo(): BelongsTo
    {
        return $this->belongsTo(Promocode::class, 'promo_id');
    }

    public function isFinal(): bool
    {
        return in_array($this->status, self::FINAL_STATUSES);
    }

    public function isRecoverable(): bool
    {
        return in_array($this->status, self::RECOVERABLE_STATUSES);
    }
}
