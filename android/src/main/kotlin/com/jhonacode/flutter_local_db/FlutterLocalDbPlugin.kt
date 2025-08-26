package com.jhonacode.flutter_local_db

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin

/** FlutterLocalDbPlugin */
class FlutterLocalDbPlugin: FlutterPlugin {
  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    // This plugin is FFI-based, so we don't need to register method channels
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    // Nothing to clean up for FFI
  }
}