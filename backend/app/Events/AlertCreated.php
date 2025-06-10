<?php

namespace App\Events;

use App\Models\Alert;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class AlertCreated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $alert;

    public function __construct(Alert $alert)
    {
        $this->alert = $alert;
    }

    public function broadcastOn()
    {
        // Broadcast to global channel and location-based channel
        $gridLat = round($this->alert->latitude * 100) / 100;
        $gridLng = round($this->alert->longitude * 100) / 100;
        $locationChannel = "alerts.location.{$gridLat}_{$gridLng}";
        
        return [
            new Channel('alerts.global'),
            new Channel($locationChannel),
        ];
    }

    public function broadcastAs()
    {
        return 'alert.created';
    }

    public function broadcastWith()
    {
        return [
            'id' => $this->alert->id,
            'type' => $this->alert->type,
            'latitude' => $this->alert->latitude,
            'longitude' => $this->alert->longitude,
            'severity' => $this->alert->severity,
            'description' => $this->alert->description,
            'confirmed_count' => $this->alert->confirmed_count,
            'dismissed_count' => $this->alert->dismissed_count,
            'reported_at' => $this->alert->created_at->toISOString(),
            'user' => [
                'id' => $this->alert->user->id,
                'username' => $this->alert->user->username,
            ],
        ];
    }
}