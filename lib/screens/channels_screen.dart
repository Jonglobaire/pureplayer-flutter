import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/channel.dart';
import 'player_screen.dart';
import 'home_screen.dart';
import '../screens/movies_screen.dart';
import '../screens/series_screen.dart';

class ChannelsScreen extends StatefulWidget {
  final List<Channel> channels;
  final String title;

  const ChannelsScreen({
    super.key,
    required this.channels,
    required this.title,
  });

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> with TickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'Live TV';
  String _selectedGroup = '';
  Channel? _selectedChannel;
  final ScrollController _groupScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();
  late AnimationController _focusAnimationController;
  late Animation<double> _focusAnimation;
  
  // State caching
  static String? _cachedSelectedGroup;
  static Channel? _cachedSelectedChannel;
  static double _cachedGroupScrollPosition = 0.0;
  static double _cachedChannelScrollPosition = 0.0;

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
    
    // Restore cached state or initialize with first group and channel
    if (_cachedSelectedGroup != null && _groupedChannels.containsKey(_cachedSelectedGroup)) {
      _selectedGroup = _cachedSelectedGroup!;
      if (_cachedSelectedChannel != null) {
        final groupChannels = _groupedChannels[_selectedGroup]!;
        if (groupChannels.contains(_cachedSelectedChannel)) {
          _selectedChannel = _cachedSelectedChannel;
        } else if (groupChannels.isNotEmpty) {
          _selectedChannel = groupChannels.first;
        }
      }
    } else if (_groupedChannels.isNotEmpty) {
      _selectedGroup = _groupedChannels.keys.first;
      final groupChannels = _groupedChannels[_selectedGroup]!;
      if (groupChannels.isNotEmpty) {
        _selectedChannel = groupChannels.first;
      }
    }
    
