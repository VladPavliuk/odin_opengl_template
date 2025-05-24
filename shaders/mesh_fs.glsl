#version 430

out vec4 o_color;

in vec3 v_fragPos;
in vec3 v_normals;
in vec2 v_texCoord;

uniform sampler2D meshTexture;
uniform bool u_hasTexture;
uniform bool u_hasMouseHover;
uniform int u_lightsCount;

struct Light {
    vec3 pos;
	float padding;
};

layout(std430, binding = 0) buffer LightBuffer {
    Light lights[];
};

uniform vec4 u_color;
uniform vec3 u_cameraPos;

void main() {
	vec4 materialColor;
	vec4 finalColor = vec4(0, 0, 0, 1);

	if (u_hasTexture) {
		materialColor = texture(meshTexture, v_texCoord);
	} else {
		materialColor = u_color;
	}

	if (u_hasMouseHover) {
		materialColor *= 1.08; // add some highligh if mouse is on some object
	}

	vec3 cameraPos = u_cameraPos;

	for (int i = 0; i < u_lightsCount; i++) {
		vec3 lightPos = lights[i].pos;
	
		//vec3 lightPos = vec3(5.0, 100.0, 100.0);

		//vec3 lightDir = normalize(lightPos - v_fragPos); // for moving light
		vec3 lightDir = vec3(-1.0, 0.0, 0.0);
		vec3 lightColor = vec3(1.0, 1.0, 1.0);

		//lightDir = normalize(-lightDir);

		// ambient
		vec3 ambient = 0.5 * vec3(materialColor) * lightColor;

		// diffuse
		float diff = max(dot(v_normals, lightDir), 0.0);
		vec3 diffuse = diff * lightColor;

		// specular
		vec3 viewDir = normalize(cameraPos - v_fragPos);
		vec3 reflectDir = reflect(-lightDir, v_normals);
		vec3 specular = 0.5 * lightColor * pow(max(dot(viewDir, reflectDir), 0.0), 32);

		finalColor = vec4(ambient + diffuse + specular, 1.0);
		//finalColor = vec4(1, 0, 1, 1);
	}

	o_color = materialColor * finalColor;
	//o_color = materialColor;
	//o_color = vec4(0.5, 0.5, 0.5, 1) * vec4(ambient + diffuse, 1.0);
	//o_color = vec4(0,0,0,1);
}