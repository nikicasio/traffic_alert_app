<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use App\Models\User;
use App\Models\Alert;
use App\Models\AlertConfirmation;

class SuperAdminController extends Controller
{
    public function __construct()
    {
        $this->middleware('auth');
        $this->middleware(function ($request, $next) {
            if (!$this->isSuperAdmin()) {
                abort(403, 'Access denied. Super admin privileges required.');
            }
            return $next($request);
        });
    }

    private function isSuperAdmin()
    {
        $user = Auth::user();
        return $user && $user->email === 'admin@traffic-alerts.com';
    }

    public function dashboard()
    {
        // Get dashboard statistics
        $stats = [
            'total_users' => User::count(),
            'online_users' => $this->getOnlineUsersCount(),
            'total_alerts' => Alert::count(),
            'active_alerts' => Alert::where('is_active', true)->count(),
            'alerts_today' => Alert::whereDate('created_at', today())->count(),
            'confirmations_today' => AlertConfirmation::whereDate('created_at', today())->count(),
        ];

        // Get recent alerts for the map
        $recent_alerts = Alert::with(['user', 'confirmations'])
            ->where('created_at', '>=', now()->subHours(24))
            ->orderBy('created_at', 'desc')
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
                    'user_name' => $alert->user->name ?? 'Unknown',
                    'user_email' => $alert->user->email ?? 'Unknown',
                    'created_at' => $alert->created_at->format('Y-m-d H:i:s'),
                    'is_active' => $alert->is_active,
                ];
            });

        // Get online users (users active in last 5 minutes)
        $online_users = User::where('updated_at', '>=', now()->subMinutes(5))
            ->select('id', 'name', 'email', 'updated_at')
            ->orderBy('updated_at', 'desc')
            ->get();

        return view('superadmin.dashboard', compact('stats', 'recent_alerts', 'online_users'));
    }

    public function users(Request $request)
    {
        $query = User::query();

        // Search functionality
        if ($request->filled('search')) {
            $search = $request->get('search');
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%")
                  ->orWhere('username', 'like', "%{$search}%");
            });
        }

        // Sorting
        $sortBy = $request->get('sort', 'created_at');
        $sortOrder = $request->get('order', 'desc');
        
        if (in_array($sortBy, ['name', 'email', 'created_at', 'updated_at'])) {
            $query->orderBy($sortBy, $sortOrder);
        }

        $users = $query->withCount(['alerts', 'confirmations'])
            ->paginate(20);

        return view('superadmin.users', compact('users'));
    }

    public function alerts(Request $request)
    {
        $query = Alert::with(['user', 'confirmations']);

        // Filter by type
        if ($request->filled('type')) {
            $query->where('type', $request->get('type'));
        }

        // Filter by active status
        if ($request->filled('status')) {
            $isActive = $request->get('status') === 'active';
            $query->where('is_active', $isActive);
        }

        // Date range filter
        if ($request->filled('date_from')) {
            $query->whereDate('created_at', '>=', $request->get('date_from'));
        }
        if ($request->filled('date_to')) {
            $query->whereDate('created_at', '<=', $request->get('date_to'));
        }

        // Search
        if ($request->filled('search')) {
            $search = $request->get('search');
            $query->where(function ($q) use ($search) {
                $q->where('description', 'like', "%{$search}%")
                  ->orWhereHas('user', function ($userQuery) use ($search) {
                      $userQuery->where('name', 'like', "%{$search}%")
                               ->orWhere('email', 'like', "%{$search}%");
                  });
            });
        }

        // Sorting
        $sortBy = $request->get('sort', 'created_at');
        $sortOrder = $request->get('order', 'desc');
        
        if (in_array($sortBy, ['created_at', 'type', 'severity', 'confirmed_count'])) {
            $query->orderBy($sortBy, $sortOrder);
        }

        $alerts = $query->paginate(25);

        // Get alert types for filter dropdown
        $alertTypes = Alert::distinct()->pluck('type')->sort();

        return view('superadmin.alerts', compact('alerts', 'alertTypes'));
    }

    public function deleteAlert($id)
    {
        $alert = Alert::findOrFail($id);
        $alert->delete();

        return response()->json([
            'success' => true,
            'message' => 'Alert deleted successfully'
        ]);
    }

    public function getAlertDetails($id)
    {
        $alert = Alert::with(['user', 'confirmations.user'])
            ->findOrFail($id);

        return response()->json([
            'id' => $alert->id,
            'type' => $alert->type,
            'latitude' => $alert->latitude,
            'longitude' => $alert->longitude,
            'severity' => $alert->severity,
            'description' => $alert->description,
            'confirmed_count' => $alert->confirmed_count,
            'dismissed_count' => $alert->dismissed_count,
            'is_active' => $alert->is_active,
            'created_at' => $alert->created_at->format('Y-m-d H:i:s'),
            'expires_at' => $alert->expires_at ? $alert->expires_at->format('Y-m-d H:i:s') : null,
            'user' => [
                'id' => $alert->user->id,
                'name' => $alert->user->name,
                'email' => $alert->user->email,
                'username' => $alert->user->username,
            ],
            'confirmations' => $alert->confirmations->map(function ($confirmation) {
                return [
                    'id' => $confirmation->id,
                    'user_name' => $confirmation->user->name,
                    'user_email' => $confirmation->user->email,
                    'created_at' => $confirmation->created_at->format('Y-m-d H:i:s'),
                ];
            }),
        ]);
    }

    public function getDashboardData()
    {
        return response()->json([
            'stats' => [
                'total_users' => User::count(),
                'online_users' => $this->getOnlineUsersCount(),
                'total_alerts' => Alert::count(),
                'active_alerts' => Alert::where('is_active', true)->count(),
                'alerts_today' => Alert::whereDate('created_at', today())->count(),
                'confirmations_today' => AlertConfirmation::whereDate('created_at', today())->count(),
            ],
            'recent_alerts' => Alert::with('user')
                ->where('created_at', '>=', now()->subHours(1))
                ->orderBy('created_at', 'desc')
                ->limit(10)
                ->get(),
            'online_users' => User::where('updated_at', '>=', now()->subMinutes(5))
                ->select('id', 'name', 'email', 'updated_at')
                ->orderBy('updated_at', 'desc')
                ->get(),
        ]);
    }

    private function getOnlineUsersCount()
    {
        // Users are considered online if they've been active in the last 5 minutes
        return User::where('updated_at', '>=', now()->subMinutes(5))->count();
    }

    public function toggleAlertStatus($id)
    {
        $alert = Alert::findOrFail($id);
        $alert->is_active = !$alert->is_active;
        $alert->save();

        return response()->json([
            'success' => true,
            'message' => 'Alert status updated successfully',
            'is_active' => $alert->is_active
        ]);
    }
}