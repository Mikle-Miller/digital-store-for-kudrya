<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductKey extends Model
{
    protected $fillable = ['sku', 'key_code', 'status', 'order_id'];

    const STATUS_AVAILABLE = 'available';
    const STATUS_RESERVED  = 'reserved';
    const STATUS_DELIVERED = 'delivered';

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }
}
