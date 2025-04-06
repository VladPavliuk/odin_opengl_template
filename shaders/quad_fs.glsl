#version 330 core

in vec4 v_color;
in vec2 v_texCoord;

out vec4 o_color;

uniform sampler2D ourTexture;

void main() {
	//o_color = v_color;
	o_color = texture(ourTexture, v_texCoord);
}