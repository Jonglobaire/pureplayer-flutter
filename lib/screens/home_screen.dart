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
                return _buildResponsiveContent(constraints);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveContent(BoxConstraints constraints) {
    // Get screen dimensions
    final screenWidth = constraints.maxWidth;
    final screenHeight = constraints.maxHeight;
    
    // Calculate responsive button dimensions
    final buttonWidth = screenWidth * 0.25; // 25% of screen width
    final buttonHeight = buttonWidth * 0.75; // 4:3 aspect ratio
    final horizontalSpacing = screenWidth * 0.035; // 3.5% horizontal spacing
    final verticalSpacing = screenHeight * 0.05; // 5% vertical spacing
    
    // Calculate responsive text and icon sizes
    final iconSize = buttonHeight * 0.3; // 30% of button height
    final fontSize = buttonHeight * 0.15; // 15% of button height
    
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.02,
          vertical: screenHeight * 0.02,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Header
            _buildHeader(screenWidth, screenHeight),
            SizedBox(height: verticalSpacing),
            
            // 2x3 Grid Layout - Centered
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Row 1: Live TV, Movies, Series
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildResponsiveButton(
                      'Live TV',
                      Icons.live_tv,
                      const Color(0xFFE50914),
                      _getChannelsByType('live').isNotEmpty ? () => _navigateToChannels('live', 'Live TV') : null,
                      buttonWidth,
                      buttonHeight,
                      iconSize,
                      fontSize,
                      0, // button index for animations
                    ),
                    SizedBox(width: horizontalSpacing),
                    _buildResponsiveButton(
                      'Movies',
                      Icons.movie,
                      const Color(0xFF1976D2),
                      _getChannelsByType('movies').isNotEmpty ? () => _navigateToChannels('movies', 'Movies') : null,
                      buttonWidth,
                      buttonHeight,
                      iconSize,
                      fontSize,
                      1, // button index for animations
                    ),
                    SizedBox(width: horizontalSpacing),
                    _buildResponsiveButton(
                      'Series',
                      Icons.video_library,
                      const Color(0xFF388E3C),
                      _getChannelsByType('series').isNotEmpty ? () => _navigateToChannels('series', 'TV Series') : null,
                      buttonWidth,
                      buttonHeight,
                      iconSize,
                      fontSize,
                      2, // button index for animations
                    ),
                  ],
                ),
                SizedBox(height: verticalSpacing),
                
                // Row 2: Reload, Settings, Exit
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildResponsiveButton(
                      'Reload',
                      Icons.refresh,
                      const Color(0xFFFF9800),
                      _allChannels.isNotEmpty && _currentPlaylistUrl != null ? () => _loadPlaylist(_currentPlaylistUrl!) : null,
                      buttonWidth,
                      buttonHeight,
                      iconSize,
                      fontSize,
                      3, // button index for animations
                    ),
                    SizedBox(width: horizontalSpacing),
                    _buildResponsiveButton(
                      'Settings',
                      Icons.settings,
                      const Color(0xFF607D8B),
                      () => _showSnackBar('Settings coming soon!'),
                      buttonWidth,
                      buttonHeight,
                      iconSize,
                      fontSize,
                      4, // button index for animations
                    ),
                    SizedBox(width: horizontalSpacing),
                    _buildResponsiveButton(
                      'Exit',
                      Icons.exit_to_app,
                      const Color(0xFFF44336),
                      _exitApp,
                      buttonWidth,
                      buttonHeight,
                      iconSize,
                      fontSize,
                      5, // button index for animations
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: verticalSpacing),
            
            // Playlist info at bottom
            _buildPlaylistInfo(screenWidth, screenHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double screenWidth, double screenHeight) {
    final logoSize = (screenWidth * 0.06).clamp(40.0, 80.0);
    final titleSize = (screenWidth * 0.03).clamp(18.0, 28.0);
    final subtitleSize = (screenWidth * 0.018).clamp(12.0, 16.0);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
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
        SizedBox(width: screenWidth * 0.015),
        Flexible(
          child: Column(
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
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Professional Streaming Experience',
                style: TextStyle(
                  fontSize: subtitleSize,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback? onTap,
    double width,
    double height,
    double iconSize,
    double fontSize,
    int buttonIndex,
  ) {
    final isEnabled = onTap != null;
    
    return SizedBox(
      width: width,
      height: height,
      child: Material(
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
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isEnabled ? Colors.white : Colors.white54,
                  size: iconSize,
                ),
                SizedBox(height: height * 0.08),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: isEnabled ? Colors.white : Colors.white54,
                      fontSize: fontSize,
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
  }

  Widget _buildPlaylistInfo(double screenWidth, double screenHeight) {
    final liveChannels = _getChannelsByType('live');
    final movieChannels = _getChannelsByType('movies');
    final seriesChannels = _getChannelsByType('series');
    final hasPlaylist = _allChannels.isNotEmpty;
    
    return Container(
      constraints: BoxConstraints(maxWidth: screenWidth * 0.8),
      padding: EdgeInsets.all(screenWidth * 0.02),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Playlist Status',
            style: TextStyle(
              color: Colors.white,
              fontSize: (screenWidth * 0.02).clamp(14.0, 18.0),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenHeight * 0.015),
          if (hasPlaylist) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tv, color: const Color(0xFFE50914), size: screenWidth * 0.015),
                SizedBox(width: screenWidth * 0.01),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Total: ${_allChannels.length} | Live: ${liveChannels.length} | Movies: ${movieChannels.length} | Series: ${seriesChannels.length}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: (screenWidth * 0.015).clamp(10.0, 14.0),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.01),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.link, color: const Color(0xFFE50914), size: screenWidth * 0.015),
                SizedBox(width: screenWidth * 0.01),
                Flexible(
                  child: Text(
                    _playlistName,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: (screenWidth * 0.015).clamp(10.0, 14.0),
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.015),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  'Change Playlist',
                  Icons.playlist_play,
                  const Color(0xFF9C27B0),
                  _showChangePlaylistDialog,
                  screenWidth,
                ),
                SizedBox(width: screenWidth * 0.02),
                _buildActionButton(
                  'Settings',
                  Icons.settings,
                  const Color(0xFF607D8B),
                  () => _showSnackBar('Settings coming soon!'),
                  screenWidth,
                ),
              ],
            ),
          ] else ...[
            Text(
              'No playlist loaded',
              style: TextStyle(
                color: Colors.white70,
                fontSize: (screenWidth * 0.018).clamp(12.0, 16.0),
              ),
            ),
            SizedBox(height: screenHeight * 0.015),
            _buildActionButton(
              'Load Playlist',
              Icons.playlist_play,
              const Color(0xFFE50914),
              _showChangePlaylistDialog,
              screenWidth,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap, double screenWidth) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.02,
            vertical: screenWidth * 0.01,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: screenWidth * 0.02,
              ),
              SizedBox(width: screenWidth * 0.01),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (screenWidth * 0.015).clamp(10.0, 14.0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}
