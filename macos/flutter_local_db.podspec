Pod::Spec.new do |s|
  s.name             = 'flutter_local_db'
  s.version          = '1.0.0'
  s.summary          = 'A high-performance cross-platform local database for Flutter using Rust+LMDB via FFI.'
  s.description      = <<-DESC
A high-performance cross-platform local database for Flutter applications using Rust+LMDB via FFI.
                       DESC
  s.homepage         = 'https://github.com/JhonaCodes/flutter_local_db'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'JhonaCode' => 'contact@jhonacode.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.swift_version = '5.0'

  # Add the native libraries for different architectures
  s.vendored_libraries = ['liboffline_first_core_arm64.dylib', 'liboffline_first_core_x86_64.dylib']
  
  # Configure linking
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-loffline_first_core_arm64 -loffline_first_core_x86_64'
  }
end