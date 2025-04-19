package main

import "core:math"

int2 :: [2]i32
int3 :: [3]i32

float2 :: [2]f32
float3 :: [3]f32
float4 :: [4]f32
mat4 :: matrix[4, 4]f32

identityMat := matrix[4, 4]f32{
	1, 0, 0, 0, 
	0, 1, 0, 0, 
	0, 0, 1, 0, 
	0, 0, 0, 1,
}

