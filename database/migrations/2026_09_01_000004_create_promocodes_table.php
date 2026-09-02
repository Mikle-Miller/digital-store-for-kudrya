<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('promocodes', function (Blueprint $table) {
            $table->id();
            $table->string('code', 50)->unique();
            $table->string('type', 20); // 'percent' | 'amount'
            $table->unsignedInteger('value');
            $table->char('currency', 3)->nullable();
            $table->unsignedInteger('max_uses');
            // Атомарный счётчик: UPDATE ... SET used = used + 1 WHERE used < max_uses
            $table->unsignedInteger('used')->default(0);
            $table->timestamps();
        });

        Schema::create('promo_uses', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('promo_id');
            $table->unsignedBigInteger('order_id');
            $table->timestamp('used_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('promo_uses');
        Schema::dropIfExists('promocodes');
    }
};
