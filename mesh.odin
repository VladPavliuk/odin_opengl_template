package main

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "base:runtime"

MeshVertex :: struct {
	pos: float3,
	normals: float3,
	texCoord: float2,
}

MeshPrimitive :: struct {
	vertices: [dynamic]MeshVertex,
	indices: [dynamic]u32,

	vbo, vao, ebo: u32,
	texture: Maybe(Texture),
    color: float4,
}

MeshType :: enum {
    TEST_MESH,
}

Mesh :: struct {
	primitives: [dynamic]MeshPrimitive,
	children: [dynamic]Mesh,
	origMat: mat4,
	mat: mat4,
}

loadMeshes :: proc() {
    //ctx.meshes[.TEST_MESH] = loadGltfFile("C:/Users/Vlad/Downloads/test1234/Untitled.glb")
    //ctx.meshes[.TEST_MESH] = loadGltfFile("C:/Users/Vlad/Downloads/house_1/scene.gltf")
    //ctx.meshes[.TEST_MESH] = loadGltfFile("C:/Users/Vlad/Downloads/rover/rover.gltf")
    //ctx.meshes[.TEST_MESH] = loadGltfFile("C:/Users/Vlad/Downloads/monster_house_mayville_map.glb")
    //ctx.meshes[.TEST_MESH] = loadGltfFile("C:\\projects\\odin_opengl_template\\res\\building_1.glb")
    ctx.meshes[.TEST_MESH] = loadGltfFile("C:\\projects\\DirectXTemplate\\DirectXTemplate\\resources\\enamy_plane.glb")
    //ctx.meshes[.TEST_MESH] = loadGltfFile("C:\\projects\\odin_opengl_template\\res\\building\\building.gltf")

    //loadGltfFile("C:/Users/Vlad/Downloads/survival_guitar_backpack/scene.gltf")
	//loadGltfFile("C:\\projects\\odin_opengl_template\\res\\ball\\ball.gltf")
	//loadGltfFile("C:/Users/Vlad/Downloads/rover/rover.gltf")

	//loadGltfFile("C:/Users/Vlad/Downloads/br0e6h1jamf4-building2/building2/building.gltf")
}

createMesh :: proc(mesh: ^Mesh) {
    for &primitive in mesh.primitives {        
        vao, vbo, ebo: u32
        gl.GenVertexArrays(1, &vao)
        gl.GenBuffers(1, &vbo)
        gl.GenBuffers(1, &ebo)

        gl.BindVertexArray(vao)

        gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
        gl.BufferData(gl.ARRAY_BUFFER, len(primitive.vertices) * size_of(primitive.vertices[0]), raw_data(primitive.vertices[:]), gl.STATIC_DRAW)
        gl.EnableVertexAttribArray(0)
        gl.EnableVertexAttribArray(1)
        gl.EnableVertexAttribArray(2)
        gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(primitive.vertices[0]), offset_of(MeshVertex, pos))
        gl.VertexAttribPointer(1, 3, gl.FLOAT, false, size_of(primitive.vertices[0]), offset_of(MeshVertex, normals))
        gl.VertexAttribPointer(2, 2, gl.FLOAT, false, size_of(primitive.vertices[0]), offset_of(MeshVertex, texCoord))

        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(primitive.indices) * size_of(primitive.indices[0]), raw_data(primitive.indices), gl.STATIC_DRAW)

        gl.BindVertexArray(0)
        gl.BindBuffer(gl.ARRAY_BUFFER, 0)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)

        primitive.vao = vao
        primitive.vbo = vbo
        primitive.ebo = ebo
    }

    for &childMesh in mesh.children {
        createMesh(&childMesh)
    }
}

applyTransfToMesh :: proc(mesh: ^Mesh, mat: mat4) {
    mesh.mat = mat * mesh.origMat
    
    for &childMesh in mesh.children {
        applyTransfToMesh(&childMesh, mesh.mat)
    }
}

clearMesh :: proc(mesh: ^Mesh) {
    for &primitive in mesh.primitives {
        if primitive.ebo != 0 { gl.DeleteBuffers(1, &primitive.ebo) }
        if primitive.vbo != 0 { gl.DeleteBuffers(1, &primitive.vbo) }
        if primitive.vao != 0 { gl.DeleteVertexArrays(1, &primitive.vao) }

        delete(primitive.vertices)
        delete(primitive.indices)
    }
    delete(mesh.primitives)

    for &childMesh in mesh.children {
        clearMesh(&childMesh)
    }
    delete(mesh.children)
}

createQaudMesh :: proc() {
    Vertex :: struct {
        pos: glm.vec3,
        col: glm.vec4,
        tex: glm.vec2,
    }

    vertices := []Vertex{
		{{-0.5, +0.5, 0}, {1.0, 0.0, 0.0, 0.75}, {0.0, 0.0}},
		{{-0.5, -0.5, 0}, {1.0, 1.0, 0.0, 0.75}, {0.0, 1.0}},
		{{+0.5, -0.5, 0}, {0.0, 1.0, 0.0, 0.75}, {1.0, 1.0}},
		{{+0.5, +0.5, 0}, {0.0, 0.0, 1.0, 0.75}, {1.0, 0.0}},
	}
	
	indices := []u32{
		0, 1, 2,
		2, 3, 0,
	}
    
    vao, vbo, ebo: u32
	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)

    gl.BindVertexArray(vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(vertices[0]), raw_data(vertices), gl.STATIC_DRAW)
    gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
	gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, col))
    gl.VertexAttribPointer(2, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, tex))

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(indices[0]), raw_data(indices), gl.STATIC_DRAW)

    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)

    ctx.quad = {
        vao = vao,
        vbo = vbo,
        ebo = ebo,
        indicesCount = len(indices),
    }
}
