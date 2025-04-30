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

    renderQuad({-0.3, -0.3 + 1, 1}, {1,1}, .DOGGO, {0, 0.0, 1}, 0)
    t += f32(ctx.timeDelta)

    renderQuad({-.6, 0.5 + 1, math.cos(h) / 4 + 1 }, {1,1}, .DOGGO_2, {0, 0.0, 1}, t / 2)

    renderQuad({0.4, 0.3 + 1, 0.9 }, {1,1}, .DOGGO_3, {0, 0.0, 1}, -t * 2)

    h += f32(ctx.timeDelta)

    for &obj in ctx.objs {
        t := glm.mat4Translate(obj.pos)
        s := glm.mat4Scale(obj.scale)
        r := glm.mat4FromQuat(obj.rot)

        applyTransfToGameObj(&obj, t * r * s)
        
        renderMesh(&obj)
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

renderMesh :: proc(obj: ^GameObj) {
    mesh := &ctx.meshes[obj.mesh.type]
    assert(len(obj.mesh.nodeTransforms) == len(mesh.nodes))

    for node, nodeIndex in mesh.nodes {
        for primitive in node.primitives {
            gl.BindVertexArray(primitive.vao)
            gl.UseProgram(ctx.shaders[.MESH].program)

            // todo: handle non textures
            hasTexture: i32 = 0
            if primitive.texture != nil {
                gl.BindTexture(gl.TEXTURE_2D, primitive.texture.?.texture)
                hasTexture = 1
            }
            
            color := primitive.color
            uniforms := ctx.shaders[.MESH].uniforms
            transformMat := obj.mesh.nodeTransforms[nodeIndex]
            gl.UniformMatrix4fv(uniforms["u_projection"].location, 1, false, &ctx.projMat[0, 0])
            gl.UniformMatrix4fv(uniforms["u_view"].location, 1, false, &ctx.viewMat[0, 0])
            gl.UniformMatrix4fv(uniforms["u_transform"].location, 1, false, &transformMat[0, 0])
            gl.Uniform1i(uniforms["u_hasTexture"].location, hasTexture)
            gl.Uniform4fv(uniforms["u_color"].location, 1, &color[0])
            //gl.Uniform3fv(uniforms["u_cameraPos"].location, 1, &ctx.cameraPos[0])

            gl.DrawElements(gl.TRIANGLES, i32(len(primitive.indices)), gl.UNSIGNED_INT, nil)
        }
    }

    // for &childMesh in mesh.children {
    //     renderMesh(&childMesh)
    // }
}
