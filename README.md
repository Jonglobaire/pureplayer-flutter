# Pure Player

A Flutter Android app for playing IPTV streams from M3U playlists with Netflix-inspired UI design.

## Features

- **Modern UI**: Netflix-inspired dark theme with red accents
- **Splash Screen**: Shows app logo and device information
- **M3U Playlist Support**: Load playlists from URLs with robust parsing
- **Organized Channel List**: Expandable groups with channel logos
- **Advanced Video Player**: Full-screen support, PiP, and catch-up features
- **Device Information**: Display MAC address and device model
- **Error Handling**: Comprehensive error handling with retry functionality
- **Material 3 Design**: Modern Android design principles

## Project Structure

```
lib/
├── main.dart              # App entry point with Netflix theme
├── models/
│   └── channel.dart       # Enhanced channel model with attributes
├── services/
│   └── m3u_parser.dart    # Robust M3U playlist parser
├── screens/
│   ├── splash_screen.dart # Animated splash with device info
│   ├── home_screen.dart   # Main playlist management screen
│   └── player_screen.dart # Advanced video player screen
└── utils/
    └── device_info.dart   # Device information utilities
```

## Running the App

### Prerequisites

1. **Flutter SDK** (3.0.0 or higher)
2. **Android Studio** with Android SDK
3. **JDK 17** (required for Gradle 8.3)
4. **Android device or emulator**

### Quick Start

1. **Clone and navigate to project:**
   ```bash
   cd ~/Downloads/pureapp
   ```

2. **Clean and get dependencies:**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Run on Android:**
   ```bash
   flutter run
   ```

### Build Configuration

- **Package Name**: `com.pure.player`
- **Gradle Version**: 8.3
- **JDK Version**: 17
- **Target SDK**: Latest Flutter default
- **Min SDK**: Flutter default (21+)

## App Features

### 🎬 Splash Screen
- Animated Pure Player logo with red "P"
- Device model and ID display
- Smooth fade-in animation
- 3-second loading time

### 🏠 Home Screen
- Clean M3U URL input with validation
- Netflix-style dark theme
- Expandable channel groups
- Channel logos and metadata
- Loading states and error handling
- Empty state with helpful tips

### 📺 Player Screen
- Better Player integration with advanced controls
- Full-screen and PiP support
- Live stream indicators
- Channel information display
- Retry functionality
- Orientation handling

### 🔧 Technical Features
- **Robust M3U Parsing**: Handles various M3U formats
- **Error Recovery**: Automatic retry mechanisms
- **Memory Management**: Proper disposal of resources
- **Network Optimization**: Custom headers and timeouts
- **Device Integration**: MAC address and model detection

## Dependencies

```yaml
dependencies:
  flutter: sdk
  http: ^1.1.0              # Network requests
  better_player: ^0.0.84    # Video playback
  device_info_plus: ^9.1.0  # Device information
  cupertino_icons: ^1.0.2   # iOS-style icons
```

## Build Requirements

### Android Configuration
- **Namespace**: `com.pure.player`
- **Compile SDK**: Latest Flutter default
- **JDK**: Version 17
- **Gradle**: 8.3
- **Kotlin**: 1.9.10

### Permissions
- `INTERNET`: Network access for streaming
- `ACCESS_NETWORK_STATE`: Network state monitoring
- `WAKE_LOCK`: Prevent sleep during playback

## Testing

### Sample M3U URLs
You can test the app with free IPTV M3U playlists available online:
- Search for "free IPTV M3U playlist"
- Use format: `https://example.com/playlist.m3u`

### Features to Test
1. **Playlist Loading**: Various M3U formats
2. **Channel Playback**: Different stream types
3. **Error Handling**: Invalid URLs and streams
4. **UI Responsiveness**: Different screen sizes
5. **Orientation Changes**: Portrait/landscape modes

## Troubleshooting

### Common Issues

1. **Build Errors**: Ensure JDK 17 is installed and configured
2. **Network Issues**: Check internet connection and URL validity
3. **Playback Failures**: Try different M3U sources
4. **Performance**: Close other apps for better streaming

### Build Commands
```bash
# Clean build
flutter clean && flutter pub get

# Debug build
flutter run --debug

# Release build
flutter build apk --release
```

## App Architecture

- **MVVM Pattern**: Clean separation of concerns
- **State Management**: StatefulWidget with proper lifecycle
- **Error Boundaries**: Comprehensive error handling
- **Resource Management**: Automatic cleanup and disposal
- **Network Layer**: Robust HTTP client with retries

## Future Enhancements

- [ ] Favorites and bookmarks
- [ ] EPG (Electronic Program Guide) support
- [ ] Chromecast integration
- [ ] Multiple playlist management
- [ ] Search and filtering
- [ ] Recording capabilities
- [ ] Custom themes

---

**Pure Player** - Professional IPTV streaming experience on Android.