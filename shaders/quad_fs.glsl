#version 330 core

in vec4 v_color;
in vec2 v_texCoord;

out vec4 o_color;

uniform vec4 u_color;
uniform bool u_hasTexture;

uniform sampler2D ourTexture;

void main() {
	if (!u_hasTexture) {
		o_color = u_color;
		return;
	}

	vec4 texColor = texture(ourTexture, v_texCoord);

	if (texColor.a < 0.01)
        discard;

	o_color = texColor;
}