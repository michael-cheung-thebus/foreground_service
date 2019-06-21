package org.thebus.foreground_service_example

import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugins.GeneratedPluginRegistrant
import org.thebus.foreground_service.ForegroundServicePlugin

class OverrideApplication: FlutterApplication(), PluginRegistry.PluginRegistrantCallback{
    override fun onCreate() {
        super.onCreate()
        ForegroundServicePlugin.setPluginRegistrantCallback(this)
    }

    override fun registerWith(p0: PluginRegistry?) {
        GeneratedPluginRegistrant.registerWith(p0)
    }
}