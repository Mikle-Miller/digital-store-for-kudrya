<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->string('sku', 50);
            $table->string('email', 255)->nullable();
            $table->unsignedInteger('amount');
            $table->char('currency', 3)->default('RUB');
            // created | paid | delivering | delivered | payment_failed | out_of_stock | delivery_failed
            $table->string('status', 30)->default('created')->index();
            $table->unsignedBigInteger('key_id')->nullable();   // → product_keys.id (FK добавим после)
            $table->unsignedBigInteger('promo_id')->nullable(); // → promocodes.id
            $table->unsignedInteger('discount')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
