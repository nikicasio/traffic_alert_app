# Flutter App Loading Issues - Troubleshooting Guide

## Issue Analysis

Based on your description, the Flutter app shows only a loading screen after closing and reopening. This suggests:

1. **App Lifecycle Issues**: The app is detecting lifecycle changes but failing to reconnect properly
2. **Surface/Rendering Issues**: GraphicBufferAllocator failures indicate memory or graphics issues
3. **Missing Reconnection Logic**: Custom Flutter logs for reconnection are not appearing

## Key Areas to Investigate

### 1. Server-Side Connectivity Issues

The app may be hanging because it's waiting for server responses that never come. Check these specific aspects:

#### A. Laravel API Server Status
```bash
# Check if Laravel is running and responding
curl -v http://159.69.41.118/api/health
curl -v -H "Accept: application/json" http://159.69.41.118/api/health

# Check Laravel error logs for recent errors
tail -f /path/to/laravel/storage/logs/laravel.log

# Check web server logs
tail -f /var/log/nginx/error.log
tail -f /var/log/nginx/access.log
```

#### B. Socket.IO Server Status
```bash
# Check if Socket.IO server is running
ps aux | grep node
ps aux | grep socket-server

# Test Socket.IO health endpoint
curl -v http://159.69.41.118:3001/health

# Check if Socket.IO is listening on correct port
netstat -tlnp | grep 3001
ss -tlnp | grep 3001

# Test Socket.IO connection from command line
npm install -g socket.io-client
node -e "
const io = require('socket.io-client');
const socket = io('http://159.69.41.118:3001');
socket.on('connect', () => {
  console.log('✅ Socket.IO connected successfully');
  process.exit(0);
});
socket.on('connect_error', (err) => {
  console.log('❌ Socket.IO connection failed:', err);
  process.exit(1);
});
setTimeout(() => {
  console.log('❌ Socket.IO connection timeout');
  process.exit(1);
}, 10000);
"
```

### 2. Authentication Token Issues

The app might be hanging on authentication checks:

```bash
# Test login endpoint
curl -X POST http://159.69.41.118/api/auth/login \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password"
  }' -v

# Test with stored token (replace with actual token)
curl -X GET http://159.69.41.118/api/auth/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Accept: application/json" -v
```

### 3. Database Connectivity Issues

```bash
# Check if database is accessible
cd /path/to/laravel
php artisan tinker
# Then run these commands in tinker:
# DB::connection()->getPdo();
# \App\Models\User::count();

# Check database server status
systemctl status mysql
# or
systemctl status postgresql

# Check database logs
tail -f /var/log/mysql/error.log
# or
tail -f /var/log/postgresql/postgresql-*.log
```

### 4. Memory and Resource Issues

The GraphicBufferAllocator failures suggest memory issues:

```bash
# Check system memory
free -h
cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable)"

# Check swap usage
swapon --show
cat /proc/swaps

# Check if system is under memory pressure
dmesg | grep -i "out of memory"
dmesg | grep -i "killed process"

# Check system load
uptime
cat /proc/loadavg

# Check disk space (full disk can cause issues)
df -h
du -sh /tmp /var/log /var/cache
```

### 5. Network and Firewall Issues

```bash
# Check if firewall is blocking connections
ufw status verbose
iptables -L -n | grep -E "(80|3001)"

# Test connectivity from different locations
# From server itself
curl -s localhost:80/api/health
curl -s localhost:3001/health

# Check for network issues
ping -c 4 159.69.41.118
traceroute 159.69.41.118

# Check DNS resolution
nslookup 159.69.41.118
dig 159.69.41.118
```

### 6. Process Management Issues

```bash
# Check if processes are running properly
ps aux | grep -E "(nginx|apache|php-fpm|node)"

# Check process limits
ulimit -a

# Check if any processes are zombie or hanging
ps aux | grep -E "(Z|<defunct>)"

# If using PM2 for Node.js
pm2 list
pm2 logs socket-server --lines 50
pm2 restart socket-server
```

### 7. Application Configuration Issues

#### Laravel Configuration
```bash
cd /path/to/laravel

# Check Laravel configuration
php artisan config:show

# Clear and rebuild caches
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# Check environment configuration
cat .env | grep -E "(APP_|DB_|BROADCAST_)"

# Test database migrations
php artisan migrate:status
```

