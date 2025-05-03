package main

import glm "core:math/linalg/glsl"
import "core:math/linalg"
import "core:mem"
import "core:math"

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

        clear(&obj.animation.nodeTransforms)
        return
    }

    NodeValue :: struct {
        nodeIndex: i32,
        transfType: MeshAnimationTransfType,
        value: union { float3, quaternion128 },
    }

    nodesValues := make([dynamic]NodeValue)
    defer delete(nodesValues)

    for channel in animation.channels {
        nodeValue := NodeValue{ nodeIndex = channel.nodeIndex }

        for timestamp, timestampIndex in channel.timestamps { // get transformation value for the timestamp
            if obj.animation.duration < timestamp {
                
                prevTimeStampIndex := math.max(timestampIndex - 1, 0) // note: sometimes animation does not start with "0" seconds
                //prevTimeStampIndex := timestampIndex > 0 ? timestampIndex - 1 : len(channel.timestamps) - 1 // note: use this one if you want to assume that "first" frame starts from the last timestamp

                //print(obj.animation.duration, timestamp)
                prevValue: union { float3, float4 }
                switch _values in channel.values {
                case []float3: prevValue = channel.values.([]float3)[prevTimeStampIndex]
                case []float4: prevValue = channel.values.([]float4)[prevTimeStampIndex]
                }

                nextValue: union { float3, float4 }
                switch _values in channel.values {
                case []float3: nextValue = channel.values.([]float3)[timestampIndex]
                case []float4: nextValue = channel.values.([]float4)[timestampIndex]
                }

                // integrpolate value
                delta := (obj.animation.duration - channel.timestamps[prevTimeStampIndex]) / (channel.timestamps[timestampIndex] - channel.timestamps[prevTimeStampIndex])
                
                value: union { float3, quaternion128 }
                switch channel.transf {
                case .ROTATION:
                    value = glm.quatSlerp(transmute(quaternion128)prevValue.(float4), transmute(quaternion128)nextValue.(float4), delta)
                case .SCALE, .TRANSLATE:
                    value = glm.lerp_vec3(prevValue.(float3), nextValue.(float3), delta)
                }

                nodeValue.transfType = channel.transf
                nodeValue.value = value
                break
            }
        }

        append(&nodesValues, nodeValue)
    }

    for nodeValue in nodesValues { // populate each transformation type for each node
        transf := obj.animation.nodeTransforms[nodeValue.nodeIndex]

        switch nodeValue.transfType {
        case .ROTATION: transf.rotation = nodeValue.value.(quaternion128)
        case .SCALE: transf.scale = nodeValue.value.(float3)
        case .TRANSLATE: transf.translation = nodeValue.value.(float3)
        }

        obj.animation.nodeTransforms[nodeValue.nodeIndex] = transf
    }
}

stopAnimation :: proc(obj: ^GameObj) {
    obj.animation.running = false
}