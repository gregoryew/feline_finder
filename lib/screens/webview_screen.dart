import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import platform-specific implementations
import '../theme.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({
    Key? key,
    required this.url,
    this.title = 'Web Page',
  }) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;
  Timer? _loadingTimeout;

  @override
  void initState() {
    super.initState();
    
    // Initialize WebView controller
    // Platform implementations are auto-registered when imported above
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _error = null;
            });
            // Set a timeout - if page doesn't load in 30 seconds, show error
            _loadingTimeout?.cancel();
            _loadingTimeout = Timer(const Duration(seconds: 30), () {
              if (mounted && _isLoading) {
                setState(() {
                  _isLoading = false;
                  _error = 'Page is taking too long to load. Please check your internet connection.';
                });
              }
            });
          },
          onPageFinished: (String url) {
            _loadingTimeout?.cancel();
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            // Handle specific error codes
            if (error.errorCode == -999) {
              // Error code -999 is a cancelled request (common with redirects)
              // This often happens with Facebook URLs due to redirects
              // Don't show error - the page should continue loading after redirect
              // Don't change loading state - let onPageFinished handle it
              return;
            }
            
            // For other errors, show the error message
            setState(() {
              _isLoading = false;
              _loadingTimeout?.cancel();
              
              // Provide more helpful error messages
              String errorMessage = 'Failed to load page';
              
              errorMessage = 'Error code: ${error.errorCode}';
                          
              if (error.description.isNotEmpty) {
                errorMessage = error.description;
                // Check for common error types
                if (errorMessage.toLowerCase().contains('unsupported url')) {
                  errorMessage = 'Unsupported URL format. The URL may be invalid or malformed.';
                } else if (errorMessage.toLowerCase().contains('network')) {
                  errorMessage = 'Network error. Please check your internet connection.';
                } else if (errorMessage.toLowerCase().contains('ssl') || 
                          errorMessage.toLowerCase().contains('certificate')) {
                  errorMessage = 'SSL certificate error. The website may not be secure.';
                }
              }
              
              _error = errorMessage;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Validate URL before navigation
            try {
              String urlToCheck = request.url;
              
              // If URL doesn't have a scheme, try to fix it
              if (!urlToCheck.startsWith('http://') && !urlToCheck.startsWith('https://')) {
                // Try adding https://
                urlToCheck = 'https://$urlToCheck';
              }
              
              final uri = Uri.parse(urlToCheck);
              if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
                setState(() {
                  _isLoading = false;
                  _error = 'Unsupported URL format. URL must start with http:// or https://\nReceived: ${request.url}';
                });
                return NavigationDecision.prevent;
              }
              
              // If we fixed the URL and it's different, we can't redirect here
              // but at least we know the URL format is valid
              // The actual navigation will use the original request.url
            } catch (e) {
              setState(() {
                _isLoading = false;
                _error = 'Invalid URL format: ${request.url}\nError: $e';
              });
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    
    // Validate the URL before loading
    try {
      final uri = Uri.parse(widget.url);
      if (!uri.hasScheme || !uri.scheme.startsWith('http')) {
        setState(() {
          _isLoading = false;
          _error = 'Invalid URL format. URL must start with http:// or https://\nReceived: ${widget.url}';
        });
        return;
      }
      
      // Load the URL
      _controller.loadRequest(uri);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid URL format: ${widget.url}\nError: $e';
      });
    }
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepPurple,
      appBar: AppBar(
        backgroundColor: AppTheme.deepPurple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.fontSizeL,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: AppTheme.deepPurple,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.goldBase),
                ),
              ),
            ),
          if (_error != null && !_isLoading)
            Container(
              color: AppTheme.deepPurple,
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading page',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTheme.fontSizeL,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: AppTheme.fontSizeM,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _controller.reload();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.goldBase,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

