import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device has a network connection.
///
/// [online] means a network interface is up (Wi-Fi, mobile data,
/// Ethernet). It does **not** mean the internet or the API is reachable: a
/// captive portal, a dead router or a backend outage still look online.
/// Use it to explain failures ("You're offline") and to retry when the
/// connection returns, never to skip or assume the outcome of a request;
/// the request's own result is the only proof.
enum ConnectivityStatus {
  /// A network interface is up.
  online,

  /// No network interface is up.
  offline,
}

/// Reports [ConnectivityStatus] and its changes.
abstract interface class ConnectivityMonitor {
  /// The status now.
  Future<ConnectivityStatus> current();

  /// Every change of status (not repeated while unchanged).
  Stream<ConnectivityStatus> get changes;
}

/// [ConnectivityMonitor] over the `connectivity_plus` plugin (Android, iOS,
/// web). The only code that imports the plugin.
final class PluginConnectivityMonitor implements ConnectivityMonitor {
  /// Creates the monitor; [connectivity] is replaceable for tests.
  PluginConnectivityMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<ConnectivityStatus> current() async =>
      statusOf(await _connectivity.checkConnectivity());

  @override
  Stream<ConnectivityStatus> get changes =>
      _connectivity.onConnectivityChanged.map(statusOf).distinct();

  /// Offline when the plugin reports no interface (or only `none`).
  static ConnectivityStatus statusOf(List<ConnectivityResult> results) =>
      results.every((result) => result == ConnectivityResult.none)
      ? ConnectivityStatus.offline
      : ConnectivityStatus.online;
}
