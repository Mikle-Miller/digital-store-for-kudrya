<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Promocode extends Model
{
    protected $fillable = [
        'code', 'type', 'value', 'currency', 'max_uses', 'used',
    ];

    const TYPE_PERCENT = 'percent';
    const TYPE_AMOUNT  = 'amount';
}
