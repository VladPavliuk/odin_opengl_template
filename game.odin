package main

import "core:math"
import glm "core:math/linalg/glsl"
import "core:math/linalg"

GameObj :: struct {
    pos, scale: float3,
    rot: quaternion128,
    // rot: struct {
    //     vec: float3,
    //     angle: f32,
    // },
    mesh: struct {
        type: MeshType,
        nodeTransforms: []mat4, // node transformation matrices, should be calculated once before rendering
    },
    animation: struct {
        running: bool,
        index: i32, // animation index from mesh animations, 
        duration: f32,
        nodeTransforms: map[i32]struct{ // apply to each node instead of static node mat
            translation: Maybe(float3),
            scale: Maybe(float3),
            rotation: Maybe(quaternion128),
        },
    },
}

initObjs :: proc() {
    scale: f32 = 0.15
    obj: GameObj = { 
        pos = { 0, 1, 0.2 },
        scale = { scale, scale, scale },
        rot = quaternion(real = 0, imag = 0, jmag = 0, kmag = 1), // default, no rotation
        mesh = { type = .TEST_MESH, nodeTransforms = make([]mat4, len(ctx.meshes[.TEST_MESH].nodes)) },
    }
    obj.rot = glm.quatAxisAngle({ 0, 0, 1 }, 1.9)
    //obj.mesh.nodeTransforms = make([]mat4, len(mesh.nodes))
    
    startAnimation(&obj, 0)

    append(&ctx.objs, obj)
}

updateObjs :: proc() {
    for &obj in ctx.objs {
        playAnimationIfAny(&obj)
        //obj.pos.x = t

        // example rotation
        // angle, axis := linalg.angle_axis_from_quaternion(obj.rot)
        
        // obj.rot = obj.rot * linalg.quaternion_angle_axis(0.05, float3{ 1, 0, 0 })
    }
}

deleteObjs :: proc() {
    for obj in ctx.objs {
        delete(obj.mesh.nodeTransforms)
        delete(obj.animation.nodeTransforms)
    }
    delete(ctx.objs)
}