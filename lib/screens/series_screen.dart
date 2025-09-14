import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/channel.dart';
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
  String _selectedCategory = '';
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _gridScrollController = ScrollController();
  late AnimationController _focusAnimationController;
  late Animation<double> _focusAnimation;
  
  // State caching for Series
  static String? _cachedSelectedCategory;
  static double _cachedCategoryScrollPosition = 0.0;
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
    
    // Auto-load Series category or restore cached state
    if (_cachedSelectedCategory != null && _seriesCategories.contains(_cachedSelectedCategory)) {
      _selectedCategory = _cachedSelectedCategory!;
    } else {
      // Auto-load first series category
      if (_seriesCategories.isNotEmpty) {
        _selectedCategory = _seriesCategories.first;
      }
    }
    
    // Restore scroll positions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_categoryScrollController.hasClients) {
        _categoryScrollController.jumpTo(_cachedCategoryScrollPosition);
      }
      if (_gridScrollController.hasClients) {
        _gridScrollController.jumpTo(_cachedGridScrollPosition);
      }
    });
    
    _focusAnimationController.forward();
  }

  List<Channel> get _filteredChannels {
    if (_searchQuery.isEmpty) {
      return widget.channels.where((channel) => 
        channel.group.toLowerCase().contains('series') || 
        channel.group.toLowerCase().contains('tv show') ||
        channel.group.toLowerCase().contains('drama') ||
        channel.group.toLowerCase().contains('show')
      ).toList();
    }
    return widget.channels.where((channel) =>
      (channel.group.toLowerCase().contains('series') || 
       channel.group.toLowerCase().contains('tv show') ||
       channel.group.toLowerCase().contains('drama') ||
       channel.group.toLowerCase().contains('show')) &&
      (channel.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
       channel.group.toLowerCase().contains(_searchQuery.toLowerCase()))
    ).toList();
  }

  List<String> get _seriesCategories {
    final categories = <String>{};
    for (final channel in _filteredChannels) {
      categories.add(channel.group);
    }
    return categories.toList()..sort();
  }

  List<Channel> get _currentCategorySeries {
    if (_selectedCategory.isEmpty) return _filteredChannels;
    return _filteredChannels.where((channel) => channel.group == _selectedCategory).toList();
  }

  void _playChannel(Channel channel) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          PlayerScreen(channel: channel),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _cachedSelectedCategory = category;
    });
  }

  void _showPlaylistUpdateSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Playlist updated – loading channels...'),
        backgroundColor: const Color(0xFFE50914),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

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
          horizontal: screenWidth * 0.03, // 3% horizontal padding
          vertical: 16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Navigation Tabs - evenly spaced
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
            
            // Search Bar - responsive width
            Flexible(
              flex: 1,
              child: Container(
                height: 40,
                constraints: BoxConstraints(
                  maxWidth: screenWidth * 0.25, // Max 25% of screen width
                  minWidth: 200, // Minimum width for usability
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
            width: (title.length * 8.0) + 24, // Account for icon width
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
        // Cache current state before navigating
        _cacheCurrentState();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 'Live TV':
        // Cache current state before navigating
        _cacheCurrentState();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChannelsScreen(channels: widget.channels, title: 'Live TV'),
          ),
        );
        break;
      case 'Movies':
        // Cache current state before navigating
        _cacheCurrentState();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MoviesScreen(channels: widget.channels, title: 'Movies'),
          ),
        );
        break;
      case 'Series':
        // Already on Series screen, just update state
        setState(() {
          _selectedTab = title;
        });
        break;
    }
  }

  void _cacheCurrentState() {
    _cachedSelectedCategory = _selectedCategory;
    if (_categoryScrollController.hasClients) {
      _cachedCategoryScrollPosition = _categoryScrollController.offset;
    }
    if (_gridScrollController.hasClients) {
      _cachedGridScrollPosition = _gridScrollController.offset;
    }
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Category Row
        _buildCategoryRow(),
        
        // Main Grid Content
        Expanded(
          child: _buildSeriesGrid(),
        ),
      ],
    );
  }

  Widget _buildCategoryRow() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: _seriesCategories.isEmpty
          ? const Center(
              child: Text(
                'No series categories available',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : Scrollbar(
              controller: _categoryScrollController,
              thumbVisibility: false,
              child: ListView.builder(
                controller: _categoryScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _seriesCategories.length,
                itemBuilder: (context, index) {
                  final category = _seriesCategories[index];
                  final isSelected = _selectedCategory == category;
                  
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectCategory(category),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? const Color(0xFFE50914)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected 
                                  ? const Color(0xFFE50914)
                                  : Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildSeriesGrid() {
    if (_currentCategorySeries.isEmpty) {
      return Center(
        child: Text(
          'No content available in this category',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
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
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid calculation
            int crossAxisCount;
            if (constraints.maxWidth > 1200) {
              crossAxisCount = 4; // TV/Large screens
            } else if (constraints.maxWidth > 800) {
              crossAxisCount = 3; // Tablet
            } else {
              crossAxisCount = 2; // Small devices
            }

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2 / 3, // Poster aspect ratio
              crossAxisSpacing: 16,
              mainAxisSpacing: 20,
              children: _currentCategorySeries.map((series) => _buildSeriesCard(series)).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSeriesCard(Channel series) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _playChannel(series),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Series Poster
              Expanded(
                flex: 4,
                child: Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: series.logo.isNotEmpty
                        ? Image.network(
                            series.logo,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultSeriesPoster();
                            },
                          )
                        : _buildDefaultSeriesPoster(),
                  ),
                ),
              ),
              
              // Series Title
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        series.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultSeriesPoster() {
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

  @override
  void dispose() {
    // Cache current state before disposing
    _cacheCurrentState();
    _searchController.dispose();
    _categoryScrollController.dispose();
    _gridScrollController.dispose();
    _focusAnimationController.dispose();
    super.dispose();
  }
}