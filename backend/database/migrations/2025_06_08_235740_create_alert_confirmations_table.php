<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('alert_confirmations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('alert_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->enum('confirmation_type', ['confirmed', 'dismissed', 'not_there']);
            $table->text('comment')->nullable();
            $table->timestamps();
            
            // Prevent duplicate confirmations from same user for same alert
            $table->unique(['alert_id', 'user_id']);
            $table->index(['alert_id', 'confirmation_type']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('alert_confirmations');
    }
};
