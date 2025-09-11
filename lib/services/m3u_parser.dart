import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class M3UParser {
  static Future<List<Channel>> fetchAndParseM3U(String url) async {
    try {
      debugPrint('🌐 Fetching M3U playlist: $url');
      
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'Pure Player/1.0',
              'Accept': '*/*',
            },
          )
          .timeout(const Duration(seconds: 60), onTimeout: () {
            debugPrint('⏳ Playlist fetch timed out after 60s: $url');
            throw TimeoutException('Playlist request timed out', const Duration(seconds: 60));
          });
      
      debugPrint('📡 HTTP Response: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        debugPrint('❌ HTTP Error ${response.statusCode} for URL: $url');
        throw Exception('Failed to load playlist: HTTP ${response.statusCode}');
      }

      debugPrint('✅ Successfully fetched playlist, parsing content...');
      return parseM3UContent(response.body);
    } catch (e) {
      debugPrint('❌ Error fetching playlist from $url: $e');
      throw Exception('Error fetching playlist: $e');
    }
  }

  static List<Channel> parseM3UContent(String content) {
    final channels = <Channel>[];
    final lines = content.split('\n');
    
    String? currentName;
    String? currentGroup;
    String? currentLogo;
    String? currentCatchup;
    Map<String, String> currentAttributes = {};
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.startsWith('#EXTINF:')) {
        // Parse channel information
        currentName = _extractChannelName(line);
        currentGroup = _extractAttribute(line, 'group-title') ?? 'Ungrouped';
        currentLogo = _extractAttribute(line, 'tvg-logo') ?? '';
        currentCatchup = _extractAttribute(line, 'catchup-source');
        
        // Extract all attributes
        currentAttributes = _extractAllAttributes(line);
      } else if (line.isNotEmpty && 
                 !line.startsWith('#') && 
                 currentName != null) {
        // This is the stream URL
        channels.add(Channel(
          name: currentName,
          url: line,
          group: currentGroup ?? 'Ungrouped',
          logo: currentLogo ?? '',
          catchupUrl: currentCatchup,
          attributes: currentAttributes,
        ));
        
        // Reset for next channel
        currentName = null;
        currentGroup = null;
        currentLogo = null;
        currentCatchup = null;
        currentAttributes = {};
      }
    }
    
    return channels;
  }
  
  static String _extractChannelName(String extinf) {
    // Extract channel name after the last comma
    final commaIndex = extinf.lastIndexOf(',');
    if (commaIndex != -1 && commaIndex < extinf.length - 1) {
      return extinf.substring(commaIndex + 1).trim();
    }
    return 'Unknown Channel';
  }
  
  static String? _extractAttribute(String extinf, String attribute) {
    final regex = RegExp('$attribute="([^"]*)"', caseSensitive: false);
    final match = regex.firstMatch(extinf);
    return match?.group(1);
  }
  
  static Map<String, String> _extractAllAttributes(String extinf) {
    final attributes = <String, String>{};
    final regex = RegExp(r'(\w+(?:-\w+)*)="([^"]*)"', caseSensitive: false);
    final matches = regex.allMatches(extinf);
    
    for (final match in matches) {
      final key = match.group(1)?.toLowerCase();
      final value = match.group(2);
      if (key != null && value != null) {
        attributes[key] = value;
      }
    }
    
    return attributes;
  }
}