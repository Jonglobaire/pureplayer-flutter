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
  bool _useSoftwareDecoding = false;

  @override
  void initState() {
    super.initState();
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
      });

      print('🎬 Pure Player: Initializing player for channel: ${widget.channel.name}');
      print('🔗 Stream URL: ${widget.channel.url}');

      final headers = <String, String>{
        'User-Agent': 'PurePlayer/1.0',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      };

      // Add referer header if possible
      if (widget.channel.url.isNotEmpty) {
        final uri = Uri.tryParse(widget.channel.url);
        if (uri != null && uri.host.isNotEmpty) {
          headers['Referer'] = '${uri.scheme}://${uri.host}/';
        }
      }

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

      _betterPlayerController!.addEventsListener(_handlePlayerEvent);

      print('✅ Pure Player: Controller initialized successfully');
    } catch (e, stackTrace) {
      print('❌ Pure Player: Failed to initialize player: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to initialize player: ${e.toString()}';
        });
        _showErrorSnackBar('Failed to initialize player. Please try again.');
      }
    }
  }

  void _handlePlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;

    print('🎮 Player Event: ${event.betterPlayerEventType}');
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = false;
          });
        }
        break;
      case BetterPlayerEventType.exception:
        _handlePlaybackException();
        break;
      default:
        break;
    }
  }

  void _handlePlaybackException() {
    if (!mounted) return;

    if (!_useSoftwareDecoding) {
      _useSoftwareDecoding = true;
      _retryPlayback();
      return;
    }

    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = 'Stream unavailable. Please try another channel.';
    });

    _showErrorSnackBar('Stream unavailable. Please try another channel.');
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _retryPlayback,
        ),
      ),
    );
  }

  void _retryPlayback() {
    _disposeController();
    _initializePlayer();
  }

  void _disposeController() {
    _betterPlayerController?.removeEventsListener(_handlePlayerEvent);
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
              child: _buildPlayerWidget(),
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
      return const Center(child: Text("Stream error", style: TextStyle(color: Colors.red)));
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
    }
    return _betterPlayerController != null
        ? BetterPlayer(controller: _betterPlayerController!)
        : const Center(child: Text("Player not initialized", style: TextStyle(color: Colors.white)));
  }

  Widget _buildChannelInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.channel.name,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        if (widget.channel.group.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(widget.channel.group,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        if (_hasError && _errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _disposeController();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }
}
