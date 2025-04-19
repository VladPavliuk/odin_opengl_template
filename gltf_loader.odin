package main
import "libs/gltf2"
import "core:encoding/json"
import glm "core:math/linalg/glsl"

loadGltfFile :: proc(filePath: string) -> Mesh {
	data, error := gltf2.load_from_file(filePath)
	
	switch err in error {
		case gltf2.JSON_Error: panic("json err")
		case gltf2.GLTF_Error: panic("gltf err")
	}
	defer gltf2.unload(data)

	scene := data.scenes[0]
	mesh: Mesh

	for node in scene.nodes {
		rootNode := data.nodes[node]
		processNode(data, &rootNode, &mesh)
	}

	createMesh(&mesh)

	return mesh
}

// quat_to_mat4 :: proc(q: quaternion128) -> mat4 {
//     x, y, z, w := q.x, q.y, q.z, q.w

//     xx := x * x
//     yy := y * y
//     zz := z * z
//     xy := x * y
//     xz := x * z
//     yz := y * z
//     wx := w * x
//     wy := w * y
//     wz := w * z

//     return mat4{
//         1 - 2*(yy + zz), 2*(xy - wz),     2*(xz + wy),     0,
//         2*(xy + wz),     1 - 2*(xx + zz), 2*(yz - wx),     0,
//         2*(xz - wy),     2*(yz + wx),     1 - 2*(xx + yy), 0,
//         0,               0,               0,               1,
//     }
// }

processNode :: proc(data: ^gltf2.Data, node: ^gltf2.Node, mesh: ^Mesh, globalTransformMat: matrix[4, 4]f32 = identityMat) {
	globalTransformMat := globalTransformMat

	if node.mat != identityMat { // matrix is actually provided
		globalTransformMat = globalTransformMat * node.mat
	} else {
		t := glm.mat4Translate(node.translation)
		r := glm.mat4FromQuat(node.rotation)
		s := glm.mat4Scale(node.scale)
	
		a := t * r * s
	
		globalTransformMat = globalTransformMat * node.mat * a
	}
	
	mesh.origMat = globalTransformMat
	mesh.mat = mesh.origMat

	if node.mesh != nil {
		nodeMesh := data.meshes[node.mesh.?]

		for primitive in nodeMesh.primitives {
			meshVertices: [dynamic]MeshVertex
			meshIndices: [dynamic]u32
			glTexture: Maybe(Texture)
			meshColor: float4

			positions: []float3
			normals: []float3
			texCoords: []float2

			for attributeName, attributeValue in primitive.attributes {
				switch attributeName {
				case "NORMAL":
					buffer, ok := gltf2.buffer_slice(data, attributeValue).([][3]f32)
					assert(ok)

					normals = buffer
				case "POSITION":
					buffer, ok := gltf2.buffer_slice(data, attributeValue).([][3]f32)
					assert(ok)

					positions = buffer
				case "TEXCOORD_0":
					buffer, ok := gltf2.buffer_slice(data, attributeValue).([][2]f32)
					assert(ok)

					texCoords = buffer
				}
			}
			
			if primitive.indices != nil {
				#partial switch indices in gltf2.buffer_slice(data, primitive.indices.?) {
					case []u32:
						reserve(&meshIndices, len(indices))
						//for index in indices { append(&mesh.indices, prevVerticesCount + index) }
						append(&meshIndices, ..indices)
					case []u16:
						reserve(&meshIndices, len(indices))
						for index in indices { append(&meshIndices, u32(index)) }
					case:
						panic("wrong gltf indices format")
				}
			}

			// populate vertices
			reserve(&meshVertices, len(positions))
			for i in 0..<len(positions) {
				append(&meshVertices, MeshVertex{
					pos = positions[i],
					normals = normals[i],
					texCoord = len(texCoords) != 0 ? texCoords[i] : { 0, 0 },
				})
			}

			_loadTexture :: proc(data: ^gltf2.Data, index: u32) -> (Maybe(Texture), bool) {
				image := data.images[index]

				imageData: []byte
				if image.uri != nil {
					imageData = image.uri.([]byte)
				} else if image.buffer_view != nil {
					bufferView := data.buffer_views[image.buffer_view.?]
					
					buffer := data.buffers[bufferView.buffer]
					imageData = buffer.uri.([]byte)[bufferView.byte_offset:bufferView.byte_offset+bufferView.byte_length]
				} else { panic("Image data is not present") }
				
				return loadTextureFromImage(imageData)
			}
			
			// todo: these IFs look stupid
			if primitive.material != nil {
				material := data.materials[primitive.material.?]
				
				if material.extensions != nil && "KHR_materials_pbrSpecularGlossiness" in material.extensions.(json.Object) {
					pbr := material.extensions.(json.Object)["KHR_materials_pbrSpecularGlossiness"].(json.Object)

					if "diffuseTexture" in pbr {
						textureId := pbr["diffuseTexture"].(json.Object)["index"]

						if texture, ok := _loadTexture(data, u32(textureId.(f64))); ok { glTexture = texture }
					}
				} else if metallicRoughness, ok := material.metallic_roughness.?; ok { // KHR_materials_pbrSpecularGlossiness has higher priority then metallicRoughness
					meshColor = metallicRoughness.base_color_factor

					if metallicRoughness.base_color_texture != nil {
						textureIndex := metallicRoughness.base_color_texture.?.index
						texture := data.textures[textureIndex]

						if texture.source != nil {
							if texture, ok := _loadTexture(data, u32(texture.source.?)); ok { glTexture = texture }
						}
					}
				}
			}

			append(&mesh.primitives, MeshPrimitive{
				vertices = meshVertices,
				indices = meshIndices,
				texture = glTexture,
				color = meshColor,
			})
		}
	}

    for childrenIndex in node.children {
		childMesh: Mesh
		processNode(data, &data.nodes[childrenIndex], &childMesh, globalTransformMat)

		append(&mesh.children, childMesh)
	}
}
