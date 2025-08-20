Pod::Spec.new do |s|
  s.name             = 'flutter_local_db'
  s.version          = '0.9.0'
  s.summary          = 'Flutter local database with Rust backend'
  s.description      = 'A high-performance cross-platform local database for Flutter with Rust FFI backend.'
  s.homepage         = 'https://github.com/JhonaCodes/flutter_local_db'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'JhonaCodes' => 'jhonacode@example.com' }
  s.source           = { :path => '.' }
  
  s.platform = :osx, '10.14'

  # FFI plugin - native libraries only
  s.vendored_libraries = 'Frameworks/liboffline_first_core_arm64.dylib'
  s.preserve_paths = 'Frameworks/*.dylib'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end