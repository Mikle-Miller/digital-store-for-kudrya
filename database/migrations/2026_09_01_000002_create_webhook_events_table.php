<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // PRIMARY KEY = event_id → INSERT ON CONFLICT DO NOTHING
        // Гарантирует что 50 одинаковых вебхуков обработается ровно 1 раз
        Schema::create('webhook_events', function (Blueprint $table) {
            $table->string('event_id', 100)->primary();
            $table->string('order_id', 50);
            $table->string('status', 20);
            $table->timestamp('processed_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('webhook_events');
    }
};
