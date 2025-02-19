/// Defines the locations and filenames of the native libraries for different platforms.
/// Each platform requires its own specific library format and location.
enum FFiNativeLibLocation {
  /// Android shared library (.so)
  /// Located in the root library directory
  android('liboffline_first_core.so'),

  /// iOS static library (.a)
  /// Located in the ios subdirectory
  ios('ios/liboffline_first_core.a'),

  /// macOS dynamic library (.dylib)
  /// Located in the macos subdirectory
  macos('liboffline_first_core.dylib'),

  /// Linux dynamic library (.dylib)
  /// Located in the linux subdirectory
  linux('liboffline_first_core.dylib'),

  /// Windows executable library (.exe)
  /// Located in the windows subdirectory
  windows('liboffline_first_core.exe');

  /// The platform-specific library path and filename
  /// This path is relative to the application's library directory
  final String lib;

  /// Constructor that maps each platform to its corresponding library path
  const FFiNativeLibLocation(this.lib);

}
