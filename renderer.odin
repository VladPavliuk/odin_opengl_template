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

    renderObjects()

    // renderSprite({400,400}, {100,100}, {1,1,1,1}) // sample sprite

    renderText(fmt.tprintfln("%i fps", i32(1 / ctx.timeDelta)), { 0, 0 }, { 0, 0, 0 })

    if ctx.showUseLabel {
        renderText("E to use", { f32(ctx.windowSize.x) / 2, f32(ctx.windowSize.y) / 2 })
    }
    
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
    
    u_hasTexture: i32 = 1
    gl.Uniform1i(ctx.shaders[.QUAD].uniforms["u_hasTexture"].location, u_hasTexture)
    //gl.Uniform1f(ctx.shaders[.QUAD].uniforms["u_time"].location, time)
    time += 3 * f32(ctx.timeDelta)

    gl.DrawElements(gl.TRIANGLES, i32(ctx.quad.indicesCount), gl.UNSIGNED_INT, nil)
}

// renders in screen space
renderSprite :: proc(pos: float2, scale: float2, color: float4 = { 0, 0, 0, 0 }, texture: Maybe(TextureType) = nil, rotationAngle: f32 = 1) {
    gl.BindVertexArray(ctx.quad.vao)
    gl.UseProgram(ctx.shaders[.QUAD].program)

    modelTransf := glm.mat4Translate({ pos.x, pos.y, 0 }) * glm.mat4Rotate({ 0, 0, 1 }, rotationAngle) * glm.mat4Scale({ scale.x, scale.y, 1 })

    u_transform := ctx.uiProjMat * modelTransf

    gl.UniformMatrix4fv(ctx.shaders[.QUAD].uniforms["u_transform"].location, 1, false, &u_transform[0, 0])

    u_hasTexture: i32 = 0
    if texture != nil {
        u_hasTexture = 1

        if ctx.textures[texture.?] == nil { panic(fmt.tprintf("%i texture is not set", texture)) }
        gl.BindTexture(gl.TEXTURE_2D, ctx.textures[texture.?].?.texture)
    } else {
        color := color
        gl.Uniform4fv(ctx.shaders[.QUAD].uniforms["u_color"].location, 1, raw_data(&color))
    }
    
    gl.Uniform1i(ctx.shaders[.QUAD].uniforms["u_hasTexture"].location, u_hasTexture)

    gl.DrawElements(gl.TRIANGLES, i32(ctx.quad.indicesCount), gl.UNSIGNED_INT, nil)
}

renderObjects :: proc() {
    lightSources := make([dynamic]float3)
    defer delete(lightSources)

    { // calculate all light sources    
        for obj in ctx.objs { // select all light sources
            if obj.emitsLight { append(&lightSources, obj.pos) }
        }
        
        assert(ctx.lightsUBO != 0)
        gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, ctx.lightsUBO)
        gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, size_of(float3) * len(lightSources), raw_data(lightSources))
        gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, 0)
    }

    // render to default framebuffer
    gl.UseProgram(ctx.shaders[.MESH].program)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, ctx.lightsUBO)
    
    for &obj in ctx.objs {
        t := glm.mat4Translate(obj.pos)
        s := glm.mat4Scale(obj.scale)
        r := glm.mat4FromQuat(obj.rot)

        applyTransfToGameObj(&obj, t * r * s)
        
        mesh := &ctx.meshes[obj.mesh.type]
        assert(len(obj.mesh.nodeTransforms) == len(mesh.nodes))

        hasHighlight: i32 = (obj.readyToInteract) ? 1 : 0

        for node, nodeIndex in mesh.nodes {
            for primitive in node.primitives {
                gl.BindVertexArray(primitive.vao)

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
                gl.Uniform1i(uniforms["u_hasHighlight"].location, hasHighlight)
                gl.Uniform4fv(uniforms["u_color"].location, 1, &color[0])
                gl.Uniform3fv(uniforms["u_cameraPos"].location, 1, &ctx.camera.pos[0])
                gl.Uniform1i(uniforms["u_lightsCount"].location, i32(len(lightSources)))

                gl.DrawElements(gl.TRIANGLES, i32(len(primitive.indices)), gl.UNSIGNED_INT, nil)
            }
        }
    }

    // render to pick framebuffer
    gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, ctx.pickFBO.fbo)
    emptyPickVal: i32 = 0
    gl.ClearBufferiv(gl.COLOR, 0, &emptyPickVal) // COLOR_BUFFER_BIT does not work for int format texture, you should manualy specify default value
    gl.Clear(gl.DEPTH_BUFFER_BIT)
    gl.UseProgram(ctx.shaders[.PICK].program)
    for &obj in ctx.objs {
        mesh := &ctx.meshes[obj.mesh.type]

        for node, nodeIndex in mesh.nodes {
            for primitive in node.primitives {
                gl.BindVertexArray(primitive.vao)

                uniforms := ctx.shaders[.PICK].uniforms
                transformMat := ctx.projMat * ctx.viewMat * obj.mesh.nodeTransforms[nodeIndex]
                gl.UniformMatrix4fv(uniforms["u_transform"].location, 1, false, &transformMat[0, 0])
                gl.Uniform1i(uniforms["u_obj_id"].location, obj.id)

                gl.DrawElements(gl.TRIANGLES, i32(len(primitive.indices)), gl.UNSIGNED_INT, nil)
            }
        }
    }
    gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)  
}

