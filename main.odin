package main

import win "core:sys/windows"
import "base:runtime"
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
	PICK,
	TEST_COMPUTE,
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
	pickFBO: struct {
		fbo: u32,
		pickTexture, depthTexture: u32,
	},

	quad: struct {
		vbo, vao, ebo: u32,
		indicesCount: int,
	},
	meshes: [MeshType]Mesh,
	shaders: [ShaderType]Shader,
	textures: [TextureType]Maybe(Texture),

	testSSBO: u32,

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
	hoveredObj: i32,

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
    createPickFBO(ctx.windowSize.x, ctx.windowSize.y)

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

	testData := []float2 {
		{0,0},
		{1,1},
		{2,2},
	}
	ctx.testSSBO = createSSBO(testData)

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

		// testing compute shader
		// gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, ctx.testSSBO)
		// gl.UseProgram(ctx.shaders[.TEST_COMPUTE].program)
		// gl.DispatchCompute(3, 1, 1)
		// gl.MemoryBarrier(gl.SHADER_STORAGE_BARRIER_BIT) // make sure compute shader is done

		// // read
		// gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, ctx.testSSBO)
		// readData := gl.MapBuffer(gl.SHADER_STORAGE_BUFFER, gl.READ_ONLY)
		// testData2 := transmute([]float2)runtime.Raw_Slice{readData, len(testData)}
		// gl.UnmapBuffer(gl.SHADER_STORAGE_BUFFER)

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
