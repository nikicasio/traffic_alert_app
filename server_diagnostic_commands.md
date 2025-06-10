# Server Diagnostic Commands for Traffic Alert App

## 1. Health Check Commands

### Test Laravel API Health Endpoint
```bash
# Basic health check
curl -X GET http://159.69.41.118/api/health -H "Accept: application/json" -v

# Test with timeout
curl -X GET http://159.69.41.118/api/health -H "Accept: application/json" --connect-timeout 10 --max-time 30 -v

# Check response headers and status
curl -I http://159.69.41.118/api/health
```

### Test Socket.IO Server
```bash
# Test Socket.IO health endpoint
curl -X GET http://159.69.41.118:3001/health -H "Accept: application/json" -v

# Test Socket.IO base endpoint
curl -X GET http://159.69.41.118:3001/ -v

# Check if Socket.IO is responding to HTTP upgrade requests
curl -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" -H "Sec-WebSocket-Version: 13" http://159.69.41.118:3001/socket.io/ -v
```

## 2. Server Status and Logs

### Check Server Processes
```bash
# Check if Laravel/PHP processes are running
ps aux | grep php
ps aux | grep nginx
ps aux | grep apache

# Check if Node.js Socket.IO server is running
ps aux | grep node
ps aux | grep socket-server

# Check listening ports
netstat -tlnp | grep :80
netstat -tlnp | grep :3001
ss -tlnp | grep :80
ss -tlnp | grep :3001
```

### Check Server Logs
```bash
# Laravel logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
tail -f /path/to/laravel/storage/logs/laravel.log

# System logs
journalctl -f -u nginx
journalctl -f -u php-fpm
dmesg | tail -20

# If using PM2 for Node.js
pm2 logs socket-server
pm2 status
```

## 3. Network and Connectivity Tests

### Test Network Connectivity
```bash
# Test basic connectivity to server
ping 159.69.41.118

# Test port connectivity
telnet 159.69.41.118 80
telnet 159.69.41.118 3001

# Using nc (netcat) if telnet not available
nc -zv 159.69.41.118 80
nc -zv 159.69.41.118 3001

# Test from multiple locations
nmap -p 80,3001 159.69.41.118
```

### Test Laravel API Endpoints
```bash
# Test alerts endpoint (requires authentication)
curl -X GET "http://159.69.41.118/api/alerts?latitude=40.7128&longitude=-74.0060&radius=10000" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" -v

# Test authentication endpoints
curl -X POST http://159.69.41.118/api/auth/login \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"email":"test@example.com","password":"password"}' -v
```

## 4. Server Configuration Checks

### Check Web Server Configuration
```bash
# Check nginx configuration
nginx -t
cat /etc/nginx/sites-available/default

# Check Apache configuration (if using Apache)
apache2ctl configtest
cat /etc/apache2/sites-available/000-default.conf

# Check PHP-FPM status
systemctl status php8.2-fpm
# or
systemctl status php-fpm
```

### Check Firewall and Security
```bash
# Check firewall rules
ufw status verbose
iptables -L -n

# Check if ports are blocked
iptables -L INPUT -n | grep -E "(80|3001)"

# Check SELinux status (if applicable)
sestatus
```

## 5. Application-Specific Diagnostics

### Laravel Application
```bash
# Check Laravel configuration
cd /path/to/laravel/app
php artisan config:cache
php artisan route:cache
php artisan optimize

# Check database connectivity
php artisan tinker
# Then run: DB::connection()->getPdo();

# Check storage permissions
ls -la storage/
chmod -R 775 storage/
```

### Socket.IO Server
```bash
# Check if Node.js dependencies are installed
cd /path/to/socket-server
npm list
node -v
npm -v

# Test Socket.IO server directly
node socket-server.cjs

# Check for any JavaScript errors
node --trace-warnings socket-server.cjs
```

## 6. Resource Usage Monitoring

### Check System Resources
```bash
# Check memory usage
free -h
cat /proc/meminfo

# Check CPU usage
top -bn1 | head -20
htop

# Check disk space
df -h
du -sh /var/log/

# Check load average
uptime
cat /proc/loadavg
```

## 7. Debugging Commands for Loading Issues

### Laravel Debug Mode
```bash
# Enable debug mode temporarily
echo "APP_DEBUG=true" >> .env
php artisan config:cache

# Check Laravel logs for errors
tail -f storage/logs/laravel-$(date +%Y-%m-%d).log
```

### Socket.IO Debug Mode
```bash
# Run Socket.IO server with debug output
DEBUG=socket.io* node socket-server.cjs

# Or set environment variable
export DEBUG=socket.io*
node socket-server.cjs
```

## 8. Common Issues and Solutions

### Issue: API Returns 500 Errors
```bash
# Check Laravel error logs
tail -50 storage/logs/laravel.log

# Check PHP error logs
tail -50 /var/log/php_errors.log

# Verify database connection
php artisan migrate:status
```

### Issue: Socket.IO Connection Refused
```bash
# Check if port 3001 is open
netstat -tlnp | grep 3001

# Test Socket.IO from command line
npm install -g socket.io-client
echo "
const io = require('socket.io-client');
const socket = io('http://159.69.41.118:3001');
socket.on('connect', () => console.log('Connected!'));
socket.on('disconnect', () => console.log('Disconnected!'));
" > test-socket.js
node test-socket.js
```

### Issue: CORS Errors
```bash
# Check if CORS headers are being sent
curl -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: X-Requested-With" \
  -X OPTIONS \
  http://159.69.41.118/api/health -v
```

## 9. Performance Testing

### Load Testing
```bash
# Install apache bench (ab)
apt-get install apache2-utils

# Test API performance
ab -n 100 -c 10 http://159.69.41.118/api/health

# Test Socket.IO performance
# (requires specialized tools like artillery or custom scripts)
```

## 10. Automated Health Check Script

```bash
#!/bin/bash
echo "=== Traffic Alert App Health Check ==="
echo "Timestamp: $(date)"
echo

echo "1. Testing Laravel API Health..."
if curl -s http://159.69.41.118/api/health > /dev/null; then
    echo "✅ Laravel API is responding"
    curl -s http://159.69.41.118/api/health | jq .
else
    echo "❌ Laravel API is not responding"
fi
echo

echo "2. Testing Socket.IO Health..."
if curl -s http://159.69.41.118:3001/health > /dev/null; then
    echo "✅ Socket.IO server is responding"
    curl -s http://159.69.41.118:3001/health | jq .
else
    echo "❌ Socket.IO server is not responding"
fi
echo

echo "3. Testing port connectivity..."
if nc -z 159.69.41.118 80; then
    echo "✅ Port 80 is open"
else
    echo "❌ Port 80 is closed"
fi

if nc -z 159.69.41.118 3001; then
    echo "✅ Port 3001 is open"
else
    echo "❌ Port 3001 is closed"
fi
echo

echo "4. Server resource usage..."
echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "Load: $(uptime | awk -F'load average:' '{ print $2 }')"
echo "Disk: $(df -h / | tail -1 | awk '{print $5 " used"}')"
```

Save this as `health_check.sh`, make it executable with `chmod +x health_check.sh`, and run it with `./health_check.sh`.