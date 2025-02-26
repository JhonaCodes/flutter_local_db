Pod::Spec.new do |s|
  s.name             = 'flutter_local_db'
  s.version          = '0.1.0'
  s.summary          = 'Flutter local database with Rust backend'
  s.description      = 'Flutter local database functionality with Rust FFI implementation.'
  s.homepage         = 'http://jhonacode.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Jhonacode' => 'team@jhonacode.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '12.0'

  LIB_NAME = 'liboffline_first_core.dylib'
  FRAMEWORKS_DIR = 'Frameworks'

  # Cambiado: Utilizamos rutas relativas para la biblioteca
  s.vendored_libraries = "#{FRAMEWORKS_DIR}/#{LIB_NAME}"
  s.preserve_paths = "#{FRAMEWORKS_DIR}/#{LIB_NAME}"

  # Configuración de Xcode
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '@executable_path/Frameworks $(inherited)',
    'OTHER_LDFLAGS' => '-Wl,-rpath,@executable_path/Frameworks',
    'ARCHS' => '$(ARCHS_STANDARD)',
    'VALID_ARCHS' => 'arm64 x86_64'
  }

  # Script para copiar la biblioteca al bundle final
  s.script_phases = [
    {
      :name => 'Copy Rust Library',
      :execution_position => :before_compile,
      :shell_path => '/bin/sh',
      :script => <<-SCRIPT
        mkdir -p "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
        cp -f "${PODS_TARGET_SRCROOT}/#{FRAMEWORKS_DIR}/#{LIB_NAME}" "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/"
      SCRIPT
    }
  ]
end