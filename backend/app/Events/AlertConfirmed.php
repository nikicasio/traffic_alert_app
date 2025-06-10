<?php

namespace App\Events;

use App\Models\Alert;
use App\Models\AlertConfirmation;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class AlertConfirmed implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $alert;
    public $confirmation;

    public function __construct(Alert $alert, AlertConfirmation $confirmation)
    {
        $this->alert = $alert;
        $this->confirmation = $confirmation;
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
        return 'alert.confirmed';
    }

    public function broadcastWith()
    {
        return [
            'alert_id' => $this->alert->id,
            'confirmation_type' => $this->confirmation->confirmation_type,
            'confirmed_count' => $this->alert->confirmed_count,
            'dismissed_count' => $this->alert->dismissed_count,
            'user' => [
                'id' => $this->confirmation->user->id,
                'username' => $this->confirmation->user->username,
            ],
        ];
    }
}