@extends('layouts.superadmin')

@section('title', 'Alerts Management')
@section('header', 'Alerts Management')

@section('content')
<div class="space-y-6">
    <!-- Search and Filters -->
    <div class="bg-white rounded-lg shadow-sm p-6">
        <form method="GET" action="{{ route('superadmin.alerts') }}" class="space-y-4 md:space-y-0 md:grid md:grid-cols-6 md:gap-4">
            <div class="md:col-span-2">
                <label for="search" class="block text-sm font-medium text-gray-700 mb-1">Search Alerts</label>
                <input type="text" 
                       name="search" 
                       id="search"
                       value="{{ request('search') }}"
                       placeholder="Search by description or user..."
                       class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            </div>
            
            <div>
                <label for="type" class="block text-sm font-medium text-gray-700 mb-1">Alert Type</label>
                <select name="type" id="type" class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                    <option value="">All Types</option>
                    @foreach($alertTypes as $type)
                    <option value="{{ $type }}" {{ request('type') == $type ? 'selected' : '' }}>
                        {{ ucfirst($type) }}
                    </option>
                    @endforeach
                </select>
            </div>
            
            <div>
                <label for="status" class="block text-sm font-medium text-gray-700 mb-1">Status</label>
                <select name="status" id="status" class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                    <option value="">All Status</option>
                    <option value="active" {{ request('status') == 'active' ? 'selected' : '' }}>Active</option>
                    <option value="inactive" {{ request('status') == 'inactive' ? 'selected' : '' }}>Inactive</option>
                </select>
            </div>
            
            <div>
                <label for="date_from" class="block text-sm font-medium text-gray-700 mb-1">From Date</label>
                <input type="date" 
                       name="date_from" 
                       id="date_from"
                       value="{{ request('date_from') }}"
                       class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            </div>
            
            <div>
                <label for="date_to" class="block text-sm font-medium text-gray-700 mb-1">To Date</label>
                <input type="date" 
                       name="date_to" 
                       id="date_to"
                       value="{{ request('date_to') }}"
                       class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            </div>
            
            <div class="md:col-span-6 flex space-x-2">
                <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2">
                    <i class="fas fa-search mr-1"></i> Filter
                </button>
                
                <a href="{{ route('superadmin.alerts') }}" class="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2">
                    <i class="fas fa-refresh mr-1"></i> Reset
                </a>
                
                <button type="button" onclick="bulkDeleteSelected()" class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2">
                    <i class="fas fa-trash mr-1"></i> Delete Selected
                </button>
            </div>
        </form>
    </div>
    
    <!-- Statistics Summary -->
    <div class="grid grid-cols-1 md:grid-cols-5 gap-6">
        <div class="bg-white p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-blue-500 rounded-full">
                    <i class="fas fa-triangle-exclamation text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">Total Alerts</p>
                    <p class="text-2xl font-bold text-gray-900">{{ $alerts->total() }}</p>
                </div>
            </div>
        </div>
        
        <div class="bg-white p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-green-500 rounded-full">
                    <i class="fas fa-check-circle text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">Active Alerts</p>
                    <p class="text-2xl font-bold text-gray-900">{{ \App\Models\Alert::where('is_active', true)->count() }}</p>
                </div>
            </div>
        </div>
        
        <div class="bg-white p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-yellow-500 rounded-full">
                    <i class="fas fa-calendar-day text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">Today's Alerts</p>
                    <p class="text-2xl font-bold text-gray-900">{{ \App\Models\Alert::whereDate('created_at', today())->count() }}</p>
                </div>
            </div>
        </div>
        
        <div class="bg-white p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-purple-500 rounded-full">
                    <i class="fas fa-thumbs-up text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">Confirmations</p>
                    <p class="text-2xl font-bold text-gray-900">{{ \App\Models\AlertConfirmation::count() }}</p>
                </div>
            </div>
        </div>
        
        <div class="bg-white p-6 rounded-lg shadow-sm">
            <div class="flex items-center">
                <div class="p-3 bg-red-500 rounded-full">
                    <i class="fas fa-clock text-white text-xl"></i>
                </div>
                <div class="ml-4">
                    <p class="text-sm font-medium text-gray-600">This Week</p>
                    <p class="text-2xl font-bold text-gray-900">{{ \App\Models\Alert::where('created_at', '>=', now()->subWeek())->count() }}</p>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Alerts Table -->
    <div class="bg-white rounded-lg shadow-sm overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
            <h3 class="text-lg font-semibold text-gray-900">
                <i class="fas fa-triangle-exclamation mr-2"></i>
                Alerts List
                @if(request()->hasAny(['search', 'type', 'status', 'date_from', 'date_to']))
                    <span class="text-sm font-normal text-gray-600">- Filtered results</span>
                @endif
            </h3>
            
            <div class="flex items-center space-x-2">
                <label class="flex items-center text-sm">
                    <input type="checkbox" id="select-all" class="mr-2 rounded border-gray-300 text-blue-600 focus:ring-blue-500">
                    Select All
                </label>
            </div>
        </div>
        
        @if($alerts->count() > 0)
        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            <input type="checkbox" id="header-checkbox" class="rounded border-gray-300 text-blue-600 focus:ring-blue-500">
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Alert Info</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Location</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Reporter</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Confirmations</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Created</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                    </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                    @foreach($alerts as $alert)
                    <tr class="hover:bg-gray-50" id="alert-row-{{ $alert->id }}">
                        <td class="px-6 py-4 whitespace-nowrap">
                            <input type="checkbox" class="alert-checkbox rounded border-gray-300 text-blue-600 focus:ring-blue-500" value="{{ $alert->id }}">
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <div class="flex items-center">
                                <div class="flex-shrink-0">
                                    <i class="fas fa-triangle-exclamation text-{{ $alert->severity >= 3 ? 'red' : ($alert->severity >= 2 ? 'yellow' : 'blue') }}-500 text-lg"></i>
                                </div>
                                <div class="ml-4">
                                    <div class="text-sm font-medium text-gray-900">{{ ucfirst($alert->type) }}</div>
                                    <div class="text-sm text-gray-500">Severity: {{ $alert->severity }}/5</div>
                                    @if($alert->description)
                                    <div class="text-xs text-gray-400 mt-1">{{ Str::limit($alert->description, 50) }}</div>
                                    @endif
                                </div>
                            </div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            <div>{{ number_format($alert->latitude, 6) }}</div>
                            <div>{{ number_format($alert->longitude, 6) }}</div>
                            <button onclick="showOnMap({{ $alert->latitude }}, {{ $alert->longitude }})" class="text-blue-600 hover:text-blue-900 text-xs">
                                <i class="fas fa-map-marker-alt mr-1"></i>View on Map
                            </button>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <div class="text-sm text-gray-900">{{ $alert->user->name ?? 'Unknown' }}</div>
                            <div class="text-sm text-gray-500">{{ $alert->user->email ?? 'Unknown' }}</div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                {{ $alert->confirmed_count }} confirmations
                            </span>
                            @if($alert->dismissed_count > 0)
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800 mt-1">
                                {{ $alert->dismissed_count }} dismissed
                            </span>
                            @endif
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            <div>{{ $alert->created_at->format('M d, Y') }}</div>
                            <div>{{ $alert->created_at->format('H:i') }}</div>
                            <div class="text-xs text-gray-400">{{ $alert->created_at->diffForHumans() }}</div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <button onclick="toggleAlertStatus({{ $alert->id }})" class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium cursor-pointer {{ $alert->is_active ? 'bg-green-100 text-green-800 hover:bg-green-200' : 'bg-gray-100 text-gray-800 hover:bg-gray-200' }}">
                                <i class="fas fa-{{ $alert->is_active ? 'check-circle' : 'times-circle' }} mr-1"></i>
                                {{ $alert->is_active ? 'Active' : 'Inactive' }}
                            </button>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                            <button onclick="showAlertDetails({{ $alert->id }})" class="text-blue-600 hover:text-blue-900">
                                <i class="fas fa-eye"></i>
                            </button>
                            <button onclick="deleteAlert({{ $alert->id }})" class="text-red-600 hover:text-red-900">
                                <i class="fas fa-trash"></i>
                            </button>
                        </td>
                    </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
        
        <!-- Pagination -->
        <div class="bg-white px-4 py-3 border-t border-gray-200 sm:px-6">
            {{ $alerts->appends(request()->query())->links() }}
        </div>
        @else
        <div class="text-center py-12">
            <i class="fas fa-triangle-exclamation text-gray-400 text-4xl mb-4"></i>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No alerts found</h3>
            @if(request()->hasAny(['search', 'type', 'status', 'date_from', 'date_to']))
                <p class="text-gray-600">No alerts match your filter criteria.</p>
                <a href="{{ route('superadmin.alerts') }}" class="mt-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-blue-700 bg-blue-100 hover:bg-blue-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                    <i class="fas fa-arrow-left mr-2"></i>
                    View all alerts
                </a>
            @else
                <p class="text-gray-600">No alerts have been reported yet.</p>
            @endif
        </div>
        @endif
    </div>
