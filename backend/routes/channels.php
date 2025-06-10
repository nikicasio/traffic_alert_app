<?php

use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});

// Traffic Alert Channels
Broadcast::channel('alerts.global', function ($user) {
    return $user !== null; // Any authenticated user can listen to global alerts
});

Broadcast::channel('alerts.location.{lat}_{lng}', function ($user, $lat, $lng) {
    return $user !== null; // Any authenticated user can listen to location-based alerts
});

Broadcast::channel('alerts.user.{userId}', function ($user, $userId) {
    return (int) $user->id === (int) $userId; // Users can only listen to their own alerts
});
