<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WebhookEvent extends Model
{
    public $incrementing = false;
    public $timestamps   = false;

    protected $primaryKey = 'event_id';
    protected $keyType    = 'string';

    protected $fillable = ['event_id', 'order_id', 'status', 'processed_at'];
}
