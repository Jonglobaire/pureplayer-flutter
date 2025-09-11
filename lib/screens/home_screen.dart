import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import '../services/m3u_parser.dart';
import 'channels_screen.dart';
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
  final FocusNode _liveTvFocus = FocusNode();
  final FocusNode _moviesFocus = FocusNode();
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
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'p.m.' : 'a.m.'}';
    if (mounted) {
      setState(() {
        _currentTime = timeString;
      });
    }
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
        // Clock in top-right corner
        Positioned(
          top: screenHeight * 0.03,
          right: screenWidth * 0.03,
          child: Text(
            _currentTime,
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth * 0.02,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        // Logo centered horizontally, slightly above center
        Positioned(
          top: screenHeight * 0.15,
          left: screenWidth * 0.5 - (screenWidth * 0.15),
          child: Container(
            width: screenWidth * 0.3,
            height: screenHeight * 0.15,
            decoration: BoxDecoration(
              color: const Color(0xFFE50914),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE50914).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ibo',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: const Color(0xFFE50914),
                      size: screenWidth * 0.025,
                    ),
                  ),
                  Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: screenWidth * 0.025,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Main content area
        Positioned(
          top: screenHeight * 0.35,
          left: 0,
          right: 0,
          bottom: 0,
          child: Row(
            children: [
              // Left Section - 2x2 Grid
              Expanded(
                flex: 7,
                child: _buildLeftSection(screenWidth, screenHeight),
              ),
              
              // Right Section - Vertical buttons
              Expanded(
                flex: 3,
                child: _buildRightSection(screenWidth, screenHeight),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeftSection(double screenWidth, double screenHeight) {
    final buttonWidth = screenWidth * 0.15;
    final buttonHeight = screenHeight * 0.2;
    final largeButtonWidth = screenWidth * 0.25;
    final largeButtonHeight = screenHeight * 0.35;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large Live TV button
              _buildMainButton(
                'EN DIRECT',
                Icons.live_tv,
                const Color(0xFF5D2C2C),
                _getChannelsByType('live').isNotEmpty ? () => _navigateToChannels('live', 'Live TV') : null,
                largeButtonWidth,
                largeButtonHeight,
                _liveTvFocus,
                isLarge: true,
              ),
              SizedBox(width: screenWidth * 0.03),
              Column(
                children: [
                  // Films button
                  _buildMainButton(
                    'FILMS',
                    Icons.movie,
                    const Color(0xFF5D2C2C),
                    _getChannelsByType('movies').isNotEmpty ? () => _navigateToChannels('movies', 'Movies') : null,
                    buttonWidth,
                    buttonHeight * 0.7,
                    _moviesFocus,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  // Series button
                  _buildMainButton(
                    'SÉRIES',
                    Icons.video_library,
                    const Color(0xFF5D2C2C),
                    _getChannelsByType('series').isNotEmpty ? () => _navigateToChannels('series', 'TV Series') : null,
                    buttonWidth,
                    buttonHeight * 0.7,
                    _accountFocus,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.03),
          // Bottom row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMainButton(
                'COMPTE\nUTILISATEUR',
                Icons.person,
                const Color(0xFF5D2C2C),
                () => _showSnackBar('Account settings coming soon!'),
                buttonWidth,
                buttonHeight * 0.7,
                _accountFocus,
              ),
              SizedBox(width: screenWidth * 0.03),
              _buildMainButton(
                'CHANGER LA LISTE\nDE LECTURE',
                Icons.playlist_play,
                const Color(0xFF5D2C2C),
                _showChangePlaylistDialog,
                buttonWidth,
                buttonHeight * 0.7,
                _playlistFocus,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightSection(double screenWidth, double screenHeight) {
    final buttonWidth = screenWidth * 0.2;
    final buttonHeight = screenHeight * 0.08;
    
    return Padding(
      padding: EdgeInsets.only(right: screenWidth * 0.03),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSlimButton(
            'PARAMÈTRES',
            Icons.settings,
            () => _showSnackBar('Settings coming soon!'),
            buttonWidth,
            buttonHeight,
            _settingsFocus,
          ),
          SizedBox(height: screenHeight * 0.03),
          _buildSlimButton(
            'RECHARGER',
            Icons.refresh,
            _allChannels.isNotEmpty && _currentPlaylistUrl != null ? () => _loadPlaylist(_currentPlaylistUrl!) : null,
            buttonWidth,
            buttonHeight,
            _reloadFocus,
          ),
          SizedBox(height: screenHeight * 0.03),
          _buildSlimButton(
            'QUITTER',
            Icons.exit_to_app,
            _exitApp,
            buttonWidth,
            buttonHeight,
            _exitFocus,
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback? onTap,
    double width,
    double height,
    FocusNode focusNode, {
    bool isLarge = false,
  }) {
    final isEnabled = onTap != null;
    
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            if (isEnabled) onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, child) {
          final isFocused = focusNode.hasFocus;
          return AnimatedScale(
            scale: isFocused ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: color.withOpacity(isEnabled ? 0.9 : 0.3),
                borderRadius: BorderRadius.circular(12),
                border: isFocused ? Border.all(color: Colors.white, width: 2) : null,
                boxShadow: isFocused ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isEnabled ? onTap : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: isEnabled ? Colors.white : Colors.white54,
                        size: isLarge ? width * 0.2 : width * 0.25,
                      ),
                      SizedBox(height: height * 0.1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isEnabled ? Colors.white : Colors.white54,
                            fontSize: isLarge ? width * 0.06 : width * 0.08,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
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

  Widget _buildSlimButton(
    String title,
    IconData icon,
    VoidCallback? onTap,
    double width,
    double height,
    FocusNode focusNode,
  ) {
    final isEnabled = onTap != null;
    
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            if (isEnabled) onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, child) {
          final isFocused = focusNode.hasFocus;
          return AnimatedScale(
            scale: isFocused ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFocused ? const Color(0xFFE50914) : Colors.white.withOpacity(0.5),
                  width: isFocused ? 2 : 1,
                ),
                boxShadow: isFocused ? [
                  BoxShadow(
                    color: const Color(0xFFE50914).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isEnabled ? onTap : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: isEnabled ? Colors.white : Colors.white54,
                        size: height * 0.4,
                      ),
                      SizedBox(width: width * 0.05),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            style: TextStyle(
                              color: isEnabled ? Colors.white : Colors.white54,
                              fontSize: height * 0.25,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
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
    _liveTvFocus.dispose();
    _moviesFocus.dispose();
    _accountFocus.dispose();
    _playlistFocus.dispose();
    _settingsFocus.dispose();
    _reloadFocus.dispose();
    _exitFocus.dispose();
    super.dispose();
  }
}