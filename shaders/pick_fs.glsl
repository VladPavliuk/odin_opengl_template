#version 330 core

uniform int u_obj_id;

out int o_id;

void main() {
    o_id = u_obj_id;
}
