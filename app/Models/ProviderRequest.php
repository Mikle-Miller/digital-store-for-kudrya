<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProviderRequest extends Model
{
    public $incrementing = false;
    public $timestamps   = false;

    protected $primaryKey = 'request_id';
    protected $keyType    = 'string';

    protected $fillable = [
        'request_id', 'order_id', 'provider', 'key_code', 'status',
    ];

    const STATUS_PENDING = 'pending';
    const STATUS_OK      = 'ok';
    const STATUS_ERROR   = 'error';
    const STATUS_TIMEOUT = 'timeout';
}
