import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

class _SeriesScreenState extends State<SeriesScreen> with TickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'Series';
  String _selectedGroup = '';
  final ScrollController _groupScrollController = ScrollController();
  final ScrollController _gridScrollController = ScrollController();
  late AnimationController _focusAnimationController;
  late Animation<double> _focusAnimation;
  
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
      // Use first channel URL to get playlist URL (simplified)
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
    final groups = <String>{};
    for (final series in _filteredSeries) {
      groups.add(series.group);
    }
    return groups.toList()..sort();
  }

  List<Channel> get _currentGroupSeries {
    if (_selectedGroup.isEmpty) return _filteredSeries;
    return _filteredSeries.where((series) => series.group == _selectedGroup).toList();
  }

  void _selectGroup(String group) {
    setState(() {
      _selectedGroup = group;
      _cachedSelectedGroup = group;
    });
  }

  void _showSeriesModal(Channel series) {
    final episodes = _getSeriesEpisodes(series);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildSeriesModal(series, episodes),
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
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
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
                  child: SizedBox(
                    width: 120,
                    height: 180,
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
                                child: Row(
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
                                          
                                          const SizedBox(height: 4),
                                          
                                          // Progress bar
                                          if (progress > 0.0)
                                            LinearProgressIndicator(
                                              value: progress,
                                              backgroundColor: Colors.white.withOpacity(0.2),
                                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                                              minHeight: 2,
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

  @override
  Widget build(BuildContext context) {
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
              child: Container(
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
                    prefixIcon: Icon(
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
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 8,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
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
                      final seriesCount = _currentGroupSeries.length;
                      
                      return Container(
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
      return const Center(
        child: Text(
          'No content available in this category',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 16,
          ),
        ),
      );
    }

    return Scrollbar(
      controller: _gridScrollController,
      thumbVisibility: false,
      child: SingleChildScrollView(
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

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2 / 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 20,
              children: _currentGroupSeries.map((series) => _buildSeriesCard(series)).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSeriesCard(Channel series) {
    final progress = _contentProvider.getWatchProgress(series.url);
    final isPartiallyWatched = _contentProvider.isPartiallyWatched(series.url);
    
    return Material(
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
                        aspectRatio: 2 / 3,
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
                child: Text(
                  series.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
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
    _cacheCurrentState();
    _searchController.dispose();
    _groupScrollController.dispose();
    _gridScrollController.dispose();
    _focusAnimationController.dispose();
    super.dispose();
  }
}