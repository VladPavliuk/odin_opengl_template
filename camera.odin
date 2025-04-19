package main

import "core:math"
import glm "core:math/linalg/glsl"
import win "core:sys/windows"

initCamera :: proc() {
    ctx.camera.pos = { 0, 0, 1 }
    ctx.camera.up = {0, 0, 1} // z is up
    ctx.camera.yaw = -1.6
    ctx.camera.pitch = 0.8
    setCameraFront()
    syncCameraMat()
    initProjections()
}

setCameraFront :: proc() {
    ctx.camera.front = glm.normalize_vec3({ 
        math.cos(ctx.camera.yaw) * math.cos(ctx.camera.pitch),
        math.sin(ctx.camera.yaw) * math.cos(ctx.camera.pitch),
        math.sin(ctx.camera.pitch),
    })
}

syncCameraMat :: proc() {
    cameraSize :: 10 // increasing "size" means that moving the camera affect camerae "position" less
    ctx.viewMat = glm.mat4LookAt(ctx.camera.pos + ctx.camera.front / cameraSize, ctx.camera.pos, ctx.camera.up)
}

initProjections :: proc() {
    //ctx.projMat = glm.mat4Perspective(45, f32(ctx.windowSize.x) / f32(ctx.windowSize.y), 0.1, 100.0)
    ctx.projMat = glm.mat4PerspectiveInfinite(45, f32(ctx.windowSize.x) / f32(ctx.windowSize.y), 0.1)
    ctx.uiProjMat = glm.mat4Ortho3d(0, f32(ctx.windowSize.x), f32(ctx.windowSize.y), 0, 0, 100)
}

toggleFreeCameraMode :: proc() {
    ctx.camera.freeMode = !ctx.camera.freeMode

    win.ShowCursor(win.BOOL(!ctx.camera.freeMode))

    if ctx.camera.freeMode {
        rect: win.RECT
        win.GetClientRect(ctx.hwnd, &rect)

        ul: win.POINT = { rect.left, rect.top }
        lr: win.POINT = { rect.right, rect.bottom }
        win.ClientToScreen(ctx.hwnd, &ul)
        win.ClientToScreen(ctx.hwnd, &lr)

        rect = { ul.x, ul.y, lr.x, lr.y }
        win.ClipCursor(&rect)
    } else {
        win.SetCursorPos(ctx.windowSize.x / 2, ctx.windowSize.y / 2)
        win.ClipCursor(nil)
    }
}