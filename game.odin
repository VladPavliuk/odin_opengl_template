package main

import "core:math"
import glm "core:math/linalg/glsl"
import "core:math/linalg"

GameObj :: struct {
    id: i32,
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
    emitsLight: bool,

    canInteract: bool,
    readyToInteract: bool,
}

initObjs :: proc() {
    scale: f32 = 0.15
    obj: GameObj = {
        id = genNextObjId(),
        pos = { 0, 1, 0.2 },
        scale = { scale, scale, scale },
        rot = quaternion(real = 0, imag = 0, jmag = 0, kmag = 1), // default, no rotation
        mesh = { type = .TEST_MESH, nodeTransforms = make([]mat4, len(ctx.meshes[.TEST_MESH].nodes)) },
        canInteract = true,
    }
    obj.rot = glm.quatAxisAngle({ 0, 0, 1 }, 1.9)
    //obj.mesh.nodeTransforms = make([]mat4, len(mesh.nodes))
    
    //startAnimation(&obj, 0)

    append(&ctx.objs, obj)

    obj2 := createEmptyObj()
    
    obj2.emitsLight = true
    obj2.pos.y = 5
}

createEmptyObj :: proc() -> ^GameObj {
    obj: GameObj = {
        id = genNextObjId(),
        pos = 0, scale = 1, rot = quaternion(real = 0, imag = 0, jmag = 0, kmag = 1),
        mesh = { type = .CUBE, nodeTransforms = make([]mat4, len(ctx.meshes[.CUBE].nodes)) },
    }
    append(&ctx.objs, obj)

    return &ctx.objs[len(ctx.objs) - 1]
}

genNextObjId :: proc() -> i32 {
    ctx.objIdCounter += 1
    return ctx.objIdCounter
}

updateObjs :: proc() {
    //ctx.hoveredObj = 0

    for &obj in ctx.objs {
        assert(obj.id != 0, "Object can't have zero ID!!!")

        { // animation
            obj.readyToInteract = false

            if obj.canInteract && obj.id == ctx.hoveredObj {
                if ctx.distanceToHoveredObj < 1 {
                    if ctx.pressedKeys[.E] {
                        obj.readyToInteract = false
                        startAnimation(&obj, 0)
                    } else if !obj.animation.running {
                        obj.readyToInteract = true
                        ctx.showUseLabel = true
                    }
                }
            }

            playAnimationIfAny(&obj)
        }
        
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