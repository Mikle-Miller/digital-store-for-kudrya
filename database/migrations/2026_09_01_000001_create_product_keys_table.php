<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_keys', function (Blueprint $table) {
            $table->id();
            $table->string('sku', 50)->index();
            $table->string('key_code', 100)->unique();
            // available | reserved | delivered
            $table->string('status', 20)->default('available')->index();
            $table->unsignedBigInteger('order_id')->nullable(); // → orders.id
            $table->timestamps();

            // Составной индекс для быстрого SELECT FOR UPDATE SKIP LOCKED
            $table->index(['sku', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_keys');
    }
};
