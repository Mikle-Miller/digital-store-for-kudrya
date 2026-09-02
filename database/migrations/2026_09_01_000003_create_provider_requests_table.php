<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // PRIMARY KEY = request_id → повторный вызов поставщика с тем же request_id
        // вернёт тот же ключ, не выдаст новый (таймаут ≠ отказ)
        Schema::create('provider_requests', function (Blueprint $table) {
            $table->string('request_id', 100)->primary();
            $table->unsignedBigInteger('order_id');
            $table->char('provider', 1); // 'A' | 'B'
            $table->string('key_code', 100)->nullable();
            // pending | ok | error | timeout
            $table->string('status', 20);
            $table->timestamp('created_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('provider_requests');
    }
};
