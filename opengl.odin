package main

import gl "vendor:OpenGL"
import win "core:sys/windows"
import glm "core:math/linalg/glsl"
import "core:bytes"

import "core:image"

import "core:image/png" // since png module has autoload function, don't remove it!
_ :: png._MAX_IDAT

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

    gl.Enable(gl.CULL_FACE)
    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LESS)

    gl.Enable(gl.BLEND)
    //gl.DepthMask(gl.TRUE)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    //gl.Enable(gl.TEXTURE_2D)
}

clearOpengl :: proc() {
    for shader in ctx.shaders {
		gl.DeleteProgram(shader.program)

        for uniformName in shader.uniforms { delete(uniformName) }
        delete(shader.uniforms)
	}

	for &mesh in ctx.meshes {
		gl.DeleteBuffers(1, &mesh.ebo)
		gl.DeleteBuffers(1, &mesh.vbo)
		gl.DeleteVertexArrays(1, &mesh.vao)
	}
    
	for &texture in ctx.textures {
		gl.DeleteTextures(1, &texture.texture)
	}

	win.wglMakeCurrent(nil, nil)
	win.wglDeleteContext(ctx.openglCtx)
	win.ReleaseDC(ctx.hwnd, ctx.hdc)
}

loadShaders :: proc() {
    { // quad
        program, program_ok := gl.load_shaders_source(#load("./shaders/quad_vs.glsl"), #load("./shaders/quad_fs.glsl"))
        assert(program_ok)

        ctx.shaders[.QUAD] = Shader{
            program = program,
            uniforms = gl.get_uniforms_from_program(program),
        }
            
    }

    { // font
        program, program_ok := gl.load_shaders_source(#load("./shaders/font_vs.glsl"), #load("./shaders/font_fs.glsl"))
        assert(program_ok)

        ctx.shaders[.FONT] = Shader{
            program = program,
            uniforms = gl.get_uniforms_from_program(program),
        }
            
    }
}

loadTextures :: proc() {
    ctx.textures[.DOGGO] = loadTextureFromImage(#load("./res/doggo.png"))
    ctx.textures[.DOGGO_2] = loadTextureFromImage(#load("./res/doggo_2.png"))
    ctx.textures[.DOGGO_3] = loadTextureFromImage(#load("./res/doggo_3.png"))
}

loadTextureFromImage :: proc(imageFileContent: []u8) -> Texture {
    parsedImage, imageErr := image.load_from_bytes(imageFileContent)
    assert(imageErr == nil, "Couldn't parse image")
    defer image.destroy(parsedImage)

    image.alpha_add_if_missing(parsedImage)

    bitmap := bytes.buffer_to_bytes(&parsedImage.pixels)

    texture: u32
    gl.GenTextures(1, &texture)

    gl.BindTexture(gl.TEXTURE_2D, texture)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(parsedImage.width), i32(parsedImage.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(bitmap))
    gl.GenerateMipmap(gl.TEXTURE_2D)
    
    gl.BindTexture(gl.TEXTURE_2D, 0)

    return Texture {
        texture = texture,
        width = parsedImage.width,
        height = parsedImage.height,
    }
}