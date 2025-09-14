import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/netflix_button.dart';
import '../screens/channels_screen.dart';
import '../screens/input_screen.dart';
import 'playlist_screen.dart';
import '../screens/movies_screen.dart';
import '../screens/series_screen.dart';
import '../screens/account_screen.dart';
import '../screens/settings_screen.dart';
import '../services/m3u_parser.dart'; // Correct import path

class HomeScreen extends StatefulWidget {
  final String? initialPlaylistUrl;
  
  const HomeScreen({Key? key, this.initialPlaylistUrl}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _focusedIndex = 0;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<String?> _resolveSavedPlaylistUrl() async {
    if (_prefs == null) await _initPrefs();
    
    // First try 'playlistUrl'
    String? url = _prefs!.getString('playlistUrl');
    if (url != null && url.isNotEmpty) {
      return url;
    }
    
    // Fallback to 'm3u_url'
    url = _prefs!.getString('m3u_url');
    if (url != null && url.isNotEmpty) {
      return url;
    }
    
    // Try building M3U link from Xtream credentials
    final portal = _prefs!.getString('xtreamPortal');
    final username = _prefs!.getString('xtreamUsername');
    final password = _prefs!.getString('xtreamPassword');
    
    if (portal != null && portal.isNotEmpty &&
        username != null && username.isNotEmpty &&
        password != null && password.isNotEmpty) {
      return '$portal/get.php?username=$username&password=$password&type=m3u_plus&output=ts';
    }
    
    return null;
  }

  Future<bool> _checkPlaylistAndShowError() async {
    final url = await _resolveSavedPlaylistUrl();
    if (url == null) {
      _showInlineError("Please add a playlist first");
      return false;
    }
    return true;
  }

  void _showInlineError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Focus(
              autofocus: true,
              onKey: _handleKeyPress,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;

                  // EXACT PERCENTAGES FROM LAYOUT.JSON
                  const livetvWidth = 0.275;    // 27.5% Live TV width
                  const livetvHeight = 0.41;    // 41% Live TV height
                  const gridButtonWidth = 0.1159;  // 11.59% Grid button width
                  const gridButtonHeight = 0.1977; // 19.77% Grid button height
                  const rightButtonWidth = 0.176;  // 17.6% Right button width
                  const rightButtonHeight = 0.1163; // 11.63% Right button height
                  const logoWidth = 0.33;    // 33% Logo width (50% increase)
                  const logoTopMargin = 0.045;  // 4.5% Logo top margin
                  const gridTopPosition = 0.4078; // 40.78% Grid top position

                  // TIGHTENED GAPS - FURTHER REDUCED
                  final gLiveToGrid = (0.03 * w) * 0.75;    // 2.25% gap (REDUCED by 25%)
                  final gGridCols = (0.025 * w) * 0.8;    // 2% gap between grid columns (REDUCED by 20%)
                  final gGridToRight = 0.035 * w;  // 3.5% gap to right column
                  final gRightVert = 0.035 * h;    // 3.5% vertical gap in right column

                  // CALCULATE SIZES
                  final liveW = livetvWidth * w;
                  final liveH = livetvHeight * h;
                  final gridW = gridButtonWidth * w;
                  final gridH = gridButtonHeight * h;
                  final rightW = rightButtonWidth * w;
                  final rightH = rightButtonHeight * h;

                  // CALCULATE TOTAL WIDTH AND CENTER
                  final totalWidth = liveW + gLiveToGrid + (2 * gridW + gGridCols) + gGridToRight + rightW;
                  final leftPad = (w - totalWidth) / 2;

                  return Stack(
                    children: [
                      // === BOTTOM GRADIENT OVERLAY ===
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 0.18 * h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent
                              ],
                            ),
                          ),
                        ),
                      ),

                      // === LOGO - TOP CENTER ===
                      Positioned(
                        top: 0.045 * h,
                        left: (w - 0.33 * w) / 2, // Perfect center
                        width: 0.33 * w,
                        height: h * 0.15, // Maintain aspect ratio
                        child: IgnorePointer(
                          child: Container(
                            alignment: Alignment.center,
                            child: Image.asset(
                              "assets/images/logo.png",
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      // === CENTERED MAIN LAYOUT ===
                      Positioned(
                        top: gridTopPosition * h,
                        left: leftPad,
                        child: SizedBox(
                          width: totalWidth,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // === LIVE TV BUTTON ===
                              SizedBox(
                                width: liveW,
                                height: liveH,
                                child: NetflixButton(
                                  isFocused: _focusedIndex == 0,
                                  onTap: () => _onPressed(0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/images/tv.svg',
                                        color: Colors.white,
                                        height: 70,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Live TV',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(width: gLiveToGrid),

                              // === 2x2 GRID BUTTONS ===
                              SizedBox(
                                width: 2 * gridW + gGridCols,
                                child: Column(
                                  children: [
                                    // Top row: Movies + Series
                                    Row(
                                      children: [
                                        // Movies
                                        SizedBox(
                                          width: gridW,
                                          height: gridH,
                                          child: NetflixButton(
                                            isFocused: _focusedIndex == 1,
                                            onTap: () => _onPressed(1),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/images/movies.svg',
                                                  color: Colors.white,
                                                  height: 35,
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  'Movies',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: gGridCols),
                                        // Series
                                        SizedBox(
                                          width: gridW,
                                          height: gridH,
                                          child: NetflixButton(
                                            isFocused: _focusedIndex == 2,
                                            onTap: () => _onPressed(2),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/images/series.svg',
                                                  color: Colors.white,
                                                  height: 35,
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  'Series',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 0.02 * h), // 2% vertical gap
                                    // Bottom row: Account + Playlist
                                    Row(
                                      children: [
                                        // Account
                                        SizedBox(
                                          width: gridW,
                                          height: gridH,
                                          child: NetflixButton(
                                            isFocused: _focusedIndex == 3,
                                            onTap: () => _onPressed(3),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/images/users.svg',
                                                  color: Colors.white,
                                                  height: 35,
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  'Account',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: gGridCols),
                                        // Playlist
                                        SizedBox(
                                          width: gridW,
                                          height: gridH,
                                          child: NetflixButton(
                                            isFocused: _focusedIndex == 4,
                                            onTap: () => _onPressed(4),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/images/switch_user.svg',
                                                  color: Colors.white,
                                                  height: 35,
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  'Playlist',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(width: gGridToRight),

                              // === RIGHT COLUMN BUTTONS ===
                              Column(
                                children: [
                                  // Settings
                                  SizedBox(
                                    width: rightW,
                                    height: rightH,
                                    child: NetflixButton(
                                      isOutline: true,
                                      isFocused: _focusedIndex == 5,
                                      onTap: () => _onPressed(5),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.settings,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Settings',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: gRightVert),
                                  // Reload
                                  SizedBox(
                                    width: rightW,
                                    height: rightH,
                                    child: NetflixButton(
                                      isOutline: true,
                                      isFocused: _focusedIndex == 6,
                                      onTap: () => _onPressed(6),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.refresh,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Reload',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: gRightVert),
                                  // Quit
                                  SizedBox(
                                    width: rightW,
                                    height: rightH,
                                    child: NetflixButton(
                                      isOutline: true,
                                      isFocused: _focusedIndex == 7,
                                      onTap: () => _onPressed(7),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.exit_to_app,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Quit',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKeyPress(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          _moveFocus(-1, isVertical: true);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowDown:
          _moveFocus(1, isVertical: true);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
          _moveFocus(-1, isVertical: false);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          _moveFocus(1, isVertical: false);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.select:
          _onPressed(_focusedIndex);
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _moveFocus(int direction, {required bool isVertical}) {
    setState(() {
      if (isVertical) {
        // Vertical navigation within 2x2 grid
        if (_focusedIndex >= 1 && _focusedIndex <= 4) {
          if (_focusedIndex <= 2 && direction > 0) {
            _focusedIndex += 2; // Top row to bottom row
          } else if (_focusedIndex >= 3 && direction < 0) {
            _focusedIndex -= 2; // Bottom row to top row
          }
        }
        // Vertical navigation within right column
        else if (_focusedIndex >= 5 && _focusedIndex <= 7) {
          final newIndex = _focusedIndex + direction;
          if (newIndex >= 5 && newIndex <= 7) {
            _focusedIndex = newIndex;
          }
        }
      } else {
        // Horizontal navigation between columns
        if (_focusedIndex == 0 && direction > 0) {
          _focusedIndex = 1; // Live TV to Movies
        } else if (_focusedIndex >= 1 && _focusedIndex <= 4) {
          if (direction > 0) {
            _focusedIndex = 5; // Grid to Settings
          } else if (direction < 0) {
            _focusedIndex = 0; // Grid to Live TV
          }
        } else if (_focusedIndex >= 5 && _focusedIndex <= 7 && direction < 0) {
          _focusedIndex = 1; // Right column to Movies
        }
        // Horizontal navigation within 2x2 grid
        else if (_focusedIndex >= 1 && _focusedIndex <= 4) {
          if ((_focusedIndex == 1 || _focusedIndex == 3) && direction > 0) {
            _focusedIndex += 1; // Left to right within row
          } else if ((_focusedIndex == 2 || _focusedIndex == 4) && direction < 0) {
            _focusedIndex -= 1; // Right to left within row
          }
        }
      }
    });
  }

  void _onPressed(int index) async {
    switch (index) {
      case 0: // Live TV
        if (await _checkPlaylistAndShowError()) {
          _navigateToLiveTV();
        }
        break;
      case 1: // Movies
        if (await _checkPlaylistAndShowError()) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MoviesScreen()),
          );
        }
        break;
      case 2: // Series
        if (await _checkPlaylistAndShowError()) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SeriesScreen()),
          );
        }
        break;
      case 3: // Account
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AccountScreen()),
        );
        break;
      case 4: // Playlist
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlaylistScreen()),
        );
        break;
      case 5: // Settings
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        break;
      case 6: // Reload
        _reloadPlaylist();
        break;
      case 7: // Quit
        _showQuitDialog();
        break;
    }
  }

  Future<void> _navigateToLiveTV() async {
    final playlistUrl = await _resolveSavedPlaylistUrl();
    if (playlistUrl != null) {
      try {
        final channels = await M3UParser.fetchAndParseM3U(playlistUrl);
        if (channels.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChannelsScreen(
                channels: channels,
                title: 'Live TV',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No channels found in playlist')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading playlist: $e')),
        );
      }
    } else {
      _showInlineError("Please add a playlist first");
      return;
    }
  }

  Future<void> _switchPlaylist() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InputScreen()),
    );
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _reloadPlaylist() async {
    final playlistUrl = await _resolveSavedPlaylistUrl();
    if (playlistUrl != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reloading playlist...')),
      );
      
      try {
        final channels = await M3UParser.fetchAndParseM3U(playlistUrl);
        if (channels.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChannelsScreen(
                channels: channels,
                title: 'Live TV',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No channels found in playlist')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reloading playlist: $e')),
        );
      }
    } else {
      _showInlineError("No playlist to reload");
    }
  }

  void _showQuitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Quit App'),
          content: const Text('Are you sure you want to quit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
              child: const Text('Quit'),
            ),
          ],
        );
      },
    );
  }
}