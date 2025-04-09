package main

import win "core:sys/windows"
import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
fmt :: fmt

ShaderType :: enum {
	QUAD,
	FONT,
}

Shader :: struct {
	program: u32,
	uniforms: gl.Uniforms,
}

TextureType :: enum {
	FONT,
	DOGGO,
	DOGGO_2,
	DOGGO_3,
}

Texture :: struct {
	texture: u32,
	width, height: int,
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
	textures: [TextureType]Texture,

	uiProjMat, projMat, viewMat: mat4,

	font: FontData,
}

ctx: Context = {}

// todo:
// sprites
// text
// framebuffer
// instancing
// ui
// mesh rendering
// lighting
// sound
// pbr
main :: proc() {
    default_context = context

    initWindow()

	loadShaders()
	createQaudMesh()
	createSpriteMesh()
	loadTextures()
	loadFont()
	initCamera()
    
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