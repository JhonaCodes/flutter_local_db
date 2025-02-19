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
  s.author           = { 'jhonacode' => 'team@jhonacode.com' }
  s.source           = { :path => '.' }
  s.platform = :osx, '10.11'

  # No source files needed for FFI
  s.source_files = ''

  # Configuración específica según la arquitectura
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'FRAMEWORK_SEARCH_PATHS' => '$(PLATFORM_DIR)/Developer/Library/Frameworks',
  }

  # Asegurar que las bibliotecas se copian al bundle
  s.preserve_paths = [
    'Frameworks/arm64/*.dylib',
    'Frameworks/x86_64/*.dylib'
  ]

  # Script para copiar la biblioteca correcta según la arquitectura
  s.script_phase = {
    :name => 'Copy Rust library',
    :script => <<-SCRIPT
      set -e
      ARCH="$ARCHS"
      if [[ $ARCH == *"arm64"* ]]; then
        cp -f "${PODS_TARGET_SRCROOT}/Frameworks/arm64/liboffline_first_core.dylib" "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/liboffline_first_core_arm64.dylib"
      fi
      if [[ $ARCH == *"x86_64"* ]]; then
        cp -f "${PODS_TARGET_SRCROOT}/Frameworks/x86_64/liboffline_first_core.dylib" "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/liboffline_first_core_x86_64.dylib"
      fi
    SCRIPT
    ,
    :execution_position => :after_compile
  }
end