// renderMesh :: proc(obj: ^GameObj) {
//     mesh := &ctx.meshes[obj.mesh.type]
//     assert(len(obj.mesh.nodeTransforms) == len(mesh.nodes))

//     hasHighlight: i32 = (obj.readyToInteract) ? 1 : 0

//     gl.UseProgram(ctx.shaders[.MESH].program)
//     for node, nodeIndex in mesh.nodes {
//         for primitive in node.primitives {
//             gl.BindVertexArray(primitive.vao)

//             hasTexture: i32 = 0
//             if primitive.texture != nil {
//                 gl.BindTexture(gl.TEXTURE_2D, primitive.texture.?.texture)
//                 hasTexture = 1
//             }

//             color := primitive.color
//             uniforms := ctx.shaders[.MESH].uniforms
//             transformMat := obj.mesh.nodeTransforms[nodeIndex]
//             gl.UniformMatrix4fv(uniforms["u_projection"].location, 1, false, &ctx.projMat[0, 0])
//             gl.UniformMatrix4fv(uniforms["u_view"].location, 1, false, &ctx.viewMat[0, 0])
//             gl.UniformMatrix4fv(uniforms["u_transform"].location, 1, false, &transformMat[0, 0])
//             gl.Uniform1i(uniforms["u_hasTexture"].location, hasTexture)
//             gl.Uniform1i(uniforms["u_hasHighlight"].location, hasHighlight)
//             gl.Uniform4fv(uniforms["u_color"].location, 1, &color[0])
//             //gl.Uniform3fv(uniforms["u_cameraPos"].location, 1, &ctx.cameraPos[0])

//             gl.DrawElements(gl.TRIANGLES, i32(len(primitive.indices)), gl.UNSIGNED_INT, nil)
//         }
//     }

//     // render to pick fbo
//     {
//         gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, ctx.pickFBO.fbo)
//         emptyPickVal: i32 = 0
//         gl.ClearBufferiv(gl.COLOR, 0, &emptyPickVal) // COLOR_BUFFER_BIT does not work for int format texture, you should manualy specify default value
//         gl.Clear(gl.DEPTH_BUFFER_BIT)
//         gl.UseProgram(ctx.shaders[.PICK].program)

//         for node, nodeIndex in mesh.nodes {
//             for primitive in node.primitives {
//                 gl.BindVertexArray(primitive.vao)

//                 uniforms := ctx.shaders[.PICK].uniforms
//                 transformMat := ctx.projMat * ctx.viewMat * obj.mesh.nodeTransforms[nodeIndex]
//                 gl.UniformMatrix4fv(uniforms["u_transform"].location, 1, false, &transformMat[0, 0])
//                 gl.Uniform1i(uniforms["u_obj_id"].location, obj.id)

//                 gl.DrawElements(gl.TRIANGLES, i32(len(primitive.indices)), gl.UNSIGNED_INT, nil)
//             }
//         }
//         gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)        
//     }
// }

readFromPickFbo :: proc() {
    gl.BindFramebuffer(gl.READ_FRAMEBUFFER, ctx.pickFBO.fbo)
    mousePos := getMousePos()
    gl.ReadPixels(mousePos.x, ctx.windowSize.y - mousePos.y - 1, 1, 1, gl.RED_INTEGER, gl.INT, &ctx.hoveredObj)
    
    depth: f32
    gl.ReadPixels(mousePos.x, ctx.windowSize.y - mousePos.y - 1, 1, 1, gl.DEPTH_COMPONENT, gl.FLOAT, &depth)

    gl.BindFramebuffer(gl.READ_FRAMEBUFFER, 0)

    if depth < 1 { // 1 means cursor points into empty space
        x_ndc := 2 * f32(mousePos.x) / f32(ctx.windowSize.x) - 1
        y_ndc := 1 - 2 * f32(mousePos.y) / f32(ctx.windowSize.y)
        z_ndc := 2 * depth - 1
        clipCoords: float4 = { x_ndc, y_ndc, z_ndc, 1 }

        invVP := glm.inverse(ctx.projMat * ctx.viewMat)
        worldCoords := invVP * clipCoords
        worldCoords /= worldCoords.w
        surfacePos: float3 = worldCoords.xyz // note: might be useful is we want to figure out exact point in the worlds where user wants to point to

        ctx.distanceToHoveredObj = glm.distance(ctx.camera.pos, surfacePos)
    } else {
        ctx.distanceToHoveredObj = 0
    }
}