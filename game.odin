package main

GameObj :: struct {
    pos, scale: float3,
    rot: struct {
        vec: float3,
        angle: f32,
    },
    meshType: MeshType,
}

initObjs :: proc() {
    scale: f32 = .01
    obj: GameObj = { 
        pos = { 0, 0, 0 },
        scale = { scale, scale, scale },
        rot = {{ 1, 0, 0 }, -1.6},
    }

    append(&ctx.objs, obj)
}

updateObjs :: proc() {
    // @(static)
    // t: f32 = 50.0
    // t += 10.1
    // print(t)

    // for &obj in ctx.objs {
        
    //     obj.pos.x = t
    // }
}

deleteObjs :: proc() {
    delete(ctx.objs)
}