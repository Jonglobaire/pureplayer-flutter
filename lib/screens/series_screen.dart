import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/channel.dart';
import '../services/content_provider.dart';
import 'player_screen.dart';
import 'home_screen.dart';
import '../screens/channels_screen.dart';
import '../screens/movies_screen.dart';

class SeriesScreen extends StatefulWidget {
  final List<Channel> channels;
  final String title;

  const SeriesScreen({
    super.key,
    required this.channels,
    required this.title,
  });

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> 
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'Series';
  String _selectedGroup = '';
  final ScrollController _groupScrollController = ScrollController();
  final ScrollController _gridScrollController = ScrollController();
  late AnimationController _focusAnimationController;
  late Animation<double> _focusAnimation;
  
  // Search functionality
  Timer? _debounceTimer;
  bool _isSearching = false;
  List<String> _searchHistory = [];
  bool _showSearchHistory = false;
  
  // Content provider
  final ContentProvider _contentProvider = ContentProvider();
  
  // State caching for Series
  static String? _cachedSelectedGroup;
  static double _cachedGroupScrollPosition = 0.0;
  static double _cachedGridScrollPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _focusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _focusAnimationController, curve: Curves.easeInOut),
    );
    
    _initializeContent();
    _focusAnimationController.forward();
  }

  Future<void> _initializeContent() async {
    // Initialize content provider if needed
    if (!_contentProvider.isInitialized && widget.channels.isNotEmpty) {
      await _contentProvider.initialize('');
    }
    
    // Auto-load Series category or restore cached state
    final seriesGroups = _contentProvider.getSeriesGroups();
    if (_cachedSelectedGroup != null && seriesGroups.contains(_cachedSelectedGroup)) {
      _selectedGroup = _cachedSelectedGroup!;
    } else if (seriesGroups.isNotEmpty) {
      _selectedGroup = seriesGroups.first;
    }
    
    // Restore scroll positions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_groupScrollController.hasClients) {
        _groupScrollController.jumpTo(_cachedGroupScrollPosition);
      }
      if (_gridScrollController.hasClients) {
        _gridScrollController.jumpTo(_cachedGridScrollPosition);
      }
    });
    
    setState(() {});
  }

  List<Channel> get _filteredSeries {
    final series = widget.channels.where((channel) => 
      channel.group.toLowerCase().contains('series') || 
      channel.group.toLowerCase().contains('tv show') ||
      channel.group.toLowerCase().contains('drama') ||
      channel.group.toLowerCase().contains('show')
    ).toList();
    
    if (_searchQuery.isEmpty) {
      return series;
    }
    return series.where((channel) =>
      channel.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      channel.group.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  List<String> get _seriesGroups {
    final groups = <String>['⭐ Favorites', '⏳ Last Watched'];
    final seriesGroups = <String>{};
    for (final series in _filteredSeries) {
      seriesGroups.add(series.group);
    }
    groups.addAll(seriesGroups.toList()..sort());
    return groups;
  }

  List<Channel> get _currentGroupSeries {
    if (_selectedGroup.isEmpty) return _filteredSeries;
    
    if (_selectedGroup == '⭐ Favorites') {
      return _filteredSeries.where((series) => _contentProvider.isFavorite(series.url)).toList();
    }
    
    if (_selectedGroup == '⏳ Last Watched') {
      return _contentProvider.getRecentlyWatched().where((series) => 
        series.group.toLowerCase().contains('series') || 
        series.group.toLowerCase().contains('tv show') ||
        series.group.toLowerCase().contains('drama') ||
        series.group.toLowerCase().contains('show')
      ).toList();
    }
    
    return _filteredSeries.where((series) => series.group == _selectedGroup).toList();
  }

  void _selectGroup(String group) {
    setState(() {
      _selectedGroup = group;
      _cachedSelectedGroup = group;
    });
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    setState(() {
      _isSearching = true;
      _showSearchHistory = value.isEmpty;
    });
    
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value;
        _isSearching = false;
        _showSearchHistory = false;
      });
      
      if (value.isNotEmpty && !_searchHistory.contains(value)) {
        _searchHistory.insert(0, value);
        if (_searchHistory.length > 5) {
          _searchHistory.removeLast();
        }
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
      _showSearchHistory = false;
    });
  }

  void _preloadImages() {
    for (int i = 0; i < _currentGroupSeries.length && i < 10; i++) {
      final series = _currentGroupSeries[i];
      if (series.logo.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(series.logo), context);
      }
    }
  }

  void _showSeriesModal(Channel series) {
    final episodes = _getSeriesEpisodes(series);
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Series Details',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: AnimatedScale(
              scale: animation.value,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: FadeTransition(
                opacity: animation,
                child: _buildSeriesModal(series, episodes),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Channel> _getSeriesEpisodes(Channel series) {
    // Get all episodes from the same series group
    return _currentGroupSeries.where((episode) => 
      episode.group == series.group &&
      episode.name.toLowerCase().contains(series.name.toLowerCase().split(' ').first)
    ).toList();
  }

  Widget _buildSeriesModal(Channel series, List<Channel> episodes) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ),
          
          // Series header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Series poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 2/3,
                    child: SizedBox(
                      width: 120,
                      child: series.logo.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: series.logo,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 300),
                              memCacheHeight: 600,
                              memCacheWidth: 400,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[800],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFE50914),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => _buildDefaultPoster(),
                            )
                          : _buildDefaultPoster(),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Series info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        series.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE50914),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          series.group,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Text(
                        '${episodes.length} Episodes',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        series.attributes['description'] ?? 'No description available.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Episodes list
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Episodes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: episodes.length,
                      itemBuilder: (context, index) {
                        final episode = episodes[index];
                        final progress = _contentProvider.getWatchProgress(episode.url);
                        final isPartiallyWatched = _contentProvider.isPartiallyWatched(episode.url);
                        final isCompleted = _contentProvider.isCompleted(episode.url);
                        
                        return Container(
                          key: ValueKey('episode_${episode.url}'),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                _playEpisode(episode);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        // Episode thumbnail
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: SizedBox(
                                            width: 80,
                                            height: 45,
                                            child: episode.logo.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: episode.logo,
                                                    fit: BoxFit.cover,
                                                    fadeInDuration: const Duration(milliseconds: 300),
                                                    memCacheHeight: 600,
                                                    memCacheWidth: 400,
                                                    placeholder: (context, url) => Container(
                                                      color: Colors.grey[800],
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons.tv,
                                                          color: Colors.white54,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ),
                                                    errorWidget: (context, url, error) => Container(
                                                      color: Colors.grey[800],
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons.tv,
                                                          color: Colors.white54,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Container(
                                                    color: Colors.grey[800],
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.tv,
                                                        color: Colors.white54,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        
                                        const SizedBox(width: 12),
                                        
                                        // Episode info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      episode.name,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  
                                                  // Continue/Completed indicator
                                                  if (isPartiallyWatched)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFE50914),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'Continue',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    )
                                                  else if (isCompleted)
                                                    const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green,
                                                      size: 16,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Play button
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE50914).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow,
                                            color: Color(0xFFE50914),
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Progress indicator under episode title
                                    if (progress > 0.0) ...[
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                                        minHeight: 2,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultPoster() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(
          Icons.tv,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }

  void _playEpisode(Channel episode) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          PlayerScreen(channel: episode),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, index),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: const TextStyle(
              color: Color(0xFFE50914),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: text.substring(index + query.length),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      height: 80,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.03,
          vertical: 16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Navigation Tabs
            Flexible(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTabButton('Home', Icons.home),
                  _buildTabButton('Live TV', Icons.live_tv),
                  _buildTabButton('Movies', Icons.movie),
                  _buildTabButton('Series', Icons.tv),
                ],
              ),
            ),
            
            const SizedBox(width: 24),
            
            // Search Bar
            Flexible(
              flex: 1,
              child: Stack(
                children: [
                  Container(
                    height: 40,
                    constraints: BoxConstraints(
                      maxWidth: screenWidth * 0.25,
                      minWidth: 200,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search series...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        prefixIcon: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFE50914),
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.search, 
                                color: Colors.white.withOpacity(0.6), 
                                size: 20,
                              ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear, 
                                  color: Colors.white.withOpacity(0.6), 
                                  size: 18,
                                ),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, 
                          vertical: 8,
                        ),
                      ),
                      onChanged: _onSearchChanged,
                      onTap: () {
                        setState(() {
                          _showSearchHistory = _searchController.text.isEmpty;
                        });
                      },
                    ),
                  ),
                  
                  // Search history dropdown
                  if (_showSearchHistory && _searchHistory.isNotEmpty)
                    Positioned(
                      top: 45,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: _searchHistory.map((query) => 
                            InkWell(
                              onTap: () {
                                _searchController.text = query;
                                _onSearchChanged(query);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.history, color: Colors.white54, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        query,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, IconData icon) {
    final isActive = _selectedTab == title;
    return InkWell(
      onTap: () {
        _navigateToTab(title);
      },
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : Colors.white.withOpacity(0.7),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: (title.length * 8.0) + 24,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFE50914) : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTab(String title) {
    switch (title) {
      case 'Home':
        _cacheCurrentState();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 'Live TV':
        _cacheCurrentState();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChannelsScreen(channels: widget.channels, title: 'Live TV'),
          ),
        );
        break;
      case 'Movies':
        _cacheCurrentState();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MoviesScreen(channels: widget.channels, title: 'Movies'),
          ),
        );
        break;
      case 'Series':
        setState(() {
          _selectedTab = title;
        });
        break;
    }
  }

  void _cacheCurrentState() {
    _cachedSelectedGroup = _selectedGroup;
    if (_groupScrollController.hasClients) {
      _cachedGroupScrollPosition = _groupScrollController.offset;
    }
    if (_gridScrollController.hasClients) {
      _cachedGridScrollPosition = _gridScrollController.offset;
    }
  }

  Widget _buildMainContent() {
    return Row(
      children: [
        // Left Column - Groups
        Container(
          width: MediaQuery.of(context).size.width * 0.25,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            border: Border(
              right: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: _buildGroupsList(),
        ),
        
        // Right Side - Series Grid
        Expanded(
          child: _buildSeriesGrid(),
        ),
      ],
    );
  }

  Widget _buildGroupsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: const Text(
            'Series Categories',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Groups List
        Expanded(
          child: _seriesGroups.isEmpty
              ? const Center(
                  child: Text(
                    'No series categories available',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : Scrollbar(
                  controller: _groupScrollController,
                  thumbVisibility: false,
                  child: ListView.builder(
                    controller: _groupScrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _seriesGroups.length,
                    itemBuilder: (context, index) {
                      final group = _seriesGroups[index];
                      final isSelected = _selectedGroup == group;
                      final seriesCount = _filteredSeries.where((s) => s.group == group).length;
                      
                      return Container(
                        key: ValueKey('group_$group'),
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectGroup(group),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? const Color(0xFFE50914).withOpacity(0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected 
                                      ? const Color(0xFFE50914)
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      group,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? const Color(0xFFE50914)
                                          : Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$seriesCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
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
                ),
        ),
      ],
    );
  }

  Widget _buildSeriesGrid() {
    if (_currentGroupSeries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No results found for "$_searchQuery"'
                  : 'No content available in this category',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Preload images for smooth scrolling
    WidgetsBinding.instance.addPostFrameCallback((_) => _preloadImages());

    return PageStorage(
      bucket: PageStorageBucket(),
      child: Scrollbar(
        controller: _gridScrollController,
        thumbVisibility: false,
        child: SingleChildScrollView(
          key: const PageStorageKey('series_grid'),
          controller: _gridScrollController,
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive grid calculation
              int crossAxisCount;
              if (constraints.maxWidth > 1200) {
                crossAxisCount = 4;
              } else if (constraints.maxWidth > 800) {
                crossAxisCount = 3;
              } else {
                crossAxisCount = 2;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 16 / 9,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 20,
                ),
                itemCount: _currentGroupSeries.length,
                itemBuilder: (context, index) {
                  final series = _currentGroupSeries[index];
                  return _buildSeriesCard(series, index);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSeriesCard(Channel series, int index) {
    final progress = _contentProvider.getWatchProgress(series.url);
    final isPartiallyWatched = _contentProvider.isPartiallyWatched(series.url);
    
    return Material(
      key: ValueKey('series_${series.url}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showSeriesModal(series),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Series Poster
              Expanded(
                flex: 4,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: series.logo.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: series.logo,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFE50914),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => _buildDefaultPoster(),
                              )
                            : _buildDefaultPoster(),
                      ),
                    ),
                    
                    // Progress indicator
                    if (isPartiallyWatched)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Series Title
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: _buildHighlightedText(series.name, _searchQuery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cacheCurrentState();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _groupScrollController.dispose();
    _gridScrollController.dispose();
    _focusAnimationController.dispose();
    super.dispose();
  }
}