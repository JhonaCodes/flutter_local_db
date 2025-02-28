#═══════════════════════════════════════════════════════════════════════════
#  ╔═╗╦  ╦ ╦╔╦╗╔╦╗╔═╗╦═╗  ╦  ╔═╗╔═╗╔═╗╦    ╔╦╗╔╗
#  ╠╣ ║  ║ ║ ║  ║ ║╣ ╠╦╝  ║  ║ ║║  ╠═╣║     ║║╠╩╗
#  ╚  ╩═╝╚═╝ ╩  ╩ ╚═╝╩╚═  ╩═╝╚═╝╚═╝╩ ╩╩═╝  ═╩╝╚═╝
#     with Rust Backend & Multi-Architecture Support
#═══════════════════════════════════════════════════════════════════════════
# 🚀 Version: 0.0.1
# 🔧 Platform: macOS 10.13+
# 📦 Architectures: ARM64 & x86_64
# 👨‍💻 Author: Jhonacode Team (team@jhonacode.com)
#═══════════════════════════════════════════════════════════════════════════

# Determine architecture and set library path
arch = `uname -m`.strip
if arch == 'arm64'
 ARCH_LIB = "Frameworks/liboffline_first_core_arm64.dylib"
 CURRENT_ARCH = "arm64"
else
 ARCH_LIB = "Frameworks/liboffline_first_core_x86_64.dylib"
 CURRENT_ARCH = "x86_64"
end

Pod::Spec.new do |s|
 s.name             = 'flutter_local_db'
 s.version          = '0.0.1'
 s.summary          = 'Flutter local database with Rust backend'
 s.description      = 'Flutter local database functionality with Rust FFI implementation.'
 s.homepage         = 'http://jhonacode.com'
 s.license          = { :file => '../LICENSE' }
 s.author           = { 'Jhonacode' => 'team@jhonacode.com' }
 s.source           = { :path => '.' }
 s.platform         = :osx, '10.13'

 #══════════════════════════════════════════
 # 📚 Library Architecture Configuration
 #══════════════════════════════════════════
 s.vendored_libraries = ARCH_LIB
 s.preserve_paths = 'Frameworks/*.dylib'

 #══════════════════════════════════════════
 # ⚙️ XCode Build Configuration
 #══════════════════════════════════════════
 s.pod_target_xcconfig = {
   'DEFINES_MODULE' => 'YES',
   'LD_RUNPATH_SEARCH_PATHS' => '@executable_path/Frameworks $(inherited)',
   'DYLIB_INSTALL_NAME_BASE' => '@rpath',
   'CODE_SIGN_ENTITLEMENTS' => '${PODS_TARGET_SRCROOT}/macos/flutter_local_db.entitlements',
   'ENABLE_HARDENED_RUNTIME' => 'YES',
   'OTHER_LDFLAGS' => '-Wl,-no_fixup_chains',
   'VALID_ARCHS' => CURRENT_ARCH,
   'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/Frameworks $(BUILT_PRODUCTS_DIR)',
   'DYLIB_COMPATIBILITY_VERSION' => '1',
   'DYLIB_CURRENT_VERSION' => '1'
 }

 #══════════════════════════════════════════
 # 🔄 Dynamic Library Setup Script
 #══════════════════════════════════════════
 s.script_phases = [{
   :name => 'Setup Library Permissions',
   :shell_path => '/bin/sh',
   :execution_position => :after_compile,
   :input_files => [
     "${PODS_TARGET_SRCROOT}/#{ARCH_LIB}"
   ],
   :output_files => [
     "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/Contents/Frameworks/#{File.basename(ARCH_LIB)}"
   ],
   :script => %Q(
#!/bin/sh
# 🔍 Setup paths
FRAMEWORKS_DIR="${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/Contents/Frameworks"
LIB_NAME="#{File.basename(ARCH_LIB)}"
DEST_PATH="${FRAMEWORKS_DIR}/${LIB_NAME}"

# Create frameworks directory if needed
mkdir -p "${FRAMEWORKS_DIR}"

# Copy and configure library
echo "Processing ${LIB_NAME}..."
cp -f "${PODS_TARGET_SRCROOT}/#{ARCH_LIB}" "${DEST_PATH}"
chmod +x "${DEST_PATH}"
install_name_tool -id "@rpath/${LIB_NAME}" "${DEST_PATH}"

# ✅ Verify configuration
echo "Checking library permissions and signature:"
ls -la "${DEST_PATH}"
codesign -dvv "${DEST_PATH}" || true
   )
 }]

 #══════════════════════════════════════════
 # 📑 Additional Resources
 #══════════════════════════════════════════
 s.resource_bundles = {
   'flutter_local_db' => ['macos/*.entitlements']
 }
end

#═══════════════════════════════════════════════════════════════════════════
# End of Flutter Local DB Podspec Configuration
#═══════════════════════════════════════════════════════════════════════════