<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserDevice;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class NotificationController extends Controller
{
    public function updateDeviceToken(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'device_token' => 'required|string',
            'action' => 'sometimes|string|in:add,remove',
            'device_name' => 'sometimes|string|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $action = $request->action ?? 'add';
            
            if ($action === 'remove') {
                UserDevice::where('user_id', $request->user()->id)
                    ->where('device_token', $request->device_token)
                    ->delete();
                    
                return response()->json([
                    'success' => true,
                    'message' => 'Device token removed successfully'
                ]);
            }

            UserDevice::updateOrCreate(
                [
                    'user_id' => $request->user()->id,
                    'device_token' => $request->device_token
                ],
                [
                    'device_type' => $this->detectDeviceType($request),
                    'device_name' => $request->device_name ?? 'Mobile Device',
                    'is_active' => true,
                    'last_used_at' => now(),
                ]
            );

            return response()->json([
                'success' => true,
                'message' => 'Device token updated successfully'
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to update device token',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function sendTest(Request $request)
    {
        try {
            // For now, just return success - we'll implement FCM later
            return response()->json([
                'success' => true,
                'message' => 'Test notification would be sent (FCM not implemented yet)'
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to send test notification',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function getSettings(Request $request)
    {
        try {
            // Return default notification settings for now
            return response()->json([
                'success' => true,
                'settings' => [
                    'push_enabled' => true,
                    'alert_types' => [
                        'police' => true,
                        'accident' => true,
                        'roadwork' => true,
                        'traffic' => true,
                        'obstacle' => true,
                        'fire' => true,
                        'blocked_road' => true,
                    ],
                    'radius_km' => 10,
                    'min_severity' => 1,
                ]
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to get notification settings',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function updateSettings(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'push_enabled' => 'sometimes|boolean',
            'alert_types' => 'sometimes|array',
            'radius_km' => 'sometimes|integer|min:1|max:50',
            'min_severity' => 'sometimes|integer|min:1|max:5',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            // For now, just return the updated settings - we'll store them in user preferences later
            return response()->json([
                'success' => true,
                'message' => 'Notification settings updated successfully',
                'settings' => $request->all()
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to update notification settings',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    private function detectDeviceType(Request $request): string
    {
        $userAgent = $request->header('User-Agent', '');
        
        if (stripos($userAgent, 'iPhone') !== false || stripos($userAgent, 'iPad') !== false) {
            return 'ios';
        } elseif (stripos($userAgent, 'Android') !== false) {
            return 'android';
        } else {
            return 'web';
        }
    }
}
