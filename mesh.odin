package main

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

MeshType :: enum {
	QUAD,
    SPRITE,
}

Mesh :: struct {
	vbo, vao, ebo: u32,
	indicesCount: int,
}

createSpriteMesh :: proc() {
    Vertex :: struct {
        pos: glm.vec2,
        tex: glm.vec2,
    }

	indices := []u16{
		0, 1, 2,
		2, 3, 0,
	}
    
    vao, vbo, ebo: u32
	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)

    gl.BindVertexArray(vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, 4 * size_of(Vertex), nil, gl.DYNAMIC_DRAW)
    gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, tex))

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(indices[0]), raw_data(indices), gl.STATIC_DRAW)

    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)

    ctx.meshes[.SPRITE] = {
        vao = vao,
        vbo = vbo,
        ebo = ebo,
        indicesCount = len(indices),
    }
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
	
	indices := []u16{
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

    ctx.meshes[.QUAD] = {
        vao = vao,
        vbo = vbo,
        ebo = ebo,
        indicesCount = len(indices),
    }
}
