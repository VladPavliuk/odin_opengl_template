package main
import win "core:sys/windows"
import "base:intrinsics"

L :: intrinsics.constant_utf16_cstring

initWindow :: proc() {
    wndClassName := L("wnd class")
    hHandle := win.HINSTANCE(win.GetModuleHandleW(nil))
    defaultCursor := win.LoadCursorA(nil, win.IDC_ARROW)

    wndClass := win.WNDCLASSW{
        lpszClassName = wndClassName,
        hInstance = hHandle,
        lpfnWndProc = winProc,
        hCursor = defaultCursor,
    }

    if win.RegisterClassW(&wndClass) == 0 { panic("Couldn't register a wnd class") }

    ctx.hwnd = win.CreateWindowExW(
        0,
        wndClassName,
        L("opengl"),
        win.WS_OVERLAPPEDWINDOW,
        win.CW_USEDEFAULT, win.CW_USEDEFAULT,
        win.CW_USEDEFAULT, win.CW_USEDEFAULT,
        nil, nil, hHandle, nil,
    )

    if ctx.hwnd == nil { panic("Couldn't create a window") }

    //> set instance window show without fade in transition
    attrib: u32 = 1
    win.DwmSetWindowAttribute(ctx.hwnd, u32(win.DWMWINDOWATTRIBUTE.DWMWA_TRANSITIONS_FORCEDISABLED), &attrib, size_of(u32))
    //<

    win.ShowWindow(ctx.hwnd, win.SW_SHOWDEFAULT)
    ctx.isWindowCreated = true

    rect: win.RECT
    win.GetClientRect(ctx.hwnd, &rect)
    ctx.windowSize = { rect.right - rect.left, rect.bottom - rect.top }
}

toggleBorderlessFullscreen :: proc() {
    if (ctx.isFullscreen) {
        win.SetWindowLongW(ctx.hwnd, win.GWL_STYLE, transmute(i32)(win.WS_OVERLAPPEDWINDOW | win.WS_VISIBLE))

        // win.SetWindowPos(ctx.hwnd, win.HWND_NOTOPMOST,
        //     win.CW_USEDEFAULT, win.CW_USEDEFAULT, win.CW_USEDEFAULT, win.CW_USEDEFAULT,
        //     win.SWP_FRAMECHANGED | win.SWP_SHOWWINDOW)
        win.SetWindowPlacement(ctx.hwnd, &ctx.windowPlaceBeforeFullscreen)

    } else {
        screenWidth := win.GetSystemMetrics(win.SM_CXSCREEN)
        screenHeight := win.GetSystemMetrics(win.SM_CYSCREEN)

        win.GetWindowPlacement(ctx.hwnd, &ctx.windowPlaceBeforeFullscreen)
        
        win.SetWindowLongW(ctx.hwnd, win.GWL_STYLE, transmute(i32)(win.WS_POPUP | win.WS_VISIBLE))
        win.SetWindowPos(ctx.hwnd, win.HWND_TOP,
                    0, 0,
                    screenWidth, screenHeight,
                    win.SWP_FRAMECHANGED | win.SWP_SHOWWINDOW)
    }

    ctx.isFullscreen = !ctx.isFullscreen
}