<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'SuperAdmin Panel') - Traffic Alert App</title>
    
    <!-- Tailwind CSS -->
    <script src="https://cdn.tailwindcss.com"></script>
    
    <!-- Font Awesome -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    
    <!-- Leaflet CSS for Maps -->
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    
    <!-- Chart.js -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    
    <style>
        .sidebar-active {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .stat-card {
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
        }
        .alert-marker {
            border-radius: 50%;
            border: 2px solid white;
            box-shadow: 0 0 10px rgba(0,0,0,0.3);
        }
        .leaflet-popup-content {
            margin: 8px 12px;
            min-width: 200px;
        }
    </style>
</head>
<body class="bg-gray-50">
    <div class="flex h-screen">
        <!-- Sidebar -->
        <div class="w-64 bg-white shadow-lg">
            <div class="p-6 border-b">
                <h1 class="text-xl font-bold text-gray-800">
                    <i class="fas fa-shield-halved text-blue-600 mr-2"></i>
                    SuperAdmin Panel
                </h1>
            </div>
            
            <nav class="mt-6">
                <a href="{{ route('superadmin.dashboard') }}" 
                   class="flex items-center px-6 py-3 text-gray-700 hover:bg-blue-50 hover:text-blue-600 {{ request()->routeIs('superadmin.dashboard') ? 'sidebar-active text-white' : '' }}">
                    <i class="fas fa-dashboard mr-3"></i>
                    Dashboard
                </a>
                
                <a href="{{ route('superadmin.users') }}" 
                   class="flex items-center px-6 py-3 text-gray-700 hover:bg-blue-50 hover:text-blue-600 {{ request()->routeIs('superadmin.users') ? 'sidebar-active text-white' : '' }}">
                    <i class="fas fa-users mr-3"></i>
                    Users
                </a>
                
                <a href="{{ route('superadmin.alerts') }}" 
                   class="flex items-center px-6 py-3 text-gray-700 hover:bg-blue-50 hover:text-blue-600 {{ request()->routeIs('superadmin.alerts') ? 'sidebar-active text-white' : '' }}">
                    <i class="fas fa-triangle-exclamation mr-3"></i>
                    Alerts
                </a>
                
                <div class="border-t mt-6 pt-6">
                    <a href="{{ route('dashboard') }}" 
                       class="flex items-center px-6 py-3 text-gray-700 hover:bg-gray-50">
                        <i class="fas fa-arrow-left mr-3"></i>
                        Back to App
                    </a>
                    
                    <form method="POST" action="{{ route('logout') }}">
                        @csrf
                        <button type="submit" class="flex items-center w-full px-6 py-3 text-gray-700 hover:bg-red-50 hover:text-red-600">
                            <i class="fas fa-sign-out-alt mr-3"></i>
                            Logout
                        </button>
                    </form>
                </div>
            </nav>
        </div>
        
        <!-- Main Content -->
        <div class="flex-1 flex flex-col overflow-hidden">
            <!-- Header -->
            <header class="bg-white shadow-sm border-b">
                <div class="px-6 py-4">
                    <div class="flex justify-between items-center">
                        <h2 class="text-2xl font-bold text-gray-800">
                            @yield('header', 'Dashboard')
                        </h2>
                        
                        <div class="flex items-center space-x-4">
                            <div class="text-sm text-gray-600">
                                <i class="fas fa-user mr-1"></i>
                                {{ Auth::user()->name }}
                            </div>
                            
                            <div class="text-sm text-gray-600">
                                <i class="fas fa-clock mr-1"></i>
                                <span id="current-time"></span>
                            </div>
                        </div>
                    </div>
                </div>
            </header>
            
            <!-- Page Content -->
            <main class="flex-1 overflow-y-auto p-6">
                @yield('content')
            </main>
        </div>
    </div>
    
    <!-- Leaflet JS -->
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    
    <!-- Socket.IO for real-time updates -->
    <script src="https://cdn.socket.io/4.7.2/socket.io.min.js"></script>
    
    <script>
        // Update current time
        function updateTime() {
            const now = new Date();
            document.getElementById('current-time').textContent = now.toLocaleTimeString();
        }
        updateTime();
        setInterval(updateTime, 1000);
        
        // CSRF token setup for AJAX
        window.Laravel = {
            csrfToken: '{{ csrf_token() }}'
        };
        
        // Global AJAX setup
        fetch.defaults = {
            headers: {
                'X-CSRF-TOKEN': window.Laravel.csrfToken,
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
        };
    </script>
    
    @stack('scripts')
</body>
</html>