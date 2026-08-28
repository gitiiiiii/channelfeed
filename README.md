# ChannelFeed

A personalized video feed built from the channels you choose. Search YouTube,
follow the channels you care about, and get a combined feed of their latest
uploads. Independent app, not affiliated with YouTube.

## Features

- **Three tabs**: Home (your feed), Channels (search & follow), Profile
  (settings).
- **Live channel search** via the YouTube Data API v3, with real thumbnails,
  handles, and subscriber counts.
- **Personalized feed** combining the most recent uploads from the channels
  you follow, sorted newest-first, with loading/error/empty states.
- **Video cards** with thumbnail, title, channel name, and publish time;
  tapping opens the video in the official YouTube app/browser.
- **Selection & preference persistence** — followed channels and settings
  (theme, autoplay, view counts) survive app restarts (stored on-device via
  `shared_preferences`).
- **Offline fallback** — without an API key the app runs entirely on built-in
  sample data, so it still works out of the box.

## YouTube API key setup

The app reads its API key from a `--dart-define` at build time, so no secret
is committed to the repository.

### 1. Create a key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project.
3. **APIs & Services > Library** and enable the **YouTube Data API v3**.
4. **APIs & Services > Credentials > Create Credentials > API key**.
5. Copy the key.

### 2. Restrict the key (recommended)

1. In **Credentials**, edit the key you just created.
2. Set **Application restrictions** to **Android apps** and add your app's
   package name (default: `com.example.channelfeed`) and the SHA-1 of your
   signing key (from `keytool -list -v -keystore <keystore>`).
   For local development you can instead restrict by **IP addresses**.
3. Set **API restrictions** to **YouTube Data API v3** only.
4. Save.

> Quotas: the free tier allows 10,000 units/day; a search costs 100 units and
> a `videos.list` call 1 unit. This app caches results for 5 minutes to stay
> well within limits.

### 3. Run the app

```bash
flutter run --dart-define=YOUTUBE_API_KEY=YOUR_API_KEY
```

For a debug build:

```bash
flutter build apk --debug --dart-define=YOUTUBE_API_KEY=YOUR_API_KEY
```

To use the built-in sample data instead, just run without the define:

```bash
flutter run
```

## Project structure

```
lib/
  main.dart                       # Wiring: services + repository injection
  data/mock_data.dart             # Offline sample channels and videos
  models/                         # Channel, Video, Preferences, UserProfile
  screens/                        # Home shell, Home, Channels, Profile
  services/
    youtube_api_service.dart      # Isolated YouTube Data API v3 client
    content_repository.dart       # Live API / offline fallback abstraction
    channel_service.dart          # Directory + follow state
    feed_service.dart             # Feed resolution + live refresh
    local_store.dart              # On-device persistence (preferences + ids)
    settings_service.dart         # Preferences
  widgets/                        # ChannelCard, VideoCard, ChannelAvatar, ...
  utils/formats.dart              # Number/duration/date formatters
```

## Tests

```bash
flutter analyze
flutter test
```

The test suite covers the formatters, the YouTube API client (parsing, caching,
error handling, via a mock HTTP client), live/offline feed behavior, channel
search, persistence, and the widget flows.