#### Socket.IO Configuration
```bash
cd /path/to/socket-server

# Check Node.js version compatibility
node --version
npm --version

# Verify dependencies
npm list socket.io express cors

# Test Socket.IO server directly
node -c socket-server.cjs  # Check syntax
DEBUG=socket.io* node socket-server.cjs  # Run with debug output
```

### 8. Monitoring Commands

Create a monitoring script to continuously check server status:

```bash
#!/bin/bash
# Save as monitor_server.sh

while true; do
    echo "=== $(date) ==="
    
    # Test Laravel API
    if curl -s --connect-timeout 5 http://159.69.41.118/api/health > /dev/null; then
        echo "✅ Laravel API: OK"
    else
        echo "❌ Laravel API: FAILED"
    fi
    
    # Test Socket.IO
    if curl -s --connect-timeout 5 http://159.69.41.118:3001/health > /dev/null; then
        echo "✅ Socket.IO: OK"
    else
        echo "❌ Socket.IO: FAILED"
    fi
    
    # Check memory usage
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    echo "Memory Usage: ${MEM_USAGE}%"
    
    # Check load average
    LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)
    echo "Load Average: ${LOAD}"
    
    echo "---"
    sleep 30
done
```

### 9. Specific Checks for App Loading Issues

#### Check Critical Endpoints Used by App
```bash
# Test the endpoints that the app calls during startup
# (based on your RealApiService.dart)

# 1. API reachability check
curl -I --connect-timeout 5 http://159.69.41.118/api

# 2. Health check with timeout
curl --connect-timeout 5 --max-time 15 http://159.69.41.118/api/health

# 3. Test alerts endpoint (the one most likely to be called first)
curl -X GET "http://159.69.41.118/api/alerts?latitude=40.7128&longitude=-74.0060&radius=10000" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer TOKEN_HERE" \
  --connect-timeout 10 --max-time 30 -v
```

#### Check Socket.IO Connection Process
```bash
# Test the exact Socket.IO connection flow that the app uses
node -e "
const io = require('socket.io-client');
console.log('Attempting to connect to Socket.IO server...');

const socket = io('http://159.69.41.118:3001', {
  transports: ['websocket'],
  autoConnect: false,
  auth: {
    userId: 'test-user-123',
    authToken: 'test-token'
  }
});

socket.on('connect', () => {
  console.log('✅ Connected to Socket.IO server');
  
  // Test authentication flow
  socket.emit('authenticate', {
    userId: 'test-user-123',
    authToken: 'test-token'
  });
});

socket.on('authenticated', (data) => {
  console.log('✅ Successfully authenticated:', data);
  socket.disconnect();
  process.exit(0);
});

socket.on('authentication_failed', (data) => {
  console.log('❌ Authentication failed:', data);
  process.exit(1);
});

socket.on('connect_error', (err) => {
  console.log('❌ Connection error:', err.message);
  process.exit(1);
});

socket.on('error', (err) => {
  console.log('❌ Socket error:', err);
  process.exit(1);
});

// Start connection
socket.connect();

// Timeout after 15 seconds
setTimeout(() => {
  console.log('❌ Connection timeout after 15 seconds');
  process.exit(1);
}, 15000);
"
```

### 10. Recovery Actions

If issues are found, here are the recovery steps:

#### Restart Services
```bash
# Restart web server
systemctl restart nginx
# or
systemctl restart apache2

# Restart PHP-FPM
systemctl restart php8.2-fpm

# Restart Socket.IO server (if using PM2)
pm2 restart socket-server
# or if running directly
pkill -f socket-server
nohup node socket-server.cjs > socket.log 2>&1 &

# Restart database if needed
systemctl restart mysql
```

#### Clear Caches and Logs
```bash
# Clear Laravel caches
cd /path/to/laravel
php artisan config:clear
php artisan cache:clear
php artisan route:clear

# Clear system caches
sync && echo 3 > /proc/sys/vm/drop_caches

# Rotate logs if they're too large
logrotate -f /etc/logrotate.conf
```

#### Check and Fix Permissions
```bash
# Fix Laravel permissions
cd /path/to/laravel
chown -R www-data:www-data storage/
chmod -R 775 storage/
chmod -R 775 bootstrap/cache/
```

This comprehensive troubleshooting guide should help you identify the root cause of the app loading issues. Start with the server health checks and work your way through the different areas systematically.