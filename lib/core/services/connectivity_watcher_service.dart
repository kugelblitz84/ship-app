import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ConnectivityWatcherService extends GetxService {
  final RxBool isConnected = true.obs;

  final Connectivity _connectivity = Connectivity();
  final InternetConnection _internetConnection = InternetConnection();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<InternetStatus>? _internetStatusSubscription;

  bool _isOfflineDialogVisible = false;

  bool get isOffline => !isConnected.value;

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void onReady() {
    super.onReady();
    if (!_isSupportedPlatform) {
      return;
    }
    _startWatching();
  }

  Future<void> _startWatching() async {
    await _refreshConnectionState(forceDialogUpdate: true);

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((_) {
      unawaited(_refreshConnectionState());
    });

    _internetStatusSubscription = _internetConnection.onStatusChange.listen((
      status,
    ) {
      _updateState(status == InternetStatus.connected, forceDialogUpdate: true);
    });
  }

  Future<void> checkNow() async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _refreshConnectionState(forceDialogUpdate: true);
  }

  Future<void> _refreshConnectionState({bool forceDialogUpdate = false}) async {
    final hasTransport = await _hasNetworkTransport();
    if (!hasTransport) {
      _updateState(false, forceDialogUpdate: forceDialogUpdate);
      return;
    }

    final hasInternet = await _internetConnection.hasInternetAccess;
    _updateState(hasInternet, forceDialogUpdate: forceDialogUpdate);
  }

  Future<bool> _hasNetworkTransport() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  void _updateState(bool connected, {bool forceDialogUpdate = false}) {
    final didChange = isConnected.value != connected;
    if (didChange) {
      isConnected.value = connected;
    }

    if (connected) {
      _closeOfflineDialog();
      return;
    }

    if (didChange || forceDialogUpdate) {
      _showOfflineDialog();
    }
  }

  void _showOfflineDialog() {
    if (_isOfflineDialogVisible) {
      return;
    }

    final context = Get.overlayContext ?? Get.context;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isOffline) {
          _showOfflineDialog();
        }
      });
      return;
    }

    _isOfflineDialogVisible = true;
    unawaited(
      Get.dialog<void>(
        PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('No internet connection'),
            content: const Text('Please reconnect to continue using the app.'),
            actions: [
              TextButton(onPressed: checkNow, child: const Text('Reconnect')),
            ],
          ),
        ),
        barrierDismissible: false,
      ).whenComplete(() {
        _isOfflineDialogVisible = false;
      }),
    );
  }

  void _closeOfflineDialog() {
    if (!_isOfflineDialogVisible) {
      return;
    }

    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }
    _isOfflineDialogVisible = false;
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    _internetStatusSubscription?.cancel();
    super.onClose();
  }
}
