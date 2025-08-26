#include "include/flutter_local_db/flutter_local_db_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#define FLUTTER_LOCAL_DB_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_local_db_plugin_get_type(), \
                               FlutterLocalDbPlugin))

struct _FlutterLocalDbPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FlutterLocalDbPlugin, flutter_local_db_plugin, g_object_get_type())

static void flutter_local_db_plugin_class_init(FlutterLocalDbPluginClass* klass) {
}

static void flutter_local_db_plugin_init(FlutterLocalDbPlugin* self) {
}

void flutter_local_db_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  // This plugin is FFI-based, so we don't need to register method channels
}