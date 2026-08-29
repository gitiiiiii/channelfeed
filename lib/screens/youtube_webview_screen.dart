import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens a YouTube page (video or channel) in an in-app WebView.
///
/// The WebView is isolated from the rest of the app: it owns its own
/// controller, supports normal page navigation plus back navigation that first
/// walks the WebView history, plays videos fullscreen, and surfaces loading
/// and error states. It never modifies the loaded YouTube page.
class YoutubeWebViewScreen extends StatefulWidget {
  const YoutubeWebViewScreen({
    super.key,
    required this.initialUrl,
    this.title = 'YouTube',
  });

  /// The URL to load, e.g. a watch page or a channel page.
  final String initialUrl;

  /// AppBar title shown while the page has not reported its own title.
  final String title;

  /// Accepts http/https URLs; upgrades YouTube pages to https. Returns null
  /// for anything that cannot be loaded safely in a WebView.
  static Uri? normalizeUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      return null;
    }
    final scheme = uri.scheme;
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }
    if (uri.host.isEmpty) {
      return null;
    }
    final host = uri.host.toLowerCase();
    final isYouTube = host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtu.be' ||
        host.endsWith('.youtu.be');
    if (isYouTube && scheme == 'http') {
      return uri.replace(scheme: 'https');
    }
    return uri;
  }

  @override
  State<YoutubeWebViewScreen> createState() => _YoutubeWebViewScreenState();
}

class _YoutubeWebViewScreenState extends State<YoutubeWebViewScreen> {
  final WebViewController _controller = WebViewController();

  Uri? _uri;
  double? _progress;
  String? _error;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _uri = YoutubeWebViewScreen.normalizeUrl(widget.initialUrl);
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (int progress) {
          if (!mounted) {
            return;
          }
          setState(() => _progress = progress.toDouble());
        },
        onPageStarted: (String url) {
          if (!mounted) {
            return;
          }
          setState(() {
            _progress = 0;
            _error = null;
          });
        },
        onPageFinished: (String url) {
          if (!mounted) {
            return;
          }
          setState(() {
            _hasLoaded = true;
            _progress = null;
            _error = null;
          });
        },
        onWebResourceError: (WebResourceError error) {
          if (!mounted) {
            return;
          }
          if (!_hasLoaded) {
            setState(() {
              _error = 'This page could not be loaded. '
                  'Check your connection and try again.';
            });
          }
        },
      ));
    _load();
  }

  Future<void> _load() async {
    final uri = _uri;
    if (uri == null) {
      setState(() {
        _error = 'This link is invalid and could not be opened.';
      });
      return;
    }
    try {
      await _controller.loadRequest(uri);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'This page could not be loaded. '
            'Check your connection and try again.';
      });
    }
  }

  Future<void> _goBackOrPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _hasLoaded = false;
      _progress = 0;
    });
    await _load();
  }

  Widget _buildError(String message) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (error != null) {
      return _buildError(error);
    }
    if (_uri == null) {
      return _buildError('This link is invalid and could not be opened.');
    }
    return WebViewWidget(controller: _controller);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        await _goBackOrPop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _goBackOrPop),
          title: Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: Column(
          children: <Widget>[
            if (_progress != null && _error == null && _progress! < 100)
              LinearProgressIndicator(value: _progress! / 100),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}
