@extends('layouts.superadmin')

@section('title', 'Users Management')
@section('header', 'Users Management')

@section('content')
<div class="space-y-6">
    <!-- Search and Filters -->
    <div class="bg-white rounded-lg shadow-sm p-6">
        <form method="GET" action="{{ route('superadmin.users') }}" class="space-y-4 md:space-y-0 md:flex md:items-end md:space-x-4">
            <div class="flex-1">
                <label for="search" class="block text-sm font-medium text-gray-700 mb-1">Search Users</label>
                <input type="text" 
                       name="search" 
                       id="search"
                       value="{{ request('search') }}"
                       placeholder="Search by name, email, or username..."
                       class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            </div>
            
            <div>
                <label for="sort" class="block text-sm font-medium text-gray-700 mb-1">Sort By</label>
                <select name="sort" id="sort" class="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                    <option value="created_at" {{ request('sort') == 'created_at' ? 'selected' : '' }}>Registration Date</option>
                    <option value="updated_at" {{ request('sort') == 'updated_at' ? 'selected' : '' }}>Last Activity</option>
                    <option value="name" {{ request('sort') == 'name' ? 'selected' : '' }}>Name</option>
                    <option value="email" {{ request('sort') == 'email' ? 'selected' : '' }}>Email</option>
                </select>
            </div>
            
            <div>
                <label for="order" class="block text-sm font-medium text-gray-700 mb-1">Order</label>
                <select name="order" id="order" class="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                    <option value="desc" {{ request('order') == 'desc' ? 'selected' : '' }}>Descending</option>
                    <option value="asc" {{ request('order') == 'asc' ? 'selected' : '' }}>Ascending</option>
                </select>
            </div>
            
            <div class="flex space-x-2">
                <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2">
                    <i class="fas fa-search mr-1"></i> Search
                </button>
                
                <a href="{{ route('superadmin.users') }}" class="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2">
                    <i class="fas fa-refresh mr-1"></i> Reset
                </a>
            </div>
        </form>
    </div>
    
    <!-- Statistics Summary -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div class="bg-white p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-blue-500 rounded-full">
                    <i class="fas fa-users text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">Total Users</p>
                    <p class="text-2xl font-bold text-gray-900">{{ $users->total() }}</p>
                </div>
            </div>
        </div>
        
        <div class="bg-white p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-green-500 rounded-full">
                    <i class="fas fa-user-plus text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">New Today</p>
                    <p class="text-2xl font-bold text-gray-900">{{ \App\Models\User::whereDate('created_at', today())->count() }}</p>
                </div>
            </div>
        </div>
        
        <div class="bg-white p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-yellow-500 rounded-full">
                    <i class="fas fa-circle text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">Active Users</p>
                    <p class="text-2xl font-bold text-gray-900">{{ \App\Models\User::where('updated_at', '>=', now()->subMinutes(5))->count() }}</p>
                </div>
            </div>
        </div>
        
        <div class="bg-white p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-purple-500 rounded-full">
                    <i class="fas fa-chart-line text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">This Week</p>
                    <p class="text-2xl font-bold text-gray-900">{{ \App\Models\User::where('created_at', '>=', now()->subWeek())->count() }}</p>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Users Table -->
    <div class="bg-white rounded-lg shadow-sm overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-semibold text-gray-900">
                <i class="fas fa-users mr-2"></i>
                Users List
                @if(request('search'))
                    <span class="text-sm font-normal text-gray-600">- Search results for "{{ request('search') }}"</span>
                @endif
            </h3>
        </div>
        
        @if($users->count() > 0)
        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Contact</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Activity</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Statistics</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Registration</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                    </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                    @foreach($users as $user)
                    <tr class="hover:bg-gray-50">
                        <td class="px-6 py-4 whitespace-nowrap">
                            <div class="flex items-center">
                                <div class="flex-shrink-0 h-10 w-10">
                                    <div class="h-10 w-10 rounded-full bg-gradient-to-r from-purple-400 via-pink-500 to-red-500 flex items-center justify-center">
                                        <span class="text-white font-bold text-sm">{{ substr($user->name, 0, 2) }}</span>
                                    </div>
                                </div>
                                <div class="ml-4">
                                    <div class="text-sm font-medium text-gray-900">{{ $user->name }}</div>
                                    @if($user->username)
                                    <div class="text-sm text-gray-500">@{{ $user->username }}</div>
                                    @endif
                                </div>
                            </div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <div class="text-sm text-gray-900">{{ $user->email }}</div>
                            @if($user->email_verified_at)
                            <div class="text-sm text-green-600">
                                <i class="fas fa-check-circle mr-1"></i>Verified
                            </div>
                            @else
                            <div class="text-sm text-red-600">
                                <i class="fas fa-exclamation-circle mr-1"></i>Unverified
                            </div>
                            @endif
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            <div>Last seen: {{ $user->updated_at->diffForHumans() }}</div>
                            @if($user->updated_at >= now()->subMinutes(5))
                            <div class="text-green-600">
                                <i class="fas fa-circle mr-1 text-xs"></i>Online
                            </div>
                            @else
                            <div class="text-gray-500">
                                <i class="fas fa-circle mr-1 text-xs"></i>Offline
                            </div>
                            @endif
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            <div class="space-y-1">
                                <div>
                                    <i class="fas fa-triangle-exclamation mr-1 text-yellow-500"></i>
                                    {{ $user->alerts_count }} alerts
                                </div>
                                <div>
                                    <i class="fas fa-check mr-1 text-green-500"></i>
                                    {{ $user->confirmations_count }} confirmations
                                </div>
                            </div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            <div>{{ $user->created_at->format('M d, Y') }}</div>
                            <div>{{ $user->created_at->diffForHumans() }}</div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            @if($user->email === 'admin@traffic-alerts.com')
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                                <i class="fas fa-crown mr-1"></i>Super Admin
                            </span>
                            @else
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                <i class="fas fa-user mr-1"></i>User
                            </span>
                            @endif
                        </td>
                    </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
        
        <!-- Pagination -->
        <div class="bg-white px-4 py-3 border-t border-gray-200 sm:px-6">
            {{ $users->appends(request()->query())->links() }}
        </div>
        @else
        <div class="text-center py-12">
            <i class="fas fa-users text-gray-400 text-4xl mb-4"></i>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No users found</h3>
            @if(request('search'))
                <p class="text-gray-600">No users match your search criteria.</p>
                <a href="{{ route('superadmin.users') }}" class="mt-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-blue-700 bg-blue-100 hover:bg-blue-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                    <i class="fas fa-arrow-left mr-2"></i>
                    View all users
                </a>
            @else
                <p class="text-gray-600">No users have registered yet.</p>
            @endif
        </div>
        @endif
    </div>
    
    @if($users->count() > 0)
    <!-- Export Options -->
    <div class="bg-white rounded-lg shadow-sm p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">
            <i class="fas fa-download mr-2"></i>
            Export Data
        </h3>
        <div class="flex space-x-4">
            <button onclick="exportUsers('csv')" class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2">
                <i class="fas fa-file-csv mr-1"></i> Export as CSV
            </button>
            <button onclick="exportUsers('json')" class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2">
                <i class="fas fa-file-code mr-1"></i> Export as JSON
            </button>
        </div>
    </div>
    @endif
</div>
@endsection

@push('scripts')
<script>
function exportUsers(format) {
    const searchParams = new URLSearchParams(window.location.search);
    searchParams.set('format', format);
    
    const exportUrl = '{{ route("superadmin.users") }}?' + searchParams.toString();
    
    // Create a temporary link to trigger download
    const link = document.createElement('a');
    link.href = exportUrl;
    link.download = `users_export_${new Date().toISOString().slice(0, 10)}.${format}`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

// Auto-refresh user count every 30 seconds
setInterval(() => {
    fetch('/superadmin/api/dashboard-data')
        .then(response => response.json())
        .then(data => {
            // Update any live counters if needed
            console.log('Dashboard data refreshed');
        })
        .catch(error => console.error('Error refreshing data:', error));
}, 30000);
</script>
@endpush