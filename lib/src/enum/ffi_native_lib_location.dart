enum FFiNativeLibLocation {
  android('liboffline_first_core.so'),
  ios('ios/liboffline_first_core.a'),
  macos('macos/liboffline_first_core.dylib'),
  linux('linux/liboffline_first_core.dylib'),
  windows('windows/liboffline_first_core.exe');

  final String lib;

  const FFiNativeLibLocation(this.lib);
}
