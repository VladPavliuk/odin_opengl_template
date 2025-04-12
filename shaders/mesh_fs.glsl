#version 330 core

out vec4 o_color;

in vec3 v_fragPos;
in vec3 v_normals;

void main() {
	vec4 materialColor = vec4(0.9, 0.1, 0.6, 1.0);
	vec3 cameraPos = vec3(0.0, 0.0, 0.0);

	vec3 lightPos = vec3(5.0, 0.0, 0.0);

	//vec3 lightDir = normalize(lightPos - v_fragPos);
	vec3 lightDir = vec3(-1.0, 0.0, 0.0);
	vec3 lightColor = vec3(1.0, 1.0, 1.0);

	//lightDir = normalize(-lightDir);

	float diff = max(dot(v_normals, lightDir), 0.0);

	vec3 diffuse = diff * lightColor;

	o_color = materialColor + vec4(diffuse, 1.0);
}