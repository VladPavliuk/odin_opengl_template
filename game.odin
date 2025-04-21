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
    meshType: MeshType,
}

initObjs :: proc() {
    scale: f32 = 1
    obj: GameObj = { 
        pos = { 0, 20, -10 },
        scale = { scale, scale, scale },
        rot = quaternion(real = 0, imag = 0, jmag = 0, kmag = 1), // default, no rotation
    }
    //obj.rot = glm.quatAxisAngle({ 1, 0, 0 }, 0.9)
    
    append(&ctx.objs, obj)
}

updateObjs :: proc() {
    for &obj in ctx.objs {
        //obj.pos.x = t

        // example rotation
        // angle, axis := linalg.angle_axis_from_quaternion(obj.rot)
        
        // obj.rot = obj.rot * linalg.quaternion_angle_axis(0.05, float3{ 1, 0, 0 })
    }
}

deleteObjs :: proc() {
    delete(ctx.objs)
}