#version 450
layout(location = 0) out vec2 vUV;
layout(location = 1) out vec2 vBackdropUV;
layout(constant_id = 0) const float HX = 80.0;
layout(constant_id = 1) const float HY = 44.0;
void main() {
    vec2 p = vec2((gl_VertexIndex & 1) == 1 ? 1.0 : -1.0,
                  (gl_VertexIndex >> 1) == 1 ? 1.0 : -1.0);
    gl_Position  = vec4(p, 0.0, 1.0);
    vUV          = p * vec2(HX, HY);
    vBackdropUV  = p * 0.5 + 0.5;
}
