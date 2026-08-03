package com.liquidglass

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import java.net.URL

class LiquidGlassViewManager : SimpleViewManager<LiquidGlassView>() {
  override fun getName() = "LiquidGlassView"

  override fun createViewInstance(ctx: ThemedReactContext) = LiquidGlassView(ctx)

  @ReactProp(name = "uniforms")
  fun setUniforms(view: LiquidGlassView, values: ReadableArray?) {
    if (values == null) return
    val out = FloatArray(values.size())
    for (i in 0 until values.size()) out[i] = values.getDouble(i).toFloat()
    view.setUniforms(out)
  }

  @ReactProp(name = "liveBackdrop", defaultBoolean = false)
  fun setLiveBackdrop(view: LiquidGlassView, live: Boolean) = view.setLive(live)

  @ReactProp(name = "backdrop")
  fun setBackdrop(view: LiquidGlassView, source: ReadableMap?) {
    val uri = source?.getString("uri") ?: return
    Thread {
      try {
        val stream = if (uri.startsWith("http")) URL(uri).openStream()
                     else view.context.contentResolver.openInputStream(android.net.Uri.parse(uri))
        stream?.use { view.post { view.loadBackdropFromStream(it) } }
      } catch (e: Exception) {
        android.util.Log.w("LiquidGlass", "backdrop load failed: ${e.message}")
      }
    }.start()
  }
}
