import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player/better_player.dart';
import '../models/channel.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  BetterPlayerController? _betterPlayerController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isBuffering = false;
  String? _lastErrorCode;
  String? _failingUrl;

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 Pure Player: Starting PlayerScreen for ${widget.channel.name}');
    _initializePlayer();

    // Lock orientations while player is open
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _initializePlayer() {
    try {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
        _isBuffering = false;
        _lastErrorCode = null;
        _failingUrl = null;
      });

      debugPrint('🎬 Pure Player: Initializing player for channel: ${widget.channel.name}');
      debugPrint('🔗 Stream URL: ${widget.channel.url}');

      // Use VLC User-Agent as many servers require this
      final headers = <String, String>{
        'User-Agent': 'VLC/3.0.0 LibVLC/3.0.0',
      };
      debugPrint('📡 Headers: $headers');

      final betterPlayerDataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.channel.url,
        liveStream: true,
        headers: headers,
        videoFormat: BetterPlayerVideoFormat.other,
        bufferingConfiguration: const BetterPlayerBufferingConfiguration(
          minBufferMs: 2000,
          maxBufferMs: 10000,
          bufferForPlaybackMs: 1000,
          bufferForPlaybackAfterRebufferMs: 2000,
        ),
      );

      final betterPlayerConfiguration = BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        autoPlay: true,
        looping: false,
        fullScreenByDefault: false,
        allowedScreenSleep: false,
        handleLifecycle: true,
        autoDetectFullscreenDeviceOrientation: true,
        deviceOrientationsOnFullScreen: const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: const [
          DeviceOrientation.portraitUp,
        ],
        eventListener: _handlePlayerEvent,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          enableFullscreen: true,
          enablePip: true,
          enablePlayPause: true,
          enableMute: true,
          enableProgressBar: true,
          enableProgressText: true,
          enableRetry: true,
          showControlsOnInitialize: true,
          controlBarColor: Colors.black54,
          progressBarPlayedColor: Color(0xFFE50914),
          progressBarHandleColor: Color(0xFFE50914),
          loadingColor: Color(0xFFE50914),
          enableSubtitles: true,
          enableAudioTracks: true,
          showControls: true,
          enableQualities: true,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFE50914)),
          ),
        ),
        showPlaceholderUntilPlay: true,
        placeholderOnTop: false,
      );

      _betterPlayerController = BetterPlayerController(
        betterPlayerConfiguration,
        betterPlayerDataSource: betterPlayerDataSource,
      );


      debugPrint('✅ Pure Player: Controller initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Pure Player: Failed to initialize player: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to initialize player: ${e.toString()}';
        });
        _showErrorDialog('Initialization Error', 'Failed to initialize player: ${e.toString()}');
      }
    }
  }

  void _handlePlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;

    debugPrint('🎥 Player Event: ${event.betterPlayerEventType}');
    if (event.parameters != null) {
      debugPrint('📡 Params: ${event.parameters}');
    }

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = false;
            _isBuffering = false;
          });
        }
        break;
      case BetterPlayerEventType.bufferingStart:
        if (mounted) {
          setState(() {
            _isBuffering = true;
          });
        }
        break;
      case BetterPlayerEventType.bufferingEnd:
        if (mounted) {
          setState(() {
            _isBuffering = false;
          });
        }
        break;
      case BetterPlayerEventType.exception:
        _handlePlaybackException(event);
        break;
      default:
        break;
    }
  }

  void _handlePlaybackException(BetterPlayerEvent event) {
    if (!mounted) return;

    debugPrint('❌ Playback Exception: ${event.parameters}');
    
    // Extract error details from parameters
    String errorCode = 'Unknown';
    String errorMessage = 'Playback failed';
    
    if (event.parameters != null) {
      final params = event.parameters as Map<String, dynamic>?;
      if (params != null) {
        errorCode = params['code']?.toString() ?? 'Unknown';
        errorMessage = params['message']?.toString() ?? 'Playback failed';
      }
    }

    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = errorMessage;
      _lastErrorCode = errorCode;
      _failingUrl = widget.channel.url;
      _isBuffering = false;
    });

    final displayUrl = widget.channel.url.length > 50 
        ? '${widget.channel.url.substring(0, 50)}...' 
        : widget.channel.url;
    
    _showErrorDialog(
      'Playback Failed',
      'Code: $errorCode\nURL: $displayUrl\n\n$errorMessage'
    );
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _retryPlayback();
              },
              child: const Text(
                'Retry',
                style: TextStyle(color: Color(0xFFE50914)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to channel list
              },
              child: const Text(
                'Back',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBufferingSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Buffering...'),
        backgroundColor: Color(0xFFE50914),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _retryPlayback() {
    debugPrint('🔄 Retrying playback...');
    _disposeController();
    _initializePlayer();
  }

  void _disposeController() {
    _betterPlayerController?.dispose();
    _betterPlayerController = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.channel.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                children: [
                  _buildPlayerWidget(),
                  if (_isBuffering)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE50914),
                        strokeWidth: 3,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: Colors.grey[900],
              padding: const EdgeInsets.all(20),
              child: _buildChannelInfo(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerWidget() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage.isNotEmpty ? _errorMessage : 'Stream error',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (_lastErrorCode != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error Code: $_lastErrorCode',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retryPlayback,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFE50914)),
            SizedBox(height: 16),
            Text(
              'Loading stream...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    return _betterPlayerController != null
        ? BetterPlayer(controller: _betterPlayerController!)
        : const Center(
            child: Text(
              "Player not initialized",
              style: TextStyle(color: Colors.white),
            ),
          );
  }

  Widget _buildChannelInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.channel.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (widget.channel.group.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.channel.group,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        if (_hasError && _errorMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Error Details:',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
                if (_lastErrorCode != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Code: $_lastErrorCode',
                    style: const TextStyle(color: Colors.red, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_isBuffering) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFE50914),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Buffering...',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    debugPrint('🗑️ PlayerScreen: Disposing...');
    _disposeController();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }
}
