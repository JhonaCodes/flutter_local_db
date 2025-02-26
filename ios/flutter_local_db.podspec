Pod::Spec.new do |s|
  s.name             = 'flutter_local_db'
  s.version          = '0.0.1'
  s.summary          = 'Flutter local database with Rust backend'
  s.description      = 'Flutter local database functionality with Rust FFI implementation.'
  s.homepage         = 'http://jhonacode.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Jhonacode' => 'team@jhonacode.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '11.0'

  # iOS siempre usa arm64 en dispositivos modernos
  LIB_NAME = 'liboffline_first_core.dylib'

  # Configuración específica para iOS
  s.vendored_libraries = "Frameworks/#{LIB_NAME}"
  s.preserve_paths = "Frameworks/#{LIB_NAME}"

  # Configuración de XCode
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '@executable_path/Frameworks',
    'DYLIB_INSTALL_NAME_BASE' => '@rpath',
    'OTHER_LDFLAGS' => '-Wl,-rpath,@executable_path/Frameworks',
    'VALID_ARCHS' => 'arm64'
  }

  # Script para preparar la biblioteca (similar a tu implementación de macOS)
  s.script_phases = [{
    :name => 'Setup Library for iOS',
    :shell_path => '/bin/sh',
    :execution_position => :after_compile,
    :script => %Q(
#!/bin/sh
# Configurar rutas
FRAMEWORKS_DIR="${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/Frameworks"
LIB_NAME="#{LIB_NAME}"
SOURCE_PATH="${PODS_TARGET_SRCROOT}/Frameworks/${LIB_NAME}"
DEST_PATH="${FRAMEWORKS_DIR}/${LIB_NAME}"

# Crear directorio de frameworks si no existe
mkdir -p "${FRAMEWORKS_DIR}"

# Copiar la biblioteca
echo "Copiando ${LIB_NAME} para iOS..."
cp -f "${SOURCE_PATH}" "${DEST_PATH}"
chmod +x "${DEST_PATH}"

# Modificar el ID de instalación para usar @rpath
echo "Configurando install_name..."
install_name_tool -id "@rpath/${LIB_NAME}" "${DEST_PATH}"

# Firmar la biblioteca
echo "Firmando biblioteca..."
codesign -f -s "Apple Development" "${DEST_PATH}" || echo "Advertencia: Firma no completada"

# Verificar configuración
echo "Verificando configuración:"
otool -L "${DEST_PATH}" | grep -i offline
    )
  }]
end