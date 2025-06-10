<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Alert;
use Illuminate\Http\Request;

class UserController extends Controller
{
    public function reports(Request $request)
    {
        try {
            $user = $request->user();
            
            $reports = Alert::where('user_id', $user->id)
                ->orderBy('created_at', 'desc')
                ->get()
                ->map(function ($alert) {
                    return [
                        'id' => (int) $alert->id,
                        'type' => $alert->type,
                        'latitude' => (float) $alert->latitude,
                        'longitude' => (float) $alert->longitude,
                        'severity' => (int) $alert->severity,
                        'description' => $alert->description,
                        'confirmed_count' => (int) $alert->confirmed_count,
                        'dismissed_count' => (int) $alert->dismissed_count,
                        'is_active' => (bool) $alert->is_active,
                        'reported_at' => $alert->created_at->toISOString(),
                        'expires_at' => $alert->expires_at ? $alert->expires_at->toISOString() : null,
                    ];
                });

            return response()->json([
                'success' => true,
                'reports' => $reports,
                'count' => $reports->count(),
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to get user reports',
                'error' => $e->getMessage()
            ], 500);
        }
    }
}
