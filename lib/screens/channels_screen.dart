import 'package:flutter/material.dart';
import '../models/channel.dart';
import 'player_screen.dart';

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

class _ChannelsScreenState extends State<ChannelsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_filteredChannels.length} channels',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search channels...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE50914)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
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
                  vertical: 16,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Channels List
          Expanded(
            child: _filteredChannels.isEmpty
                ? _buildEmptyState()
                : _buildChannelsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.tv_off,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty 
                ? 'No channels found for "$_searchQuery"'
                : 'No channels available',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              child: const Text(
                'Clear search',
                style: TextStyle(color: Color(0xFFE50914)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChannelsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _groupedChannels.length,
      itemBuilder: (context, groupIndex) {
        final groupName = _groupedChannels.keys.elementAt(groupIndex);
        final groupChannels = _groupedChannels[groupName]!;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                groupName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                '${groupChannels.length} channels',
                style: const TextStyle(color: Colors.grey),
              ),
              iconColor: const Color(0xFFE50914),
              collapsedIconColor: Colors.grey,
              children: groupChannels.map((channel) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: channel.logo.isNotEmpty
                          ? Image.network(
                              channel.logo,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[700],
                                  child: const Icon(Icons.tv, color: Colors.white),
                                );
                              },
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[700],
                              child: const Icon(Icons.tv, color: Colors.white),
                            ),
                    ),
                    title: Text(
                      channel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      channel.group,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: Container(
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
                    onTap: () => _playChannel(channel),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}