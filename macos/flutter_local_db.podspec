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
 s.vendored_libraries = [
   "Frameworks/liboffline_first_core_arm64.dylib",
   "Frameworks/liboffline_first_core_x86_64.dylib"
 ]
 s.preserve_paths = 'Frameworks/**/*.dylib'

 #══════════════════════════════════════════
 # ⚙️ XCode Build Configuration
 #══════════════════════════════════════════
 s.pod_target_xcconfig = {
   'DEFINES_MODULE' => 'YES',
   'LD_RUNPATH_SEARCH_PATHS' => '@executable_path/../Frameworks @loader_path/Frameworks',
   'DYLIB_INSTALL_NAME_BASE' => '@rpath',
   'CODE_SIGN_ENTITLEMENTS' => '${PODS_TARGET_SRCROOT}/macos/flutter_local_db.entitlements',
   'ENABLE_HARDENED_RUNTIME' => 'YES',
   'OTHER_LDFLAGS' => '-Wl,-no_fixup_chains'
 }

 #══════════════════════════════════════════
 # 🔄 Dynamic Library Setup Script
 #══════════════════════════════════════════
 s.script_phases = [
   {
     :name => 'Setup Library Permissions',
     :shell_path => '/bin/sh',
     :script => <<-SCRIPT
       #!/bin/sh
       # 🔍 Detect current architecture
       ARCH=$(uname -m)
       if [ "$ARCH" = "arm64" ]; then
         LIB_NAME="liboffline_first_core_arm64.dylib"
       else
         LIB_NAME="liboffline_first_core_x86_64.dylib"
       fi

       FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}/Contents/Frameworks"
       DEST_PATH="${FRAMEWORKS_DIR}/${LIB_NAME}"

       # 📁 Create directory if needed
       mkdir -p "${FRAMEWORKS_DIR}"

       # 📋 Copy library from source
       cp -f "${PODS_TARGET_SRCROOT}/Frameworks/${LIB_NAME}" "${DEST_PATH}"

       # 🔒 Set execution permissions
       chmod +x "${DEST_PATH}"

       # 🔧 Configure @rpath
       install_name_tool -id "@rpath/${LIB_NAME}" "${DEST_PATH}"

       # ✅ Verify configuration
       echo "Checking library permissions and signature:"
       ls -la "${DEST_PATH}"
       codesign -dvv "${DEST_PATH}" || true
     SCRIPT
   }
 ]

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