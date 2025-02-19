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

  s.source_files = ''

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'FRAMEWORK_SEARCH_PATHS' => '$(PLATFORM_DIR)/Developer/Library/Frameworks'
  }

  s.preserve_paths = 'Frameworks/**/*.dylib'

  s.script_phases = [
    {
      :name => 'Copy Rust library',
      :shell_path => '/bin/sh',
      :script => 'ARCH="$(uname -m)"
mkdir -p "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/$ARCH"
cp -f "${PODS_TARGET_SRCROOT}/Frameworks/$ARCH/liboffline_first_core.dylib" "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/$ARCH/"
',
      :execution_position => :after_compile
    }
  ]
end