import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import '../services/m3u_parser.dart';
import 'channels_screen.dart';

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
  
  // Focus and animation controllers for each button
  final List<AnimationController> _scaleControllers = [];
  final List<Animation<double>> _scaleAnimations = [];
  final List<FocusNode> _focusNodes = [];
  
  // Button indices for 2x3 grid
  static const int _buttonCount = 6;

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
    
    // Initialize focus nodes and animation controllers for each button
    for (int i = 0; i < _buttonCount; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );
      final animation = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurveTween(curve: Curves.easeInOut).animate(controller),
      );
      
      _scaleControllers.add(controller);
      _scaleAnimations.add(animation);
      _focusNodes.add(FocusNode());
      
      // Add focus listeners
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          _scaleControllers[i].forward();
        } else {
          _scaleControllers[i].reverse();
        }
      });
    }
    
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

  // Handle button press animation (5% shrink then snap back)
  void _handleButtonPress(int index, VoidCallback? onPressed) {
    if (onPressed == null) return;
    
    final pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    final pressAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurveTween(curve: Curves.easeInOut).animate(pressController),
    );
    
    pressController.forward().then((_) {
      pressController.reverse().then((_) {
        onPressed();
        pressController.dispose();
      });
    });
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
    
    // IBO Player Pro exact specifications
    final buttonWidth = screenWidth * 0.25;
    final buttonHeight = buttonWidth * 0.75; // 4:3 ratio
    final horizontalGap = screenWidth * 0.03;
    final verticalGap = screenHeight * 0.05;
    
    // Calculate total grid dimensions
    final totalGridWidth = (buttonWidth * 3) + (horizontalGap * 2);
    final totalGridHeight = (buttonHeight * 2) + verticalGap;
    
    return Column(
      children: [
        // Header
        _buildHeader(screenWidth, screenHeight),
        
        // Main content - perfectly centered
        Expanded(
          child: Center(
            child: SizedBox(
              width: totalGridWidth,
              height: totalGridHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top row: Live TV, Movies, Series
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildIBOButton(
                        'Live TV',
                        Icons.live_tv,
                        const Color(0xFFE50914),
                        _getChannelsByType('live').isNotEmpty ? () => _navigateToChannels('live', 'Live TV') : null,
                        buttonWidth,
                        buttonHeight,
                        0,
                      ),
                      _buildIBOButton(
                        'Movies',
                        Icons.movie,
                        const Color(0xFF1976D2),
                        _getChannelsByType('movies').isNotEmpty ? () => _navigateToChannels('movies', 'Movies') : null,
                        buttonWidth,
                        buttonHeight,
                        1,
                      ),
                      _buildIBOButton(
                        'Series',
                        Icons.video_library,
                        const Color(0xFF388E3C),
                        _getChannelsByType('series').isNotEmpty ? () => _navigateToChannels('series', 'TV Series') : null,
                        buttonWidth,
                        buttonHeight,
                        2,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: verticalGap),
                  
                  // Bottom row: Reload, Settings, Exit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildIBOButton(
                        'Reload',
                        Icons.refresh,
                        const Color(0xFFFF9800),
                        _allChannels.isNotEmpty && _currentPlaylistUrl != null ? () => _loadPlaylist(_currentPlaylistUrl!) : null,
                        buttonWidth,
                        buttonHeight,
                        3,
                      ),
                      _buildIBOButton(
                        'Settings',
                        Icons.settings,
                        const Color(0xFF607D8B),
                        () => _showSnackBar('Settings coming soon!'),
                        buttonWidth,
                        buttonHeight,
                        4,
                      ),
                      _buildIBOButton(
                        'Exit',
                        Icons.exit_to_app,
                        const Color(0xFFF44336),
                        _exitApp,
                        buttonWidth,
                        buttonHeight,
                        5,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Footer - playlist info
        _buildFooter(screenWidth, screenHeight),
      ],
    );
  }

  Widget _buildIBOButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback? onTap,
    double width,
    double height,
    int index,
  ) {
    final isEnabled = onTap != null;
    
    return AnimatedBuilder(
      animation: _scaleAnimations[index],
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimations[index].value,
          child: Focus(
            focusNode: _focusNodes[index],
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index % 3 > 0) {
                  _focusNodes[index - 1].requestFocus();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && index % 3 < 2) {
                  _focusNodes[index + 1].requestFocus();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && index >= 3) {
                  _focusNodes[index - 3].requestFocus();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && index < 3) {
                  _focusNodes[index + 3].requestFocus();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.select || 
                          event.logicalKey == LogicalKeyboardKey.enter) {
                  _handleButtonPress(index, onTap);
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: SizedBox(
              width: width,
              height: height,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleButtonPress(index, onTap),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(isEnabled ? 0.9 : 0.3),
                          color.withOpacity(isEnabled ? 0.7 : 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isEnabled ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ] : null,
                      border: _focusNodes[index].hasFocus 
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          color: isEnabled ? Colors.white : Colors.white54,
                          size: height * 0.3,
                        ),
                        SizedBox(height: height * 0.08),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title.toUpperCase(),
                            style: TextStyle(
                              color: isEnabled ? Colors.white : Colors.white54,
                              fontSize: height * 0.15,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double screenWidth, double screenHeight) {
    final logoSize = (screenWidth * 0.04).clamp(30.0, 60.0);
    final titleSize = (screenWidth * 0.025).clamp(16.0, 24.0);
    final subtitleSize = (screenWidth * 0.015).clamp(10.0, 14.0);
    
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE50914).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'P',
                    style: TextStyle(
                      fontSize: logoSize * 0.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.01),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pure Player',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Professional Streaming Experience',
                    style: TextStyle(
                      fontSize: subtitleSize,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_allChannels.isEmpty)
            ElevatedButton.icon(
              onPressed: _showChangePlaylistDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.02,
                  vertical: screenHeight * 0.01,
                ),
              ),
              icon: const Icon(Icons.playlist_play, size: 20),
              label: const Text('Load Playlist'),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(double screenWidth, double screenHeight) {
    if (_allChannels.isEmpty) return const SizedBox.shrink();
    
    final liveChannels = _getChannelsByType('live');
    final movieChannels = _getChannelsByType('movies');
    final seriesChannels = _getChannelsByType('series');
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.02),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Playlist: $_playlistName | Total: ${_allChannels.length} | Live: ${liveChannels.length} | Movies: ${movieChannels.length} | Series: ${seriesChannels.length}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: (screenWidth * 0.012).clamp(10.0, 14.0),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: _showChangePlaylistDialog,
            icon: const Icon(Icons.playlist_play, color: Color(0xFFE50914), size: 16),
            label: const Text(
              'Change',
              style: TextStyle(color: Color(0xFFE50914)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    for (final controller in _scaleControllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}