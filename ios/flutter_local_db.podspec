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

  # Asegura que la librería esté incluida correctamente
  s.vendored_libraries = "../Frameworks/liboffline_first_core.dylib"
  s.preserve_paths = "#{FRAMEWORKS_DIR}/#{LIB_NAME}"

  # Configuración de Xcode
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '@executable_path/Frameworks',
    'OTHER_LDFLAGS' => '-Wl,-rpath,@executable_path/Frameworks',
    'ARCHS' => '$(ARCHS_STANDARD)',
    'VALID_ARCHS' => 'arm64 x86_64'
  }

  # Verifica que la librería esté en su lugar antes de compilar
  s.prepare_command = <<-CMD
    mkdir -p #{FRAMEWORKS_DIR}
    if [ ! -f "#{FRAMEWORKS_DIR}/#{LIB_NAME}" ]; then
      echo "Error: #{LIB_NAME} no encontrado en #{FRAMEWORKS_DIR}"
      exit 1
    fi
  CMD
end
