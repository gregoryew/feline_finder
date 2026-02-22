import 'package:flutter/material.dart';

/// Returns true if [e] is likely a network/connectivity error (no internet, timeout, DNS, Firebase/Firestore unavailable, etc.).
bool isNetworkError(Object e) {
  final name = e.runtimeType.toString().toLowerCase();
  final msg = e.toString().toLowerCase();
  return name.contains('socket') ||
      name.contains('timeout') ||
      name.contains('handshake') ||
      name.contains('clientexception') ||
      name.contains('firebase') ||
      msg.contains('socketexception') ||
      msg.contains('timeoutexception') ||
      msg.contains('connection') ||
      msg.contains('failed host lookup') ||
      msg.contains('network is unreachable') ||
      msg.contains('connection refused') ||
      msg.contains('connection reset') ||
      msg.contains('no internet') ||
      msg.contains('network error') ||
      msg.contains('unavailable') ||
      msg.contains('failed to get document') ||
      msg.contains('firestore');
}

/// User-facing message when the app cannot reach the network.
const String kNetworkErrorMessage =
    'No internet connection. Please check your network and try again.';

/// Shows a snackbar with an understandable message when the app cannot access the network.
void showNetworkErrorSnackBar(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              kNetworkErrorMessage,
              maxLines: 2,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.orange,
      duration: Duration(seconds: 4),
    ),
  );
}