</div>

<!-- Alert Details Modal -->
<div id="alert-modal" class="fixed inset-0 bg-gray-600 bg-opacity-50 hidden z-50">
    <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full">
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

<!-- Map Modal -->
<div id="map-modal" class="fixed inset-0 bg-gray-600 bg-opacity-50 hidden z-50">
    <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full">
            <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div class="sm:flex sm:items-start">
                    <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                            Alert Location
                        </h3>
                        <div id="location-map" style="height: 400px; border-radius: 8px;"></div>
                    </div>
                </div>
            </div>
            <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <button type="button" class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm" onclick="closeMapModal()">
                    Close
                </button>
            </div>
        </div>
    </div>
</div>
@endsection

@push('scripts')
<script>
let locationMap;

// Show alert details modal
function showAlertDetails(alertId) {
    fetch(`/superadmin/api/alert/${alertId}`)
        .then(response => response.json())
        .then(data => {
            const content = `
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div class="space-y-4">
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Alert Type</label>
                            <p class="mt-1 text-sm text-gray-900 capitalize">${data.type}</p>
                        </div>
                        
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Severity</label>
                            <p class="mt-1 text-sm text-gray-900">${data.severity}/5</p>
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
                                <label class="block text-sm font-medium text-gray-700">Dismissed</label>
                                <p class="mt-1 text-sm text-gray-900">${data.dismissed_count}</p>
                            </div>
                        </div>
                        
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Status</label>
                            <span class="mt-1 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${data.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}">
                                ${data.is_active ? 'Active' : 'Inactive'}
                            </span>
                        </div>
                    </div>
                    
                    <div class="space-y-4">
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Reporter</label>
                            <div class="mt-1 text-sm text-gray-900">
                                <p class="font-medium">${data.user.name}</p>
                                <p class="text-gray-600">${data.user.email}</p>
                                ${data.user.username ? `<p class="text-gray-600">@${data.user.username}</p>` : ''}
                            </div>
                        </div>
                        
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Created</label>
                            <p class="mt-1 text-sm text-gray-900">${data.created_at}</p>
                        </div>
                        
                        ${data.expires_at ? `
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Expires</label>
                            <p class="mt-1 text-sm text-gray-900">${data.expires_at}</p>
                        </div>
                        ` : ''}
                        
                        ${data.confirmations.length > 0 ? `
                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">Confirmed By</label>
                            <div class="space-y-2 max-h-32 overflow-y-auto">
                                ${data.confirmations.map(conf => `
                                    <div class="text-sm bg-gray-50 p-2 rounded">
                                        <p class="font-medium">${conf.user_name}</p>
                                        <p class="text-gray-600 text-xs">${conf.user_email}</p>
                                        <p class="text-gray-500 text-xs">${conf.created_at}</p>
                                    </div>
                                `).join('')}
                            </div>
                        </div>
                        ` : ''}
                    </div>
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

// Show location on map
function showOnMap(lat, lng) {
    if (!locationMap) {
        locationMap = L.map('location-map').setView([lat, lng], 15);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors'
        }).addTo(locationMap);
    } else {
        locationMap.setView([lat, lng], 15);
        locationMap.eachLayer(function (layer) {
            if (layer instanceof L.Marker) {
                locationMap.removeLayer(layer);
            }
        });
    }
    
    L.marker([lat, lng]).addTo(locationMap)
        .bindPopup(`Alert Location<br>Lat: ${lat}<br>Lng: ${lng}`)
        .openPopup();
    
    document.getElementById('map-modal').classList.remove('hidden');
    
    // Trigger map resize after modal is shown
    setTimeout(() => {
        locationMap.invalidateSize();
    }, 300);
}

function closeMapModal() {
    document.getElementById('map-modal').classList.add('hidden');
}

// Delete alert
function deleteAlert(alertId) {
    if (confirm('Are you sure you want to delete this alert? This action cannot be undone.')) {
        fetch(`/superadmin/api/alert/${alertId}`, {
            method: 'DELETE',
            headers: {
                'X-CSRF-TOKEN': window.Laravel.csrfToken,
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                document.getElementById(`alert-row-${alertId}`).remove();
                showNotification('Alert deleted successfully', 'success');
            } else {
                showNotification('Error deleting alert', 'error');
            }
        })
        .catch(error => {
            console.error('Error deleting alert:', error);
            showNotification('Error deleting alert', 'error');
        });
    }
}

// Toggle alert status
function toggleAlertStatus(alertId) {
    fetch(`/superadmin/api/alert/${alertId}/toggle`, {
        method: 'PATCH',
        headers: {
            'X-CSRF-TOKEN': window.Laravel.csrfToken,
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            location.reload(); // Reload to update the status display
            showNotification('Alert status updated successfully', 'success');
        } else {
            showNotification('Error updating alert status', 'error');
        }
    })
    .catch(error => {
        console.error('Error updating alert status:', error);
        showNotification('Error updating alert status', 'error');
    });
}

// Bulk delete functionality
function bulkDeleteSelected() {
    const selectedAlerts = Array.from(document.querySelectorAll('.alert-checkbox:checked')).map(cb => cb.value);
    
    if (selectedAlerts.length === 0) {
        alert('Please select alerts to delete');
        return;
    }
    
    if (confirm(`Are you sure you want to delete ${selectedAlerts.length} selected alerts? This action cannot be undone.`)) {
        Promise.all(selectedAlerts.map(alertId => 
            fetch(`/superadmin/api/alert/${alertId}`, {
                method: 'DELETE',
                headers: {
                    'X-CSRF-TOKEN': window.Laravel.csrfToken,
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                }
            })
        ))
        .then(() => {
            location.reload();
            showNotification(`${selectedAlerts.length} alerts deleted successfully`, 'success');
        })
        .catch(error => {
            console.error('Error deleting alerts:', error);
            showNotification('Error deleting some alerts', 'error');
        });
    }
}

// Select all functionality
document.getElementById('header-checkbox').addEventListener('change', function() {
    const checkboxes = document.querySelectorAll('.alert-checkbox');
    checkboxes.forEach(cb => cb.checked = this.checked);
});

// Show notification
function showNotification(message, type) {
    // Simple notification - you can enhance this with a proper notification library
    const notification = document.createElement('div');
    notification.className = `fixed top-4 right-4 p-4 rounded-md z-50 ${type === 'success' ? 'bg-green-500' : 'bg-red-500'} text-white`;
    notification.textContent = message;
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.remove();
    }, 3000);
}
</script>
@endpush