#version 330 core

layout(location=0) in vec3 a_pos;
layout(location=1) in vec3 a_normals;
layout(location=2) in vec2 a_texCoord;

uniform mat4 u_projection;
uniform mat4 u_view;
uniform mat4 u_transform;

out vec3 v_fragPos;
out vec3 v_normals;
out vec2 v_texCoord;

void main() {
	vec4 pos = u_transform * vec4(a_pos, 1.0);

	gl_Position = u_projection * u_view * pos;

	// v_fragPos and v_normals are in world space
	v_fragPos = vec3(pos);
	v_normals = normalize(vec3(u_transform * vec4(a_normals, 0.0)));
	v_texCoord = a_texCoord;
}