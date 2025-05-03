#version 430

layout(local_size_x = 256) in;

struct Body {
    vec2 posMass;
};

layout(std430, binding = 0) buffer BodyBuffer {
    Body bodies[];
};

//uniform uint numBodies;

void main() {
    uint i = gl_GlobalInvocationID.x;
    if (i >= bodies.length()) return;

    vec2 pos_i = bodies[i].posMass;

    pos_i = vec2(pos_i.x + 10, pos_i.y + 10);

    bodies[i].posMass = pos_i;
}