<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AlertConfirmation extends Model
{
    protected $fillable = [
        'alert_id',
        'user_id',
        'confirmation_type',
        'comment',
    ];

    public function alert(): BelongsTo
    {
        return $this->belongsTo(Alert::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function scopeConfirmed($query)
    {
        return $query->where('confirmation_type', 'confirmed');
    }

    public function scopeDismissed($query)
    {
        return $query->where('confirmation_type', 'dismissed');
    }

    public function scopeNotThere($query)
    {
        return $query->where('confirmation_type', 'not_there');
    }
}
