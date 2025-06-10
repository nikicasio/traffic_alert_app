<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AlertController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\GeospatialController;

// Health check endpoint
Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'timestamp' => now()->toISOString(),
        'version' => '1.0.0'
    ]);
});

// DEBUG: Check all alerts in database
Route::get('/debug/alerts', function () {
    $allAlerts = \App\Models\Alert::all(['id', 'type', 'is_active', 'expires_at', 'created_at'])->toArray();
    $activeAlerts = \App\Models\Alert::active()->get(['id', 'type', 'is_active', 'expires_at', 'created_at'])->toArray();
    
    return response()->json([
        'all_alerts_count' => count($allAlerts),
        'all_alerts' => $allAlerts,
        'active_alerts_count' => count($activeAlerts),
        'active_alerts' => $activeAlerts,
        'now' => now()->toISOString(),
    ]);
});

// Authentication routes (public)
Route::prefix('auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
    
    // Protected auth routes
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/profile', [AuthController::class, 'profile']);
        Route::put('/profile', [AuthController::class, 'updateProfile']);
    });
});

// Protected API routes
Route::middleware('auth:sanctum')->group(function () {
    
    // Alert management
    Route::prefix('alerts')->group(function () {
        Route::get('/', [AlertController::class, 'index']); // Get nearby alerts
        Route::post('/', [AlertController::class, 'store']); // Report new alert
        Route::get('/directional', [AlertController::class, 'directional']); // Get directional alerts
        Route::post('/{alert}/confirm', [AlertController::class, 'confirm']); // Confirm/dismiss alert
        Route::get('/{alert}', [AlertController::class, 'show']); // Get specific alert
        Route::put('/{alert}', [AlertController::class, 'update']); // Update alert (owner only)
        Route::delete('/{alert}', [AlertController::class, 'destroy']); // Delete alert (owner only)
    });
    
    // User management
    Route::prefix('user')->group(function () {
        Route::get('/reports', [UserController::class, 'reports']); // Get user's reported alerts
    });
    
    Route::prefix('users')->group(function () {
        Route::get('/stats', [UserController::class, 'stats']); // Get user statistics
        Route::get('/alerts', [UserController::class, 'alerts']); // Get user's alerts
        Route::get('/confirmations', [UserController::class, 'confirmations']); // Get user's confirmations
    });
    
    // Notification management
    Route::prefix('notifications')->group(function () {
        Route::post('/device-token', [NotificationController::class, 'updateDeviceToken']);
        Route::post('/test', [NotificationController::class, 'sendTest']);
        Route::get('/settings', [NotificationController::class, 'getSettings']);
        Route::put('/settings', [NotificationController::class, 'updateSettings']);
    });
    
    // Geospatial features
    Route::prefix('geospatial')->group(function () {
        Route::get('/clusters', [GeospatialController::class, 'clusters']);
        Route::get('/heatmap', [GeospatialController::class, 'heatmap']);
        Route::get('/traffic-patterns', [GeospatialController::class, 'trafficPatterns']);
    });
});