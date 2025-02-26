#═══════════════════════════════════════════════════════════════════════════
#  ╔═╗╦  ╦ ╦╔╦╗╔╦╗╔═╗╦═╗  ╦  ╔═╗╔═╗╔═╗╦    ╔╦╗╔╗
#  ╠╣ ║  ║ ║ ║  ║ ║╣ ╠╦╝  ║  ║ ║║  ╠═╣║     ║║╠╩╗
#  ╚  ╩═╝╚═╝ ╩  ╩ ╚═╝╩╚═  ╩═╝╚═╝╚═╝╩ ╩╩═╝  ═╩╝╚═╝
#     with Rust Backend & Multi-Architecture Support
#═══════════════════════════════════════════════════════════════════════════
# 🚀 Version: 0.1.0
# 🔧 Platform: iOS 11.0+
# 📦 Architectures: ARM64 & x86_64
# 👨‍💻 Author: Jhonacode Team (team@jhonacode.com)
#═══════════════════════════════════════════════════════════════════════════

Pod::Spec.new do |s|
  s.name             = 'flutter_local_db'
  s.version          = '0.1.0'
  s.summary          = 'Flutter local database with Rust backend'
  s.description      = 'Flutter local database functionality with Rust FFI implementation.'
  s.homepage         = 'http://jhonacode.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Jhonacode' => 'team@jhonacode.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '11.0'

  #══════════════════════════════════════════
  # 📚 Library Configuration
  #══════════════════════════════════════════
  LIB_NAME = 'liboffline_first_core.dylib'
  FRAMEWORKS_DIR = 'Frameworks'

  # Library path configuration
  s.vendored_libraries = "#{FRAMEWORKS_DIR}/#{LIB_NAME}"
  s.preserve_paths = "#{FRAMEWORKS_DIR}/*.dylib"

  #══════════════════════════════════════════
  # ⚙️ XCode Build Configuration
  #══════════════════════════════════════════
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '@executable_path/Frameworks @loader_path/Frameworks $(inherited)',
    'DYLIB_INSTALL_NAME_BASE' => '@rpath',
    'OTHER_LDFLAGS' => '-Wl,-rpath,@executable_path/Frameworks',
    'ENABLE_BITCODE' => 'NO',
    'VALID_ARCHS' => 'arm64 x86_64',
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/Frameworks $(BUILT_PRODUCTS_DIR)',
    'DYLIB_COMPATIBILITY_VERSION' => '1',
    'DYLIB_CURRENT_VERSION' => '1',
    'CODE_SIGN_ENTITLEMENTS' => '${PODS_TARGET_SRCROOT}/ios/flutter_local_db.entitlements'
  }

  s.user_target_xcconfig = {
    'LD_RUNPATH_SEARCH_PATHS' => '@executable_path/Frameworks $(inherited)',
    'OTHER_LDFLAGS' => '-Wl,-rpath,@executable_path/Frameworks'
  }

  #══════════════════════════════════════════
  # 🔄 Library Setup Script
  #══════════════════════════════════════════
  s.script_phases = [{
    :name => 'Setup Rust Library for iOS',
    :shell_path => '/bin/sh',
    :execution_position => :after_compile,
    :input_files => ["${PODS_TARGET_SRCROOT}/#{FRAMEWORKS_DIR}/#{LIB_NAME}"],
    :output_files => ["${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/#{LIB_NAME}"],
    :script => %Q(
#!/bin/sh
# 🔍 Setup paths
FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
LIB_NAME="#{LIB_NAME}"
DEST_PATH="${FRAMEWORKS_DIR}/${LIB_NAME}"
SOURCE_PATH="${PODS_TARGET_SRCROOT}/#{FRAMEWORKS_DIR}/${LIB_NAME}"

echo "Setting up Rust library for iOS..."
echo "Source path: ${SOURCE_PATH}"
echo "Destination path: ${DEST_PATH}"

# Create frameworks directory if needed
mkdir -p "${FRAMEWORKS_DIR}"

# Copy and configure library
if [ -f "${SOURCE_PATH}" ]; then
  echo "Copying library to frameworks directory..."
  cp -f "${SOURCE_PATH}" "${DEST_PATH}"
  chmod +x "${DEST_PATH}"
  
  # Fix library ID
  echo "Fixing library ID..."
  install_name_tool -id "@rpath/${LIB_NAME}" "${DEST_PATH}"
  
  # Add LC_RPATH command to the library if needed
  echo "Adding rpath..."
  install_name_tool -add_rpath "@loader_path/Frameworks" "${DEST_PATH}" 2>/dev/null || true
  
  # Verify configuration
  echo "Checking library permissions and signature:"
  ls -la "${DEST_PATH}"
  otool -L "${DEST_PATH}" | grep rpath || true
  codesign -dvv "${DEST_PATH}" 2>/dev/null || echo "Library not signed yet"
else
  echo "ERROR: Source library not found at ${SOURCE_PATH}"
  exit 1
fi
    )
  }]

  #══════════════════════════════════════════
  # 📑 Additional Resources
  #══════════════════════════════════════════
  s.resource_bundles = {
    'flutter_local_db' => ['ios/*.entitlements', 'ios/*.plist']
  }
end

#═══════════════════════════════════════════════════════════════════════════
# End of Flutter Local DB Podspec Configuration
#═══════════════════════════════════════════════════════════════════════════