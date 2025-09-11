import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import '../services/m3u_parser.dart';
import 'channels_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
    
    _loadSavedPlaylist();
    _fadeController.forward();
  }

  Future<void> _loadSavedPlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('m3u_url');
      
      if (savedUrl != null && savedUrl.isNotEmpty) {
        setState(() {
          _currentPlaylistUrl = savedUrl;
          _playlistName = _getShortUrl(savedUrl);
        });
        await _loadPlaylist(savedUrl);
      }
    } catch (e) {
      debugPrint('Error loading saved playlist: $e');
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
      await prefs.setString('m3u_url', url);
      
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
            child: _isLoading ? _buildLoadingScreen() : _buildMainContent(screenSize, textScale),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 4),
          SizedBox(height: 24),
          Text(
            'Loading playlist...',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(Size screenSize, double textScale) {
    final liveChannels = _getChannelsByType('live');
    final movieChannels = _getChannelsByType('movies');
    final seriesChannels = _getChannelsByType('series');

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(screenSize.width * 0.02),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content area (2x2 grid)
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(textScale),
                  SizedBox(height: screenSize.height * 0.03),

                  // Main content
                  _allChannels.isEmpty ? _buildNoPlaylistContent(screenSize) : _buildContentGrid(liveChannels, movieChannels, seriesChannels, screenSize),
                ],
              ),
            ),
            SizedBox(width: screenSize.width * 0.02),

            // Right sidebar
            _buildSidebar(liveChannels, movieChannels, seriesChannels, screenSize, textScale),
          ],
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
      ],
    );
  }

  Widget _buildNoPlaylistContent(Size screenSize) {
    return Center(
      child: Container(
        height: screenSize.height * 0.6,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.playlist_remove,
              size: 64,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Playlist Loaded',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Load an M3U playlist to start streaming',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showChangePlaylistDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Load Playlist',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentGrid(List<Channel> liveChannels, List<Channel> movieChannels, List<Channel> seriesChannels, Size screenSize) {
    return SizedBox(
      height: screenSize.height * 0.6,
      child: Row(
        children: [
          // Left side - Live TV (large tile)
          Expanded(
            flex: 2,
            child: _buildLargeTile(
              'Live TV',
              Icons.live_tv,
              '${liveChannels.length} channels',
              const Color(0xFFE50914),
              () => _navigateToChannels('live', 'Live TV'),
            ),
          ),
          const SizedBox(width: 20),
          
          // Right side - Movies and Series (2x1 grid)
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: _buildMediumTile(
                    'Movies',
                    Icons.movie,
                    '${movieChannels.length} movies',
                    const Color(0xFF1976D2),
                    () => _navigateToChannels('movies', 'Movies'),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _buildMediumTile(
                    'Series',
                    Icons.video_library,
                    '${seriesChannels.length} series',
                    const Color(0xFF388E3C),
                    () => _navigateToChannels('series', 'TV Series'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeTile(String title, IconData icon, String subtitle, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.8),
                color.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 64),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediumTile(String title, IconData icon, String subtitle, Color color, VoidCallback onTap) {
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
                color.withOpacity(0.8),
                color.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 40),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(List<Channel> liveChannels, List<Channel> movieChannels, List<Channel> seriesChannels, Size screenSize, double textScale) {
    return SizedBox(
      width: screenSize.width * 0.25,
      child: Column(
        children: [
          // Playlist info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Playlist Info',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18 * textScale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_currentPlaylistUrl != null) ...[
                  _buildInfoRow(Icons.link, 'Source', _playlistName),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.tv, 'Total', '${_allChannels.length}'),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.live_tv, 'Live TV', '${liveChannels.length}'),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.movie, 'Movies', '${movieChannels.length}'),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.video_library, 'Series', '${seriesChannels.length}'),
                ] else ...[
                  const Text(
                    'No playlist loaded',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Expanded(
            child: Column(
              children: [
                _buildSidebarButton(
                  'Change Playlist',
                  Icons.playlist_play,
                  const Color(0xFF9C27B0),
                  _showChangePlaylistDialog,
                ),
                const SizedBox(height: 12),
                _buildSidebarButton(
                  'Reload',
                  Icons.refresh,
                  const Color(0xFFFF9800),
                  _currentPlaylistUrl != null ? () => _loadPlaylist(_currentPlaylistUrl!) : null,
                ),
                const SizedBox(height: 12),
                _buildSidebarButton(
                  'Settings',
                  Icons.settings,
                  const Color(0xFF607D8B),
                  () => _showSnackBar('Settings coming soon!'),
                ),
                const Spacer(),
                _buildSidebarButton(
                  'Exit',
                  Icons.exit_to_app,
                  const Color(0xFFF44336),
                  _exitApp,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE50914), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarButton(String title, IconData icon, Color color, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: onTap != null ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onTap != null ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: onTap != null ? color : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: onTap != null ? Colors.white : Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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