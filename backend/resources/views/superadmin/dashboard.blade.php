@extends('layouts.superadmin')

@section('title', 'Dashboard')
@section('header', 'Dashboard')

@section('content')
<div class="space-y-6">
    <!-- Statistics Cards -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-6">
        <div class="stat-card p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-blue-500 rounded-full">
                    <i class="fas fa-users text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">Total Users</p>
                    <p class="text-2xl font-bold text-gray-900" id="total-users">{{ $stats['total_users'] }}</p>
                </div>
            </div>
        </div>
        
        <div class="stat-card p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-green-500 rounded-full">
                    <i class="fas fa-circle text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">Online Users</p>
                    <p class="text-2xl font-bold text-gray-900" id="online-users">{{ $stats['online_users'] }}</p>
                </div>
            </div>
        </div>
        
        <div class="stat-card p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-yellow-500 rounded-full">
                    <i class="fas fa-triangle-exclamation text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">Total Alerts</p>
                    <p class="text-2xl font-bold text-gray-900" id="total-alerts">{{ $stats['total_alerts'] }}</p>
                </div>
            </div>
        </div>
        
        <div class="stat-card p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-red-500 rounded-full">
                    <i class="fas fa-exclamation text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">Active Alerts</p>
                    <p class="text-2xl font-bold text-gray-900" id="active-alerts">{{ $stats['active_alerts'] }}</p>
                </div>
            </div>
        </div>
        
        <div class="stat-card p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-purple-500 rounded-full">
                    <i class="fas fa-calendar-day text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">Alerts Today</p>
                    <p class="text-2xl font-bold text-gray-900" id="alerts-today">{{ $stats['alerts_today'] }}</p>
                </div>
            </div>
        </div>
        
        <div class="stat-card p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-indigo-500 rounded-full">
                    <i class="fas fa-check text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">Confirmations Today</p>
                    <p class="text-2xl font-bold text-gray-900" id="confirmations-today">{{ $stats['confirmations_today'] }}</p>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Main Content Grid -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Alert Map -->
        <div class="lg:col-span-2 bg-white rounded-lg shadow-sm">
            <div class="p-6 border-b">
                <h3 class="text-lg font-semibold text-gray-900">
                    <i class="fas fa-map-marker-alt mr-2 text-red-500"></i>
                    Live Alert Map (Last 24 Hours)
                </h3>
                <p class="text-sm text-gray-600 mt-1">Click on markers to view alert details</p>
            </div>
            <div class="p-6">
                <div id="alert-map" style="height: 500px; border-radius: 8px;"></div>
            </div>
        </div>
        
        <!-- Online Users Panel -->
        <div class="bg-white rounded-lg shadow-sm">
            <div class="p-6 border-b">
                <h3 class="text-lg font-semibold text-gray-900">
                    <i class="fas fa-users mr-2 text-green-500"></i>
                    Online Users
                </h3>
                <p class="text-sm text-gray-600 mt-1">Active in last 5 minutes</p>
            </div>
            <div class="p-6">
                <div id="online-users-list" class="space-y-3 max-h-96 overflow-y-auto">
                    @forelse($online_users as $user)
                    <div class="flex items-center p-3 bg-gray-50 rounded-lg">
                        <div class="w-2 h-2 bg-green-500 rounded-full mr-3"></div>
                        <div class="flex-1">
                            <p class="text-sm font-medium text-gray-900">{{ $user->name }}</p>
                            <p class="text-xs text-gray-600">{{ $user->email }}</p>
                            <p class="text-xs text-green-600">
                                Last seen: {{ $user->updated_at->diffForHumans() }}
                            </p>
                        </div>
                    </div>
                    @empty
                    <div class="text-center py-8">
                        <i class="fas fa-user-slash text-gray-400 text-3xl mb-2"></i>
                        <p class="text-gray-600">No users currently online</p>
                    </div>
                    @endforelse
                </div>
            </div>
        </div>
    </div>
    
    <!-- Recent Activity -->
    <div class="bg-white rounded-lg shadow-sm">
        <div class="p-6 border-b">
            <h3 class="text-lg font-semibold text-gray-900">
                <i class="fas fa-clock mr-2 text-blue-500"></i>
                Recent Alerts (Last Hour)
            </h3>
        </div>
        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Alert</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Location</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Reporter</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Confirmations</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Time</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                    </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200" id="recent-alerts-table">
                    @forelse($recent_alerts as $alert)
                    <tr class="hover:bg-gray-50 cursor-pointer" onclick="showAlertDetails({{ $alert['id'] }})">
                        <td class="px-6 py-4 whitespace-nowrap">
                            <div class="flex items-center">
                                <div class="flex-shrink-0">
                                    <i class="fas fa-triangle-exclamation text-{{ $alert['severity'] >= 3 ? 'red' : ($alert['severity'] >= 2 ? 'yellow' : 'blue') }}-500"></i>
                                </div>
                                <div class="ml-4">
                                    <div class="text-sm font-medium text-gray-900">{{ ucfirst($alert['type']) }}</div>
                                    @if($alert['description'])
                                    <div class="text-sm text-gray-500">{{ Str::limit($alert['description'], 30) }}</div>
                                    @endif
                                </div>
                            </div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {{ number_format($alert['latitude'], 6) }}, {{ number_format($alert['longitude'], 6) }}
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {{ $alert['user_name'] }}
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                {{ $alert['confirmed_count'] }} confirmations
                            </span>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {{ \Carbon\Carbon::parse($alert['created_at'])->diffForHumans() }}
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            @if($alert['is_active'])
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                Active
                            </span>
                            @else
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                                Inactive
                            </span>
                            @endif
                        </td>
                    </tr>
                    @empty
                    <tr>
                        <td colspan="6" class="px-6 py-12 text-center text-gray-500">
                            <i class="fas fa-exclamation-triangle text-gray-400 text-3xl mb-2"></i>
                            <p>No recent alerts found</p>
                        </td>
                    </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
