#═══════════════════════════════════════════════════════════════════════════
#  ╔═╗╦  ╦ ╦╔╦╗╔╦╗╔═╗╦═╗  ╦  ╔═╗╔═╗╔═╗╦    ╔╦╗╔╗
#  ╠╣ ║  ║ ║ ║  ║ ║╣ ╠╦╝  ║  ║ ║║  ╠═╣║     ║║╠╩╗
#  ╚  ╩═╝╚═╝ ╩  ╩ ╚═╝╩╚═  ╩═╝╚═╝╚═╝╩ ╩╩═╝  ═╩╝╚═╝
#     with Rust Backend & iOS Support
#═══════════════════════════════════════════════════════════════════════════
# 🚀 Version: 0.0.1
# 🔧 Platform: iOS 11.0+
# 📦 Architectures: ARM64
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

  #══════════════════════════════════════════
  # 📱 iOS Platform Configuration
  #══════════════════════════════════════════
  s.platform = :ios, '11.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'ENABLE_BITCODE' => 'NO',
    'VALID_ARCHS' => 'arm64'
  }

  #══════════════════════════════════════════
  # 📚 Library Configuration
  #══════════════════════════════════════════
  s.vendored_libraries = 'Frameworks/liboffline_first_core.a'
  s.static_framework = true

  #══════════════════════════════════════════
  # ⚙️ Build Settings
  #══════════════════════════════════════════
  s.framework = 'UIKit'
  s.library = 'c++'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'OTHER_LDFLAGS' => '-force_load $(PODS_ROOT)/Frameworks/liboffline_first_core.a',
    'ENABLE_BITCODE' => 'NO',
    'STRIP_STYLE' => 'non-global',
    'STRIP_SWIFT_SYMBOLS' => 'YES',
    'VALID_ARCHS' => 'arm64',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  #══════════════════════════════════════════
  # 🔐 Required Capabilities & Permissions
  #══════════════════════════════════════════
  s.resource_bundles = {
    'flutter_local_db' => ['ios/Info.plist']
  }
end

#═══════════════════════════════════════════════════════════════════════════