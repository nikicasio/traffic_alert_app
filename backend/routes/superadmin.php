<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\SuperAdminController;

Route::prefix('superadmin')->name('superadmin.')->group(function () {
    Route::get('/dashboard', [SuperAdminController::class, 'dashboard'])->name('dashboard');
    Route::get('/users', [SuperAdminController::class, 'users'])->name('users');
    Route::get('/alerts', [SuperAdminController::class, 'alerts'])->name('alerts');
    
    // API endpoints for AJAX calls
    Route::get('/api/dashboard-data', [SuperAdminController::class, 'getDashboardData'])->name('api.dashboard');
    Route::get('/api/alert/{id}', [SuperAdminController::class, 'getAlertDetails'])->name('api.alert');
    Route::delete('/api/alert/{id}', [SuperAdminController::class, 'deleteAlert'])->name('api.delete-alert');
    Route::patch('/api/alert/{id}/toggle', [SuperAdminController::class, 'toggleAlertStatus'])->name('api.toggle-alert');
});