import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../core/log.dart';
import '../local_db.dart';
import '../utils/system_utils.dart';

/// A widget that manages LocalDB lifecycle during hot restart
/// and app lifecycle changes. This helps prevent crashes during development.
/// 
/// Set [enableHotReloadManagement] to false to disable automatic management
/// for better performance during development.
class LocalDbLifecycleManager extends StatefulWidget {
  final Widget child;
  final VoidCallback? onHotRestart;
  final VoidCallback? onAppPaused;
  final VoidCallback? onAppResumed;
  final bool enableHotReloadManagement;

  const LocalDbLifecycleManager({
    Key? key,
    required this.child,
    this.onHotRestart,
    this.onAppPaused,
    this.onAppResumed,
    this.enableHotReloadManagement = true,
  }) : super(key: key);

  @override
  State<LocalDbLifecycleManager> createState() =>
      _LocalDbLifecycleManagerState();
}

class _LocalDbLifecycleManagerState extends State<LocalDbLifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // In debug mode, listen for hot restart (but not during tests)
    // Only if hot reload management is enabled
    if (kDebugMode && !SystemUtils.isTest && widget.enableHotReloadManagement) {
      _setupHotRestartListener();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupHotRestartListener() {
    // Simplified hot restart detection - only on actual errors, not constant polling
    if (kDebugMode) {
      // Only check once on widget initialization, not continuously
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (mounted) {
          try {
            // Single, lightweight connection check - no aggressive health checks
            final isValid = await LocalDB.IsConnectionValid();
            if (!isValid) {
              Log.w('LocalDB: Initial connection invalid, attempting single recovery');
              widget.onHotRestart?.call();
              await _performSimpleRecovery();
            }
          } catch (e) {
            Log.e('LocalDB: Error during initial connection check', error: e);
            // Only attempt recovery on genuine errors
            await _performSimpleRecovery();
          }
        }
      });
    }
  }

  Future<void> _performSimpleRecovery() async {
    try {
      Log.i('LocalDB: Attempting simple recovery...');
      
      // Single recovery attempt without multiple strategies
      // Let LocalDB.init handle its own retry logic if needed
      await LocalDB.init(localDbName: 'app_database.db');
      Log.i('LocalDB: Successfully recovered database connection');
    } catch (e) {
      Log.e('LocalDB: Simple recovery failed', error: e);
      if (mounted) {
        _showHotRestartError(e);
      }
    }
  }

  void _showHotRestartError(dynamic error) {
    // Show a development-friendly error message with enhanced information
    Log.e('''
    
🔥 === LocalDB Hot Restart Recovery Failed ===

ISSUE: All database recovery strategies have been exhausted.
CAUSE: Hot restart invalidated the FFI connection to the Rust backend.

ERROR DETAILS: $error

🚀 IMMEDIATE SOLUTIONS:
1. Full App Restart (⭐ RECOMMENDED):
   - Stop debugging session completely
   - Restart app from scratch
   - This will create fresh FFI connections

2. Continue with Degraded Mode:
   - App may continue running with limited functionality
   - Some database operations might fail
   - Data may not persist between restarts

3. Check Implementation:
   - Verify Rust binary is properly compiled
   - Ensure all FFI functions are exported correctly
   - Consider updating to latest flutter_local_db version

📊 DEBUG INFO:
- Platform: Native FFI (Rust backend)
- Recovery attempts: Multiple strategies tried
- Fallback status: Failed
- Recommendation: Full restart required

=== End Hot Restart Error Report ===
    
    ''');

    // Also provide a more concise warning for production scenarios
    if (!kDebugMode) {
      Log.w(
        'LocalDB: Database connection lost. App restart may be required for full functionality.',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        // Don't close database on pause - keep connection stable during development
        Log.i('LocalDB: App paused, maintaining connection');
        widget.onAppPaused?.call();
        break;

      case AppLifecycleState.resumed:
        Log.i('LocalDB: App resumed, connection maintained');
        widget.onAppResumed?.call();
        break;

      case AppLifecycleState.detached:
        // Only close on actual app termination
        Log.i('LocalDB: App detached, closing database connection');
        LocalDB.CloseDatabase().catchError((e) {
          Log.e('LocalDB: Error closing database on detach', error: e);
        });
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Extension to make it easier to wrap apps with LocalDB lifecycle management
extension LocalDbLifecycleManagerExtension on Widget {
  /// Wraps this widget with LocalDB lifecycle management
  /// 
  /// Set [enableHotReloadManagement] to false for better performance
  /// during development if you don't need automatic hot reload handling
  Widget withLocalDbLifecycle({
    VoidCallback? onHotRestart,
    VoidCallback? onAppPaused,
    VoidCallback? onAppResumed,
    bool enableHotReloadManagement = true,
  }) {
    return LocalDbLifecycleManager(
      onHotRestart: onHotRestart,
      onAppPaused: onAppPaused,
      onAppResumed: onAppResumed,
      enableHotReloadManagement: enableHotReloadManagement,
      child: this,
    );
  }
}
