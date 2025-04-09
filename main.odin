package main

import win "core:sys/windows"
import "core:fmt"
import "core:mem"
import "core:time"
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

	timeDelta: f64,
	font: FontData,
}

ctx: Context = {}

tracker: mem.Tracking_Allocator

// todo:
// sprites
// framebuffer
// instancing
// ui
// mesh rendering
// lighting
// sound
// pbr
main :: proc() {
	when ODIN_DEBUG { 
		mem.tracking_allocator_init(&tracker, context.allocator)
		defer mem.tracking_allocator_destroy(&tracker)
		context.allocator = mem.tracking_allocator(&tracker)
	}
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

        beforeFrame := time.tick_now()
        if win.PeekMessageW(&msg, nil, 0, 0, win.PM_REMOVE) {
            win.TranslateMessage(&msg)
            win.DispatchMessageW(&msg)
            continue
        }

		render()
		ctx.timeDelta = time.duration_seconds(time.tick_diff(beforeFrame, time.tick_now()))
    }

	clearOpengl()
	clearContext()

	when ODIN_DEBUG { 
		for _, leak in tracker.allocation_map {
			fmt.printf("%v leaked %m\n", leak.location, leak.size)
		}
		for bad_free in tracker.bad_free_array {
			fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
		}

		if tracker.total_memory_allocated - tracker.total_memory_freed > 0 {        
			fmt.println("Total allocated", tracker.total_memory_allocated)
			fmt.println("Total freed", tracker.total_memory_freed)
			fmt.println("Total leaked", tracker.total_memory_allocated - tracker.total_memory_freed)
		}
	}
}

clearContext :: proc() {
	for _, kerning in ctx.font.kerningTable { delete(kerning) }

	delete(ctx.font.kerningTable)
    delete(ctx.font.chars)
}
