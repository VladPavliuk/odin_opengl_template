package main

import "base:intrinsics"
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

@(require_results)
slice_map :: proc(input: []$T, mapper: proc(T) -> $Y) -> []intrinsics.type_elem_type(Y) {
	output := make([]Y, len(input))

	for item, index in intput {
		output[index] = mapper(item)
	}

	return output
}
