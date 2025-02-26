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

  # Configuración de la biblioteca
  s.vendored_libraries = 'Frameworks/liboffline_first_core.dylib'
  s.preserve_paths = 'Frameworks/*.dylib'

  # Configuración de Xcode
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '@executable_path/Frameworks $(inherited)',
    'OTHER_LDFLAGS' => '-Wl,-rpath,@executable_path/Frameworks',
    'ENABLE_BITCODE' => 'NO',
    'VALID_ARCHS' => 'arm64 x86_64'
  }

  # Script simplificado - solo necesitamos copiar la biblioteca
  s.script_phases = [{
    :name => 'Setup Rust Library for iOS',
    :shell_path => '/bin/sh',
    :execution_position => :after_compile,
    :script => <<-SCRIPT
    #!/bin/sh
    set -e
    
    # Configuración de rutas
    FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
    LIB_NAME="liboffline_first_core.dylib"
    DEST_PATH="${FRAMEWORKS_DIR}/${LIB_NAME}"
    SOURCE_PATH="${PODS_TARGET_SRCROOT}/Frameworks/${LIB_NAME}"
    
    echo "Setting up Rust library for iOS..."
    echo "Source: ${SOURCE_PATH}"
    echo "Destination: ${DEST_PATH}"
    
    # Crear directorio si es necesario
    mkdir -p "${FRAMEWORKS_DIR}"
    
    # Copiar la biblioteca
    cp -f "${SOURCE_PATH}" "${DEST_PATH}" || { echo "Failed to copy library"; exit 1; }
    chmod +x "${DEST_PATH}"
    
    # Verificar que todo esté correcto
    echo "Library setup complete for iOS. Dependencies:"
    otool -L "${DEST_PATH}"
    SCRIPT
  }]
end