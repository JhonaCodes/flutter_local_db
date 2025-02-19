#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_local_db'
  s.version          = '0.0.1'
  s.summary          = 'Flutter local database with Rust backend'
  s.description      = <<-DESC
Flutter local database functionality with Rust FFI implementation.
                       DESC
  s.homepage         = 'http://jhonacode.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Jhonacode' => 'team@jhonacode.com' }
  s.source           = { :path => '.' }
  s.platform = :osx, '10.11'

  # No source files needed for FFI
  s.source_files = ''

  # Include the compiled Rust libraries for both architectures
  s.vendored_libraries = [
    "Frameworks/arm64/liboffline_first_core.dylib",
    "Frameworks/x86_64/liboffline_first_core.dylib"
  ]

  # Configuration for universal binary support
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'FRAMEWORK_SEARCH_PATHS' => '$(PLATFORM_DIR)/Developer/Library/Frameworks',
    'LIBRARY_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/Frameworks/arm64',
      '$(PODS_TARGET_SRCROOT)/Frameworks/x86_64'
    ].join(' ')
  }
end