    // Restore scroll positions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_groupScrollController.hasClients) {
        _groupScrollController.jumpTo(_cachedGroupScrollPosition);
      }
      if (_channelScrollController.hasClients) {
        _channelScrollController.jumpTo(_cachedChannelScrollPosition);
      }
    });
    
    _focusAnimationController.forward();
  }

  List<Channel> get _filteredChannels {
    if (_searchQuery.isEmpty) {
      return widget.channels;
    }
    return widget.channels.where((channel) =>
      channel.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      channel.group.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  Map<String, List<Channel>> get _groupedChannels {
    final grouped = <String, List<Channel>>{};
    for (final channel in _filteredChannels) {
      grouped.putIfAbsent(channel.group, () => []).add(channel);
    }
    return grouped;
  }

  List<Channel> get _currentGroupChannels {
    return _groupedChannels[_selectedGroup] ?? [];
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

  void _selectGroup(String group) {
    setState(() {
      _selectedGroup = group;
      _cachedSelectedGroup = group;
      final groupChannels = _groupedChannels[group]!;
      if (groupChannels.isNotEmpty) {
        _selectedChannel = groupChannels.first;
        _cachedSelectedChannel = _selectedChannel;
      }
    });
  }

  void _selectChannel(Channel channel) {
    setState(() {
      _selectedChannel = channel;
      _cachedSelectedChannel = channel;
    });
    // Auto-play preview when channel is selected
    _previewChannel(channel);
  }

  void _previewChannel(Channel channel) {
    // This would trigger auto-play in the preview panel
    // For now, we'll just update the selected channel
    // In a full implementation, this would start streaming the preview
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
    final isCompact = screenSize.width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: isCompact ? _buildCompactLayout() : _buildFullLayout(),
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
            Expanded(
              flex: 6,
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
            Expanded(
              flex: 3,
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
                    hintText: 'Search channels...',
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
        // Cache current state before navigating
        _cacheCurrentState();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SeriesScreen(channels: widget.channels, title: 'Series'),
          ),
        );
        break;
      case 'Live TV':
        // Already on Live TV screen, just update state
        setState(() {
          _selectedTab = title;
        });
        break;
    }
  }

  void _cacheCurrentState() {
    _cachedSelectedGroup = _selectedGroup;
    _cachedSelectedChannel = _selectedChannel;
    if (_groupScrollController.hasClients) {
      _cachedGroupScrollPosition = _groupScrollController.offset;
    }
    if (_channelScrollController.hasClients) {
      _cachedChannelScrollPosition = _channelScrollController.offset;
    }
  }

  Widget _buildFullLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Row(
      children: [
        // Left Panel - Groups
        SizedBox(
          width: screenWidth * 0.28, // 28% of screen width
          child: _buildGroupPanel(),
        ),
        
        Container(width: 1, color: Colors.white.withOpacity(0.1)),
        
        // Middle Panel - Channels
        SizedBox(
          width: screenWidth * 0.32, // 32% of screen width
          child: _buildChannelPanel(),
        ),
        
        Container(width: 1, color: Colors.white.withOpacity(0.1)),
        
        // Right Panel - Preview & EPG
        Expanded(
          child: _buildPreviewPanel(),
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return _buildChannelPanel(); // Simplified for compact screens
  }

  Widget _buildGroupPanel() {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.02, // 2% padding
              vertical: 20,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline, color: Color(0xFFE50914), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Add Group',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Groups List
          Expanded(
            child: Scrollbar(
              thumbVisibility: false,
              controller: _groupScrollController,
              child: ListView.builder(
              controller: _groupScrollController,
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.015, // 1.5% padding
                  vertical: 8,
                ),
              itemCount: _groupedChannels.length,
              itemBuilder: (context, index) {
                final groupName = _groupedChannels.keys.elementAt(index);
                final channelCount = _groupedChannels[groupName]!.length;
                final isSelected = _selectedGroup == groupName;
                
                return AnimatedBuilder(
                  animation: _focusAnimation,
                  builder: (context, child) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _selectGroup(groupName),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                horizontal: MediaQuery.of(context).size.width * 0.02,
                                vertical: 12,
                              ),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? const Color(0xFFE50914).withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected 
                                    ? const Color(0xFFE50914)
                                    : Colors.transparent,
                                width: 1,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: const Color(0xFFE50914).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ] : null,
                            ),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    groupName,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.left,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? const Color(0xFFE50914)
                                        : Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$channelCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
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
                );
              },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelPanel() {
    return Container(
      color: const Color(0xFF121212),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _selectedGroup.isNotEmpty ? _selectedGroup : 'All Channels',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Channels List
          Expanded(
            child: _currentGroupChannels.isEmpty
                ? _buildEmptyChannelState()
                : Scrollbar(
                    thumbVisibility: false,
                    controller: _channelScrollController,
                    child: ListView.builder(
                      controller: _channelScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _currentGroupChannels.length,
                      itemBuilder: (context, index) {
                      final channel = _currentGroupChannels[index];
                      final isSelected = _selectedChannel == channel;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _selectChannel(channel);
                            },
                            onHover: (isHovering) {
                              if (isHovering) {
                                _selectChannel(channel);
                              }
                            },
                            onDoubleTap: () => _playChannel(channel),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected 
                                      ? const Color(0xFFE50914)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: const Color(0xFFE50914).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ] : null,
                              ),
                              child: Row(
                                children: [
                                  // Channel Number
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE50914).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Color(0xFFE50914),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Channel Logo
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: channel.logo.isNotEmpty
                                        ? Image.network(
                                            channel.logo,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return _buildDefaultChannelIcon();
                                            },
                                          )
                                        : _buildDefaultChannelIcon(),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Channel Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          channel.name,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Live • ${channel.group}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Play Button
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE50914),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 20,
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
      ),
    );
  }

  Widget _buildPreviewPanel() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // Preview Player
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: _selectedChannel != null
                  ? _buildChannelPreview(_selectedChannel!)
                  : _buildNoChannelSelected(),
            ),
          ),
          
          // EPG Section
          Expanded(
            flex: 2,
            child: _buildEPGSection(),
          ),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildActionButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelPreview(Channel channel) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.8),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (channel.logo.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      channel.logo,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.tv, color: Colors.white, size: 80);
                      },
                    ),
                  )
                else
                  const Icon(Icons.tv, color: Colors.white, size: 80),
                const SizedBox(height: 16),
                Text(
                  channel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Preview Mode',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Play Overlay
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _playChannel(channel),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withOpacity(0.3),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Color(0xFFE50914),
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoChannelSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.tv_off,
            color: Colors.white.withOpacity(0.5),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Select a channel to preview',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEPGSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedChannel?.name ?? 'Select a channel',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: _selectedChannel != null
                ? _buildEPGList()
                : Center(
                    child: Text(
                      'Select a channel to view program guide',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEPGList() {
    // Mock EPG data - in real app, this would come from EPG service
    final programs = [
      {'time': '20:00', 'title': 'Evening News', 'current': true},
      {'time': '21:00', 'title': 'Prime Time Movie', 'current': false},
      {'time': '23:00', 'title': 'Late Night Show', 'current': false},
      {'time': '00:30', 'title': 'Documentary', 'current': false},
    ];

    return ListView.builder(
      itemCount: programs.length,
      itemBuilder: (context, index) {
        final program = programs[index];
        final isCurrent = program['current'] as bool;
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrent 
                ? const Color(0xFFE50914).withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrent 
                  ? const Color(0xFFE50914)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Text(
                program['time'] as String,
                style: TextStyle(
                  color: isCurrent ? const Color(0xFFE50914) : Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  program['title'] as String,
                  style: TextStyle(
                    color: isCurrent ? Colors.white : Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Catch Up',
            Icons.history,
            _selectedChannel?.catchupUrl != null,
            () {
              // Handle catch up
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'Favorites',
            Icons.favorite_border,
            true,
            () {
              // Handle add to favorites
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'Search',
            Icons.search,
            true,
            () {
              // Handle search
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: enabled 
                ? Colors.white.withOpacity(0.1)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled 
                  ? Colors.white.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: enabled ? Colors.white : Colors.white.withOpacity(0.5),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultChannelIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.tv, color: Colors.white, size: 24),
    );
  }

  Widget _buildEmptyChannelState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.tv_off,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No channels in this group',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              if (_groupedChannels.isNotEmpty) {
                _selectGroup(_groupedChannels.keys.first);
              }
            },
            child: const Text(
              'Select another group',
              style: TextStyle(color: Color(0xFFE50914)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Cache current state before disposing
    _cacheCurrentState();
    _searchController.dispose();
    _groupScrollController.dispose();
    _channelScrollController.dispose();
    _focusAnimationController.dispose();
    super.dispose();
  }
}