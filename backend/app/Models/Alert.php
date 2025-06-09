<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Casts\Attribute;

class Alert extends Model
{
    protected $fillable = [
        'user_id',
        'type',
        'latitude',
        'longitude',
        'severity',
        'description',
        'confirmed_count',
        'dismissed_count',
        'is_active',
        'expires_at',
    ];

    protected $casts = [
        'latitude' => 'decimal:8',
        'longitude' => 'decimal:8',
        'is_active' => 'boolean',
        'expires_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    protected $appends = [
        'reported_at'
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function confirmations(): HasMany
    {
        return $this->hasMany(AlertConfirmation::class);
    }

    public function reportedAt(): Attribute
    {
        return Attribute::make(
            get: fn() => $this->created_at,
        );
    }

    // Scope for active alerts
    public function scopeActive($query)
    {
        return $query->where('is_active', true)
                    ->where(function($q) {
                        $q->whereNull('expires_at')
                          ->orWhere('expires_at', '>', now());
                    });
    }

    // Scope for nearby alerts
    public function scopeNearby($query, $latitude, $longitude, $radiusInMeters = 10000)
    {
        $radiusInKm = $radiusInMeters / 1000;
        return $query->selectRaw("
            *,
            (6371 * acos(
                cos(radians(?)) * cos(radians(latitude)) *
                cos(radians(longitude) - radians(?)) +
                sin(radians(?)) * sin(radians(latitude))
            )) as distance_km
        ", [$latitude, $longitude, $latitude])
        ->having('distance_km', '<=', $radiusInKm)
        ->orderBy('distance_km');
    }

    // Scope for directional alerts (in direction of travel)
    public function scopeDirectional($query, $latitude, $longitude, $heading, $radiusInMeters = 2000, $angleInDegrees = 60)
    {
        $radiusInKm = $radiusInMeters / 1000;
        $angleInRadians = deg2rad($angleInDegrees / 2);
        $headingInRadians = deg2rad($heading);
        
        return $query->selectRaw("
            *,
            (6371 * acos(
                cos(radians(?)) * cos(radians(latitude)) *
                cos(radians(longitude) - radians(?)) +
                sin(radians(?)) * sin(radians(latitude))
            )) as distance_km,
            ATAN2(
                SIN(RADIANS(longitude) - RADIANS(?)) * COS(RADIANS(latitude)),
                COS(RADIANS(?)) * SIN(RADIANS(latitude)) - 
                SIN(RADIANS(?)) * COS(RADIANS(latitude)) * COS(RADIANS(longitude) - RADIANS(?))
            ) as bearing_radians
        ", [$latitude, $longitude, $latitude, $longitude, $latitude, $latitude, $longitude])
        ->having('distance_km', '<=', $radiusInKm)
        ->havingRaw('ABS(bearing_radians - ?) <= ?', [$headingInRadians, $angleInRadians])
        ->orderBy('distance_km');
    }
}
