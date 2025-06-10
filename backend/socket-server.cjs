const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
const server = createServer(app);

// Configure CORS for Socket.IO
const io = new Server(server, {
  cors: {
    origin: "*", // In production, specify your Flutter app domain
    methods: ["GET", "POST"],
    allowedHeaders: ["*"],
    credentials: true
  },
  allowEIO3: true
});

app.use(cors());
app.use(express.json());

// Store connected users and their locations
const connectedUsers = new Map();
const activeChannels = new Map();

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    connectedUsers: connectedUsers.size,
    activeChannels: activeChannels.size
  });
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`User connected: ${socket.id}`);
  
  // Handle authentication
  socket.on('authenticate', (data) => {
    const { userId, authToken } = data;
    
    // In production, verify the authToken with Laravel backend
    // For now, we'll trust the client
    socket.userId = userId;
    socket.authenticated = true;
    
    connectedUsers.set(socket.id, {
      userId: userId,
      socketId: socket.id,
      connectedAt: new Date()
    });
    
    socket.emit('authenticated', { success: true });
    console.log(`User ${userId} authenticated with socket ${socket.id}`);
  });
  
  // Handle location updates
  socket.on('location_update', (data) => {
    if (!socket.authenticated) {
      socket.emit('error', { message: 'Not authenticated' });
      return;
    }
    
    const { latitude, longitude, heading, speed } = data;
    
    // Update user location
    const user = connectedUsers.get(socket.id);
    if (user) {
      user.latitude = latitude;
      user.longitude = longitude;
      user.heading = heading;
      user.speed = speed;
      user.lastLocationUpdate = new Date();
    }
    
    // Subscribe to location-based channels
    subscribeToLocationChannels(socket, latitude, longitude);
    
    console.log(`Location update from ${socket.userId}: ${latitude}, ${longitude}`);
  });
  
  // Handle alert creation
  socket.on('report_alert', (data) => {
    if (!socket.authenticated) {
      socket.emit('error', { message: 'Not authenticated' });
      return;
    }
    
    console.log(`Alert reported by ${socket.userId}:`, data);
    
    // Broadcast to relevant channels
    broadcastAlertCreated(data);
    
    // Acknowledge the report
    socket.emit('alert_reported', { success: true, alertId: data.id });
  });
  
  // Handle alert confirmation
  socket.on('confirm_alert', (data) => {
    if (!socket.authenticated) {
      socket.emit('error', { message: 'Not authenticated' });
      return;
    }
    
    console.log(`Alert confirmation by ${socket.userId}:`, data);
    
    // Broadcast confirmation to relevant channels
    broadcastAlertConfirmed(data);
    
    // Acknowledge the confirmation
    socket.emit('alert_confirmed', { success: true });
  });
  
  // Handle manual channel subscription
  socket.on('subscribe', (data) => {
    const { channel } = data;
    socket.join(channel);
    
    if (!activeChannels.has(channel)) {
      activeChannels.set(channel, new Set());
    }
    activeChannels.get(channel).add(socket.id);
    
    console.log(`${socket.id} subscribed to ${channel}`);
    socket.emit('subscribed', { channel });
  });
  
  // Handle channel unsubscription
  socket.on('unsubscribe', (data) => {
    const { channel } = data;
    socket.leave(channel);
    
    if (activeChannels.has(channel)) {
      activeChannels.get(channel).delete(socket.id);
      if (activeChannels.get(channel).size === 0) {
        activeChannels.delete(channel);
      }
    }
    
    console.log(`${socket.id} unsubscribed from ${channel}`);
    socket.emit('unsubscribed', { channel });
  });
  
  // Handle disconnection
  socket.on('disconnect', () => {
    console.log(`User disconnected: ${socket.id}`);
    
    // Clean up user data
    connectedUsers.delete(socket.id);
    
    // Clean up channel subscriptions
    activeChannels.forEach((subscribers, channel) => {
      subscribers.delete(socket.id);
      if (subscribers.size === 0) {
        activeChannels.delete(channel);
      }
    });
  });
});

// Helper function to subscribe user to location-based channels
function subscribeToLocationChannels(socket, latitude, longitude) {
  // Calculate grid-based channel (1km grid)
  const gridLat = Math.round(latitude * 100) / 100;
  const gridLng = Math.round(longitude * 100) / 100;
  const locationChannel = `alerts.location.${gridLat}_${gridLng}`;
  
  // Subscribe to location channel
  socket.join(locationChannel);
  socket.join('alerts.global');
  
  console.log(`${socket.id} subscribed to location channels: ${locationChannel}, alerts.global`);
}

// Helper function to broadcast alert creation
function broadcastAlertCreated(alertData) {
  const { latitude, longitude } = alertData;
  
  // Calculate location channel
  const gridLat = Math.round(latitude * 100) / 100;
  const gridLng = Math.round(longitude * 100) / 100;
  const locationChannel = `alerts.location.${gridLat}_${gridLng}`;
  
  // Broadcast to global and location channels
  io.to('alerts.global').emit('alert.created', alertData);
  io.to(locationChannel).emit('alert.created', alertData);
  
  // Broadcast to nearby location channels (within ~5km radius)
  const nearbyChannels = generateNearbyChannels(latitude, longitude, 5);
  nearbyChannels.forEach(channel => {
    io.to(channel).emit('alert.created', alertData);
  });
  
  console.log(`Alert broadcasted to channels: alerts.global, ${locationChannel}, ${nearbyChannels.length} nearby`);
}

// Helper function to broadcast alert confirmation
function broadcastAlertConfirmed(confirmationData) {
  // Broadcast to global channel
  io.to('alerts.global').emit('alert.confirmed', confirmationData);
  
  console.log(`Alert confirmation broadcasted:`, confirmationData);
}

// Helper function to generate nearby location channels
function generateNearbyChannels(latitude, longitude, radiusKm) {
  const channels = [];
  const gridSize = 0.01; // ~1km
  const steps = Math.ceil(radiusKm / 111); // Approximate km per degree
  
  for (let latOffset = -steps; latOffset <= steps; latOffset++) {
    for (let lngOffset = -steps; lngOffset <= steps; lngOffset++) {
      const gridLat = Math.round((latitude + latOffset * gridSize) * 100) / 100;
      const gridLng = Math.round((longitude + lngOffset * gridSize) * 100) / 100;
      channels.push(`alerts.location.${gridLat}_${gridLng}`);
    }
  }
  
  return channels;
}

// Endpoint to trigger events from Laravel (webhook style)
app.post('/broadcast/alert-created', (req, res) => {
  const alertData = req.body;
  broadcastAlertCreated(alertData);
  res.json({ success: true, message: 'Alert broadcasted' });
});

app.post('/broadcast/alert-confirmed', (req, res) => {
  const confirmationData = req.body;
  broadcastAlertConfirmed(confirmationData);
  res.json({ success: true, message: 'Confirmation broadcasted' });
});

// Start the server
const PORT = process.env.PORT || 3001;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Socket.IO server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

// Export for testing purposes
if (require.main === module) {
  // Only start server if this file is run directly
} else {
  module.exports = { app, server, io };
}