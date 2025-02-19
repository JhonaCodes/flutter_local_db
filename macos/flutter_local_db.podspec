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

  # Seleccionar la biblioteca correcta según la arquitectura
  s.vendored_libraries = %w[arm64 x86_64].map { |arch|
    "Frameworks/#{arch}/liboffline_first_core.dylib"
  }

  # Asignar nombres únicos a las bibliotecas según la arquitectura
  s.prepare_command = <<-SCRIPT
    mkdir -p Frameworks
    for arch in arm64 x86_64; do
      if [ -f "Frameworks/$arch/liboffline_first_core.dylib" ]; then
        mv "Frameworks/$arch/liboffline_first_core.dylib" "Frameworks/$arch/liboffline_first_core_$arch.dylib"
      fi
    done
  SCRIPT

  # Actualizar las rutas de búsqueda de bibliotecas
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'FRAMEWORK_SEARCH_PATHS' => '$(PLATFORM_DIR)/Developer/Library/Frameworks',
    'LIBRARY_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/Frameworks/arm64',
      '$(PODS_TARGET_SRCROOT)/Frameworks/x86_64'
    ].join(' '),
    'OTHER_LDFLAGS' => '-loffline_first_core_$(ARCHS)'
  }
end