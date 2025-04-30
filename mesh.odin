package main

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "base:runtime"

MeshType :: enum {
    TEST_MESH,
}

MeshAnimationTransfType :: enum {
    ROTATION,
    SCALE,
    TRANSLATE,
}

MeshAnimationChannel :: struct {
    nodeIndex: i32,
    transf: MeshAnimationTransfType,
    timestamps: []f32,
    values: union{ []float3, []float4 }, // actual values that will be applied to nodes
}

MeshAnimation :: struct {
    channels: []MeshAnimationChannel,
    duration: f32,
}

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

MeshNode :: struct {
    primitives: []MeshPrimitive,
    children: []i32,

    mat: mat4,
    translation: mat4,
    scale: mat4,
    rotation: mat4,
}

Mesh :: struct {
    rootNodeIndex: i32,
    nodes: []MeshNode,
    animations: []MeshAnimation,
}

loadMeshes :: proc() {
    // meshMesh := "C:/Projects/odin_opengl_template/models/barrel/barrel.gltf"
    // meshMesh := "C:/Projects/odin_opengl_template/models/Cute_Demon.glb"
    meshMesh := "C:/Projects/odin_opengl_template/models/Light_Switch.glb"
    //meshMesh := "C:/Projects/odin_opengl_template/models/what u see.glb"

    ctx.meshes[.TEST_MESH] = loadGltfFile(meshMesh)
}

createMesh :: proc(mesh: ^Mesh) {
    for node in mesh.nodes {
        for &primitive in node.primitives {        
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
    }
}

// setMeshForGameObj :: proc(obj: ^GameObj, type: MeshType) {
//     obj.mesh.type = type

//     mesh := &ctx.meshes[type]
//     obj.mesh.nodeTransforms = make([]mat4, len(mesh.nodes))

//     for node in mesh.nodes {

//     }
// }

applyTransfToGameObj :: proc(obj: ^GameObj, mat: mat4) {
    mesh := &ctx.meshes[obj.mesh.type]
    
    _applyToSubNodes :: proc(obj: ^GameObj, mesh: ^Mesh, index: i32, parentMat: mat4) {
        node := mesh.nodes[index]
        nodeMat: mat4

        if index in obj.animation.nodesTransf {
            mat := mat4(1)
            transf := obj.animation.nodesTransf[index]

            if transf.scale != nil { mat = glm.mat4Scale(transf.scale.?) * mat }
            else { mat = node.scale * mat } 

            if transf.rotation != nil { mat = glm.mat4FromQuat(transf.rotation.?) * mat }
            else { mat = node.rotation * mat } 

            if transf.translation != nil { mat = glm.mat4Translate(transf.translation.?) * mat }
            else { mat = node.translation * mat } 

            nodeMat = parentMat * mat
        } else {
            nodeMat = parentMat * node.mat
        }

        obj.mesh.nodeTransforms[index] = nodeMat

        for nodeIndex in node.children {
            _applyToSubNodes(obj, mesh, nodeIndex, nodeMat)
        }
    }

    _applyToSubNodes(obj, mesh, mesh.rootNodeIndex, mat)
}

clearMesh :: proc(mesh: ^Mesh) {
    for node in mesh.nodes {       
        for &primitive in node.primitives {
            if primitive.ebo != 0 { gl.DeleteBuffers(1, &primitive.ebo) }
            if primitive.vbo != 0 { gl.DeleteBuffers(1, &primitive.vbo) }
            if primitive.vao != 0 { gl.DeleteVertexArrays(1, &primitive.vao) }

            delete(primitive.vertices)
            delete(primitive.indices)
        }
        delete(node.primitives)
        delete(node.children)
    }

    delete(mesh.nodes)
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
