#version 330 core

out vec4 o_color;

in vec3 v_fragPos;
in vec3 v_normals;
in vec2 v_texCoord;

uniform sampler2D meshTexture;
uniform bool u_hasTexture;

uniform vec4 u_color;
uniform vec3 u_cameraPos;

void main() {
	vec4 materialColor;

	if (u_hasTexture) {
		materialColor = texture(meshTexture, v_texCoord);
	} else {
		materialColor = u_color;
	}

	vec3 cameraPos = u_cameraPos;

	vec3 lightPos = vec3(5.0, 100.0, 100.0);

	//vec3 lightDir = normalize(lightPos - v_fragPos); // for moving light
	vec3 lightDir = vec3(-1.0, 0.0, 0.0);
	vec3 lightColor = vec3(0.0, 1.0, 0.0);

	//lightDir = normalize(-lightDir);

	// ambient
	vec3 ambient = 0.5 * vec3(materialColor) * lightColor;

	float diff = max(dot(v_normals, lightDir), 0.0);

	vec3 diffuse = diff * lightColor;

	o_color = materialColor * vec4(ambient + diffuse, 1.0);
	//o_color = materialColor;
	//o_color = vec4(0.5, 0.5, 0.5, 1) * vec4(ambient + diffuse, 1.0);
	//o_color = vec4(0,0,0,1);
}