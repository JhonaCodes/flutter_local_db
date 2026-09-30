import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

/// Bundles the prebuilt offline_first_core library (Rust + LMDB 1.0) for the
/// platform and architecture being built. The Dart bindings
/// (`lib/src/native/bindings.dart`) resolve against this code asset.
void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }
    final file = input.packageRoot.resolve(
      NativeLibraries.path(input.config.code),
    );
    if (!File.fromUri(file).existsSync()) {
      throw UnsupportedError(
        'flutter_local_db has no native library for '
        '${input.config.code.targetOS.name} '
        '${input.config.code.targetArchitecture.name} (${file.path})',
      );
    }
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: NativeLibraries.assetName,
        linkMode: DynamicLoadingBundled(),
        file: file,
      ),
    );
    output.dependencies.add(file);
  });
}

/// Where the prebuilt libraries live in this package.
///
/// `native/<os>/<architecture>/<file>`, with the SDK before the architecture
/// on iOS (`iphoneos-arm64`, `iphonesimulator-x64`). `tool/update_native.sh`
/// fills the directory from an offline_first_core release.
abstract final class NativeLibraries {
  /// The asset id the bindings use, relative to the package.
  static const String assetName = 'src/native/bindings.dart';

  /// Path of the library for [code], relative to the package root.
  static String path(CodeConfig code) {
    final os = code.targetOS;
    final architecture = code.targetArchitecture.name;
    final directory = os == OS.iOS
        ? '${code.iOS.targetSdk.type}-$architecture'
        : architecture;
    return 'native/${os.name}/$directory/${os.dylibFileName('offline_first_core')}';
  }
}
