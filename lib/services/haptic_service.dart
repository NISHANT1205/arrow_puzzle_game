// lib/services/haptic_service.dart

import 'package:flutter/services.dart';

class HapticService {
  static final HapticService _instance = HapticService._internal();

  factory HapticService() {
    return _instance;
  }

  HapticService._internal();

  bool _enabled = true;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Light tap feedback
  Future<void> lightTap() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Ignore errors on unsupported platforms
    }
  }

  /// Medium impact feedback
  Future<void> mediumImpact() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Ignore errors
    }
  }

  /// Heavy impact feedback
  Future<void> heavyImpact() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Ignore errors
    }
  }

  /// Feedback for a successful move
  Future<void> successMove() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Ignore errors
    }
  }

  /// Feedback for a blocked move
  Future<void> blockedMove() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Ignore errors
    }
  }

  /// Feedback for level completion
  Future<void> levelComplete() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Ignore errors
    }
  }
}
