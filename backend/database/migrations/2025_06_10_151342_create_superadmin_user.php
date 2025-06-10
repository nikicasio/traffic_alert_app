<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Hash;
use App\Models\User;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Create the superadmin user
        User::create([
            'name' => 'Super Admin',
            'email' => 'admin@traffic-alerts.com',
            'username' => 'superadmin',
            'password' => Hash::make('admin123456'), // Change this password!
            'email_verified_at' => now(),
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Remove the superadmin user
        User::where('email', 'admin@traffic-alerts.com')->delete();
    }
};
