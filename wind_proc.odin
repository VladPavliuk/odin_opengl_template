package main

import "base:runtime"
import win "core:sys/windows"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import "core:math"
//import "vendor:glfw"

default_context: runtime.Context

winProc :: proc "system" (hwnd: win.HWND, msg: win.UINT, wParam: win.WPARAM, lParam: win.LPARAM) -> win.LRESULT {
    // NOTE: it's a hack to override some context data like allocators, that might be redefined in other code 
    context = default_context

    switch msg {
    case win.WM_CREATE:
        ctx.hdc = win.GetDC(hwnd)

        initOpengl()
    case win.WM_INPUT:
        if !ctx.camera.freeMode { break }

        rawInput: win.RAWINPUT
        rawInputSize := u32(size_of(rawInput))
		win.GetRawInputData(win.HRAWINPUT(lParam), win.RID_INPUT, &rawInput, &rawInputSize, size_of(win.RAWINPUTHEADER))

        if rawInput.header.dwType == win.RIM_TYPEMOUSE {
            dx := f32(-rawInput.data.mouse.lLastX)
            dy := f32(rawInput.data.mouse.lLastY)

            ctx.camera.yaw += dx * 0.01
            ctx.camera.pitch += dy * 0.01

            ctx.camera.pitch = min(ctx.camera.pitch, math.PI / 2 - math.PI / 180)
            ctx.camera.pitch = max(ctx.camera.pitch, -math.PI / 2 + math.PI / 180)

            setCameraFront()
            syncCameraMat()
        }
    case win.WM_KEYDOWN:
        switch wParam {
        case win.VK_ESCAPE: win.DestroyWindow(hwnd)
        case win.VK_F: toggleBorderlessFullscreen()
        case win.VK_G: toggleFreeCameraMode()
        }
    case win.WM_LBUTTONUP:
    
    // case win.WM_MOVE:
    //     render()
    case win.WM_SIZE:
        if !ctx.isWindowCreated { break }

        if wParam == win.SIZE_MINIMIZED { break }

        rect: win.RECT
        win.GetClientRect(hwnd, &rect)

        ctx.windowSize = { rect.right - rect.left, rect.bottom - rect.top }
        gl.Viewport(0, 0, i32(ctx.windowSize.x), i32(ctx.windowSize.y))

        // NOTE: while resizing we only get resize message, so we can't redraw from main loop, so we do it explicitlly
        initProjections()
        createPickFBO(ctx.windowSize.x, ctx.windowSize.y)
        render()
    case win.WM_DESTROY: win.PostQuitMessage(0)
    }
    return win.DefWindowProcW(hwnd, msg, wParam, lParam)
}