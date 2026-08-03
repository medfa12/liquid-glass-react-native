package com.liquidglass

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLES30
import android.opengl.GLSurfaceView
import android.opengl.GLUtils
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Liquid Glass — Android native view.
 *
 * Runs the ES 300 shader (res_liquid_glass.frag), which is generated from the
 * same canonical GLSL as every other target. Uses no platform blur API, so it
 * behaves identically across Android versions and OEM skins.
 *
 * Requires GLES 3.0 for textureLod() — the blur IS mip selection, and GLES 2
 * cannot express it.
 */
class LiquidGlassView(context: Context) : GLSurfaceView(context) {

  private val renderer: GlassRenderer

  init {
    setEGLContextClientVersion(3)
    setEGLConfigChooser(8, 8, 8, 8, 0, 0)
    holder.setFormat(android.graphics.PixelFormat.TRANSLUCENT)
    setZOrderOnTop(true)
    renderer = GlassRenderer()
    setRenderer(renderer)
    renderMode = RENDERMODE_WHEN_DIRTY
  }

  fun setUniforms(values: FloatArray) {
    renderer.uniforms = values
    requestRender()
  }

  fun setBackdropBitmap(bmp: Bitmap?) {
    renderer.pendingBitmap = bmp
    requestRender()
  }

  fun setLive(live: Boolean) {
    renderMode = if (live) RENDERMODE_CONTINUOUSLY else RENDERMODE_WHEN_DIRTY
  }

  fun loadBackdropFromStream(stream: InputStream) {
    setBackdropBitmap(BitmapFactory.decodeStream(stream))
  }

  private inner class GlassRenderer : Renderer {
    var uniforms: FloatArray = FloatArray(0)
    var pendingBitmap: Bitmap? = null

    private var program = 0
    private var vao = 0
    private var ubo = 0
    private var tex = 0
    private var viewW = 1
    private var viewH = 1
    private var uboBuf: FloatBuffer? = null

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
      program = buildProgram(VERT_SRC, readAsset("res_liquid_glass.frag"))

      val ids = IntArray(1)
      GLES30.glGenVertexArrays(1, ids, 0); vao = ids[0]
      GLES30.glBindVertexArray(vao)
      val vbo = IntArray(1)
      GLES30.glGenBuffers(1, vbo, 0)
      GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vbo[0])
      val verts = floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)
      val bb = ByteBuffer.allocateDirect(verts.size * 4).order(ByteOrder.nativeOrder())
      bb.asFloatBuffer().put(verts).position(0)
      GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, verts.size * 4, bb, GLES30.GL_STATIC_DRAW)
      GLES30.glEnableVertexAttribArray(0)
      GLES30.glVertexAttribPointer(0, 2, GLES30.GL_FLOAT, false, 0, 0)
      GLES30.glBindVertexArray(0)

      val ub = IntArray(1)
      GLES30.glGenBuffers(1, ub, 0); ubo = ub[0]

      val t = IntArray(1)
      GLES30.glGenTextures(1, t, 0); tex = t[0]
      GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, tex)
      // LINEAR_MIPMAP_LINEAR is required — see the class doc.
      GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER,
        GLES30.GL_LINEAR_MIPMAP_LINEAR)
      GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER,
        GLES30.GL_LINEAR)
      GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S,
        GLES30.GL_CLAMP_TO_EDGE)
      GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T,
        GLES30.GL_CLAMP_TO_EDGE)
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
      viewW = width; viewH = height
      GLES30.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
      pendingBitmap?.let { bmp ->
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, tex)
        GLUtils.texImage2D(GLES30.GL_TEXTURE_2D, 0, bmp, 0)
        GLES30.glGenerateMipmap(GLES30.GL_TEXTURE_2D)
        pendingBitmap = null
      }
      if (uniforms.isEmpty()) return

      if (uboBuf == null || uboBuf!!.capacity() < uniforms.size) {
        uboBuf = ByteBuffer.allocateDirect(uniforms.size * 4)
          .order(ByteOrder.nativeOrder()).asFloatBuffer()
      }
      uboBuf!!.position(0); uboBuf!!.put(uniforms); uboBuf!!.position(0)
      GLES30.glBindBuffer(GLES30.GL_UNIFORM_BUFFER, ubo)
      GLES30.glBufferData(GLES30.GL_UNIFORM_BUFFER, uniforms.size * 4, uboBuf,
        GLES30.GL_DYNAMIC_DRAW)
      GLES30.glBindBufferBase(GLES30.GL_UNIFORM_BUFFER, 0, ubo)

      GLES30.glClearColor(0f, 0f, 0f, 0f)
      GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)
      GLES30.glEnable(GLES30.GL_BLEND)
      GLES30.glBlendFuncSeparate(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE_MINUS_SRC_ALPHA,
        GLES30.GL_ONE, GLES30.GL_ONE_MINUS_SRC_ALPHA)

      GLES30.glUseProgram(program)
      val blockIdx = GLES30.glGetUniformBlockIndex(program, "GlassParams")
      if (blockIdx != GLES30.GL_INVALID_INDEX) {
        GLES30.glUniformBlockBinding(program, blockIdx, 0)
      }
      GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
      GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, tex)
      GLES30.glUniform1i(GLES30.glGetUniformLocation(program, "uBackdrop"), 0)
      GLES30.glUniform2f(GLES30.glGetUniformLocation(program, "uElementHalfSizePx"),
        viewW * 0.5f, viewH * 0.5f)

      GLES30.glBindVertexArray(vao)
      GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4)
      GLES30.glBindVertexArray(0)
    }
  }

  private fun readAsset(name: String): String =
    context.assets.open(name).bufferedReader().use { it.readText() }

  private fun buildProgram(vs: String, fs: String): Int {
    fun compile(type: Int, src: String): Int {
      val id = GLES30.glCreateShader(type)
      GLES30.glShaderSource(id, src)
      GLES30.glCompileShader(id)
      val ok = IntArray(1)
      GLES30.glGetShaderiv(id, GLES30.GL_COMPILE_STATUS, ok, 0)
      if (ok[0] == 0) {
        val log = GLES30.glGetShaderInfoLog(id)
        GLES30.glDeleteShader(id)
        throw RuntimeException("LiquidGlass shader compile failed:\n$log")
      }
      return id
    }
    val v = compile(GLES30.GL_VERTEX_SHADER, vs)
    val f = compile(GLES30.GL_FRAGMENT_SHADER, fs)
    val p = GLES30.glCreateProgram()
    GLES30.glAttachShader(p, v); GLES30.glAttachShader(p, f)
    GLES30.glLinkProgram(p)
    GLES30.glDeleteShader(v); GLES30.glDeleteShader(f)
    val ok = IntArray(1)
    GLES30.glGetProgramiv(p, GLES30.GL_LINK_STATUS, ok, 0)
    if (ok[0] == 0) throw RuntimeException("LiquidGlass link failed:\n" +
      GLES30.glGetProgramInfoLog(p))
    return p
  }

  companion object {
    private const val VERT_SRC = """#version 300 es
precision highp float;
layout(location = 0) in vec2 aPos;
out vec2 vUV;
out vec2 vBackdropUV;
uniform vec2 uElementHalfSizePx;
void main() {
  vUV = aPos * uElementHalfSizePx;
  vBackdropUV = aPos * 0.5 + 0.5;
  gl_Position = vec4(aPos, 0.0, 1.0);
}
"""
  }
}
