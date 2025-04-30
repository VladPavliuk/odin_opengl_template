package main

import glm "core:math/linalg/glsl"
import "core:mem"

// Animation :: struct {

// }

startAnimation :: proc(obj: ^GameObj, animationIndex: i32) {
    obj.animation.running = true
    obj.animation.index = animationIndex
    obj.animation.duration = 0
}

playAnimationIfAny :: proc(obj: ^GameObj) {
    if !obj.animation.running { return }

    obj.animation.duration += f32(ctx.timeDelta)

    mesh := ctx.meshes[obj.mesh.type]

    assert(obj.animation.index >= 0 && int(obj.animation.index) < len(mesh.animations))

    animation := mesh.animations[obj.animation.index]

    if obj.animation.duration > animation.duration {
        //obj.animation.running = false

        obj.animation.duration = 0 // todo: temporary repeat

        clear(&obj.animation.nodesTransf)
        return
    }

    NodeValue :: struct {
        nodeIndex: i32,
        transfType: MeshAnimationTransfType,
        value: union { float3, float4 },
    }

    nodesValues := make([dynamic]NodeValue)
    defer delete(nodesValues)

    for channel in animation.channels {
        nodeValue := NodeValue{ nodeIndex = channel.nodeIndex }

        for timestamp, timestampIndex in channel.timestamps { // get transformation value for the timestamp
            if obj.animation.duration < timestamp {
                value: union { float3, float4 }
                switch _values in channel.values {
                case []float3: value = channel.values.([]float3)[timestampIndex]
                case []float4: value = channel.values.([]float4)[timestampIndex]
                }

                // nextValue: union { float3, float4 }
                // switch _values in channel.values {
                // case []float3: nextValue = channel.values.([]float3)[timestampIndex + 1]
                // case []float4: nextValue = channel.values.([]float4)[timestampIndex + 1]
                // }

                nodeValue.transfType = channel.transf
                nodeValue.value = value
                break
            }
        }

        append(&nodesValues, nodeValue)
    }

    for nodeValue in nodesValues { // populate each transformation type for each node
        transf := obj.animation.nodesTransf[nodeValue.nodeIndex]

        switch nodeValue.transfType {
        case .ROTATION:
            rotation: quaternion128
            rotationVec := nodeValue.value.(float4)
            mem.copy(&rotation, &rotationVec, size_of(quaternion128)) 
            transf.rotation = rotation
        case .SCALE: transf.scale = nodeValue.value.(float3)
        case .TRANSLATE: transf.translation = nodeValue.value.(float3)
        }

        obj.animation.nodesTransf[nodeValue.nodeIndex] = transf
    }
}

stopAnimation :: proc(obj: ^GameObj) {
    obj.animation.running = false
}