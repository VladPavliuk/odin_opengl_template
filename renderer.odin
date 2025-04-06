package main

import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import win "core:sys/windows"

t: f32 = 0.0

render :: proc() {
    gl.ClearColor(0.5, 0.7, 1.0, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    gl.BindVertexArray(ctx.meshes[.QUAD].vao)
    gl.UseProgram(ctx.shaders[.QUAD].program)

    model := glm.mat4{
        0.5,   0,   0, 0,
          0, 0.5,   0, 0,
          0,   0, 0.5, 0,
          0,   0,   0, 1,
    }

    model = model * glm.mat4Rotate({0, 1, 1}, t)
    t += 0.01
		
    view := glm.mat4LookAt({0, -1, +1}, {0, 0, 0}, {0, 0, 1})
    proj := glm.mat4Perspective(45, 1.3, 0.1, 100.0)
    
    u_transform := proj * view * model

    gl.UniformMatrix4fv(ctx.shaders[.QUAD].uniforms["u_transform"].location, 1, false, &u_transform[0, 0])

    gl.DrawElements(gl.TRIANGLES, i32(6), gl.UNSIGNED_SHORT, nil)
    win.SwapBuffers(ctx.hdc)
}