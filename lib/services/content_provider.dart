import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import 'm3u_parser.dart';

/// Content provider for managing movies and series data with caching
class ContentProvider extends ChangeNotifier {
  static final ContentProvider _instance = ContentProvider._internal();
  factory ContentProvider() => _instance;
  ContentProvider._internal();

  // Favorites functionality
  static const String _favoritesKey = 'favorite_items';
  List<String> _favorites = [];

  // Cache data
  List<Channel> _allChannels = [];
  List<Channel> _movies = [];
  List<Channel> _series = [];
  Map<String, List<Channel>> _movieGroups = {};
  Map<String, List<Channel>> _seriesGroups = {};
  
  // Loading states
  bool _isLoading = false;
  bool _isInitialized = false;
  
  // Watch progress tracking
  Map<String, double> _watchProgress = {}; // channelUrl -> progress (0.0-1.0)
  Map<String, DateTime> _lastWatched = {}; // channelUrl -> timestamp
  
  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  List<Channel> get allChannels => _allChannels;
  List<Channel> get movies => _movies;
  List<Channel> get series => _series;
  
  /// Load favorites from SharedPreferences
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favorites = prefs.getStringList(_favoritesKey) ?? [];
  }

  /// Check if item is favorite
  bool isFavorite(String url) {
    return _favorites.contains(url);
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String url) async {
    final prefs = await SharedPreferences.getInstance();

    if (_favorites.contains(url)) {
      _favorites.remove(url);
    } else {
      _favorites.add(url);
    }

    await prefs.setStringList(_favoritesKey, _favorites);
    notifyListeners();
  }

  /// Get list of favorite URLs
  List<String> getFavorites() => _favorites;

  /// Initialize content provider with M3U data
  Future<void> initialize(String playlistUrl) async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Load cached data first for instant UI
      await _loadCachedData();
      
      // Load favorites
      await _loadFavorites();
      
      // Fetch fresh data in background
      _fetchFreshData(playlistUrl);
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ ContentProvider: Error initializing: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load cached data from SharedPreferences
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load cached channels
      final cachedChannels = prefs.getString('cached_channels');
      if (cachedChannels != null) {
        final List<dynamic> channelsList = jsonDecode(cachedChannels);
        _allChannels = channelsList.map((json) => Channel.fromMap(Map<String, String>.from(json))).toList();
        _processChannels();
        debugPrint('✅ ContentProvider: Loaded ${_allChannels.length} cached channels');
      }
      
      // Load watch progress
      final progressData = prefs.getString('watch_progress');
      if (progressData != null) {
        final Map<String, dynamic> progressMap = jsonDecode(progressData);
        _watchProgress = progressMap.map((key, value) => MapEntry(key, (value as num).toDouble()));
      }
      
      // Load last watched timestamps
      final lastWatchedData = prefs.getString('last_watched');
      if (lastWatchedData != null) {
        final Map<String, dynamic> lastWatchedMap = jsonDecode(lastWatchedData);
        _lastWatched = lastWatchedMap.map((key, value) => MapEntry(key, DateTime.parse(value)));
      }
      
    } catch (e) {
      debugPrint('❌ ContentProvider: Error loading cached data: $e');
    }
  }
  
  /// Fetch fresh data in background
  Future<void> _fetchFreshData(String playlistUrl) async {
    try {
      final freshChannels = await M3UParser.fetchAndParseM3U(playlistUrl);
      
      if (freshChannels.isNotEmpty && !listEquals(freshChannels, _allChannels)) {
        _allChannels = freshChannels;
        _processChannels();
        
        // Cache fresh data
        await _cacheChannels();
        
        debugPrint('✅ ContentProvider: Updated with ${_allChannels.length} fresh channels');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ ContentProvider: Error fetching fresh data: $e');
    }
  }
  
  /// Process channels into movies and series
  void _processChannels() {
    _movies.clear();
    _series.clear();
    _movieGroups.clear();
    _seriesGroups.clear();
    
    for (final channel in _allChannels) {
      final groupLower = channel.group.toLowerCase();
      
      // Filter movies
      if (groupLower.contains('movie') || 
          groupLower.contains('film') || 
          groupLower.contains('cinema')) {
        _movies.add(channel);
        _movieGroups.putIfAbsent(channel.group, () => []).add(channel);
      }
      
      // Filter series
      if (groupLower.contains('series') || 
          groupLower.contains('tv show') || 
          groupLower.contains('drama') || 
          groupLower.contains('show')) {
        _series.add(channel);
        _seriesGroups.putIfAbsent(channel.group, () => []).add(channel);
      }
    }
    
    debugPrint('📊 ContentProvider: Processed ${_movies.length} movies, ${_series.length} series');
  }
  
  /// Cache channels to SharedPreferences
  Future<void> _cacheChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelsJson = _allChannels.map((channel) => {
        'name': channel.name,
        'url': channel.url,
        'group': channel.group,
        'logo': channel.logo,
        'catchup-source': channel.catchupUrl,
        ...channel.attributes,
      }).toList();
      
      await prefs.setString('cached_channels', jsonEncode(channelsJson));
    } catch (e) {
      debugPrint('❌ ContentProvider: Error caching channels: $e');
    }
  }
  
  /// Get movie groups
  List<String> getMovieGroups() {
    return _movieGroups.keys.toList()..sort();
  }
  
  /// Get movies by group
  List<Channel> getMoviesByGroup(String group) {
    return _movieGroups[group] ?? [];
  }
  
  /// Get series groups
  List<String> getSeriesGroups() {
    return _seriesGroups.keys.toList()..sort();
  }
  
  /// Get series by group
  List<Channel> getSeriesByGroup(String group) {
    return _seriesGroups[group] ?? [];
  }
  
  /// Get watch progress for a channel (0.0 - 1.0)
  double getWatchProgress(String channelUrl) {
    return _watchProgress[channelUrl] ?? 0.0;
  }
  
  /// Update watch progress for a channel
  Future<void> updateWatchProgress(String channelUrl, double progress) async {
    _watchProgress[channelUrl] = progress.clamp(0.0, 1.0);
    _lastWatched[channelUrl] = DateTime.now();
    
    // Save to SharedPreferences
    await _saveWatchProgress();
    notifyListeners();
  }
  
  /// Check if channel has been partially watched
  bool isPartiallyWatched(String channelUrl) {
    final progress = getWatchProgress(channelUrl);
    return progress > 0.0 && progress < 0.95; // Consider 95%+ as completed
  }
  
  /// Check if channel is completed
  bool isCompleted(String channelUrl) {
    return getWatchProgress(channelUrl) >= 0.95;
  }
  
  /// Get last watched timestamp
  DateTime? getLastWatched(String channelUrl) {
    return _lastWatched[channelUrl];
  }
  
  /// Save watch progress to SharedPreferences
  Future<void> _saveWatchProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save progress
      final progressJson = _watchProgress.map((key, value) => MapEntry(key, value));
      await prefs.setString('watch_progress', jsonEncode(progressJson));
      
      // Save timestamps
      final timestampJson = _lastWatched.map((key, value) => MapEntry(key, value.toIso8601String()));
      await prefs.setString('last_watched', jsonEncode(timestampJson));
      
    } catch (e) {
      debugPrint('❌ ContentProvider: Error saving watch progress: $e');
    }
  }
  
  /// Get recently watched content
  List<Channel> getRecentlyWatched({int limit = 10}) {
    final recentChannels = <Channel>[];
    
    // Sort by last watched timestamp
    final sortedEntries = _lastWatched.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (final entry in sortedEntries.take(limit)) {
      final channel = _allChannels.firstWhere(
        (ch) => ch.url == entry.key,
        orElse: () => Channel(name: '', url: '', group: '', logo: ''),
      );
      if (channel.name.isNotEmpty) {
        recentChannels.add(channel);
      }
    }
    
    return recentChannels;
  }
  
  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_channels');
      await prefs.remove('watch_progress');
      await prefs.remove('last_watched');
      
      _allChannels.clear();
      _movies.clear();
      _series.clear();
      _movieGroups.clear();
      _seriesGroups.clear();
      _watchProgress.clear();
      _lastWatched.clear();
      _isInitialized = false;
      
      notifyListeners();
      debugPrint('✅ ContentProvider: Cache cleared');
    } catch (e) {
      debugPrint('❌ ContentProvider: Error clearing cache: $e');
    }
  }
}