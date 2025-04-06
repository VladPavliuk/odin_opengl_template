package main

import "core:math"

int2 :: [2]i32
int3 :: [3]i32

float2 :: [2]f32
float3 :: [3]f32
mat4 :: matrix[4, 4]f32

getRotationMatrix :: proc{getRotationMatrix_vec, getRotationMatrix_params}

getRotationMatrix_params :: proc(rotation: float3) -> mat4 {
    return getRotationMatrix_vec(rotation.x, rotation.y, rotation.z)
}

getRotationMatrix_vec :: proc(pitch, roll, yaw: f32) -> mat4 {
    cp := math.cos(pitch)
    sp := math.sin(pitch)

    cy := math.cos(yaw)
    sy := math.sin(yaw)

    cr := math.cos(roll)
    sr := math.sin(roll)

    return mat4{
        cr * cy + sr * sp * sy, sr * cp, sr * sp * cy - cr * sy, 0,
        cr * sp * sy - sr * cy, cr * cp, sr * sy + cr * sp * cy, 0,
        cp * sy               , -sp    , cp * cy               , 0,
        0                     ,0       ,0                      , 1,
    }
}