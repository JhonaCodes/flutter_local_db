import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../core/log.dart';
import '../local_db.dart';
import '../utils/system_utils.dart';

/// A widget that automatically manages LocalDB lifecycle during hot restart
/// and app lifecycle changes. This helps prevent crashes during development.
class LocalDbLifecycleManager extends StatefulWidget {
  final Widget child;
  final VoidCallback? onHotRestart;
  final VoidCallback? onAppPaused;
  final VoidCallback? onAppResumed;

  const LocalDbLifecycleManager({
    Key? key,
    required this.child,
    this.onHotRestart,
    this.onAppPaused,
    this.onAppResumed,
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
    if (kDebugMode && !SystemUtils.isTest) {
      _setupHotRestartListener();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupHotRestartListener() {
    // Enhanced hot restart detection with multiple strategies
    if (kDebugMode) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          bool recoveryNeeded = false;
          String? recoveryReason;

          try {
            // Strategy 1: Check basic connection validity
            final isValid = await LocalDB.IsConnectionValid();
            if (!isValid) {
              recoveryNeeded = true;
              recoveryReason = 'Basic connection validation failed';
            }

            // Strategy 2: Try a simple ping operation to detect stale connections
            if (!recoveryNeeded) {
              try {
                final testResult = await LocalDB.GetById('__health_check__');
                // Even if the record doesn't exist, the operation should complete without FFI errors
                if (testResult.isErr) {
                  final error = testResult.errorOrNull;
                  if (error != null &&
                      error.toString().contains('Invalid or stale')) {
                    recoveryNeeded = true;
                    recoveryReason = 'Health check detected stale connection';
                  }
                }
              } catch (e) {
                // FFI errors often indicate hot restart issues
                if (e.toString().contains('pointer') ||
                    e.toString().contains('invalid') ||
                    e.toString().contains('null')) {
                  recoveryNeeded = true;
                  recoveryReason = 'Health check FFI error detected';
                }
              }
            }

            if (recoveryNeeded) {
              Log.w('LocalDB: Hot restart detected - $recoveryReason');
              widget.onHotRestart?.call();

              await _performIntelligentRecovery();
            }
          } catch (e) {
            Log.e('LocalDB: Error during hot restart detection', error: e);
            // If there's an error in detection itself, attempt recovery
            await _performIntelligentRecovery();
          }

          // Continue checking if still mounted
          // Use adaptive intervals: shorter after recovery, longer during stable periods
          if (mounted) {
            final delay = recoveryNeeded
                ? const Duration(seconds: 1)
                : // Quick recheck after recovery
                  const Duration(seconds: 3); // Normal interval
            Future.delayed(delay, _setupHotRestartListener);
          }
        }
      });
    }
  }

  Future<void> _performIntelligentRecovery() async {
    try {
      // Strategy 1: Try to recover with the same database name
      Log.i('LocalDB: Attempting intelligent recovery...');

      // First, try a gentle recovery (same DB name)
      try {
        await LocalDB.init(localDbName: 'app_database.db');
        Log.i('LocalDB: Successfully recovered with original database');
        return;
      } catch (e) {
        Log.w('LocalDB: Original database recovery failed, trying fallback');
      }

      // Strategy 2: Try with a hot restart specific name
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await LocalDB.init(localDbName: 'hot_restart_recovery_$timestamp.db');
        Log.i('LocalDB: Successfully recovered with timestamped database');
        return;
      } catch (e) {
        Log.w(
          'LocalDB: Timestamped database recovery failed, trying minimal fallback',
        );
      }

      // Strategy 3: Last resort - minimal fallback
      try {
        await LocalDB.init(localDbName: 'fallback.db');
        Log.i('LocalDB: Successfully recovered with fallback database');
        return;
      } catch (e) {
        Log.e('LocalDB: All recovery strategies failed', error: e);
        if (mounted) {
          _showHotRestartError(e);
        }
      }
    } catch (e) {
      Log.e('LocalDB: Critical error during recovery', error: e);
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
        Log.i('LocalDB: App paused, closing database connection');
        LocalDB.CloseDatabase().catchError((e) {
          Log.e('LocalDB: Error closing database on pause', error: e);
        });
        widget.onAppPaused?.call();
        break;

      case AppLifecycleState.resumed:
        Log.i(
          'LocalDB: App resumed, connection will be re-established on next operation',
        );
        widget.onAppResumed?.call();
        break;

      case AppLifecycleState.detached:
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
  Widget withLocalDbLifecycle({
    VoidCallback? onHotRestart,
    VoidCallback? onAppPaused,
    VoidCallback? onAppResumed,
  }) {
    return LocalDbLifecycleManager(
      onHotRestart: onHotRestart,
      onAppPaused: onAppPaused,
      onAppResumed: onAppResumed,
      child: this,
    );
  }
}
