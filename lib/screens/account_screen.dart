import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/device_info.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _macAddress = 'Loading...';
  String _deviceKey = 'Loading...';
  String _accountStatus = 'Loading...';
  String _accountExpiration = 'Loading...';
  String _playlistExpiration = 'Loading...';
  bool _isLoading = true;
  bool _isAccountActive = false;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    try {
      // Load device information
      final macAddress = await DeviceInfoHelper.getMacAddress();
      final deviceModel = await DeviceInfoHelper.getDeviceModel();
      
      // Load account data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('playlistUrl') ?? prefs.getString('m3u_url');
      
      // Parse account information from URL or stored data
      String accountStatus = 'Unknown';
      String accountExpiration = 'Not Available';
      String playlistExpiration = 'Not Available';
      bool isActive = false;
      
      if (savedUrl != null && savedUrl.isNotEmpty) {
        // Try to extract account info from Xtream API URL
        final uri = Uri.tryParse(savedUrl);
        if (uri != null) {
          final username = uri.queryParameters['username'];
          final password = uri.queryParameters['password'];
          
          if (username != null && password != null) {
            // Simulate account status check (in real app, this would be an API call)
            accountStatus = 'Active';
            isActive = true;
            accountExpiration = DateTime.now().add(const Duration(days: 30)).toString().split(' ')[0];
            playlistExpiration = DateTime.now().add(const Duration(days: 30)).toString().split(' ')[0];
          } else {
            accountStatus = 'Free Account';
            isActive = true;
            accountExpiration = 'No Expiration';
            playlistExpiration = 'No Expiration';
          }
        }
      } else {
        accountStatus = 'No Account';
        isActive = false;
      }

      if (mounted) {
        setState(() {
          _macAddress = macAddress;
          _deviceKey = deviceModel;
          _accountStatus = accountStatus;
          _accountExpiration = accountExpiration;
          _playlistExpiration = playlistExpiration;
          _isAccountActive = isActive;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _macAddress = 'Error loading';
          _deviceKey = 'Error loading';
          _accountStatus = 'Error';
          _accountExpiration = 'Error loading';
          _playlistExpiration = 'Error loading';
          _isAccountActive = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Account Information'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Center(
                    child: Text(
                      'Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // MAC Address
                  _buildAccountField(
                    'MAC Address:',
                    _isLoading ? 'Loading...' : _macAddress,
                  ),
                  const SizedBox(height: 16),
                  
                  // Device Key
                  _buildAccountField(
                    'Device Key:',
                    _isLoading ? 'Loading...' : _deviceKey,
                  ),
                  const SizedBox(height: 16),
                  
                  // Account Status
                  _buildAccountField(
                    'Account Status:',
                    _isLoading ? 'Loading...' : _accountStatus,
                    valueColor: _isLoading 
                        ? Colors.white70 
                        : (_isAccountActive ? Colors.green : Colors.red),
                  ),
                  const SizedBox(height: 16),
                  
                  // Account Expiration Date
                  _buildAccountField(
                    'Account Expiration Date:',
                    _isLoading ? 'Loading...' : _accountExpiration,
                  ),
                  const SizedBox(height: 16),
                  
                  // Playlist Expiration Date
                  _buildAccountField(
                    'Playlist Expiration Date:',
                    _isLoading ? 'Loading...' : _playlistExpiration,
                  ),
                  
                  if (_isLoading) ...[
                    const SizedBox(height: 24),
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE50914),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountField(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}