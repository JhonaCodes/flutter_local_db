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
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Add the native library
  s.vendored_libraries = 'liboffline_first_core.dylib'
end