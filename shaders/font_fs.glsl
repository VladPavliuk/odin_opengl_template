#version 330 core

in vec2 v_texCoord;
out vec4 o_fragColor;

uniform sampler2D u_fontTex;
uniform vec3 u_textColor;

void main() {
    float alpha = texture(u_fontTex, v_texCoord).r;
    o_fragColor = vec4(u_textColor, alpha);
}