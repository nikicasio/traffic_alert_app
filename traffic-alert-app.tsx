import React, { useState } from 'react';
import { MapPin, AlertTriangle, Construction, Car, Map, Gauge, ThumbsUp, Plus, X, Navigation, Users, ChevronUp, Zap } from 'lucide-react';

const App = () => {
  const [currentView, setCurrentView] = useState('meter'); // 'map' or 'meter'
  const [showReportModal, setShowReportModal] = useState(false);
  const [selectedReportType, setSelectedReportType] = useState(null);
  const [confirmedReports, setConfirmedReports] = useState([]);

  // Sample data for nearby alerts
  const nearbyAlerts = [
    { id: 1, type: 'police', distance: 0.8, location: 'A1 Direction Munich', speed: 80, confirmations: 24, fresh: true },
    { id: 2, type: 'roadwork', distance: 2.3, location: 'B27 Exit Tübingen', speed: 60, confirmations: 45, fresh: false },
    { id: 3, type: 'obstacle', distance: 5.1, location: 'A8 Near Stuttgart', speed: 100, confirmations: 12, fresh: true },
    { id: 4, type: 'police', distance: 12.4, location: 'B10 Karlsruhe', speed: 70, confirmations: 8, fresh: false },
  ];

  const reportTypes = [
    { type: 'police', icon: Car, label: 'Police', color: 'bg-blue-500', darkColor: 'bg-blue-600' },
    { type: 'obstacle', icon: AlertTriangle, label: 'Obstacle', color: 'bg-orange-500', darkColor: 'bg-orange-600' },
    { type: 'roadwork', icon: Construction, label: 'Roadwork', color: 'bg-yellow-500', darkColor: 'bg-yellow-600' },
  ];

  const getNextAlert = () => nearbyAlerts[0];

  const MeterView = () => {
    const nextAlert = getNextAlert();
    const alertType = reportTypes.find(r => r.type === nextAlert.type);
    const Icon = alertType.icon;

    // Calculate progress bar properties
    const isWithin1km = nextAlert.distance <= 1.0;
    const progress = isWithin1km ? (1 - nextAlert.distance) * 100 : 0;
    
    // Determine color based on distance
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
          {/* Current speed */}
          <div className="text-7xl font-bold mb-2">87</div>
          <div className="text-gray-400 text-lg mb-8">km/h</div>
          
          {/* Proximity progress bar - only shows within 1km */}
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
                {/* Distance markers */}
                <div className="absolute inset-0 flex items-center justify-between px-2 text-xs text-gray-500">
                  <span>1km</span>
                  <span>500m</span>
                  <span>0m</span>
                </div>
              </div>
              {/* Alert type indicator */}
              <div className="flex items-center justify-center mt-2">
                <div className={`${getProgressColor()} rounded-full p-1 animate-pulse`}>
                  <Icon className="w-4 h-4 text-white" />
                </div>
                <span className="ml-2 text-sm text-gray-400">{alertType.label} ahead</span>
              </div>
            </div>
          )}
          
          {/* Next alert preview */}
          <div className="bg-gray-800 rounded-2xl p-6 mx-4 w-full max-w-sm">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center">
                <div className={`${alertType.darkColor} rounded-full p-3`}>
                  <Icon className="w-6 h-6 text-white" />
                </div>
                <div className="ml-3">
                  <div className="font-semibold">{alertType.label}</div>
                  <div className="text-sm text-gray-400">{nextAlert.distance} km</div>
                </div>
              </div>
              {nextAlert.fresh && (
                <div className="flex items-center text-green-400 text-sm">
                  <Zap className="w-4 h-4 mr-1" />
                  Fresh
                </div>
              )}
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
                <span className="text-gray-400">Confirmations</span>
                <div className="flex items-center">
                  <Users className="w-4 h-4 mr-1" />
                  <span>{nextAlert.confirmations}</span>
                </div>
              </div>
            </div>

            {/* Confirm button */}
            <button 
              onClick={() => {
                if (!confirmedReports.includes(nextAlert.id)) {
                  setConfirmedReports([...confirmedReports, nextAlert.id]);
                }
              }}
              className={`w-full mt-4 py-3 rounded-lg font-medium transition-colors ${
                confirmedReports.includes(nextAlert.id)
                  ? 'bg-green-600 text-white'
                  : 'bg-gray-700 text-white hover:bg-gray-600'
              }`}
            >
              {confirmedReports.includes(nextAlert.id) ? (
                <span className="flex items-center justify-center">
                  <ThumbsUp className="w-4 h-4 mr-2" />
                  Confirmed
                </span>
              ) : (
                'Confirm Alert'
              )}
            </button>
          </div>
        </div>

        {/* Upcoming alerts */}
        <div className="bg-gray-800 rounded-t-3xl">
          <div className="p-4">
            <div className="flex items-center justify-center mb-3">
              <ChevronUp className="w-6 h-6 text-gray-500" />
            </div>
            <h3 className="text-sm font-medium text-gray-400 mb-3">Upcoming Alerts</h3>
            <div className="space-y-2">
              {nearbyAlerts.slice(1, 4).map(alert => {
                const type = reportTypes.find(r => r.type === alert.type);
                const Icon = type.icon;
                return (
                  <div key={alert.id} className="bg-gray-700 rounded-lg p-3 flex items-center">
                    <div className={`${type.darkColor} rounded-full p-2`}>
                      <Icon className="w-4 h-4 text-white" />
                    </div>
                    <div className="ml-3 flex-1">
                      <div className="text-sm font-medium">{type.label}</div>
                      <div className="text-xs text-gray-400">{alert.location}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-sm font-medium">{alert.distance} km</div>
                      <div className="text-xs text-gray-400">{alert.confirmations} confirms</div>
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
      {/* Map placeholder with dark theme */}
      <div className="absolute inset-0 bg-gradient-to-br from-gray-800 to-gray-900">
        {/* Alert markers */}
        {nearbyAlerts.map((alert, index) => {
          const type = reportTypes.find(r => r.type === alert.type);
          return (
            <div
              key={alert.id}
              className="absolute animate-pulse"
              style={{
                top: `${20 + index * 15}%`,
                left: `${30 + index * 10}%`
              }}
            >
              <div className={`${type.darkColor} rounded-full p-2 shadow-lg`}>
                <MapPin className="w-4 h-4 text-white" />
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

      {/* Speed overlay */}
      <div className="absolute top-4 left-4 bg-gray-800 rounded-2xl p-4 shadow-lg">
        <div className="text-4xl font-bold text-white">87</div>
        <div className="text-sm text-gray-400">km/h</div>
      </div>

      {/* Next alert overlay */}
      <div className="absolute top-4 right-4 left-24 bg-gray-800 rounded-2xl p-3 shadow-lg">
        {(() => {
          const alert = getNextAlert();
          const type = reportTypes.find(r => r.type === alert.type);
          const Icon = type.icon;
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
                <div className={`${type.darkColor} rounded-full p-2`}>
                  <Icon className="w-5 h-5 text-white" />
                </div>
                <div className="ml-3 flex-1">
                  <div className="text-white font-medium">{type.label} • {alert.distance} km</div>
                  <div className="text-xs text-gray-400">{alert.confirmations} confirmations</div>
                </div>
              </div>
              {/* Mini progress bar for map view */}
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
    </div>
  );

  const ReportModal = () => (
    <div className="fixed inset-0 bg-black bg-opacity-75 flex items-end z-50">
      <div className="bg-gray-800 rounded-t-3xl w-full">
        <div className="p-4 border-b border-gray-700">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-bold text-white">Report Alert</h3>
            <button onClick={() => {
              setShowReportModal(false);
              setSelectedReportType(null);
            }}>
              <X className="w-6 h-6 text-gray-400" />
            </button>
          </div>
        </div>
        
        <div className="p-4 pb-8">
          {!selectedReportType ? (
            <div className="grid grid-cols-3 gap-4">
              {reportTypes.map(type => {
                const Icon = type.icon;
                return (
                  <button
                    key={type.type}
                    onClick={() => setSelectedReportType(type.type)}
                    className="bg-gray-700 rounded-2xl p-6 flex flex-col items-center hover:bg-gray-600 transition-colors"
                  >
                    <div className={`${type.darkColor} rounded-full p-4 mb-3`}>
                      <Icon className="w-8 h-8 text-white" />
                    </div>
                    <span className="text-white font-medium">{type.label}</span>
                  </button>
                );
              })}
            </div>
          ) : (
            <div className="space-y-4">
              <div className="bg-gray-700 rounded-lg p-4">
                <div className="flex items-center text-white mb-2">
                  <MapPin className="w-5 h-5 mr-2" />
                  <span className="font-medium">Location detected</span>
                </div>
                <div className="text-gray-400">A1 • km 145.3 • Direction Munich</div>
              </div>
              
              <div className="grid grid-cols-2 gap-3">
                <button className="bg-blue-600 text-white py-3 rounded-lg font-medium">
                  My direction
                </button>
                <button className="bg-gray-700 text-gray-300 py-3 rounded-lg font-medium">
                  Opposite
                </button>
              </div>
              
              <button
                onClick={() => {
                  setShowReportModal(false);
                  setSelectedReportType(null);
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

  return (
    <div className="h-screen w-full bg-gray-900 flex flex-col">
      {/* Header */}
      <div className="bg-gray-800 p-4 flex items-center justify-between">
        <h1 className="text-white font-bold text-lg">RadarAlert</h1>
        <div className="flex items-center space-x-2">
          <button
            onClick={() => setCurrentView(currentView === 'map' ? 'meter' : 'map')}
            className="bg-gray-700 p-2 rounded-lg"
          >
            {currentView === 'map' ? (
              <Gauge className="w-5 h-5 text-white" />
            ) : (
              <Map className="w-5 h-5 text-white" />
            )}
          </button>
        </div>
      </div>

      {/* Main content */}
      {currentView === 'meter' ? <MeterView /> : <MapView />}

      {/* Report button */}
      <button
        onClick={() => setShowReportModal(true)}
        className="fixed bottom-6 right-6 bg-red-600 text-white rounded-full p-4 shadow-lg hover:bg-red-700 transition-colors"
      >
        <Plus className="w-6 h-6" />
      </button>

      {/* Report modal */}
      {showReportModal && <ReportModal />}
    </div>
  );
};

export default App;