package main
import "libs/gltf2"

identity := matrix[4, 4]f32{
	1, 0, 0, 0, 
	0, 1, 0, 0, 
	0, 0, 1, 0, 
	0, 0, 0, 1,
}

loadGltfFile :: proc(filePath: string) {
	data, error := gltf2.load_from_file(filePath)
	
	switch err in error {
		case gltf2.JSON_Error: panic("json err")
		case gltf2.GLTF_Error: panic("gltf err")
	}
	defer gltf2.unload(data)

	generateMesh(data)
}

MeshVertex :: struct {
	pos: float3,
	normals: float3,
	texCoord: float2,
}

Mesh2 :: struct {
	vertices: [dynamic]MeshVertex,
	indices: [dynamic]u32,
}

generateMesh :: proc(data: ^gltf2.Data) {
	scene := data.scenes[0]
	rootNodeIndex := scene.nodes[0]
	rootNode := data.nodes[rootNodeIndex]
	mesh: Mesh2

	processNode(data, &rootNode, &mesh)

	createMesh(mesh.vertices[:], mesh.indices[:])

	delete(mesh.vertices)
	delete(mesh.indices)
}

processNode :: proc(data: ^gltf2.Data, node: ^gltf2.Node, mesh: ^Mesh2, globalTransformMat: matrix[4, 4]f32 = identity) {
	globalTransformMat := node.mat * globalTransformMat

	if node.mesh != nil {
		nodeMesh := data.meshes[node.mesh.?]
		
		for primitive in nodeMesh.primitives {
			positions: []float3
			normals: []float3			

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
				}
			}
			
			if primitive.indices != nil {
				prevVerticesCount := u32(len(mesh.vertices)) // add comment
			
				//reserve(&mesh.indices, len(mesh.indices) + len(indices))
				#partial switch indices in gltf2.buffer_slice(data, primitive.indices.?) {
					case []u32:
						for index in indices { append(&mesh.indices, prevVerticesCount + index) }
						//append(&mesh.indices, ..indices)
					case []u16:
						for index in indices { append(&mesh.indices, prevVerticesCount + u32(index)) }
					case:
						panic("wrong gltf indices format")
				}
			}

			// populate vertices
			reserve(&mesh.vertices, len(mesh.vertices) + len(positions))
			for i in 0..<len(positions) {
				pos := positions[i]
				append(&mesh.vertices, MeshVertex{
					pos = (globalTransformMat * [4]f32{ pos.x, pos.y, pos.z, 1 }).xyz,
					normals = normals[i],
				})
			}

		}
	}

    for childrenIndex in node.children {
		processNode(data, &data.nodes[childrenIndex], mesh, globalTransformMat)
	}
}
