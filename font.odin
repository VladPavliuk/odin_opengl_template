package main

import "core:os"
import "core:mem"
import "core:math"
import stbtt "vendor:stb/truetype"
import gl "vendor:OpenGL"

FontChar :: stbtt.bakedchar

FontData :: struct {
	ascent: f32,
	descent: f32,
	lineGap: f32,
    lineHeight: f32,
	scale: f32,

    chars: map[rune]FontChar,
    kerningTable: map[rune]map[rune]f32,

    // opengl staff
    vbo, vao, ebo: u32,
	indicesCount: int,
}

loadFont :: proc() {
    fileContent, success := os.read_entire_file_from_filename("C:\\Windows\\Fonts\\arial.ttf")
    assert(success)
    defer delete(fileContent)

    bitmapSize :: int2{ 1024, 1024 }

    tmpFontBitmap := make([]byte, bitmapSize.x * bitmapSize.y)
    defer delete(tmpFontBitmap)

    alphabet := "АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯабвгґдеєжзиіїйклмнопрстуфхцчшщьюя\t !\"#$%&'()*+,-./0123456789:;<=>?@[\\]^_`{|}~ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    font := BakeFontBitmapCustomChars(fileContent, 32.0, tmpFontBitmap, bitmapSize, alphabet)

    fontTexture: u32
    gl.GenTextures(1, &fontTexture)
    gl.BindTexture(gl.TEXTURE_2D, fontTexture)

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, bitmapSize.x, bitmapSize.y, 0, gl.RED, gl.UNSIGNED_BYTE, raw_data(tmpFontBitmap))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)

    gl.BindTexture(gl.TEXTURE_2D, 0)

    ctx.font = font
    ctx.textures[.FONT] = Texture{
        texture = fontTexture,
        width = int(bitmapSize.x),
        height = int(bitmapSize.y),
    }
    createFontMesh()
}

GetBakedFontQuad :: proc(chardata: FontChar, pw: int, ph: int, xpos: ^f32, ypos: ^f32) -> stbtt.aligned_quad {
   ipw := 1.0 / f32(pw)
   iph := 1.0 / f32(ph)
   b := chardata
   round_x := math.floor((xpos^ + b.xoff) + 0.5)
   round_y := math.floor((ypos^ + b.yoff) + 0.5)

   xpos^ += b.xadvance

   return stbtt.aligned_quad{
    x0 = round_x,
    y0 = round_y,
    x1 = round_x + f32(b.x1 - b.x0),
    y1 = round_y + f32(b.y1 - b.y0),
    s0 = f32(b.x0) * ipw,
    t0 = f32(b.y0) * iph,
    s1 = f32(b.x1) * ipw,
    t1 = f32(b.y1) * iph,
   }
}

BakeFontBitmapCustomChars :: proc(data: []byte, pixelHeight: f32, bitmap: []byte, bitmapSize: int2, charsList: string) -> FontData {
    x, y, bottomY: i32
    font: stbtt.fontinfo

    if !stbtt.InitFont(&font, raw_data(data), 0) {
        panic("Error font parsing")
    }
    x = 1
    y = 1
	bottomY = 1

    ascent, descent, lineGap: i32
    stbtt.GetFontVMetrics(&font, &ascent, &descent, &lineGap)
    
    scale := stbtt.ScaleForPixelHeight(&font, pixelHeight)
    fontData := FontData{
        ascent = f32(ascent) * scale,
        descent = f32(descent) * scale,
        lineGap = f32(lineGap) * scale,
        scale = scale,
    }
    fontData.lineHeight = fontData.ascent - fontData.descent

    for char in charsList {
        advance, lsb, x0, y0, x1, y1, gw, gh: i32

        g := stbtt.FindGlyphIndex(&font, char)

        stbtt.GetGlyphHMetrics(&font, g, &advance, &lsb)
        stbtt.GetGlyphBitmapBox(&font, g, fontData.scale, fontData.scale, &x0, &y0, &x1, &y1)

        gw = x1 - x0
        gh = y1 - y0
        if x + gw + 1 >= bitmapSize.x {
            y = bottomY
            x = 1
        }
        if y + gh + 1 >= bitmapSize.y {
            panic("Bitmap size is nout enough to fit font")
        }
        assert(x + gw < bitmapSize.x)
        assert(y + gh < bitmapSize.y)

        bitmapOffset := mem.ptr_offset(raw_data(bitmap), x + y * bitmapSize.y)
        // xtest: f32
        // ytest: f32
        // stbtt.MakeGlyphBitmapSubpixelPrefilter(&font, bitmapOffset, gw, gh, bitmapSize.x, fontData.scale, fontData.scale, 2.0, 2.0, 2, 2, &xtest, &ytest, g)
        // stbtt.MakeGlyphBitmapSubpixel(&font, bitmapOffset, gw, gh, bitmapSize.x, fontData.scale, fontData.scale, 1.0, 1.0, g)
        stbtt.MakeGlyphBitmap(&font, bitmapOffset, gw, gh, bitmapSize.x, fontData.scale, fontData.scale, g)

        fontData.chars[char] = FontChar{
            x0 = u16(x),
            y0 = u16(y),
            x1 = u16(x + gw),
            y1 = u16(y + gh),
            xadvance = scale * f32(advance),
            xoff = f32(x0),
            yoff = f32(y0),
        }

        x = x + gw + 1
        if y + gh + 1 > bottomY {
            bottomY = y + gh + 1
        }
    }

    for aChar in fontData.chars {
        glyphKernings := make(map[rune]f32)

        for bChar in fontData.chars {
            glyphKernings[bChar] = f32(stbtt.GetCodepointKernAdvance(&font, aChar, bChar))
        }

        fontData.kerningTable[aChar] = glyphKernings
    }

    // TODO: make this behaviour configurable
    // NOTE: Since tab symbol has a weird glyph sometimes, just rewrite visual part of it by space glyph
    // tabGlyph := fontData.chars['\t']

    // tabGlyph.offset = fontData.chars[' '].offset
    // tabGlyph.rect = fontData.chars[' '].rect

    // fontData.chars['\t'] = tabGlyph

    return fontData
}

createFontMesh :: proc() {
    Vertex :: struct {
        pos: float2,
        tex: float2,
    }

	indices := []u32{
		0, 1, 2,
		2, 3, 0,
	}
    
    vao, vbo, ebo: u32
	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)

    gl.BindVertexArray(vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, 4 * size_of(Vertex), nil, gl.DYNAMIC_DRAW)
    gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, tex))

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(indices[0]), raw_data(indices), gl.STATIC_DRAW)

    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)

    ctx.font.vao = vao
    ctx.font.vbo = vbo
    ctx.font.ebo = ebo
    ctx.font.indicesCount = len(indices)
}
