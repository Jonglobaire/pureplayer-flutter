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
            children: [
              Icon(Icons.playlist_play, color: Color(0xFFE50914), size: 28),
              SizedBox(width: 12),
              Text('Change Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 400,
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
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 16)),
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
    final screenSize = MediaQuery.of(context).size;
    final textScale = MediaQuery.of(context).textScaleFactor;
    
    // Show loading screen while fetching playlist
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.red),
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
            child: _buildMainContent(screenSize, textScale),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(Size screenSize, double textScale) {
    final liveChannels = _getChannelsByType('live');
    final movieChannels = _getChannelsByType('movies');
    final seriesChannels = _getChannelsByType('series');
    final hasPlaylist = _allChannels.isNotEmpty;

    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.all(screenSize.width * 0.02),
          child: _buildHeader(textScale),
        ),
        
        // Main content - IBO Player style layout
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate button dimensions based on available space
                final availableWidth = constraints.maxWidth * 0.9; // 90% of screen width
                final availableHeight = constraints.maxHeight * 0.7; // 70% of screen height
                
                // Large Live TV button (left side)
                final largeButtonWidth = availableWidth * 0.35; // 35% of available width
                final largeButtonHeight = availableHeight * 0.8; // 80% of available height
                
                // Small buttons (right side) - 2x3 grid
                final smallButtonWidth = availableWidth * 0.15; // 15% of available width
                final smallButtonHeight = smallButtonWidth * 0.75; // 4:3 aspect ratio
                
                // Spacing
                final horizontalGap = availableWidth * 0.03; // 3% horizontal gap
                final verticalGap = availableHeight * 0.05; // 5% vertical gap
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Large Live TV button (left side)
                    SizedBox(
                      width: largeButtonWidth,
                      height: largeButtonHeight,
                      child: _buildLargeTile(
                        'LIVE TV',
                        Icons.live_tv,
                        hasPlaylist ? '${liveChannels.length} channels' : 'No playlist loaded',
                        const Color(0xFFE50914),
                        hasPlaylist ? () => _navigateToChannels('live', 'Live TV') : null,
                      ),
                    ),
                    
                    SizedBox(width: horizontalGap * 2), // Double gap between sections
                    
                    // Right side - 2x3 grid of smaller buttons
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Top row: Movies, Series
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: smallButtonWidth,
                              height: smallButtonHeight,
                              child: _buildSmallTile(
                                'MOVIES',
                                Icons.movie,
                                hasPlaylist ? '${movieChannels.length}' : '0',
                                const Color(0xFF1976D2),
                                hasPlaylist ? () => _navigateToChannels('movies', 'Movies') : null,
                              ),
                            ),
                            SizedBox(width: horizontalGap),
                            SizedBox(
                              width: smallButtonWidth,
                              height: smallButtonHeight,
                              child: _buildSmallTile(
                                'SERIES',
                                Icons.video_library,
                                hasPlaylist ? '${seriesChannels.length}' : '0',
                                const Color(0xFF388E3C),
                                hasPlaylist ? () => _navigateToChannels('series', 'TV Series') : null,
                              ),
                            ),
                            SizedBox(width: horizontalGap),
                            SizedBox(
                              width: smallButtonWidth,
                              height: smallButtonHeight,
                              child: _buildSmallTile(
                                'SETTINGS',
                                Icons.settings,
                                '',
                                const Color(0xFF607D8B),
                                () => _showSnackBar('Settings coming soon!'),
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: verticalGap),
                        
                        // Bottom row: Reload, Exit (centered)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: smallButtonWidth,
                              height: smallButtonHeight,
                              child: _buildSmallTile(
                                'RELOAD',
                                Icons.refresh,
                                '',
                                const Color(0xFFFF9800),
                                hasPlaylist && _currentPlaylistUrl != null ? () => _loadPlaylist(_currentPlaylistUrl!) : null,
                              ),
                            ),
                            SizedBox(width: horizontalGap),
                            SizedBox(
                              width: smallButtonWidth,
                              height: smallButtonHeight,
                              child: _buildSmallTile(
                                'EXIT',
                                Icons.exit_to_app,
                                '',
                                const Color(0xFFF44336),
                                _exitApp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        
        // Bottom playlist info (compact)
        if (hasPlaylist)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(screenSize.width * 0.02),
            child: Center(
              child: Text(
                'Playlist: $_playlistName • ${_allChannels.length} channels total',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14 * textScale,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLargeTile(String title, IconData icon, String subtitle, Color color, VoidCallback? onTap) {
    final isEnabled = onTap != null;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(isEnabled ? 0.8 : 0.3),
                color.withOpacity(isEnabled ? 0.6 : 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isEnabled ? [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ] : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Icon(
                    icon, 
                    color: isEnabled ? Colors.white : Colors.white54, 
                    size: 80,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isEnabled ? Colors.white : Colors.white54,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: isEnabled ? Colors.white70 : Colors.white38,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallTile(String title, IconData icon, String subtitle, Color color, VoidCallback? onTap) {
    final isEnabled = onTap != null;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(isEnabled ? 0.8 : 0.3),
                color.withOpacity(isEnabled ? 0.6 : 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isEnabled ? [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: Icon(
                    icon, 
                    color: isEnabled ? Colors.white : Colors.white54, 
                    size: 32,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isEnabled ? Colors.white : Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isEnabled ? Colors.white70 : Colors.white38,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double textScale) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFE50914),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE50914).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'P',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pure Player',
              style: TextStyle(
                fontSize: 28 * textScale,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Professional Streaming Experience',
              style: TextStyle(
                fontSize: 16 * textScale,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Change Playlist button in header
        ElevatedButton.icon(
          onPressed: _showChangePlaylistDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9C27B0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.playlist_play, size: 20),
          label: const Text('Change Playlist'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}