package main

import "core:bytes"
import "core:image"
import "core:strings"
import "base:runtime"

import win "core:sys/windows"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import stb_image "vendor:stb/image"

import "core:image/png" // since png module has autoload function, don't remove it!
//import "core:image/bmp" // since png module has autoload function, don't remove it!
_ :: png._MAX_IDAT

initOpengl :: proc() {
    majorVersion :: 4
    minorVersion :: 5
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
    //gl.Enable(gl.MULTISAMPLE) // should on by default

    gl.Enable(gl.DEBUG_OUTPUT)
    gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)
    debugProc :: proc "c" (source: u32, type: u32, id: u32, severity: u32, length: i32, message: cstring, userParam: rawptr) {
        if severity == gl.DEBUG_SEVERITY_NOTIFICATION { return }
        
        context = default_context
        print(severity, message)
    }
    gl.DebugMessageCallback(debugProc, nil)

    //gl.Enable(gl.CULL_FACE)
    gl.Disable(gl.CULL_FACE) // just for testing 3d models
    //gl.CullFace(gl.FRONT)
    //gl.CullFace(gl.BACK)
    //gl.FrontFace(gl.CW)

    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LESS)

    gl.Enable(gl.BLEND)
    //gl.DepthMask(gl.TRUE)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    //gl.Enable(gl.TEXTURE_2D)
}

createPickFBO :: proc(width, height: i32) {
    if ctx.pickFBO.fbo != 0 {
        gl.DeleteFramebuffers(1, &ctx.pickFBO.fbo)
        gl.DeleteTextures(1, &ctx.pickFBO.pickTexture)
        gl.DeleteTextures(1, &ctx.pickFBO.depthTexture)
    }

    fbo: u32
    gl.GenFramebuffers(1, &fbo)
    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo)

    pickTexture: u32
    gl.GenTextures(1, &pickTexture)
    gl.BindTexture(gl.TEXTURE_2D, pickTexture)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.R32I, i32(width), i32(height), 0, gl.RED_INTEGER, gl.INT, nil)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, pickTexture, 0)

    depthTexture: u32
    gl.GenTextures(1, &depthTexture)
    gl.BindTexture(gl.TEXTURE_2D, depthTexture)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT, i32(width), i32(height), 0, gl.DEPTH_COMPONENT, gl.FLOAT, nil)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, depthTexture, 0)

    drawBuffers := []u32{ gl.COLOR_ATTACHMENT0 }
    gl.DrawBuffers(1, raw_data(drawBuffers)) 

    assert(gl.CheckFramebufferStatus(gl.FRAMEBUFFER) == gl.FRAMEBUFFER_COMPLETE)

    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
    gl.BindTexture(gl.TEXTURE_2D, 0)

    ctx.pickFBO = { fbo, pickTexture, depthTexture }
}

clearOpengl :: proc() {
    for shader in ctx.shaders {
		gl.DeleteProgram(shader.program)

        for uniformName in shader.uniforms { delete(uniformName) }
        delete(shader.uniforms)
	}

	for &mesh in ctx.meshes {
        clearMesh(&mesh)
	}
    
	for &texture in ctx.textures {
        if texture != nil {
            textureId := texture.?.texture
            gl.DeleteTextures(1, &textureId)
        }
	}

	win.wglMakeCurrent(nil, nil)
	win.wglDeleteContext(ctx.openglCtx)
	win.ReleaseDC(ctx.hwnd, ctx.hdc)
}

createSSBO :: proc(data: []$T) -> u32 {
    buffer: u32
    gl.GenBuffers(1, &buffer)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, buffer)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(T) * len(data), raw_data(data), gl.DYNAMIC_COPY)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, 0)

    return buffer
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

    { // mesh
        program, program_ok := gl.load_shaders_source(#load("./shaders/mesh_vs.glsl"), #load("./shaders/mesh_fs.glsl"))
        assert(program_ok)

        ctx.shaders[.MESH] = Shader{
            program = program,
            uniforms = gl.get_uniforms_from_program(program),
        }
    }

    { // pick
        program, program_ok := gl.load_shaders_source(#load("./shaders/pick_vs.glsl"), #load("./shaders/pick_fs.glsl"))
        assert(program_ok)

        ctx.shaders[.PICK] = Shader{
            program = program,
            uniforms = gl.get_uniforms_from_program(program),
        }
    }

    { // test compute shader
        program, program_ok := gl.load_compute_source(#load("./shaders/test_compute.glsl"))
        assert(program_ok)

        ctx.shaders[.TEST_COMPUTE] = Shader{
            program = program,
            uniforms = gl.get_uniforms_from_program(program),
        }
    }
}

loadTextures :: proc() {
    ctx.textures[.DOGGO], _ = loadTextureFromImage(#load("./res/doggo.png"))
    ctx.textures[.DOGGO_2], _ = loadTextureFromImage(#load("./res/doggo_2.png"))
    ctx.textures[.DOGGO_3], _ = loadTextureFromImage(#load("./res/doggo_3.png"))
}

loadTextureFromImage :: proc(imageFileContent: []u8) -> (Maybe(Texture), bool) {
    _convertImageToTexture :: proc(data: []byte, width, height: int) -> (Maybe(Texture), bool) {
        texture: u32
        gl.GenTextures(1, &texture)

        gl.BindTexture(gl.TEXTURE_2D, texture)

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(width), i32(height), 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(data))
        gl.GenerateMipmap(gl.TEXTURE_2D)
        
        gl.BindTexture(gl.TEXTURE_2D, 0)

        return Texture {
            texture = texture,
            width = width,
            height = height,
        }, true
    }

    { // try default Odin parser first
        parsedImage, imageErr := image.load_from_bytes(imageFileContent)

        if imageErr == nil {
            defer image.destroy(parsedImage)

            image.alpha_add_if_missing(parsedImage)

            bitmap := bytes.buffer_to_bytes(&parsedImage.pixels)

            return _convertImageToTexture(bitmap, parsedImage.width, parsedImage.height)
        } else {
            print("Couldn't parse image", imageErr)
        }
    }

    { // try stb parser (from JPEG)
        width, height, channels: i32
        bitmap := stb_image.load_from_memory(raw_data(imageFileContent), i32(len(imageFileContent)), &width, &height, &channels, 0)
        defer stb_image.image_free(bitmap)

        if bitmap == nil { 
            size := width * height *channels
            data := transmute([]byte)runtime.Raw_Slice{bitmap, int(size)}
    
            return _convertImageToTexture(data, int(width), int(height))    
        } else {
            print(string(stb_image.failure_reason())) 
        }
    }

    return nil, false
}