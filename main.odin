package main

import win "core:sys/windows"
import "core:fmt"
import "core:mem"
import "core:time"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
fmt :: fmt
print :: fmt.println

ShaderType :: enum {
	QUAD,
	FONT,
	MESH,
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

	quad: struct {
		vbo, vao, ebo: u32,
		indicesCount: int,
	},
	meshes: [MeshType]Mesh,
	shaders: [ShaderType]Shader,
	textures: [TextureType]Maybe(Texture),

	camera: struct{
		freeMode: bool,
		pos: float3,
		up: float3,

		yaw: f32,
		pitch: f32,
		front: float3,
	},
	uiProjMat, projMat, viewMat: mat4,

	objs: [dynamic]GameObj,

	timeDelta: f64,
	font: FontData,
}

ctx: Context = {}

tracker: mem.Tracking_Allocator

// todo:
// sprites
// ability to select items on screen
// framebuffer
// instancing
// ui
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
	loadTextures()
	loadFont()
	initCamera()
	loadMeshes()

	initObjs()

	// for testing
	// toggleBorderlessFullscreen()
	toggleFreeCameraMode()

    msg: win.MSG
    for msg.message != win.WM_QUIT {
        defer free_all(context.temp_allocator)

        beforeFrame := time.tick_now()
        if win.PeekMessageW(&msg, nil, 0, 0, win.PM_REMOVE) {
            win.TranslateMessage(&msg)
            win.DispatchMessageW(&msg)
            continue
        }

		handleKeyboard()
		updateObjs()

		render()
		ctx.timeDelta = time.duration_seconds(time.tick_diff(beforeFrame, time.tick_now()))
    }

	clearOpengl()
	clearContext()
	deleteObjs()

	when ODIN_DEBUG { 
		for _, leak in tracker.allocation_map {
			fmt.printf("%v leaked %m\n", leak.location, leak.size)
		}
		for bad_free in tracker.bad_free_array {
			fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
		}

		if tracker.total_memory_allocated - tracker.total_memory_freed > 0 {        
			// fmt.println("Total allocated", tracker.total_memory_allocated)
			// fmt.println("Total freed", tracker.total_memory_freed)
			fmt.println("Total leaked", tracker.total_memory_allocated - tracker.total_memory_freed)
		}
	}
}

clearContext :: proc() {
	for _, kerning in ctx.font.kerningTable { delete(kerning) }

	delete(ctx.font.kerningTable)
    delete(ctx.font.chars)
}
