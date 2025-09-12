import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import '../services/m3u_parser.dart';
import 'channels_screen.dart';
import 'input_screen.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  final String? initialPlaylistUrl;

  const HomeScreen({super.key, this.initialPlaylistUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Channel> _allChannels = [];
  bool _isLoading = false;
  String? _currentPlaylistUrl;
  String _playlistName = '';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _clockTimer;
  String _currentTime = '';

  // Focus nodes for navigation
  final FocusNode _livetvFocus = FocusNode();
  final FocusNode _filmsFocus = FocusNode();
  final FocusNode _accountFocus = FocusNode();
  final FocusNode _playlistFocus = FocusNode();
  final FocusNode _settingsFocus = FocusNode();
  final FocusNode _reloadFocus = FocusNode();
  final FocusNode _exitFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    
    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurveTween(curve: Curves.easeInOut).animate(_fadeController),
    );
    
    // Initialize clock
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
    
    // Load initial playlist if provided
    if (widget.initialPlaylistUrl != null && widget.initialPlaylistUrl!.isNotEmpty) {
      _loadPlaylist(widget.initialPlaylistUrl!);
    } else {
      setState(() {
        _playlistName = 'No Playlist Loaded';
      });
    }
    
    _fadeController.forward();
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'p.m.' : 'a.m.';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    
    setState(() {
      _currentTime = '$displayHour:$minute $period';
    });
  }

  Future<void> _loadPlaylist(String url) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final channels = await M3UParser.fetchAndParseM3U(url);
      setState(() {
        _allChannels = channels;
        _currentPlaylistUrl = url;
        _playlistName = _getShortUrl(url);
        _isLoading = false;
      });
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('playlistUrl', url);
      
      _showSnackBar('Playlist loaded successfully! ${channels.length} channels found');
      debugPrint('✅ Loaded ${channels.length} channels');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Failed to load playlist', e.toString());
    }
  }

  void _showChangePlaylistDialog() {
    final TextEditingController urlController = TextEditingController();
    if (_currentPlaylistUrl != null) {
      urlController.text = _currentPlaylistUrl!;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.playlist_play, color: Color(0xFFE50914), size: 28),
              SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Change Playlist', 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth > 400 ? 400 : constraints.maxWidth * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: urlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'M3U Playlist URL',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'https://example.com/playlist.m3u',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.link, color: Color(0xFFE50914)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE50914), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  Navigator.of(context).pop();
                  _loadPlaylist(url);
                }
              },
              child: const Text('Load Playlist', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : const Color(0xFFE50914),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  title, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Text(
            message, 
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showChangePlaylistDialog();
              },
              child: const Text('Change Playlist', style: TextStyle(color: Colors.orange)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
              onPressed: () {
                Navigator.of(context).pop();
                if (_currentPlaylistUrl != null) {
                  _loadPlaylist(_currentPlaylistUrl!);
                }
              },
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  List<Channel> _getChannelsByType(String type) {
    switch (type.toLowerCase()) {
      case 'live':
        return _allChannels.where((channel) => 
          !channel.group.toLowerCase().contains('movie') &&
          !channel.group.toLowerCase().contains('series') &&
          !channel.group.toLowerCase().contains('vod')
        ).toList();
      case 'movies':
        return _allChannels.where((channel) => 
          channel.group.toLowerCase().contains('movie') ||
          channel.group.toLowerCase().contains('film') ||
          channel.group.toLowerCase().contains('cinema')
        ).toList();
      case 'series':
        return _allChannels.where((channel) => 
          channel.group.toLowerCase().contains('series') ||
          channel.group.toLowerCase().contains('tv show') ||
          channel.group.toLowerCase().contains('drama')
        ).toList();
      default:
        return _allChannels;
    }
  }

  void _navigateToChannels(String type, String title) {
    if (_allChannels.isEmpty) {
      _showSnackBar('Please load a playlist first', isError: true);
      return;
    }
    
    final channels = _getChannelsByType(type);
    if (channels.isEmpty) {
      _showSnackBar('No $title channels found', isError: true);
      return;
    }
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          ChannelsScreen(channels: channels, title: title),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _navigateToAccount() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const InputScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  String _getShortUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.length > 20 ? '${uri.host.substring(0, 20)}...' : uri.host;
    } catch (e) {
      return url.length > 25 ? '${url.substring(0, 25)}...' : url;
    }
  }

  void _exitApp() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while fetching playlist
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFE50914)),
        ),
      );
    }
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black,
              Color(0xFF1A1A1A),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildIBOLayout(constraints);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIBOLayout(BoxConstraints constraints) {
    final screenWidth = constraints.maxWidth;
    final screenHeight = constraints.maxHeight;
    
    return Stack(
      children: [
        // Live Clock - Top Right
        Positioned(
          top: screenHeight * 0.03,
          right: screenWidth * 0.03,
          child: Text(
            _currentTime,
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth * 0.025,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        // Main Content - Centered
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                margin: EdgeInsets.only(bottom: screenHeight * 0.05),
                child: _buildLogo(screenWidth),
              ),
              
              // Main Layout Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Section - 2x2 Grid
                  _buildLeftGrid(screenWidth, screenHeight),
                  
                  SizedBox(width: screenWidth * 0.08),
                  
                  // Right Section - Vertical Stack
                  _buildRightStack(screenWidth, screenHeight),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogo(double screenWidth) {
    final logoSize = screenWidth * 0.18; // 18% of screen width
    
    return Container(
      width: logoSize,
      height: logoSize * 0.6, // Maintain aspect ratio
      decoration: BoxDecoration(
        color: const Color(0xFFE50914),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE50914).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'IBO PRO',
          style: TextStyle(
            fontSize: logoSize * 0.15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildLeftGrid(double screenWidth, double screenHeight) {
    final buttonSize = screenWidth * 0.12; // Base button size
    final spacing = screenWidth * 0.02; // Spacing between buttons
    
    return Column(
      children: [
        // Top Row
        Row(
          children: [
            // En direct (Live TV) - Double size
            _buildMainButton(
              'EN DIRECT',
              Icons.live_tv,
              const Color(0xFF5D2C2C),
              () => _navigateToChannels('live', 'Live TV'),
              buttonSize * 2 + spacing, // Double width + spacing
              buttonSize * 2 + spacing, // Double height + spacing
              screenWidth,
              _livetvFocus,
            ),
            
            SizedBox(width: spacing),
            
            // Films
            _buildMainButton(
              'FILMS',
              Icons.movie,
              const Color(0xFF5D2C2C),
              () => _navigateToChannels('movies', 'Movies'),
              buttonSize,
              buttonSize,
              screenWidth,
              _filmsFocus,
            ),
          ],
        ),
        
        SizedBox(height: spacing),
        
        // Bottom Row
        Row(
          children: [
            // Compte utilisateur
            _buildMainButton(
              'COMPTE\nUTILISATEUR',
              Icons.person,
              const Color(0xFF5D2C2C),
              _navigateToAccount,
              buttonSize,
              buttonSize,
              screenWidth,
              _accountFocus,
            ),
            
            SizedBox(width: spacing),
            
            // Changer la liste de lecture
            _buildMainButton(
              'CHANGER LA\nLISTE DE LECTURE',
              Icons.playlist_play,
              const Color(0xFF5D2C2C),
              _showChangePlaylistDialog,
              buttonSize,
              buttonSize,
              screenWidth,
              _playlistFocus,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightStack(double screenWidth, double screenHeight) {
    final buttonWidth = screenWidth * 0.15;
    final buttonHeight = screenHeight * 0.08;
    final spacing = screenHeight * 0.03;
    
    return Column(
      children: [
        _buildRightButton(
          'PARAMÈTRES',
          Icons.settings,
          () => _showSnackBar('Settings coming soon!'),
          buttonWidth,
          buttonHeight,
          screenWidth,
          _settingsFocus,
        ),
        
        SizedBox(height: spacing),
        
        _buildRightButton(
          'RECHARGER',
          Icons.refresh,
          _allChannels.isNotEmpty && _currentPlaylistUrl != null 
            ? () => _loadPlaylist(_currentPlaylistUrl!) 
            : null,
          buttonWidth,
          buttonHeight,
          screenWidth,
          _reloadFocus,
        ),
        
        SizedBox(height: spacing),
        
        _buildRightButton(
          'QUITTER',
          Icons.exit_to_app,
          _exitApp,
          buttonWidth,
          buttonHeight,
          screenWidth,
          _exitFocus,
        ),
      ],
    );
  }

  Widget _buildMainButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback? onTap,
    double width,
    double height,
    double screenWidth,
    FocusNode focusNode,
  ) {
    final isEnabled = onTap != null;
    final fontSize = screenWidth * 0.012;
    final iconSize = width * 0.25;
    
    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          
          return AnimatedScale(
            scale: hasFocus ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: color.withOpacity(isEnabled ? 0.9 : 0.3),
                borderRadius: BorderRadius.circular(12),
                border: hasFocus 
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
                boxShadow: hasFocus ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ] : [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: isEnabled ? Colors.white : Colors.white54,
                        size: iconSize,
                      ),
                      SizedBox(height: height * 0.08),
                      Text(
                        title,
                        style: TextStyle(
                          color: isEnabled ? Colors.white : Colors.white54,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRightButton(
    String title,
    IconData icon,
    VoidCallback? onTap,
    double width,
    double height,
    double screenWidth,
    FocusNode focusNode,
  ) {
    final isEnabled = onTap != null;
    final fontSize = screenWidth * 0.014;
    final iconSize = height * 0.35;
    
    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          
          return AnimatedScale(
            scale: hasFocus ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFocus ? Colors.white : Colors.white70,
                  width: hasFocus ? 2 : 1,
                ),
                boxShadow: hasFocus ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ] : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: isEnabled ? Colors.white : Colors.white54,
                        size: iconSize,
                      ),
                      SizedBox(width: width * 0.08),
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isEnabled ? Colors.white : Colors.white54,
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _clockTimer?.cancel();
    _livetvFocus.dispose();
    _filmsFocus.dispose();
    _accountFocus.dispose();
    _playlistFocus.dispose();
    _settingsFocus.dispose();
    _reloadFocus.dispose();
    _exitFocus.dispose();
    super.dispose();
  }
}