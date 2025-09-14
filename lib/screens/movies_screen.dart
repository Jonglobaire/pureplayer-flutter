import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/channel.dart';
import '../services/content_provider.dart';
import 'player_screen.dart';
import 'home_screen.dart';
import '../screens/channels_screen.dart';
import '../screens/series_screen.dart';

class MoviesScreen extends StatefulWidget {
  final List<Channel> channels;
  final String title;

  const MoviesScreen({
    super.key,
    required this.channels,
    required this.title,
  });

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> 
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'Movies';
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
  
  // State caching for Movies
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
    
    // Auto-load Movies category or restore cached state
    final movieGroups = _contentProvider.getMovieGroups();
    if (_cachedSelectedGroup != null && movieGroups.contains(_cachedSelectedGroup)) {
      _selectedGroup = _cachedSelectedGroup!;
    } else if (movieGroups.isNotEmpty) {
      _selectedGroup = movieGroups.first;
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

  List<Channel> get _filteredMovies {
    final movies = widget.channels.where((channel) => 
      channel.group.toLowerCase().contains('movie') || 
      channel.group.toLowerCase().contains('film') ||
      channel.group.toLowerCase().contains('cinema')
    ).toList();
    
    if (_searchQuery.isEmpty) {
      return movies;
    }
    return movies.where((channel) =>
      channel.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      channel.group.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  List<String> get _movieGroups {
    final groups = <String>{};
    for (final movie in _filteredMovies) {
      groups.add(movie.group);
    }
    return groups.toList()..sort();
  }

  List<Channel> get _currentGroupMovies {
    if (_selectedGroup.isEmpty) return _filteredMovies;
    return _filteredMovies.where((movie) => movie.group == _selectedGroup).toList();
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
    for (int i = 0; i < _currentGroupMovies.length && i < 10; i++) {
      final movie = _currentGroupMovies[i];
      if (movie.logo.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(movie.logo), context);
      }
    }
  }

  void _showMovieModal(Channel movie) {
    final progress = _contentProvider.getWatchProgress(movie.url);
    final isPartiallyWatched = _contentProvider.isPartiallyWatched(movie.url);
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Movie Details',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: AnimatedScale(
              scale: animation.value,
              child: FadeTransition(
                opacity: animation,
                child: _buildMovieModal(movie, progress, isPartiallyWatched),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovieModal(Channel movie, double progress, bool isPartiallyWatched) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      height: MediaQuery.of(context).size.height * 0.7,
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
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Movie poster
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 200,
                      height: 300,
                      child: movie.logo.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: movie.logo,
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
                  
                  const SizedBox(width: 20),
                  
                  // Movie details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
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
                            movie.group,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Progress bar if partially watched
                        if (isPartiallyWatched) ...[
                          Text(
                            'Progress: ${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Synopsis
                        const Text(
                          'Synopsis',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            movie.attributes['description'] ?? 'No description available.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _playMovie(movie, fromStart: true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE50914),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Play from Start'),
                              ),
                            ),
                            
                            if (isPartiallyWatched) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _playMovie(movie, fromStart: false);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.play_circle_outline),
                                  label: const Text('Continue Watching'),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.withOpacity(0.3),
                                    foregroundColor: Colors.grey,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.play_circle_outline),
                                  label: const Text('Continue Watching'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
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
          Icons.movie,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }

  void _playMovie(Channel movie, {required bool fromStart}) {
    if (fromStart) {
      _contentProvider.updateWatchProgress(movie.url, 0.0);
    }
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          PlayerScreen(channel: movie),
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
                        hintText: 'Search movies...',
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
      case 'Series':
        _cacheCurrentState();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SeriesScreen(channels: widget.channels, title: 'Series'),
          ),
        );
        break;
      case 'Movies':
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
        
        // Right Side - Movie Grid
        Expanded(
          child: _buildMovieGrid(),
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
            'Movie Categories',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Groups List
        Expanded(
          child: _movieGroups.isEmpty
              ? const Center(
                  child: Text(
                    'No movie categories available',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : Scrollbar(
                  controller: _groupScrollController,
                  thumbVisibility: false,
                  child: ListView.builder(
                    controller: _groupScrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _movieGroups.length,
                    itemBuilder: (context, index) {
                      final group = _movieGroups[index];
                      final isSelected = _selectedGroup == group;
                      final movieCount = _filteredMovies.where((m) => m.group == group).length;
                      
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
                                      '$movieCount',
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

  Widget _buildMovieGrid() {
    if (_currentGroupMovies.isEmpty) {
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
          key: const PageStorageKey('movies_grid'),
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
                itemCount: _currentGroupMovies.length,
                itemBuilder: (context, index) {
                  final movie = _currentGroupMovies[index];
                  return _buildMovieCard(movie, index);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMovieCard(Channel movie, int index) {
    final progress = _contentProvider.getWatchProgress(movie.url);
    final isPartiallyWatched = _contentProvider.isPartiallyWatched(movie.url);
    
    return Material(
      key: ValueKey('movie_${movie.url}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMovieModal(movie),
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
              // Movie Poster
              Expanded(
                flex: 4,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: movie.logo.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: movie.logo,
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
              
              // Movie Title
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: _buildHighlightedText(movie.name, _searchQuery),
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