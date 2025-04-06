package main

import win "core:sys/windows"
import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
fmt :: fmt

MeshType :: enum {
	QUAD,
}

Mesh :: struct {
	vbo: u32,
	vao: u32,
	ebo: u32,
}

ShaderType :: enum {
	QUAD,
}

Shader :: struct {
	program: u32,
	uniforms: gl.Uniforms,
}

Context :: struct {
	isWindowCreated: bool,
	windowSize: int2,
	isFullscreen: bool,
	windowPlaceBeforeFullscreen: win.WINDOWPLACEMENT,

    hdc: win.HDC,
	hwnd: win.HWND,
	openglCtx: win.HGLRC,

	meshes: [MeshType]Mesh,
	shaders: [ShaderType]Shader,
}

ctx: Context = {}

main :: proc() {
    default_context = context

    initWindow()

	loadShaders()
	createQaudMesh()
    
    msg: win.MSG
    for msg.message != win.WM_QUIT {
        defer free_all(context.temp_allocator)

        if win.PeekMessageW(&msg, nil, 0, 0, win.PM_REMOVE) {
            win.TranslateMessage(&msg)
            win.DispatchMessageW(&msg)
            continue
        }

		render()
    }

	clearOpengl()
}