</div>

<!-- Alert Details Modal -->
<div id="alert-modal" class="fixed inset-0 bg-gray-600 bg-opacity-50 hidden z-50">
    <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
            <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div class="sm:flex sm:items-start">
                    <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                            Alert Details
                        </h3>
                        <div id="alert-details-content">
                            <!-- Content loaded via AJAX -->
                        </div>
                    </div>
                </div>
            </div>
            <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <button type="button" class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm" onclick="closeAlertModal()">
                    Close
                </button>
            </div>
        </div>
    </div>
</div>
@endsection

@push('scripts')
<script>
    let alertMap;
    let alertMarkers = [];
    
    // Initialize map
    function initMap() {
        alertMap = L.map('alert-map').setView([50.7441, 6.1729], 10);
        
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors'
        }).addTo(alertMap);
        
        loadAlertMarkers();
    }
    
    // Load alert markers
    function loadAlertMarkers() {
        const alerts = @json($recent_alerts);
        
        // Clear existing markers
        alertMarkers.forEach(marker => alertMap.removeLayer(marker));
        alertMarkers = [];
        
        alerts.forEach(alert => {
            const alertColor = getAlertColor(alert.type, alert.severity);
            const marker = L.circleMarker([alert.latitude, alert.longitude], {
                color: 'white',
                fillColor: alertColor,
                fillOpacity: 0.8,
                radius: 8 + (alert.severity * 2),
                weight: 2
            }).addTo(alertMap);
            
            const popupContent = `
                <div class="p-2">
                    <h4 class="font-bold text-lg">${alert.type.charAt(0).toUpperCase() + alert.type.slice(1)}</h4>
                    <p class="text-sm text-gray-600 mb-2">${alert.description || 'No description'}</p>
                    <div class="space-y-1 text-sm">
                        <p><strong>Reporter:</strong> ${alert.user_name}</p>
                        <p><strong>Confirmations:</strong> ${alert.confirmed_count}</p>
                        <p><strong>Severity:</strong> ${alert.severity}/5</p>
                        <p><strong>Time:</strong> ${new Date(alert.created_at).toLocaleString()}</p>
                        <p><strong>Status:</strong> ${alert.is_active ? 'Active' : 'Inactive'}</p>
                    </div>
                    <button onclick="showAlertDetails(${alert.id})" class="mt-2 bg-blue-500 hover:bg-blue-700 text-white font-bold py-1 px-2 rounded text-xs">
                        View Details
                    </button>
                </div>
            `;
            
            marker.bindPopup(popupContent);
            alertMarkers.push(marker);
        });
        
        // Fit map bounds to show all markers
        if (alertMarkers.length > 0) {
            const group = new L.featureGroup(alertMarkers);
            alertMap.fitBounds(group.getBounds().pad(0.1));
        }
    }
    
    function getAlertColor(type, severity) {
        const colors = {
            'police': '#3B82F6',
            'accident': '#EF4444',
            'roadwork': '#F59E0B',
            'traffic': '#EF4444',
            'obstacle': '#8B5CF6',
            'fire': '#DC2626',
            'blocked_road': '#6B7280'
        };
        
        return colors[type] || '#6B7280';
    }
    
    // Show alert details modal
    function showAlertDetails(alertId) {
        fetch(`/superadmin/api/alert/${alertId}`)
            .then(response => response.json())
            .then(data => {
                const content = `
                    <div class="space-y-4">
                        <div class="grid grid-cols-2 gap-4">
                            <div>
                                <label class="block text-sm font-medium text-gray-700">Type</label>
                                <p class="mt-1 text-sm text-gray-900">${data.type.charAt(0).toUpperCase() + data.type.slice(1)}</p>
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700">Severity</label>
                                <p class="mt-1 text-sm text-gray-900">${data.severity}/5</p>
                            </div>
                        </div>
                        
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Location</label>
                            <p class="mt-1 text-sm text-gray-900">${data.latitude}, ${data.longitude}</p>
                        </div>
                        
                        ${data.description ? `
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Description</label>
                            <p class="mt-1 text-sm text-gray-900">${data.description}</p>
                        </div>
                        ` : ''}
                        
                        <div class="grid grid-cols-2 gap-4">
                            <div>
                                <label class="block text-sm font-medium text-gray-700">Confirmations</label>
                                <p class="mt-1 text-sm text-gray-900">${data.confirmed_count}</p>
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700">Status</label>
                                <span class="mt-1 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${data.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}">
                                    ${data.is_active ? 'Active' : 'Inactive'}
                                </span>
                            </div>
                        </div>
                        
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Reporter</label>
                            <p class="mt-1 text-sm text-gray-900">${data.user.name} (${data.user.email})</p>
                        </div>
                        
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Created</label>
                            <p class="mt-1 text-sm text-gray-900">${data.created_at}</p>
                        </div>
                        
                        ${data.confirmations.length > 0 ? `
                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">Confirmed By</label>
                            <div class="space-y-1 max-h-32 overflow-y-auto">
                                ${data.confirmations.map(conf => `
                                    <div class="text-sm text-gray-600 bg-gray-50 p-2 rounded">
                                        ${conf.user_name} (${conf.user_email}) - ${conf.created_at}
                                    </div>
                                `).join('')}
                            </div>
                        </div>
                        ` : ''}
                    </div>
                `;
                
                document.getElementById('alert-details-content').innerHTML = content;
                document.getElementById('alert-modal').classList.remove('hidden');
            })
            .catch(error => {
                console.error('Error fetching alert details:', error);
                alert('Error loading alert details');
            });
    }
    
    function closeAlertModal() {
        document.getElementById('alert-modal').classList.add('hidden');
    }
    
    // Auto-refresh dashboard data every 30 seconds
    function refreshDashboard() {
        fetch('/superadmin/api/dashboard-data')
            .then(response => response.json())
            .then(data => {
                // Update statistics
                document.getElementById('total-users').textContent = data.stats.total_users;
                document.getElementById('online-users').textContent = data.stats.online_users;
                document.getElementById('total-alerts').textContent = data.stats.total_alerts;
                document.getElementById('active-alerts').textContent = data.stats.active_alerts;
                document.getElementById('alerts-today').textContent = data.stats.alerts_today;
                document.getElementById('confirmations-today').textContent = data.stats.confirmations_today;
                
                // Update online users list
                const onlineUsersList = document.getElementById('online-users-list');
                if (data.online_users.length > 0) {
                    onlineUsersList.innerHTML = data.online_users.map(user => `
                        <div class="flex items-center p-3 bg-gray-50 rounded-lg">
                            <div class="w-2 h-2 bg-green-500 rounded-full mr-3"></div>
                            <div class="flex-1">
                                <p class="text-sm font-medium text-gray-900">${user.name}</p>
                                <p class="text-xs text-gray-600">${user.email}</p>
                                <p class="text-xs text-green-600">Last seen: ${new Date(user.updated_at).toLocaleString()}</p>
                            </div>
                        </div>
                    `).join('');
                } else {
                    onlineUsersList.innerHTML = `
                        <div class="text-center py-8">
                            <i class="fas fa-user-slash text-gray-400 text-3xl mb-2"></i>
                            <p class="text-gray-600">No users currently online</p>
                        </div>
                    `;
                }
            })
            .catch(error => console.error('Error refreshing dashboard:', error));
    }
    
    // Initialize when page loads
    document.addEventListener('DOMContentLoaded', function() {
        initMap();
        
        // Refresh dashboard every 30 seconds
        setInterval(refreshDashboard, 30000);
    });
</script>
@endpush