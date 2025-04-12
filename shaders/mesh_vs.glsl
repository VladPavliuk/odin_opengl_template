#version 330 core

layout(location=0) in vec3 a_pos;
layout(location=1) in vec3 a_normals;

uniform mat4 u_transform;

out vec3 v_fragPos;
out vec3 v_normals;

void main() {
	vec4 pos = u_transform * vec4(a_pos, 1.0);

	gl_Position = pos;

	v_fragPos = vec3(pos);
	v_normals = normalize(vec3(u_transform * vec4(a_normals, 0.0)));
}