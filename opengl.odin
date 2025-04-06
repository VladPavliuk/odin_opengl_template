package main

import gl "vendor:OpenGL"
import win "core:sys/windows"
import glm "core:math/linalg/glsl"

initOpengl :: proc() {
    majorVersion :: 4
    minorVersion :: 4
    multisampleLevel :: 4

    {
        // why it's supposed to be needed???!!!
        // 06.04.2025 - that's weird but without it multisampling does not work, weird!
        dummy := win.CreateWindowExW(0, L("STATIC"), L("DummyWindow"), 
            win.WS_OVERLAPPED, win.CW_USEDEFAULT, win.CW_USEDEFAULT, win.CW_USEDEFAULT, win.CW_USEDEFAULT, nil, nil, nil, nil)
        defer win.DestroyWindow(dummy)

        hdc := win.GetDC(dummy)
        defer win.ReleaseDC(dummy, hdc)

        desc := win.PIXELFORMATDESCRIPTOR{
            nSize = size_of(win.PIXELFORMATDESCRIPTOR),
            nVersion = 1,
            dwFlags = win.PFD_DRAW_TO_WINDOW | win.PFD_SUPPORT_OPENGL | win.PFD_DOUBLEBUFFER,
            iPixelType = win.PFD_TYPE_RGBA,
            cColorBits = 24,
        }
        format := win.ChoosePixelFormat(hdc, &desc)
        win.DescribePixelFormat(hdc, format, size_of(desc), &desc)
        win.SetPixelFormat(hdc, format, &desc)

        rc := win.wglCreateContext(hdc)
        defer win.wglDeleteContext(rc)
        
        win.wglMakeCurrent(hdc, rc)
        defer win.wglMakeCurrent(nil, nil)

        win.wglChoosePixelFormatARB = win.ChoosePixelFormatARBType(win.wglGetProcAddress("wglChoosePixelFormatARB"))
        win.wglCreateContextAttribsARB = win.CreateContextAttribsARBType(win.wglGetProcAddress("wglCreateContextAttribsARB"))
        win.wglSwapIntervalEXT = win.SwapIntervalEXTType(win.wglGetProcAddress("wglSwapIntervalEXT"))
    }

    {
        attrib := [?]i32{
            win.WGL_DRAW_TO_WINDOW_ARB, 1,
            win.WGL_SUPPORT_OPENGL_ARB, 1,
            win.WGL_DOUBLE_BUFFER_ARB, 1,
            win.WGL_PIXEL_TYPE_ARB, win.WGL_TYPE_RGBA_ARB,
            win.WGL_COLOR_BITS_ARB, 24,
            win.WGL_STENCIL_BITS_ARB, 8,

            // multisample
            win.WGL_DOUBLE_BUFFER_ARB, 1,
            win.WGL_SAMPLE_BUFFERS_ARB, 1,
            win.WGL_SAMPLES_ARB, multisampleLevel,

            0,
        }

        format: i32
        formats: u32
        win.wglChoosePixelFormatARB(ctx.hdc, &attrib[0], nil, 1, &format, &formats)
        desc := win.PIXELFORMATDESCRIPTOR{
            nSize = size_of(win.PIXELFORMATDESCRIPTOR),
        }
        win.DescribePixelFormat(ctx.hdc, format, size_of(desc), &desc)
        win.SetPixelFormat(ctx.hdc, format, &desc)
    }

    {
        attrib := [?]i32{
            win.WGL_CONTEXT_MAJOR_VERSION_ARB, majorVersion,
            win.WGL_CONTEXT_MINOR_VERSION_ARB, minorVersion,
            win.WGL_CONTEXT_PROFILE_MASK_ARB, win.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,

            win.WGL_CONTEXT_FLAGS_ARB, win.WGL_CONTEXT_DEBUG_BIT_ARB,
            0,
        }

        rc := win.wglCreateContextAttribsARB(ctx.hdc, nil, &attrib[0])
        win.wglMakeCurrent(ctx.hdc, rc)
    }

    gl.load_up_to(majorVersion, minorVersion, win.gl_set_proc_address)

    win.wglSwapIntervalEXT(1) // enable v sync
    // gl.Enable(gl.MULTISAMPLE) // should on by default
}

clearOpengl :: proc() {
    for shader in ctx.shaders {
		gl.DeleteProgram(shader.program)
        delete(shader.uniforms)
	}

	for &mesh in ctx.meshes {
		gl.DeleteBuffers(1, &mesh.ebo)
		gl.DeleteBuffers(1, &mesh.vbo)
		gl.DeleteVertexArrays(1, &mesh.vao)
	}

	win.wglMakeCurrent(nil, nil)
	win.wglDeleteContext(ctx.openglCtx)
	win.ReleaseDC(ctx.hwnd, ctx.hdc)
}

loadShaders :: proc() {
    program, program_ok := gl.load_shaders_source(#load("./shaders/quad_vs.glsl"), #load("./shaders/quad_fs.glsl"))
    assert(program_ok)

    ctx.shaders[.QUAD] = Shader{
        program = program,
        uniforms = gl.get_uniforms_from_program(program),
    }
}

createQaudMesh :: proc() {
    Vertex :: struct {
        pos: glm.vec3,
        col: glm.vec4,
    }

    vertices := []Vertex{
		{{-0.5, +0.5, 0}, {1.0, 0.0, 0.0, 0.75}},
		{{-0.5, -0.5, 0}, {1.0, 1.0, 0.0, 0.75}},
		{{+0.5, -0.5, 0}, {0.0, 1.0, 0.0, 0.75}},
		{{+0.5, +0.5, 0}, {0.0, 0.0, 1.0, 0.75}},
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
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
	gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, col))

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(indices[0]), raw_data(indices), gl.STATIC_DRAW)

    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)

    ctx.meshes[.QUAD] = {
        vao = vao,
        vbo = vbo,
        ebo = ebo,
    }
}