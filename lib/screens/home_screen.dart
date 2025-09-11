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
  
  // Focus management for D-Pad navigation
  int _focusedRow = 0;
  int _focusedCol = 0;
  final List<List<FocusNode>> _focusNodes = [];
  
  // Animation controllers for button interactions
  late List<List<AnimationController>> _scaleControllers;
  late List<List<Animation<double>>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    
    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Initialize focus nodes and animation controllers for 2x3 grid
    _initializeFocusAndAnimations();
    
    // Load initial playlist if provided
    if (widget.initialPlaylistUrl != null && widget.initialPlaylistUrl!.isNotEmpty) {
      _loadPlaylist(widget.initialPlaylistUrl!);
    }
  }

  void _initializeFocusAndAnimations() {
    // Create 2 rows, 3 columns
    for (int row = 0; row < 2; row++) {
      _focusNodes.add([]);
      _scaleControllers.add([]);
      for (int col = 0; col < 3; col++) {
        // Focus nodes
        final focusNode = FocusNode();
        _focusNodes[row].add(focusNode);
        
        // Animation controllers
        final controller = AnimationController(
          duration: const Duration(milliseconds: 150),
          vsync: this,
        );
        _scaleControllers.add([]);
        _scaleControllers[row].add(controller);
        
        // Scale animations
        final animation = Tween<double>(
          begin: 1.0,
          end: 1.1,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeOut,
        ));
        
        if (row == 0) {
          _scaleAnimations.add([]);
        }
        _scaleAnimations[row].add(animation);
        
        // Focus listeners
        focusNode.addListener(() {
          if (focusNode.hasFocus) {
            controller.forward();
            setState(() {
              _focusedRow = row;
              _focusedCol = col;
            });
          } else {
            controller.reverse();
          }
        });
      }
    }
    
    // Set initial focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0][0].requestFocus();
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
        _isLoading = false;
      });
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('playlistUrl', url);
      
      _showSnackBar('Playlist loaded successfully! ${channels.length} channels found');
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
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.playlist_play, color: Color(0xFFE50914), size: 28),
              SizedBox(width: 12),
              Text(
                'CHANGE PLAYLIST', 
                style: TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'M3U PLAYLIST URL',
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  Navigator.of(context).pop();
                  _loadPlaylist(url);
                }
              },
              child: const Text('LOAD PLAYLIST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Text(
                title.toUpperCase(), 
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            message, 
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showChangePlaylistDialog();
              },
              child: const Text('CHANGE PLAYLIST', style: TextStyle(color: Colors.orange)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                if (_currentPlaylistUrl != null) {
                  _loadPlaylist(_currentPlaylistUrl!);
                }
              },
              child: const Text('RETRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _handleButtonPress(int row, int col) {
    // Press animation
    _scaleControllers[row][col].forward().then((_) {
      _scaleControllers[row][col].reverse();
    });

    // Handle navigation based on button position
    if (row == 0) {
      // Top row: Live TV, Movies, Series
      switch (col) {
        case 0:
          _navigateToChannels('live', 'Live TV');
          break;
        case 1:
          _navigateToChannels('movies', 'Movies');
          break;
        case 2:
          _navigateToChannels('series', 'TV Series');
          break;
      }
    } else {
      // Bottom row: Reload, Settings, Exit
      switch (col) {
        case 0:
          if (_currentPlaylistUrl != null) {
            _loadPlaylist(_currentPlaylistUrl!);
          } else {
            _showChangePlaylistDialog();
          }
          break;
        case 1:
          _showSnackBar('Settings coming soon!');
          break;
        case 2:
          SystemNavigator.pop();
          break;
      }
    }
  }

  Widget _buildGridButton({
    required String title,
    required IconData icon,
    required int row,
    required int col,
    required bool isEnabled,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        // Button dimensions: 25% of screen width, 4:3 ratio
        final buttonWidth = screenWidth * 0.25;
        final buttonHeight = buttonWidth * 0.75;
        
        // Font size: 4-5% of screen height
        final fontSize = screenHeight * 0.045;
        final iconSize = fontSize * 1.2;

        return Focus(
          focusNode: _focusNodes[row][col],
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              switch (event.logicalKey) {
                case LogicalKeyboardKey.arrowLeft:
                  if (col > 0) {
                    _focusNodes[row][col - 1].requestFocus();
                  }
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowRight:
                  if (col < 2) {
                    _focusNodes[row][col + 1].requestFocus();
                  }
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowUp:
                  if (row > 0) {
                    _focusNodes[row - 1][col].requestFocus();
                  }
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowDown:
                  if (row < 1) {
                    _focusNodes[row + 1][col].requestFocus();
                  }
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.enter:
                case LogicalKeyboardKey.select:
                  if (isEnabled) {
                    _handleButtonPress(row, col);
                  }
                  return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: AnimatedBuilder(
            animation: _scaleAnimations[row][col],
            builder: (context, child) {
              final scale = _scaleAnimations[row][col].value;
              final isFocused = _focusNodes[row][col].hasFocus;
              
              return Transform.scale(
                scale: scale,
                child: GestureDetector(
                  onTap: isEnabled ? () => _handleButtonPress(row, col) : null,
                  onTapDown: (_) {
                    if (isEnabled) {
                      _scaleControllers[row][col].forward();
                    }
                  },
                  onTapUp: (_) {
                    if (isEnabled) {
                      _scaleControllers[row][col].reverse();
                    }
                  },
                  onTapCancel: () {
                    if (isEnabled) {
                      _scaleControllers[row][col].reverse();
                    }
                  },
                  child: Container(
                    width: buttonWidth,
                    height: buttonHeight,
                    decoration: BoxDecoration(
                      color: isEnabled ? const Color(0xFFE50914) : const Color(0xFF666666),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isFocused && isEnabled ? [
                        BoxShadow(
                          color: const Color(0xFFE50914).withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
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
                        SizedBox(height: screenHeight * 0.01),
                        Text(
                          title,
                          style: TextStyle(
                            color: isEnabled ? Colors.white : Colors.white54,
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while fetching playlist
    if (_isLoading) {
      return const LoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          
          // Calculate spacing
          final horizontalSpacing = screenWidth * 0.035; // 3.5% of screen width
          final verticalSpacing = screenHeight * 0.05; // 5% of screen height
          
          final hasPlaylist = _allChannels.isNotEmpty;
          final liveChannels = _getChannelsByType('live');
          final movieChannels = _getChannelsByType('movies');
          final seriesChannels = _getChannelsByType('series');

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Live TV, Movies, Series
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGridButton(
                      title: 'LIVE TV',
                      icon: Icons.live_tv,
                      row: 0,
                      col: 0,
                      isEnabled: hasPlaylist && liveChannels.isNotEmpty,
                    ),
                    SizedBox(width: horizontalSpacing),
                    _buildGridButton(
                      title: 'MOVIES',
                      icon: Icons.movie,
                      row: 0,
                      col: 1,
                      isEnabled: hasPlaylist && movieChannels.isNotEmpty,
                    ),
                    SizedBox(width: horizontalSpacing),
                    _buildGridButton(
                      title: 'SERIES',
                      icon: Icons.video_library,
                      row: 0,
                      col: 2,
                      isEnabled: hasPlaylist && seriesChannels.isNotEmpty,
                    ),
                  ],
                ),
                
                SizedBox(height: verticalSpacing),
                
                // Bottom row: Reload, Settings, Exit
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGridButton(
                      title: 'RELOAD',
                      icon: Icons.refresh,
                      row: 1,
                      col: 0,
                      isEnabled: true, // Always enabled - opens playlist dialog if no playlist
                    ),
                    SizedBox(width: horizontalSpacing),
                    _buildGridButton(
                      title: 'SETTINGS',
                      icon: Icons.settings,
                      row: 1,
                      col: 1,
                      isEnabled: true,
                    ),
                    SizedBox(width: horizontalSpacing),
                    _buildGridButton(
                      title: 'EXIT',
                      icon: Icons.exit_to_app,
                      row: 1,
                      col: 2,
                      isEnabled: true,
                    ),
                  ],
                ),
                
                // Playlist info at bottom
                if (!hasPlaylist) ...[
                  SizedBox(height: screenHeight * 0.08),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                      vertical: screenHeight * 0.02,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NO PLAYLIST LOADED',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: screenHeight * 0.025,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        GestureDetector(
                          onTap: _showChangePlaylistDialog,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.03,
                              vertical: screenHeight * 0.015,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'CHANGE PLAYLIST',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenHeight * 0.02,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    for (int row = 0; row < _scaleControllers.length; row++) {
      for (int col = 0; col < _scaleControllers[row].length; col++) {
        _scaleControllers[row][col].dispose();
      }
    }
    
    // Dispose all focus nodes
    for (int row = 0; row < _focusNodes.length; row++) {
      for (int col = 0; col < _focusNodes[row].length; col++) {
        _focusNodes[row][col].dispose();
      }
    }
    
    super.dispose();
  }
}

// Loading Screen Widget
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          
          // Logo size: 20% of screen width
          final logoSize = screenWidth * 0.2;
          
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // App Logo
                Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE50914).withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
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
                
                SizedBox(height: screenHeight * 0.08),
                
                // Loading Spinner
                const CircularProgressIndicator(
                  color: Color(0xFFE50914),
                  strokeWidth: 4,
                ),
                
                SizedBox(height: screenHeight * 0.04),
                
                // Loading Text
                Text(
                  'SERVER CONTENT LOADING...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenHeight * 0.03,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}