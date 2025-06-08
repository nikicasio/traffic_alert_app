import React, { useState, useEffect } from 'react';
import { MapPin, AlertTriangle, Construction, Car, Map, Gauge, ThumbsUp, Plus, X, Navigation, Users, ChevronUp, Zap, ChevronRight, Trophy, Shield, Flame, Volume2, Vibrate, Eye, Clock, CheckCircle, XCircle, Mic, Camera, Share2, TrendingUp, Award, Star, Wind, CloudRain, Fuel, ParkingCircle, ChargingStation, Train, TreePine, AlertCircle, Siren } from 'lucide-react';

const App = () => {
  const [currentView, setCurrentView] = useState('meter');
  const [showReportModal, setShowReportModal] = useState(false);
  const [selectedReportType, setSelectedReportType] = useState(null);
  const [selectedSubType, setSelectedSubType] = useState(null);
  const [confirmedReports, setConfirmedReports] = useState([]);
  const [userStats, setUserStats] = useState({
    level: 'Knight',
    points: 12450,
    rank: 89,
    reports: 324,
    confirms: 892,
    streak: 7
  });
  const [settings, setSettings] = useState({
    voiceAlerts: true,
    vibration: true,
    autoReport: false,
    theme: 'dark'
  });
  const [isVoiceRecording, setIsVoiceRecording] = useState(false);

  // Enhanced alert categories based on research
  const reportCategories = {
    enforcement: {
      label: 'Enforcement',
      icon: Car,
      color: 'bg-blue-500',
      darkColor: 'bg-blue-600',
      subtypes: [
        { id: 'fixed', label: 'Fixed Camera', icon: Camera },
        { id: 'mobile', label: 'Mobile Speed Trap', icon: Car },
        { id: 'redlight', label: 'Red Light Camera', icon: AlertCircle },
        { id: 'average', label: 'Average Speed Zone', icon: Gauge }
      ]
    },
    hazards: {
      label: 'Hazards',
      icon: AlertTriangle,
      color: 'bg-orange-500',
      darkColor: 'bg-orange-600',
      subtypes: [
        { id: 'accident', label: 'Accident', icon: AlertTriangle },
        { id: 'obstacle', label: 'Object on Road', icon: AlertCircle },
        { id: 'pothole', label: 'Pothole', icon: Circle },
        { id: 'animal', label: 'Animal on Road', icon: TreePine }
      ]
    },
    roadwork: {
      label: 'Roadwork',
      icon: Construction,
      color: 'bg-yellow-500',
      darkColor: 'bg-yellow-600',
      subtypes: [
        { id: 'construction', label: 'Construction', icon: Construction },
        { id: 'lane_closed', label: 'Lane Closed', icon: AlertTriangle },
        { id: 'road_closed', label: 'Road Closed', icon: X },
        { id: 'maintenance', label: 'Maintenance', icon: Construction }
      ]
    },
    weather: {
      label: 'Weather',
      icon: CloudRain,
      color: 'bg-purple-500',
      darkColor: 'bg-purple-600',
      subtypes: [
        { id: 'fog', label: 'Fog', icon: Wind },
        { id: 'ice', label: 'Ice/Snow', icon: CloudRain },
        { id: 'flooding', label: 'Flooding', icon: CloudRain },
        { id: 'wind', label: 'Strong Wind', icon: Wind }
      ]
    },
    services: {
      label: 'Services',
      icon: Fuel,
      color: 'bg-green-500',
      darkColor: 'bg-green-600',
      subtypes: [
        { id: 'gas', label: 'Gas Prices', icon: Fuel },
        { id: 'parking', label: 'Parking', icon: ParkingCircle },
        { id: 'charging', label: 'EV Charging', icon: ChargingStation },
        { id: 'rest', label: 'Rest Area', icon: TreePine }
      ]
    }
  };

  // Enhanced nearby alerts with more details
  const [nearbyAlerts] = useState([
    { 
      id: 1, 
      type: 'enforcement',
      subtype: 'mobile',
      distance: 0.8, 
      location: 'A1 Direction Munich', 
      speed: 80, 
      confirmations: 24, 
      fresh: true,
      severity: 'high',
      reportedBy: 'Knight_Driver',
      reliability: 92,
      lastConfirmed: 2
    },
    { 
      id: 2, 
      type: 'roadwork',
      subtype: 'lane_closed',
      distance: 2.3, 
      location: 'B27 Exit Tübingen', 
      speed: 60, 
      confirmations: 45, 
      fresh: false,
      severity: 'medium',
      reportedBy: 'Road_Warrior',
      reliability: 87,
      lastConfirmed: 15
    },
    { 
      id: 3, 
      type: 'hazards',
      subtype: 'obstacle',
      distance: 5.1, 
      location: 'A8 Near Stuttgart', 
      speed: 100, 
      confirmations: 12, 
      fresh: true,
      severity: 'medium',
      reportedBy: 'SafeDriver22',
      reliability: 78,
      lastConfirmed: 5
    }
  ]);

  // Gamification levels
  const levels = [
    { name: 'Baby', minPoints: 0, icon: '👶' },
    { name: 'Grown-up', minPoints: 1000, icon: '🧑' },
    { name: 'Warrior', minPoints: 5000, icon: '⚔️' },
    { name: 'Knight', minPoints: 10000, icon: '🛡️' },
    { name: 'Royalty', minPoints: 25000, icon: '👑' }
  ];

  const getNextAlert = () => nearbyAlerts[0];

  const handleConfirmAlert = (alertId) => {
    if (!confirmedReports.includes(alertId)) {
      setConfirmedReports([...confirmedReports, alertId]);
      setUserStats(prev => ({
        ...prev,
        points: prev.points + 10,
        confirms: prev.confirms + 1
      }));
    }
  };

  const handleVoiceReport = () => {
    setIsVoiceRecording(!isVoiceRecording);
    if (!isVoiceRecording) {
      // Simulate voice recording
      setTimeout(() => {
        setIsVoiceRecording(false);
        setShowReportModal(true);
        setSelectedReportType('enforcement');
      }, 2000);
    }
  };

  const MeterView = () => {
    const nextAlert = getNextAlert();
    const alertCategory = reportCategories[nextAlert.type];
    const alertSubtype = alertCategory.subtypes.find(s => s.id === nextAlert.subtype);
    const Icon = alertSubtype?.icon || alertCategory.icon;

    // Progress bar calculations
    const isWithin1km = nextAlert.distance <= 1.0;
    const progress = isWithin1km ? (1 - nextAlert.distance) * 100 : 0;
    
    const getProgressColor = () => {
      if (nextAlert.distance > 0.5) return 'bg-green-500';
      if (nextAlert.distance > 0.2) return 'bg-yellow-500';
      if (nextAlert.distance > 0.1) return 'bg-orange-500';
      return 'bg-red-500';
    };

    const getProgressGradient = () => {
      if (nextAlert.distance > 0.5) return 'from-green-400 to-green-600';
      if (nextAlert.distance > 0.2) return 'from-yellow-400 to-yellow-600';
      if (nextAlert.distance > 0.1) return 'from-orange-400 to-orange-600';
      return 'from-red-400 to-red-600';
    };

    return (
      <div className="flex-1 flex flex-col bg-gray-900 text-white">
        {/* Speed meter section */}
        <div className="flex-1 flex flex-col items-center justify-center relative">
          {/* User stats badge */}
          <div className="absolute top-4 right-4 bg-gray-800 rounded-lg p-2 flex items-center space-x-2">
            <Trophy className="w-4 h-4 text-yellow-500" />
            <span className="text-sm font-medium">{userStats.level}</span>
            <span className="text-xs text-gray-400">#{userStats.rank}</span>
          </div>

          {/* Current speed */}
          <div className="text-7xl font-bold mb-2">87</div>
          <div className="text-gray-400 text-lg mb-8">km/h</div>
          
          {/* Proximity progress bar */}
          {isWithin1km && (
            <div className="w-full max-w-sm mx-4 mb-6">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm text-gray-400">Distance</span>
                <span className="text-lg font-bold">{(nextAlert.distance * 1000).toFixed(0)}m</span>
              </div>
              <div className="h-8 bg-gray-800 rounded-full overflow-hidden relative">
                <div 
                  className={`h-full bg-gradient-to-r ${getProgressGradient()} transition-all duration-300 relative`}
                  style={{ width: `${progress}%` }}
                >
                  <div className="absolute inset-0 bg-white bg-opacity-20 animate-pulse"></div>
                </div>
                <div className="absolute inset-0 flex items-center justify-between px-2 text-xs text-gray-500">
                  <span>1km</span>
                  <span>500m</span>
                  <span>0m</span>
                </div>
              </div>
              <div className="flex items-center justify-center mt-2">
                <div className={`${getProgressColor()} rounded-full p-1 animate-pulse`}>
                  <Icon className="w-4 h-4 text-white" />
                </div>
                <span className="ml-2 text-sm text-gray-400">{alertSubtype?.label} ahead</span>
              </div>
            </div>
          )}
          
          {/* Enhanced next alert card */}
          <div className="bg-gray-800 rounded-2xl p-6 mx-4 w-full max-w-sm">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center">
                <div className={`${alertCategory.darkColor} rounded-full p-3`}>
                  <Icon className="w-6 h-6 text-white" />
                </div>
                <div className="ml-3">
                  <div className="font-semibold">{alertSubtype?.label}</div>
                  <div className="text-sm text-gray-400">{nextAlert.distance} km</div>
                </div>
              </div>
              <div className="text-right">
                {nextAlert.fresh && (
                  <div className="flex items-center text-green-400 text-sm mb-1">
                    <Zap className="w-4 h-4 mr-1" />
                    Fresh
                  </div>
                )}
                <div className="flex items-center text-xs text-gray-400">
                  <Shield className="w-3 h-3 mr-1" />
                  {nextAlert.reliability}% reliable
                </div>
              </div>
            </div>
            
            <div className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-400">Location</span>
                <span>{nextAlert.location}</span>
              </div>
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-400">Speed limit</span>
                <span>{nextAlert.speed} km/h</span>
              </div>
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-400">Reported by</span>
                <span className="flex items-center">
                  <Award className="w-3 h-3 mr-1 text-yellow-500" />
                  {nextAlert.reportedBy}
                </span>
              </div>
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-400">Confirmations</span>
                <div className="flex items-center">
                  <Users className="w-4 h-4 mr-1" />
                  <span>{nextAlert.confirmations}</span>
                  <span className="text-xs text-gray-500 ml-1">({nextAlert.lastConfirmed}m ago)</span>
                </div>
              </div>
            </div>

            {/* Action buttons */}
            <div className="flex gap-2 mt-4">
              <button 
                onClick={() => handleConfirmAlert(nextAlert.id)}
                className={`flex-1 py-3 rounded-lg font-medium transition-colors ${
                  confirmedReports.includes(nextAlert.id)
                    ? 'bg-green-600 text-white'
                    : 'bg-gray-700 text-white hover:bg-gray-600'
                }`}
              >
                {confirmedReports.includes(nextAlert.id) ? (
                  <span className="flex items-center justify-center">
                    <CheckCircle className="w-4 h-4 mr-2" />
                    Confirmed
                  </span>
                ) : (
                  <span className="flex items-center justify-center">
                    <ThumbsUp className="w-4 h-4 mr-2" />
                    Confirm
                  </span>
                )}
              </button>
              <button className="px-4 py-3 bg-gray-700 rounded-lg hover:bg-gray-600 transition-colors">
                <Share2 className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Streak indicator */}
          <div className="mt-4 flex items-center text-sm text-gray-400">
            <Flame className="w-4 h-4 text-orange-500 mr-1" />
            {userStats.streak} day streak
          </div>
        </div>

        {/* Upcoming alerts with swipe gesture */}
        <div className="bg-gray-800 rounded-t-3xl">
          <div className="p-4">
            <div className="flex items-center justify-center mb-3">
              <ChevronUp className="w-6 h-6 text-gray-500" />
            </div>
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-medium text-gray-400">Upcoming Alerts</h3>
              <span className="text-xs text-gray-500">{nearbyAlerts.length} total</span>
            </div>
            <div className="space-y-2">
              {nearbyAlerts.slice(1, 4).map(alert => {
                const category = reportCategories[alert.type];
                const subtype = category.subtypes.find(s => s.id === alert.subtype);
                const Icon = subtype?.icon || category.icon;
                return (
                  <div key={alert.id} className="bg-gray-700 rounded-lg p-3 flex items-center">
                    <div className={`${category.darkColor} rounded-full p-2`}>
                      <Icon className="w-4 h-4 text-white" />
                    </div>
                    <div className="ml-3 flex-1">
                      <div className="text-sm font-medium">{subtype?.label}</div>
                      <div className="text-xs text-gray-400">{alert.location}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-sm font-medium">{alert.distance} km</div>
                      <div className="text-xs text-gray-400 flex items-center justify-end">
                        <Users className="w-3 h-3 mr-1" />
                        {alert.confirmations}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    );
  };

  const MapView = () => (
    <div className="flex-1 relative bg-gray-900">
      {/* Map with dark theme */}
      <div className="absolute inset-0 bg-gradient-to-br from-gray-800 to-gray-900">
        {/* Alert markers */}
        {nearbyAlerts.map((alert, index) => {
          const category = reportCategories[alert.type];
          return (
            <div
              key={alert.id}
              className="absolute animate-pulse"
              style={{
                top: `${20 + index * 15}%`,
                left: `${30 + index * 10}%`
              }}
            >
              <div className={`${category.darkColor} rounded-full p-2 shadow-lg relative`}>
                <MapPin className="w-4 h-4 text-white" />
                {alert.fresh && (
                  <div className="absolute -top-1 -right-1 w-2 h-2 bg-green-400 rounded-full"></div>
                )}
              </div>
            </div>
          );
        })}
        
        {/* User location */}
        <div className="absolute bottom-1/3 left-1/2 transform -translate-x-1/2">
          <div className="bg-blue-500 rounded-full p-3 shadow-lg">
            <Navigation className="w-6 h-6 text-white transform -rotate-45" />
          </div>
        </div>
      </div>

      {/* Speed and stats overlay */}
      <div className="absolute top-4 left-4 bg-gray-800 rounded-2xl p-4 shadow-lg">
        <div className="text-4xl font-bold text-white">87</div>
        <div className="text-sm text-gray-400">km/h</div>
        <div className="mt-2 flex items-center text-xs text-gray-400">
          <TrendingUp className="w-3 h-3 mr-1" />
          +{userStats.points} pts
        </div>
      </div>

      {/* Enhanced next alert overlay */}
      <div className="absolute top-4 right-4 left-24 bg-gray-800 rounded-2xl p-3 shadow-lg">
        {(() => {
          const alert = getNextAlert();
          const category = reportCategories[alert.type];
          const subtype = category.subtypes.find(s => s.id === alert.subtype);
          const Icon = subtype?.icon || category.icon;
          const isWithin1km = alert.distance <= 1.0;
          const progress = isWithin1km ? (1 - alert.distance) * 100 : 0;
          
          const getProgressColor = () => {
            if (alert.distance > 0.5) return 'bg-green-500';
            if (alert.distance > 0.2) return 'bg-yellow-500';
            if (alert.distance > 0.1) return 'bg-orange-500';
            return 'bg-red-500';
          };

          return (
            <div>
              <div className="flex items-center">
                <div className={`${category.darkColor} rounded-full p-2`}>
                  <Icon className="w-5 h-5 text-white" />
                </div>
                <div className="ml-3 flex-1">
                  <div className="text-white font-medium">{subtype?.label} • {alert.distance} km</div>
                  <div className="text-xs text-gray-400 flex items-center">
                    <Users className="w-3 h-3 mr-1" />
                    {alert.confirmations} confirms
                    <Shield className="w-3 h-3 ml-2 mr-1" />
                    {alert.reliability}%
                  </div>
                </div>
              </div>
              {isWithin1km && (
                <div className="mt-2">
                  <div className="h-2 bg-gray-700 rounded-full overflow-hidden">
                    <div 
                      className={`h-full ${getProgressColor()} transition-all duration-300`}
                      style={{ width: `${progress}%` }}
                    />
                  </div>
                  <div className="text-xs text-gray-400 mt-1 text-center">
                    {(alert.distance * 1000).toFixed(0)}m away
                  </div>
                </div>
              )}
            </div>
          );
        })()}
      </div>

      {/* Voice report button */}
      <button
        onClick={handleVoiceReport}
        className={`fixed bottom-24 right-6 ${
          isVoiceRecording ? 'bg-red-500' : 'bg-gray-700'
        } text-white rounded-full p-4 shadow-lg transition-colors`}
      >
        <Mic className={`w-6 h-6 ${isVoiceRecording ? 'animate-pulse' : ''}`} />
      </button>
    </div>
  );

  const EnhancedReportModal = () => (
    <div className="fixed inset-0 bg-black bg-opacity-75 flex items-end z-50">
      <div className="bg-gray-800 rounded-t-3xl w-full max-h-[80vh] overflow-hidden">
        <div className="p-4 border-b border-gray-700">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-bold text-white">Report Alert</h3>
            <button onClick={() => {
              setShowReportModal(false);
              setSelectedReportType(null);
              setSelectedSubType(null);
            }}>
              <X className="w-6 h-6 text-gray-400" />
            </button>
          </div>
        </div>
        
        <div className="p-4 pb-8 overflow-y-auto">
          {!selectedReportType ? (
            <>
              <div className="mb-4 text-center">
                <p className="text-gray-400 text-sm">Your report helps {nearbyAlerts.length * 47} drivers</p>
                <div className="flex items-center justify-center mt-2 text-green-400">
                  <Star className="w-4 h-4 mr-1" />
                  <span className="text-sm">+50 points for accurate reports</span>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                {Object.entries(reportCategories).map(([key, category]) => {
                  const Icon = category.icon;
                  return (
                    <button
                      key={key}
                      onClick={() => setSelectedReportType(key)}
                      className="bg-gray-700 rounded-2xl p-4 flex flex-col items-center hover:bg-gray-600 transition-colors"
                    >
                      <div className={`${category.darkColor} rounded-full p-3 mb-2`}>
                        <Icon className="w-6 h-6 text-white" />
                      </div>
                      <span className="text-white font-medium text-sm">{category.label}</span>
                    </button>
                  );
                })}
              </div>
            </>
          ) : !selectedSubType ? (
            <div>
              <button
                onClick={() => setSelectedReportType(null)}
                className="text-blue-400 text-sm flex items-center mb-4"
              >
                <ChevronRight className="w-4 h-4 rotate-180 mr-1" />
                Back
              </button>
              <h4 className="text-white font-medium mb-3">Select type:</h4>
              <div className="grid grid-cols-2 gap-3">
                {reportCategories[selectedReportType].subtypes.map(subtype => {
                  const Icon = subtype.icon;
                  return (
                    <button
                      key={subtype.id}
                      onClick={() => setSelectedSubType(subtype.id)}
                      className="bg-gray-700 rounded-lg p-3 flex items-center hover:bg-gray-600 transition-colors"
                    >
                      <Icon className="w-5 h-5 text-gray-300 mr-3" />
                      <span className="text-white text-sm">{subtype.label}</span>
                    </button>
                  );
                })}
              </div>
            </div>
          ) : (
            <div className="space-y-4">
              <button
                onClick={() => setSelectedSubType(null)}
                className="text-blue-400 text-sm flex items-center"
              >
                <ChevronRight className="w-4 h-4 rotate-180 mr-1" />
                Back
              </button>
              
              <div className="bg-gray-700 rounded-lg p-4">
                <div className="flex items-center text-white mb-2">
                  <MapPin className="w-5 h-5 mr-2" />
                  <span className="font-medium">Location detected</span>
                </div>
                <div className="text-gray-400">A1 • km 145.3 • Direction Munich</div>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Direction</label>
                <div className="grid grid-cols-2 gap-3">
                  <button className="bg-blue-600 text-white py-3 rounded-lg font-medium">
                    My direction
                  </button>
                  <button className="bg-gray-700 text-gray-300 py-3 rounded-lg font-medium">
                    Opposite
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Add photo (optional)</label>
                <button className="w-full bg-gray-700 text-gray-300 py-3 rounded-lg font-medium flex items-center justify-center hover:bg-gray-600 transition-colors">
                  <Camera className="w-5 h-5 mr-2" />
                  Take Photo
                </button>
              </div>
              
              <button
                onClick={() => {
                  setShowReportModal(false);
                  setSelectedReportType(null);
                  setSelectedSubType(null);
                  setUserStats(prev => ({
                    ...prev,
                    points: prev.points + 50,
                    reports: prev.reports + 1
                  }));
                }}
                className="w-full bg-green-600 text-white py-4 rounded-lg font-medium hover:bg-green-700 transition-colors"
              >
                Submit Report
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );

  // Alert settings bar
  const AlertSettingsBar = () => (
    <div className="bg-gray-800 border-t border-gray-700 px-4 py-2 flex items-center justify-around">
      <button
        onClick={() => setSettings(prev => ({ ...prev, voiceAlerts: !prev.voiceAlerts }))}
        className={`p-2 rounded-lg ${settings.voiceAlerts ? 'bg-gray-700' : 'bg-gray-900'}`}
      >
        <Volume2 className={`w-5 h-5 ${settings.voiceAlerts ? 'text-white' : 'text-gray-500'}`} />
      </button>
      <button
        onClick={() => setSettings(prev => ({ ...prev, vibration: !prev.vibration }))}
        className={`p-2 rounded-lg ${settings.vibration ? 'bg-gray-700' : 'bg-gray-900'}`}
      >
        <Vibrate className={`w-5 h-5 ${settings.vibration ? 'text-white' : 'text-gray-500'}`} />
      </button>
      <button
        onClick={() => setSettings(prev => ({ ...prev, autoReport: !prev.autoReport }))}
        className={`p-2 rounded-lg ${settings.autoReport ? 'bg-gray-700' : 'bg-gray-900'}`}
      >
        <Eye className={`w-5 h-5 ${settings.autoReport ? 'text-white' : 'text-gray-500'}`} />
      </button>
      <div className="h-8 w-px bg-gray-700"></div>
      <button
        onClick={() => setCurrentView(currentView === 'map' ? 'meter' : 'map')}
        className="p-2 rounded-lg bg-gray-700"
      >
        {currentView === 'map' ? (
          <Gauge className="w-5 h-5 text-white" />
        ) : (
          <Map className="w-5 h-5 text-white" />
        )}
      </button>
    </div>
  );

  return (
    <div className="h-screen w-full bg-gray-900 flex flex-col">
      {/* Header with user stats */}
      <div className="bg-gray-800 p-4 flex items-center justify-between">
        <div>
          <h1 className="text-white font-bold text-lg">RadarAlert Pro</h1>
          <div className="flex items-center text-xs text-gray-400 mt-1">
            <Trophy className="w-3 h-3 mr-1 text-yellow-500" />
            {userStats.points.toLocaleString()} pts • {userStats.level}
          </div>
        </div>
        <div className="flex items-center space-x-3">
          <div className="text-right">
            <div className="text-white text-sm font-medium">{userStats.reports}</div>
            <div className="text-xs text-gray-400">Reports</div>
          </div>
          <div className="h-8 w-px bg-gray-700"></div>
          <div className="text-right">
            <div className="text-white text-sm font-medium">{userStats.confirms}</div>
            <div className="text-xs text-gray-400">Confirms</div>
          </div>
        </div>
      </div>

      {/* Main content */}
      {currentView === 'meter' ? <MeterView /> : <MapView />}

      {/* Alert settings bar */}
      <AlertSettingsBar />

      {/* Report button */}
      <button
        onClick={() => setShowReportModal(true)}
        className="fixed bottom-20 right-6 bg-red-600 text-white rounded-full p-4 shadow-lg hover:bg-red-700 transition-colors"
      >
        <Plus className="w-6 h-6" />
      </button>

      {/* Report modal */}
      {showReportModal && <EnhancedReportModal />}
    </div>
  );
};

export default App;