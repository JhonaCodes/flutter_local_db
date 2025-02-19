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

  # Configuración básica
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'FRAMEWORK_SEARCH_PATHS' => '$(PLATFORM_DIR)/Developer/Library/Frameworks'
  }

  # Preservar las bibliotecas en sus respectivas carpetas
  s.preserve_paths = 'Frameworks/**/*.dylib'

  # Script simple para copiar la biblioteca según la arquitectura
  s.script_phase = {
    :name => 'Copy Rust library',
    :script => <<-SCRIPT
      set -e
      ARCH="$(uname -m)"
      mkdir -p "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/$ARCH"
      cp -f "${PODS_TARGET_SRCROOT}/Frameworks/$ARCH/liboffline_first_core.dylib" "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/$ARCH/"
    SCRIPT
    ,
    :execution_position => :after_compile
  }
end