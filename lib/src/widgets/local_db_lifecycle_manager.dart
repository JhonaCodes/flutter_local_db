import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../local_db.dart';

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
  State<LocalDbLifecycleManager> createState() => _LocalDbLifecycleManagerState();
}

class _LocalDbLifecycleManagerState extends State<LocalDbLifecycleManager>
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // In debug mode, listen for hot restart
    if (kDebugMode) {
      _setupHotRestartListener();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupHotRestartListener() {
    // This is a workaround to detect hot restart
    // We check connection validity periodically in debug mode
    if (kDebugMode) {
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (mounted) {
          try {
            final isValid = await LocalDB.IsConnectionValid();
            if (!isValid) {
              debugPrint('LocalDB: Connection became invalid, likely due to hot restart');
              widget.onHotRestart?.call();
            }
          } catch (e) {
            debugPrint('LocalDB: Error checking connection: $e');
          }
          
          // Continue checking if still mounted
          if (mounted) {
            _setupHotRestartListener();
          }
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        debugPrint('LocalDB: App paused, closing database connection');
        LocalDB.CloseDatabase().catchError((e) {
          debugPrint('LocalDB: Error closing database on pause: $e');
        });
        widget.onAppPaused?.call();
        break;
        
      case AppLifecycleState.resumed:
        debugPrint('LocalDB: App resumed, connection will be re-established on next operation');
        widget.onAppResumed?.call();
        break;
        
      case AppLifecycleState.detached:
        debugPrint('LocalDB: App detached, closing database connection');
        LocalDB.CloseDatabase().catchError((e) {
          debugPrint('LocalDB: Error closing database on detach: $e');
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