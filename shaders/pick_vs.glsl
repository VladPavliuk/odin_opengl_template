#version 330 core

layout(location=0) in vec3 a_pos;
layout(location=1) in vec3 a_normals;
layout(location=2) in vec2 a_texCoord;

uniform mat4 u_transform;

void main() {
	vec4 pos = u_transform * vec4(a_pos, 1.0);

	gl_Position = pos;
}