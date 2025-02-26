#═══════════════════════════════════════════════════════════════════════════
#  ╔═╗╦  ╦ ╦╔╦╗╔╦╗╔═╗╦═╗  ╦  ╔═╗╔═╗╔═╗╦    ╔╦╗╔╗
#  ╠╣ ║  ║ ║ ║  ║ ║╣ ╠╦╝  ║  ║ ║║  ╠═╣║     ║║╠╩╗
#  ╚  ╩═╝╚═╝ ╩  ╩ ╚═╝╩╚═  ╩═╝╚═╝╚═╝╩ ╩╩═╝  ═╩╝╚═╝
#     with Rust Backend & Multi-Architecture Support
#═══════════════════════════════════════════════════════════════════════════
# 🚀 Version: 0.1.0
# 🔧 Platform: iOS 12.0+
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
  s.platform         = :ios, '12.0'

  #══════════════════════════════════════════
  # 📚 Library Configuration
  #══════════════════════════════════════════
  s.vendored_libraries = 'Frameworks/liboffline_first_core.dylib'
  s.preserve_paths = 'Frameworks/*.dylib'

  #══════════════════════════════════════════
  # ⚙️ XCode Build Configuration
  #══════════════════════════════════════════
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '@executable_path/Frameworks $(inherited)',
    'OTHER_LDFLAGS' => '-Wl,-rpath,@executable_path/Frameworks',
    'ENABLE_BITCODE' => 'NO',
    'VALID_ARCHS' => 'arm64 x86_64',
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/Frameworks $(BUILT_PRODUCTS_DIR)',
    'DYLIB_COMPATIBILITY_VERSION' => '1',
    'DYLIB_CURRENT_VERSION' => '1'
  }

  #══════════════════════════════════════════
  # 🔄 Library Setup Script
  #══════════════════════════════════════════
  s.script_phases = [{
    :name => 'Setup Rust Library for iOS',
    :shell_path => '/bin/sh',
    :execution_position => :after_compile,
    :script => %Q(
#!/bin/sh
# 🔍 Setup paths
FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
LIB_NAME="liboffline_first_core.dylib"
DEST_PATH="${FRAMEWORKS_DIR}/${LIB_NAME}"
SOURCE_PATH="${PODS_TARGET_SRCROOT}/Frameworks/${LIB_NAME}"

echo "Setting up Rust library for iOS..."
echo "Source: ${SOURCE_PATH}"
echo "Destination: ${DEST_PATH}"

# Create frameworks directory if needed
mkdir -p "${FRAMEWORKS_DIR}"

# Copy and configure library
if [ -f "${SOURCE_PATH}" ]; then
  cp -f "${SOURCE_PATH}" "${DEST_PATH}"
  chmod +x "${DEST_PATH}"
  
  # Verify configuration
  echo "Library setup complete for iOS. Dependencies:"
  otool -L "${DEST_PATH}"
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