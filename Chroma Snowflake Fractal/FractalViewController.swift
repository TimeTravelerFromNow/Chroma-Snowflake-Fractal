
import MetalKit

class SnowflakeRenderer: NSObject {
    private var _time: Float = 0
    private let snowflakeColor = float4(0.85,0.86, 0.9, 1.0)
    private static var CustomVertexDescriptor: MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        var offset: Int = 0
        //Position
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        offset += float3.size
        //Color
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = offset
        
        vertexDescriptor.layouts[0].stride = CustomVertex.stride
        return vertexDescriptor
    }
    
    private var vertices:  [ CustomVertex ] = []
    
    private var _indices: [ uint32 ] = []
    // need to store indices in the order of the sides on the outside
    private var _outsideIndices: [ uint32 ] = []
    
    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    var vertexBuffer: MTLBuffer!
    private var _indexBuffer: MTLBuffer!

    var pipelineState: MTLRenderPipelineState!
    var timer: Float = 0
    
    var iterationNo: Int = 0
    
    func resetTriangle() {
        vertices = [
            CustomVertex( position: float3(-0.5,-0.5,0.0), color: snowflakeColor ),
            CustomVertex( position: float3(0.5, -0.5, 0.0), color: snowflakeColor ),
            CustomVertex( position: float3(0.0,0.366,0.0), color: snowflakeColor )
            // tan(pi/3) * 0.5 (the height) - 0.5 ( the offset )
        ]
        _indices = [
            0, 1, 2
        ]
        _outsideIndices = [
            0 , 1, 2
        ]
        iterationNo = 0
    }
    
    init(metalView: MTKView) {
      guard
        let device = MTLCreateSystemDefaultDevice(),
        let commandQueue = device.makeCommandQueue() else {
          fatalError("GPU not available")
      }
        SnowflakeRenderer.device = device
        SnowflakeRenderer.commandQueue = commandQueue
      metalView.device = device
      
      let library = device.makeDefaultLibrary()
      let vertexFunction = library?.makeFunction(name: "vertex_main")
      let fragmentFunction = library?.makeFunction(name: "fragment_main")
      
      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.vertexFunction = vertexFunction
      pipelineDescriptor.fragmentFunction = fragmentFunction
      pipelineDescriptor.vertexDescriptor = SnowflakeRenderer.CustomVertexDescriptor
        
      pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
      do {
        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
      } catch let error {
        fatalError(error.localizedDescription)
      }
      
      super.init()
      metalView.clearColor = MTLClearColor(red: 0.1, green: 0.1,
                                           blue: 0.1, alpha: 1.0)
      metalView.delegate = self
        
      resetTriangle()
    }
    
    func updateBuffers()
    {
        vertexBuffer = SnowflakeRenderer.device.makeBuffer(bytes: &vertices, length: CustomVertex.stride(vertices.count))
        _indexBuffer = SnowflakeRenderer.device.makeBuffer(bytes: self._indices,
                                                length: uint32.stride(self._indices.count),
                                                options: [])
    }
    
    func kochIteration() {
        // new vertex amount
        let newVertexCount = _outsideIndices.count + _outsideIndices.count * 3
        
        var newIndexArr = [ uint32 ].init(repeating: 0, count: newVertexCount)
        var newVerticesArr = [ CustomVertex ].init(repeating: CustomVertex(position: float3(0,0,0), color: float4(0.5,0.5,1.0,1.0)), count: newVertexCount)
        
        var newOutsideIndicesArr = newIndexArr
        
        //save old indices only for drawing new triangles
        for i in 0..<_indices.count {
            newIndexArr[i] = _indices[i]
            newVerticesArr[i] = vertices[i]
        }
        
        var newTriOffset = 1
        var newIndexOffset = uint32(_outsideIndices.count)
        // construct new positions, save the triangle
        for i in 0..<_outsideIndices.count - 1 {
            let firstIndex = Int(_outsideIndices[i])
            let secondIndex = Int(_outsideIndices[i + 1])
            let newTriangle = newTri(v0: vertices[firstIndex].position, v1: vertices[secondIndex].position )
            
            newVerticesArr[Int(newIndexOffset)]     = CustomVertex(position: newTriangle[0], color: snowflakeColor)
            newVerticesArr[Int(newIndexOffset) + 1] = CustomVertex(position: newTriangle[1], color: snowflakeColor)
            newVerticesArr[Int(newIndexOffset) + 2] = CustomVertex(position: newTriangle[2], color: snowflakeColor)

            // populate new outside indices array in place
            newOutsideIndicesArr[newTriOffset - 1] = _outsideIndices[i]// old index ( using - 1 )
            newOutsideIndicesArr[newTriOffset] = newIndexOffset
            newOutsideIndicesArr[newTriOffset + 1] = newIndexOffset + 1
            newOutsideIndicesArr[newTriOffset + 2] = newIndexOffset + 2
            newOutsideIndicesArr[newTriOffset + 3] = _outsideIndices[i + 1]// old index
            
            // store these new indices for the drawing index buffer
            newIndexArr[Int(newIndexOffset)] = newIndexOffset
            newIndexArr[Int(newIndexOffset) + 1] = newIndexOffset + 1
            newIndexArr[Int(newIndexOffset) + 2] = newIndexOffset + 2
            
            newTriOffset += 4 // skip existing index by adding 4
            newIndexOffset += 3 // we only added 3 new vertices
        }
        // finish the triangle by adding the triangle between the first and last vertex
        
            let newTriangle = newTri(v0: vertices[_outsideIndices.count - 1].position, v1: vertices[0].position )
            
            newVerticesArr[Int(newIndexOffset)]     = CustomVertex(position: newTriangle[0], color: snowflakeColor)
            newVerticesArr[Int(newIndexOffset) + 1] = CustomVertex(position: newTriangle[1], color: snowflakeColor)
            newVerticesArr[Int(newIndexOffset) + 2] = CustomVertex(position: newTriangle[2], color: snowflakeColor)
             // old vertex already stored in very first iteration

            
            newOutsideIndicesArr[newTriOffset - 1] = _outsideIndices[_outsideIndices.count - 1]// old index
            newOutsideIndicesArr[newTriOffset] = newIndexOffset
            newOutsideIndicesArr[newTriOffset + 1] = newIndexOffset + 1
            newOutsideIndicesArr[newTriOffset + 2] = newIndexOffset + 2
            // old index already made in very first iteration ( should == 0 )
        newIndexArr[Int(newIndexOffset)] = newIndexOffset
        newIndexArr[Int(newIndexOffset) + 1] = newIndexOffset + 1
        newIndexArr[Int(newIndexOffset) + 2] = newIndexOffset + 2
        // done with last triangle
        
        //override stored variables and write buffers
    _indices = newIndexArr
        _outsideIndices = newOutsideIndicesArr
        vertices = newVerticesArr
        
        updateBuffers()
        if (iterationNo == 1) {
            print(vertices.map() { CGPoint(x: CGFloat($0.position.x),y: CGFloat($0.position.y)) })
            print(_indices)
        }
        iterationNo += 1
    }
    
    func newTri(v0 : float3, v1: float3) -> [float3] {
        var triOut = [float3].init(repeating: float3(0), count: 3)
        let sideV = v1 - v0
        let sideVLength = sqrt(sideV.x * sideV.x + sideV.y * sideV.y)
        
        triOut[0] = v0 + sideV / 3
        //        /  |
        //      /    | h      tan(60) = h / base = h / ( 0.5 * ( sideVLength / 3 ) )
        //    /60deg_|        h = tan(60) * all_that
        let h = tan( .pi / 3) * ( sideVLength / 6)
        triOut[1] = v0 + 0.5 * sideV + h * normalize(ninetyDegRotated(sideV))
        triOut[2] = v0 + 2 * sideV / 3
        return triOut
    }
    
    func ninetyDegRotated(_ sideVector: float3) -> float3 {
        let ninetyDegRotMat: [[Float]] = [
            [ 0, 1 ], // cos(pi/2) , - sin(pi/2)
            [ -1, 0 ]       //  sin(pi/2) , cos(pi/2)
        ]
        
        return float3( sideVector.y * ninetyDegRotMat[0][1], sideVector.x * ninetyDegRotMat[1][0] , sideVector.z )
    }
  }

  extension SnowflakeRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {
        _time += 1 / 9
      guard
        let descriptor = view.currentRenderPassDescriptor,
        let commandBuffer = SnowflakeRenderer.commandQueue.makeCommandBuffer(),
        let renderEncoder =
        commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
          return
      }
      
      updateBuffers()
      
      renderEncoder.setRenderPipelineState(pipelineState)
      renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&_time,
                                     length: MemoryLayout<Float>.stride,
                                     index: 1)
        
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: _indices.count, indexType: .uint32, indexBuffer: _indexBuffer, indexBufferOffset: 0)
//        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
      
      renderEncoder.endEncoding()
      guard let drawable = view.currentDrawable else {
        return
      }
      commandBuffer.present(drawable)
      commandBuffer.commit()
    }
}

class FractalViewController: MTKView {
    
    var renderer: SnowflakeRenderer?
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        
        self.renderer = SnowflakeRenderer(metalView: self)
    }
    @IBAction func snowflakeButtonPressed(_ sender: Any) {
        renderer?.kochIteration()
    }
   
    @IBAction func resetButtonPressed(_ sender: Any) {
        renderer?.resetTriangle()
    }
}


