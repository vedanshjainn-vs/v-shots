// ═════════════════════════════════════════════════════════════════════════════
// V Shots — OfflineBanner (non-blocking connectivity indicator)
// ═════════════════════════════════════════════════════════════════════════════
//
// A lightweight, non-blocking banner that appears at the top of the screen
// when the device loses connectivity. It NEVER delays startup or blocks any
// interaction. Cached/local content remains fully usable offline.
//
// Implementation: listens to connectivity_plus stream, shows/hides with
// AnimatedOpacity + AnimatedContainer (GPU-friendly, no layout jank).
// The banner is mounted ONCE at the app shell (MainShell) and reacts to
// connectivity changes without rebuilding the rest of the app.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  bool _isOffline = false;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Check initial connectivity state (non-blocking).
    unawaited(_checkInitial());

    // Listen for connectivity changes.
    _subscription = Connectivity().onConnectivityChanged.listen(_onChanged);
  }

  Future<void> _checkInitial() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (!mounted) return;
      final offline = _isOfflineResult(results);
      if (offline != _isOffline) {
        setState(() => _isOffline = offline);
        if (offline) {
          unawaited(_slideController.forward());
        }
      }
    } catch (_) {
      // Connectivity check failed — assume online (non-blocking).
    }
  }

  void _onChanged(List<ConnectivityResult> results) {
    if (!mounted) return;
    final offline = _isOfflineResult(results);
    if (offline == _isOffline) return;
    setState(() => _isOffline = offline);
    if (offline) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
  }

  bool _isOfflineResult(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    return results.every((r) => r == ConnectivityResult.none);
  }

  @override
  void dispose() {
    _subscription.cancel();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: IgnorePointer(
        ignoring: !_isOffline,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.92),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'No internet connection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• Cached content still available',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
