import 'package:flutter/material.dart';
import '../services/real_api_service.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  
  final _apiService = RealApiService();
  final _notificationService = NotificationService();
  final _websocketService = WebSocketService();
  
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
      });
      return;
    }

    if (!_isLogin && _passwordController.text != _passwordConfirmController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get FCM token to send with login/register
      final fcmToken = await _notificationService.getFCMToken();
      
      Map<String, dynamic>? result;
      
      if (_isLogin) {
        result = await _apiService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          deviceToken: fcmToken,
        );
      } else {
        if (_usernameController.text.isEmpty) {
          setState(() {
            _errorMessage = 'Username is required for registration';
            _isLoading = false;
          });
          return;
        }
        
        result = await _apiService.register(
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          passwordConfirmation: _passwordConfirmController.text,
        );
        
        // Update FCM token after registration
        if (result != null && fcmToken != null) {
          await _apiService.updateDeviceToken(fcmToken);
        }
      }

      setState(() {
        _isLoading = false;
      });

      if (result != null) {
        // Update FCM token on server after successful authentication
        await _notificationService.updateTokenOnServer();
        
        // Update WebSocket authentication
        await _websocketService.updateAuthentication(
          result['user']['id'].toString(),
          result['token'],
        );
        
        // Navigate to home screen
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() {
          _errorMessage = _isLogin ? 'Invalid credentials' : 'Registration failed';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred. Please try again.';
      });
      print('Authentication error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo and title
              Icon(
                Icons.traffic,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'RadarAlert',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              
              // Auth form
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Email field
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    
                    // Username field (for registration only)
                    if (!_isLogin) ...[
                      TextField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Password field
                    TextField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    
                    // Confirm password field (for registration only)
                    if (!_isLogin) ...[
                      TextField(
                        controller: _passwordConfirmController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _authenticate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : Text(
                                _isLogin ? 'Login' : 'Register',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Switch between login and register
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        _isLogin
                            ? 'Don\'t have an account? Register'
                            : 'Already have an account? Login',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}