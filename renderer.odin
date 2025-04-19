package main

import "core:math"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import win "core:sys/windows"
import stbtt "vendor:stb/truetype"

t: f32 = 0.0
h: f32 = 0.1

render :: proc() {
    gl.ClearColor(0.5, 0.7, 1.0, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    renderQuad({-0.3, -0.3, 0}, {1,1}, .DOGGO, {0, 0.0, 1}, 0)
    t += 0.01

    renderQuad({0, 0.5, math.cos(h) / 4 }, {1,1}, .DOGGO_2, {0, 0.0, 1}, t / 2)

    renderQuad({0.4, 0.3, -0.1 }, {1,1}, .DOGGO_3, {0, 0.0, 1}, -t * 2)

    h += 0.01

    for obj in ctx.objs {
        t := glm.mat4Translate(obj.pos)
        s := glm.mat4Scale(obj.scale)
        if obj.rot.angle != 0 {
            r := glm.mat4Rotate(obj.rot.vec, obj.rot.angle)
            applyTransfToMesh(&ctx.meshes[.TEST_MESH], t * r * s)
        } else {
            applyTransfToMesh(&ctx.meshes[.TEST_MESH], t * s)
        }
    
        renderMesh(&ctx.meshes[.TEST_MESH])
    }


    renderText(fmt.tprintfln("%i fps", i32(1 / ctx.timeDelta)), { 0, 0 }, { 0, 0, 0 })
    
    win.SwapBuffers(ctx.hdc)
}

renderText :: proc(text: string, pos: float2, color: float3 = { 0, 0, 0 }, maxLineWidth: f32 = 0) {
    color := color
    fontTexture := ctx.textures[.FONT].?

    gl.BindVertexArray(ctx.font.vao)
    gl.UseProgram(ctx.shaders[.FONT].program)
    gl.BindTexture(gl.TEXTURE_2D, fontTexture.texture)

    gl.UniformMatrix4fv(ctx.shaders[.FONT].uniforms["u_projection"].location, 1, false, &ctx.uiProjMat[0, 0])
    gl.Uniform3fv(ctx.shaders[.FONT].uniforms["u_textColor"].location, 1, raw_data(&color))


    x: f32 = pos.x
    y: f32 = pos.y + ctx.font.ascent

    for l in text {
        q := GetBakedFontQuad(ctx.font.chars[l], fontTexture.width, fontTexture.height, &x, &y)

        vertices := [4][4]f32 {
            { q.x0, q.y0, q.s0, q.t0 },
            { q.x0, q.y1, q.s0, q.t1 },
            { q.x1, q.y1, q.s1, q.t1 },
            { q.x1, q.y0, q.s1, q.t0 },
        }

        if maxLineWidth != 0 && x > maxLineWidth {
            y += ctx.font.ascent - ctx.font.descent
            x = pos.x
        }

        gl.BindVertexArray(ctx.font.vao)
        gl.BindBuffer(gl.ARRAY_BUFFER, ctx.font.vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), raw_data(vertices[:]))

        gl.DrawElements(gl.TRIANGLES, i32(ctx.font.indicesCount), gl.UNSIGNED_INT, nil)
    }
}

initCamera :: proc() {
    ctx.viewMat = glm.mat4LookAt({0, -1, +1}, {0, 0, 0}, {0, 0, 1})
    initProjections()
}

initProjections :: proc() {
    //ctx.projMat = glm.mat4Perspective(45, f32(ctx.windowSize.x) / f32(ctx.windowSize.y), 0.1, 100.0)
    ctx.projMat = glm.mat4PerspectiveInfinite(45, f32(ctx.windowSize.x) / f32(ctx.windowSize.y), 0.1)
    ctx.uiProjMat = glm.mat4Ortho3d(0, f32(ctx.windowSize.x), f32(ctx.windowSize.y), 0, 0, 100)
}

moveCamera :: proc(pos: float3) {
    ctx.cameraPos += pos
    ctx.viewMat = glm.mat4LookAt(ctx.cameraPos + {0, -1, +1}, ctx.cameraPos, {0, 0, 1})
}

time: f32 = 0
renderQuad :: proc(position: float3, scale: float2, texture: TextureType, rotationVec: float3 = { 0, 0, 0 }, rotationAngle: f32 = 0) {
    gl.BindVertexArray(ctx.quad.vao)
    gl.UseProgram(ctx.shaders[.QUAD].program)
    gl.BindTexture(gl.TEXTURE_2D, ctx.textures[texture].?.texture)

    model := glm.mat4Translate(position)
    model = model * glm.mat4Scale({scale.x, scale.y, 0})

    if (rotationAngle != 0) {
        model = model * glm.mat4Rotate(rotationVec, rotationAngle)
    }
		
    u_transform := ctx.projMat * ctx.viewMat * model

    gl.UniformMatrix4fv(ctx.shaders[.QUAD].uniforms["u_transform"].location, 1, false, &u_transform[0, 0])
    gl.Uniform1f(ctx.shaders[.QUAD].uniforms["u_time"].location, time)
    time += 0.030

    gl.DrawElements(gl.TRIANGLES, i32(ctx.quad.indicesCount), gl.UNSIGNED_INT, nil)
}

renderMesh :: proc(mesh: ^Mesh) {
    for primitive in mesh.primitives {
        gl.BindVertexArray(primitive.vao)
        gl.UseProgram(ctx.shaders[.MESH].program)

        // todo: handle non textures
        hasTexture: i32 = 0
        if primitive.texture != nil {
            gl.BindTexture(gl.TEXTURE_2D, primitive.texture.?.texture)
            hasTexture = 1
        }
        
        u_projection := ctx.projMat * ctx.viewMat
        u_transform := mesh.mat
        color := primitive.color

        uniforms := ctx.shaders[.MESH].uniforms
        gl.UniformMatrix4fv(uniforms["u_projection"].location, 1, false, &u_projection[0, 0])
        gl.UniformMatrix4fv(uniforms["u_transform"].location, 1, false, &u_transform[0, 0])
        gl.Uniform1i(uniforms["u_hasTexture"].location, hasTexture)
        gl.Uniform4fv(uniforms["u_color"].location, 1, &color[0])
        //gl.Uniform3fv(uniforms["u_cameraPos"].location, 1, &ctx.cameraPos[0])

        gl.DrawElements(gl.TRIANGLES, i32(len(primitive.indices)), gl.UNSIGNED_INT, nil)
    }

    for &childMesh in mesh.children {
        renderMesh(&childMesh)
    }
}

// renderQube :: proc(position: float3, size: f32, rotationVec: float3 = { 0, 0, 0 }, rotationAngle: f32 = 0) {
//     renderQuad(position, { size, size }, rotationVec, rotationAngle)
// }