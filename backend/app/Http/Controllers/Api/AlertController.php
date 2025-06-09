<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Alert;
use App\Models\AlertConfirmation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;

class AlertController extends Controller
{
    public function index(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'radius' => 'sometimes|integer|min:100|max:50000',
            'type' => 'sometimes|string|in:police,roadwork,obstacle,accident,fire,traffic,blocked_road',
            'severity' => 'sometimes|integer|min:1|max:5',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $latitude = $request->latitude;
            $longitude = $request->longitude;
            $radius = $request->radius ?? 10000; // Default 10km
            $type = $request->type;
            $severity = $request->severity;

            $query = Alert::active()
                ->nearby($latitude, $longitude, $radius)
                ->with(['user:id,username', 'confirmations']);

            if ($type) {
                $query->where('type', $type);
            }

            if ($severity) {
                $query->where('severity', $severity);
            }

            $alerts = $query->get()->map(function ($alert) use ($latitude, $longitude) {
                return [
                    'id' => $alert->id,
                    'type' => $alert->type,
                    'latitude' => $alert->latitude,
                    'longitude' => $alert->longitude,
                    'severity' => $alert->severity,
                    'description' => $alert->description,
                    'confirmed_count' => $alert->confirmed_count,
                    'dismissed_count' => $alert->dismissed_count,
                    'is_active' => $alert->is_active,
                    'reported_at' => $alert->created_at->toISOString(),
                    'distance_meters' => isset($alert->distance_km) ? round($alert->distance_km * 1000) : null,
                    'user' => $alert->user ? [
                        'id' => $alert->user->id,
                        'username' => $alert->user->username,
                    ] : null,
                ];
            });

            return response()->json([
                'success' => true,
                'alerts' => $alerts,
                'count' => $alerts->count(),
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to get alerts',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function directional(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'heading' => 'required|numeric|between:0,360',
            'radius' => 'sometimes|integer|min:100|max:10000',
            'angle' => 'sometimes|integer|min:10|max:180',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $latitude = $request->latitude;
            $longitude = $request->longitude;
            $heading = $request->heading;
            $radius = $request->radius ?? 2000; // Default 2km
            $angle = $request->angle ?? 60; // Default 60 degrees

            $alerts = Alert::active()
                ->directional($latitude, $longitude, $heading, $radius, $angle)
                ->with(['user:id,username'])
                ->get()
                ->map(function ($alert) {
                    return [
                        'id' => $alert->id,
                        'type' => $alert->type,
                        'latitude' => $alert->latitude,
                        'longitude' => $alert->longitude,
                        'severity' => $alert->severity,
                        'description' => $alert->description,
                        'confirmed_count' => $alert->confirmed_count,
                        'is_active' => $alert->is_active,
                        'reported_at' => $alert->created_at->toISOString(),
                        'distance_meters' => isset($alert->distance_km) ? round($alert->distance_km * 1000) : null,
                        'user' => $alert->user ? [
                            'id' => $alert->user->id,
                            'username' => $alert->user->username,
                        ] : null,
                    ];
                });

            return response()->json([
                'success' => true,
                'alerts' => $alerts,
                'count' => $alerts->count(),
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to get directional alerts',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'type' => 'required|string|in:police,roadwork,obstacle,accident,fire,traffic,blocked_road',
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'severity' => 'sometimes|integer|min:1|max:5',
            'description' => 'sometimes|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $alert = Alert::create([
                'user_id' => $request->user()->id,
                'type' => $request->type,
                'latitude' => $request->latitude,
                'longitude' => $request->longitude,
                'severity' => $request->severity ?? 1,
                'description' => $request->description,
                'expires_at' => now()->addHours(24), // Auto-expire after 24 hours
            ]);

            $alert->load('user:id,username');

            return response()->json([
                'success' => true,
                'message' => 'Alert reported successfully',
                'alert' => [
                    'id' => $alert->id,
                    'type' => $alert->type,
                    'latitude' => $alert->latitude,
                    'longitude' => $alert->longitude,
                    'severity' => $alert->severity,
                    'description' => $alert->description,
                    'confirmed_count' => $alert->confirmed_count,
                    'dismissed_count' => $alert->dismissed_count,
                    'is_active' => $alert->is_active,
                    'reported_at' => $alert->created_at->toISOString(),
                    'user' => [
                        'id' => $alert->user->id,
                        'username' => $alert->user->username,
                    ],
                ]
            ], 201);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to report alert',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function confirm(Request $request, Alert $alert)
    {
        $validator = Validator::make($request->all(), [
            'confirmation_type' => 'required|string|in:confirmed,dismissed,not_there',
            'comment' => 'sometimes|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            DB::beginTransaction();

            // Check if user already confirmed this alert
            $existingConfirmation = AlertConfirmation::where('alert_id', $alert->id)
                ->where('user_id', $request->user()->id)
                ->first();

            if ($existingConfirmation) {
                return response()->json([
                    'success' => false,
                    'message' => 'You have already confirmed this alert'
                ], 422);
            }

            // Create confirmation
            AlertConfirmation::create([
                'alert_id' => $alert->id,
                'user_id' => $request->user()->id,
                'confirmation_type' => $request->confirmation_type,
                'comment' => $request->comment,
            ]);

            // Update alert counts
            switch ($request->confirmation_type) {
                case 'confirmed':
                    $alert->increment('confirmed_count');
                    break;
                case 'dismissed':
                case 'not_there':
                    $alert->increment('dismissed_count');
                    break;
            }

            // Deactivate alert if too many dismissals
            $totalConfirmations = $alert->confirmed_count + $alert->dismissed_count;
            if ($totalConfirmations >= 5 && ($alert->dismissed_count / $totalConfirmations) >= 0.6) {
                $alert->update(['is_active' => false]);
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Alert confirmation recorded',
                'alert' => [
                    'id' => $alert->id,
                    'confirmed_count' => $alert->confirmed_count,
                    'dismissed_count' => $alert->dismissed_count,
                    'is_active' => $alert->is_active,
                ]
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Failed to confirm alert',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function show(Alert $alert)
    {
        try {
            $alert->load(['user:id,username', 'confirmations.user:id,username']);

            return response()->json([
                'success' => true,
                'alert' => [
                    'id' => $alert->id,
                    'type' => $alert->type,
                    'latitude' => $alert->latitude,
                    'longitude' => $alert->longitude,
                    'severity' => $alert->severity,
                    'description' => $alert->description,
                    'confirmed_count' => $alert->confirmed_count,
                    'dismissed_count' => $alert->dismissed_count,
                    'is_active' => $alert->is_active,
                    'reported_at' => $alert->created_at->toISOString(),
                    'expires_at' => $alert->expires_at ? $alert->expires_at->toISOString() : null,
                    'user' => $alert->user ? [
                        'id' => $alert->user->id,
                        'username' => $alert->user->username,
                    ] : null,
                    'confirmations' => $alert->confirmations->map(function ($confirmation) {
                        return [
                            'id' => $confirmation->id,
                            'confirmation_type' => $confirmation->confirmation_type,
                            'comment' => $confirmation->comment,
                            'created_at' => $confirmation->created_at->toISOString(),
                            'user' => [
                                'id' => $confirmation->user->id,
                                'username' => $confirmation->user->username,
                            ],
                        ];
                    }),
                ]
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to get alert',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function update(Request $request, Alert $alert)
    {
        // Only allow owner to update
        if ($alert->user_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized to update this alert'
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'type' => 'sometimes|string|in:police,roadwork,obstacle,accident,fire,traffic,blocked_road',
            'severity' => 'sometimes|integer|min:1|max:5',
            'description' => 'sometimes|string|max:1000',
            'is_active' => 'sometimes|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $alert->update($request->only(['type', 'severity', 'description', 'is_active']));

            return response()->json([
                'success' => true,
                'message' => 'Alert updated successfully',
                'alert' => [
                    'id' => $alert->id,
                    'type' => $alert->type,
                    'severity' => $alert->severity,
                    'description' => $alert->description,
                    'is_active' => $alert->is_active,
                    'updated_at' => $alert->updated_at->toISOString(),
                ]
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to update alert',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function destroy(Request $request, Alert $alert)
    {
        // Only allow owner to delete
        if ($alert->user_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized to delete this alert'
            ], 403);
        }

        try {
            $alert->delete();

            return response()->json([
                'success' => true,
                'message' => 'Alert deleted successfully'
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to delete alert',
                'error' => $e->getMessage()
            ], 500);
        }
    }
}