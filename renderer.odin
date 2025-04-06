package main

import "core:math"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import win "core:sys/windows"

t: f32 = 0.0
h: f32 = 0.1

render :: proc() {
    gl.ClearColor(0.5, 0.7, 1.0, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    renderQuad({-0.3, -0.3, 0}, {1,1}, .DOGGO, {0, 0.0, 1}, t)
    t += 0.01

    renderQuad({0, 0.5, math.cos(h) / 4 }, {1,1}, .DOGGO_2, {0, 0.0, 1}, t / 2)

    renderQuad({0.4, 0.3, -0.1 }, {1,1}, .DOGGO_3, {0, 0.0, 1}, t * 2)

    h += 0.01

    win.SwapBuffers(ctx.hdc)
}

initCamera :: proc() {
    ctx.viewMat = glm.mat4LookAt({0, -1, +1}, {0, 0, 0}, {0, 0, 1})
    ctx.projMat = glm.mat4Perspective(45, 1.3, 0.1, 100.0)
}

renderQuad :: proc(position: float3, scale: float2, texture: TextureType, rotationVec: float3 = { 0, 0, 0 }, rotationAngle: f32 = 0) {
    gl.BindVertexArray(ctx.meshes[.QUAD].vao)
    gl.UseProgram(ctx.shaders[.QUAD].program)
    gl.BindTexture(gl.TEXTURE_2D, ctx.textures[texture].texture)

    model := glm.mat4Translate(position)
    model = model * glm.mat4Scale({scale.x, scale.y, 0})

    if (rotationAngle != 0) {
        model = model * glm.mat4Rotate(rotationVec, rotationAngle)
    }
		
    u_transform := ctx.projMat * ctx.viewMat * model

    gl.UniformMatrix4fv(ctx.shaders[.QUAD].uniforms["u_transform"].location, 1, false, &u_transform[0, 0])

    gl.DrawElements(gl.TRIANGLES, i32(ctx.meshes[.QUAD].indicesCount), gl.UNSIGNED_SHORT, nil)
}

// renderQube :: proc(position: float3, size: f32, rotationVec: float3 = { 0, 0, 0 }, rotationAngle: f32 = 0) {
//     renderQuad(position, { size, size }, rotationVec, rotationAngle)
// }