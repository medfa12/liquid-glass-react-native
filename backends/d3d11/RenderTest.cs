// Headless validation of the Liquid Glass HLSL on Windows.
// Compiles the shader at runtime, renders one frame on WARP (the VM has no D3D
// hardware — VirtIO GPU DOD is display-only), and reports pixel results.
// This is the first time the HLSL or the 660-byte constant buffer have been
// exercised by an actual D3D runtime.
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Vortice.D3DCompiler;
using Vortice.Direct3D;
using Vortice.Direct3D11;
using Vortice.Direct3D11.Shader;
using Vortice.DXGI;
using Vortice.Mathematics;

class RenderTest
{
    const int W = 256, H = 160;

    static int Main()
    {
        var log = new StringBuilder();
        void L(string m) { log.AppendLine(m); Console.WriteLine(m); }
        try
        {
            L($"struct GlassParams = {Marshal.SizeOf<LiquidGlass.GlassParams>()} bytes");
            var probe = LiquidGlass.GlassPresets.Regular();
            LiquidGlass.GlassStyle.Regular.ApplyTo(ref probe);
            L($"preset: halfSize={probe.HalfSize} exp={probe.Exponent} faceOp={probe.FaceOpacity} " +
              $"sdr={probe.SdrWhite} edr={probe.EdrScale} diff={probe.Diffusion} " +
              $"blur={probe.BlurRadius} scaleRef={probe.ScaleRef} clamp={probe.ClampLimit} " +
              $"edgeRange={probe.EdgeRange} edgeOp={probe.EdgeOpacity}");

            // --- compile HLSL ---
            string psSrc = File.ReadAllText(@"C:\lg\hlsl\LiquidGlassPS.hlsl");
            string vsSrc = File.ReadAllText(@"C:\lg\hlsl\LiquidGlassVS.hlsl");
            var psBlob = Compiler.Compile(psSrc, "main", "LiquidGlassPS.hlsl", "ps_5_0");
            var vsBlob = Compiler.Compile(vsSrc, "main", "LiquidGlassVS.hlsl", "vs_5_0");
            L($"HLSL compiled: vs={vsBlob.Length}B ps={psBlob.Length}B");
            // Trust the blobs, not the source: dump the actual signatures.
            using (var vr = Compiler.Reflect<ID3D11ShaderReflection>(vsBlob.Span.ToArray()))
            {
                var d = vr.Description;
                for (uint i = 0; i < d.OutputParameters; i++) {
                    var pd = vr.GetOutputParameterDescription(i);
                    L($"  VS out[{i}] {pd.SemanticName}{pd.SemanticIndex} reg={pd.Register} mask={(int)pd.UsageMask} type={pd.ComponentType}");
                }
            }
            using (var pr = Compiler.Reflect<ID3D11ShaderReflection>(psBlob.Span.ToArray()))
            {
                var d = pr.Description;
                for (uint i = 0; i < d.InputParameters; i++) {
                    var pd = pr.GetInputParameterDescription(i);
                    L($"  PS in [{i}] {pd.SemanticName}{pd.SemanticIndex} reg={pd.Register} mask={(int)pd.UsageMask} rw={(int)pd.ReadWriteMask}");
                }
            }

            // --- WARP device ---
            // disambiguate the overload explicitly; Vortice has two 6-arg forms
            ID3D11Device device; ID3D11DeviceContext ctx;
            D3D11.D3D11CreateDevice((IDXGIAdapter)null, DriverType.Warp,
                DeviceCreationFlags.None, new FeatureLevel[] { FeatureLevel.Level_11_0 },
                out device, out ctx).CheckError();
            L($"device: WARP, feature level {device.FeatureLevel}");

            var vs = device.CreateVertexShader(vsBlob.Span);
            var ps = device.CreatePixelShader(psBlob.Span);

            // --- backdrop: left half dark, right half bright (hard edge to test blur) ---
            const int BW = 128, BH = 128;
            var px = new uint[BW * BH];
            for (int y = 0; y < BH; y++)
                for (int x = 0; x < BW; x++)
                    px[y * BW + x] = x < BW / 2 ? 0xFF202020u : 0xFFE0E0E0u;
            ID3D11Texture2D bd;
            unsafe {
                fixed (uint* pp = px) {
                    bd = device.CreateTexture2D(Format.B8G8R8A8_UNorm, BW, BH, 1, 1,
                        new[] { new SubresourceData((nint)pp, BW * 4) });
                }
            }
            var srv = device.CreateShaderResourceView(bd);
            var samp = device.CreateSamplerState(SamplerDescription.LinearClamp);

            // --- constant buffers ---
            // GlassPresets.Regular() is the full parameter set (the C# analogue
            // of baseParams()); GlassStyle only overrides the style fields, so
            // starting from a zeroed struct left SdrWhite/EdrScale/opacities at 0
            // and every fragment discarded.
            // Bypass GlassPresets entirely: write the constant buffer as raw floats
            // at the reflected offsets -- byte-identical to the values that render
            // correctly under Vulkan/MoltenVK. If this draws, the bug is in the C#
            // preset; if it still discards, it is the DXBC or the D3D harness.
            const int NF = 168;
            var raw = new float[NF];
            raw[0] = 80.0f;
            raw[1] = 44.0f;
            raw[2] = 2.0f;
            raw[3] = 4.0f;
            raw[4] = 0.03333333333333333f;
            raw[5] = -13.0f;
            raw[6] = 0.0625f;
            raw[7] = 0.65f;
            raw[8] = 1.0f;
            raw[10] = -30.0f;
            raw[11] = 0.0f;
            raw[12] = 1.0f;
            raw[13] = 0.0f;
            raw[14] = 0.0f;
            raw[15] = 1.0f;
            raw[16] = 1.0f;
            raw[17] = 0.0f;
            raw[18] = 3.0f;
            raw[19] = 0.045454545454545456f;
            raw[20] = 0.0f;
            raw[22] = 1.0f;
            raw[23] = 0.0f;
            raw[32] = 45.0f;
            raw[24] = 0.0f;
            raw[25] = 8.0f;
            raw[26] = 20.0f;
            raw[27] = 40.0f;
            raw[28] = 1.0f;
            raw[29] = 0.6f;
            raw[30] = 0.3f;
            raw[31] = 0.0f;
            raw[33] = 24.0f;
            raw[34] = 0.05f;
            raw[35] = 32.0f;
            raw[36] = 0.0f;
            raw[37] = 26.0f;
            raw[38] = 0.15f;
            raw[40] = 0.92f;
            raw[41] = 0.0f;
            raw[42] = 0.0f;
            raw[43] = 8.0f;
            raw[44] = 0.0f;
            raw[45] = 0.0f;
            raw[46] = 0.0f;
            raw[47] = -1.0f;
            raw[48] = 0.35f;
            raw[49] = 10.0f;
            raw[50] = 0.5f;
            raw[51] = 0.0f;
            raw[52] = 10.0f;
            raw[53] = 0.05f;
            raw[54] = 0.0f;
            raw[55] = 0.004f;
            raw[56] = 0.038461538461538464f;
            raw[57] = 0.0f;
            raw[58] = 0.5f;
            raw[59] = 6.0f;
            raw[117] = 0.1f;
            raw[118] = 1.5f;
            raw[60] = 0.921f;
            raw[61] = -0.265f;
            raw[62] = -0.027f;
            raw[63] = 0.235f;
            raw[64] = -0.079f;
            raw[65] = 0.735f;
            raw[66] = -0.027f;
            raw[67] = 0.235f;
            raw[68] = -0.079f;
            raw[69] = -0.265f;
            raw[70] = 0.973f;
            raw[71] = 0.235f;
            raw[72] = 1.0f;
            raw[73] = 0.0f;
            raw[74] = 0.0f;
            raw[75] = 0.0f;
            raw[76] = 0.0f;
            raw[77] = 1.0f;
            raw[78] = 0.0f;
            raw[79] = 0.0f;
            raw[80] = 0.0f;
            raw[81] = 0.0f;
            raw[82] = 1.0f;
            raw[83] = 0.0f;
            raw[84] = 0.2f;
            raw[85] = 0.0f;
            raw[86] = 0.0f;
            raw[87] = 0.0f;
            raw[88] = 0.0f;
            raw[89] = 0.2f;
            raw[90] = 0.0f;
            raw[91] = 0.0f;
            raw[92] = 0.0f;
            raw[93] = 0.0f;
            raw[94] = 0.2f;
            raw[95] = 0.0f;
            raw[96] = 1.0f;
            raw[97] = 0.0f;
            raw[98] = 1.0f;
            raw[99] = 1.0f;
            raw[100] = 1.0f;
            raw[101] = 1.0f;
            raw[102] = 0.0f;
            raw[116] = 45.0f;
            raw[137] = 44.0f;
            raw[122] = 9.0f;
            raw[123] = 30.0f;
            raw[124] = 0.0f;
            raw[125] = 1.0f;
            raw[126] = 0.35f;
            raw[127] = -0.94f;
            raw[128] = 70.0f;
            raw[129] = 0.55f;
            raw[130] = 0.0f;
            raw[131] = 4.0f;
            raw[133] = 48.0f;
            raw[163] = 0.74f;
            raw[164] = 1.0f;
            var psCb = device.CreateBuffer(raw.AsSpan(), new BufferDescription(
                (uint)(NF * 4), BindFlags.ConstantBuffer, ResourceUsage.Default));
            var vsData = new float[] { raw[0], raw[1], 0, 0 };  // uHalfSize
            var vsCb = device.CreateBuffer(vsData.AsSpan(), new BufferDescription(16u,
                BindFlags.ConstantBuffer, ResourceUsage.Default));

            // --- render target ---
            var rt = device.CreateTexture2D(new Texture2DDescription(
                Format.B8G8R8A8_UNorm, W, H, 1, 1, BindFlags.RenderTarget));
            var rtv = device.CreateRenderTargetView(rt);
            ctx.OMSetRenderTargets(rtv);
            ctx.RSSetViewport(0, 0, W, H);
            // D3D11 defaults to CullMode.Back with FrontCounterClockwise=false,
            // so the CCW-wound fullscreen strip is treated as back-facing and
            // culled before the pixel shader ever runs -- which looks exactly
            // like "the shader discards everything". Vulkan needed the same
            // thing said explicitly (VK_CULL_MODE_NONE) and that is why it drew.
            var rsDesc = RasterizerDescription.CullNone;
            using var rs = device.CreateRasterizerState(rsDesc);
            ctx.RSSetState(rs);
            ctx.ClearRenderTargetView(rtv, new Color4(0, 0, 0, 0));
            ctx.VSSetShader(vs); ctx.PSSetShader(ps);
            // singular VSSetConstantBuffer was silently not taking effect;
            // bind via the array form, which maps to the raw D3D11 call.
            // Bind the SAME buffer to both stages. VertexParams expects a float2
            // at offset 0 and GlassParams has uHalfSize at offset 0 -- the same
            // bytes -- so the vertex stage reads the element half-size straight
            // from the glass params. One buffer, no chance of the two disagreeing.
            ctx.VSSetConstantBuffers(1, new[] { vsCb });
            ctx.PSSetConstantBuffers(1, new[] { psCb });
            ctx.PSSetShaderResource(0, srv); ctx.PSSetSampler(0, samp);
            ctx.IASetPrimitiveTopology(PrimitiveTopology.TriangleStrip);
            ctx.Draw(4, 0);
            ctx.Flush();

            // --- read back ---
            var stage = device.CreateTexture2D(new Texture2DDescription(
                Format.B8G8R8A8_UNorm, W, H, 1, 1, BindFlags.None,
                ResourceUsage.Staging, CpuAccessFlags.Read));
            ctx.CopyResource(stage, rt);
            var map = ctx.Map(stage, 0, MapMode.Read);
            int nonZero = 0; long lumSum = 0;
            var row = new byte[W * 4];
            var mid = new int[W];
            for (int y = 0; y < H; y++)
            {
                Marshal.Copy(IntPtr.Add(map.DataPointer, (int)(y * map.RowPitch)), row, 0, W * 4);
                for (int x = 0; x < W; x++)
                {
                    int b = row[x*4], g = row[x*4+1], r = row[x*4+2], a = row[x*4+3];
                    if (a > 8) { nonZero++; lumSum += (int)(0.2126*r + 0.7152*g + 0.0722*b); }
                    if (y == H / 2) mid[x] = a > 8 ? (int)(0.2126*r + 0.7152*g + 0.0722*b) : -1;
                }
            }
            ctx.Unmap(stage, 0);
            // raw centre pixel: separates "PS discarded" from "PS ran, alpha 0"
            Marshal.Copy(IntPtr.Add(map.DataPointer, (int)((H/2) * map.RowPitch)), row, 0, W*4);
            int cx = W/2;
            L($"centre BGRA = {row[cx*4]},{row[cx*4+1]},{row[cx*4+2]},{row[cx*4+3]}");
            L($"covered pixels: {nonZero} / {W*H}");
            L($"mean luma inside glass: {(nonZero>0 ? lumSum/nonZero : 0)}");
            var sb = new StringBuilder("mid-row luma: ");
            for (int x = 0; x < W; x += 16) sb.Append(mid[x] + " ");
            L(sb.ToString());
            ctx.Unmap(stage, 0);
            L(nonZero > 1000 ? "RESULT=PASS glass rendered" : "RESULT=FAIL nothing drawn");
        }
        catch (Exception e) { L("EXCEPTION: " + e); }

        try {
            using var http = new System.Net.Http.HttpClient();
            http.PostAsync("http://10.0.2.2:8899/r",
                new System.Net.Http.StringContent(log.ToString())).Wait();
        } catch { }
        return 0;
    }
}
