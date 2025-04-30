package main
import "libs/gltf2"
import "core:encoding/json"
import "core:os"
import "core:fmt"
import "core:slice"
import glm "core:math/linalg/glsl"

loadGltfFile :: proc(filePath: string) -> Mesh {
	if !os.exists(filePath) { panic(fmt.tprintf("%s file does not exist!", filePath)) }

	data, error := gltf2.load_from_file(filePath)
	
	switch err in error {
		case gltf2.JSON_Error: {
			print(err)
			panic("json err")
		}
		case gltf2.GLTF_Error: {
			print(err)
			panic("gltf err")
		}
	}
	defer gltf2.unload(data)

	scene := data.scenes[0]
	mesh: Mesh

	{ // find root node
		rootScene := data.scenes[data.scene != nil ? data.scene.? : 0]

		mesh.rootNodeIndex = i32(rootScene.nodes[0])
	}

	mesh.animations = processAnimations(data)
	mesh.nodes = processNodes(data)

	createMesh(&mesh)

	return mesh
}

processAnimations :: proc(data: ^gltf2.Data) -> []MeshAnimation {
	meshAnimations := make([]MeshAnimation, len(data.animations))
	animationEndTime: f32 = 0.0

	for animation, animationIndex in data.animations {
		meshAnimation: MeshAnimation
		meshAnimation.channels = make([]MeshAnimationChannel, len(animation.channels))

		for channel, channelIndex in animation.channels {
			sampler := animation.samplers[channel.sampler]
			
			timestamps := slice.clone(gltf2.buffer_slice(data, sampler.input).([]f32))
			lastTimestamp := timestamps[len(timestamps) - 1]
			if lastTimestamp > animationEndTime { animationEndTime = lastTimestamp }

			transformations: union { []float3, []float4 }

			#partial switch output in gltf2.buffer_slice(data, sampler.output) {
			case []float3: transformations = slice.clone(output)
			case []float4: transformations = slice.clone(output)
			}

			transfType: MeshAnimationTransfType
			#partial switch channel.target.path { // todo: no Weights!
			case .Rotation: transfType = .ROTATION
			case .Scale: transfType = .SCALE
			case .Translation: transfType = .TRANSLATE
			}

			meshAnimation.channels[channelIndex] = MeshAnimationChannel {
				nodeIndex = i32(channel.target.node.?), // todo: can be empty
				transf = transfType,
				timestamps = timestamps,
				values = transformations,
			}
		}

		meshAnimation.duration = animationEndTime

		meshAnimations[animationIndex] = meshAnimation
	}

	return meshAnimations
}

processNodes :: proc(data: ^gltf2.Data) -> []MeshNode {
	meshNodes := make([]MeshNode, len(data.nodes))

	for node, nodeIndex in data.nodes {
		meshNode: MeshNode

		meshNode.children = make([]i32, len(node.children))
		for a, b in node.children { meshNode.children[b] = i32(a) }
		
		if node.mat != identityMat { // matrix is actually provided other staff should be ignored
			// meshNode.translation = glm.mat4Translate({ 0, 0, 0 }) // 
			// meshNode.scale = glm.mat4Scale({ 1, 1, 1 })
			// meshNode.rotation = glm.mat4FromQuat(quaternion128(0))

			meshNode.mat = node.mat
		} else {
			meshNode.translation = glm.mat4Translate(node.translation)
			meshNode.rotation = glm.mat4FromQuat(node.rotation)
			meshNode.scale = glm.mat4Scale(node.scale)
		
			meshNode.mat = meshNode.translation * meshNode.rotation * meshNode.scale
		}
		
		if node.mesh != nil {
			nodeMesh := data.meshes[node.mesh.?]
			
			meshNode.primitives = make([]MeshPrimitive, len(nodeMesh.primitives))

			for primitive, primitiveIndex in nodeMesh.primitives {
				meshVertices: [dynamic]MeshVertex
				meshIndices: [dynamic]u32
				glTexture: Maybe(Texture) = nil
				meshColor: float4

				positions: []float3
				normals: []float3
				texCoords: []float2

				for attributeName, attributeValue in primitive.attributes {
					switch attributeName {
					case "NORMAL":
						buffer, ok := gltf2.buffer_slice(data, attributeValue).([]float3)
						assert(ok)

						normals = buffer
					case "POSITION":
						buffer, ok := gltf2.buffer_slice(data, attributeValue).([]float3)
						assert(ok)

						positions = buffer
					case "TEXCOORD_0":
						buffer, ok := gltf2.buffer_slice(data, attributeValue).([]float2)
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

				meshNode.primitives[primitiveIndex] = MeshPrimitive{
					vertices = meshVertices,
					indices = meshIndices,
					texture = glTexture,
					color = meshColor,
				}
			}

		}

		meshNodes[nodeIndex] = meshNode
		// for childrenIndex in node.children {
		// 	childMesh: Mesh
		// 	processNode(data, &data.nodes[childrenIndex], &childMesh, globalTransformMat)

		// 	append(&mesh.children, childMesh)
		// }	
	}

	return meshNodes
}
