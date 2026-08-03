
import Foundation
import MetalKit
import UIKit

@objc(LiquidGlassView)
public final class LiquidGlassView: UIView {

  private var device: MTLDevice!
  private var queue: MTLCommandQueue!
  private var pipeline: MTLRenderPipelineState!
  private var sampler: MTLSamplerState!
  private var mtkView: MTKView!
  private var backdropTexture: MTLTexture?
  private var uniformBuffer: MTLBuffer?
  private var uniformFloats: [Float] = []

  @objc public var uniforms: NSArray = [] {
    didSet { updateUniforms() }
  }

  @objc public var liveBackdrop: Bool = false {
    didSet { mtkView?.enableSetNeedsDisplay = !liveBackdrop
             mtkView?.isPaused = !liveBackdrop }
  }

  @objc public var backdrop: NSDictionary? {
    didSet { loadBackdrop() }
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    guard let dev = MTLCreateSystemDefaultDevice() else {
      NSLog("[LiquidGlass] Metal unavailable; view will stay transparent.")
      return
    }
    device = dev
    queue = dev.makeCommandQueue()

    mtkView = MTKView(frame: bounds, device: dev)
    mtkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    mtkView.framebufferOnly = false
    mtkView.colorPixelFormat = .bgra8Unorm
    mtkView.isOpaque = false
    mtkView.layer.isOpaque = false
    mtkView.backgroundColor = .clear
    mtkView.enableSetNeedsDisplay = true
    mtkView.isPaused = true
    mtkView.delegate = self
    addSubview(mtkView)

    buildPipeline()

    let sd = MTLSamplerDescriptor()
    sd.minFilter = .linear
    sd.magFilter = .linear
    // Mandatory: the blur IS mip selection. Without mipmapped sampling every
    sd.mipFilter = .linear
    sd.sAddressMode = .clampToEdge
    sd.tAddressMode = .clampToEdge
    sampler = dev.makeSamplerState(descriptor: sd)
  }

  private func buildPipeline() {
    guard let lib = try? device.makeDefaultLibrary(bundle: Bundle(for: Self.self)) else {
      NSLog("[LiquidGlass] could not load default.metallib — is LiquidGlass.metal in the target?")
      return
    }
    let desc = MTLRenderPipelineDescriptor()
    desc.vertexFunction = lib.makeFunction(name: "lg_vertex")
    desc.fragmentFunction = lib.makeFunction(name: "main0")
    desc.colorAttachments[0].pixelFormat = .bgra8Unorm
    desc.colorAttachments[0].isBlendingEnabled = true
    desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    desc.colorAttachments[0].sourceAlphaBlendFactor = .one
    desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    pipeline = try? device.makeRenderPipelineState(descriptor: desc)
    if pipeline == nil { NSLog("[LiquidGlass] pipeline creation failed") }
  }

  private func updateUniforms() {
    uniformFloats = (uniforms as? [NSNumber])?.map { $0.floatValue } ?? []
    guard !uniformFloats.isEmpty, let dev = device else { return }
    let bytes = uniformFloats.count * MemoryLayout<Float>.size
    if uniformBuffer == nil || uniformBuffer!.length < bytes {
      uniformBuffer = dev.makeBuffer(length: bytes, options: .storageModeShared)
    }
    uniformBuffer?.contents().copyMemory(
      from: uniformFloats, byteCount: bytes)
    mtkView?.setNeedsDisplay()
  }

  private func loadBackdrop() {
    guard let dict = backdrop, let uriString = dict["uri"] as? String,
          let dev = device else { return }

    let finish: (UIImage) -> Void = { [weak self] image in
      guard let self, let cg = image.cgImage else { return }
      let loader = MTKTextureLoader(device: dev)
      // allocateMipmaps + generateMipmaps: without these the blur is a no-op.
      let opts: [MTKTextureLoader.Option: Any] = [
        .allocateMipmaps: true,
        .generateMipmaps: true,
        .SRGB: false,
      ]
      self.backdropTexture = try? loader.newTexture(cgImage: cg, options: opts)
      DispatchQueue.main.async { self.mtkView?.setNeedsDisplay() }
    }

    if uriString.hasPrefix("http") , let url = URL(string: uriString) {
      URLSession.shared.dataTask(with: url) { data, _, _ in
        if let d = data, let img = UIImage(data: d) { finish(img) }
      }.resume()
    } else if let img = UIImage(named: uriString) ?? UIImage(contentsOfFile: uriString) {
      finish(img)
    }
  }
}

extension LiquidGlassView: MTKViewDelegate {
  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  public func draw(in view: MTKView) {
    guard let pipeline, let drawable = view.currentDrawable,
          let rpd = view.currentRenderPassDescriptor,
          let ub = uniformBuffer, let tex = backdropTexture,
          let cmd = queue.makeCommandBuffer(),
          let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }

    rpd.colorAttachments[0].loadAction = .clear
    rpd.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)

    enc.setRenderPipelineState(pipeline)
    enc.setFragmentTexture(tex, index: 0)
    enc.setFragmentSamplerState(sampler, index: 0)
    enc.setFragmentBuffer(ub, offset: 0, index: 0)
    var halfSize = SIMD2<Float>(Float(view.drawableSize.width) * 0.5,
                                Float(view.drawableSize.height) * 0.5)
    enc.setVertexBytes(&halfSize, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
    enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    enc.endEncoding()
    cmd.present(drawable)
    cmd.commit()
  }
}
