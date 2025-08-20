import 'dart:io';

/// Defines the locations and filenames of the native libraries for different platforms.
/// Each platform requires its own specific library format and location.
enum FFiNativeLibLocation {
  /// Android shared library (.so)
  /// Located in the root library directory
  android('liboffline_first_core.so'),

  /// iOS static library (.a)
  /// Located in the ios subdirectory
  ios('liboffline_first_core.dylib'),

  /// macOS dynamic library (.dylib)
  /// Located in the macos subdirectory
  macos('liboffline_first_core.dylib'),

  /// Linux dynamic library (.dylib)
  /// Located in the linux subdirectory
  linux('liboffline_first_core.so'),

  /// Windows executable library (.exe)
  /// Located in the windows subdirectory
  windows('liboffline_first_core.dll');

  /// The platform-specific library path and filename
  /// This path is relative to the application's library directory
  final String lib;

  /// Constructor that maps each platform to its corresponding library path
  const FFiNativeLibLocation(this.lib);

  Future<String> toMacosArchPath() async {
    try {
      final result = await Process.run('uname', ['-m']);
      final arch = result.stdout.toString().trim();
      final archPath = 'liboffline_first_core_$arch.dylib';
      print('Architecture: $arch, Library path: $archPath');
      return archPath;
    } catch (e) {
      print('Error getting architecture: $e, falling back to default');
      return 'liboffline_first_core.dylib';
    }
  }
}
