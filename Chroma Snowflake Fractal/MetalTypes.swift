
import simd

typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

typealias uint32 = UInt32

extension float3: sizeable { }
extension float4: sizeable { }

extension uint32: sizeable { }

protocol sizeable{ }
extension sizeable{
    static var size: Int{
        return MemoryLayout<Self>.size
    }
    
    static var stride: Int{
        return MemoryLayout<Self>.stride
    }
    
    static func size(_ count: Int)->Int{
        return MemoryLayout<Self>.size * count
    }
    
    static func stride(_ count: Int)->Int{
        return MemoryLayout<Self>.stride * count
    }
}

struct CustomVertex: sizeable {
    var position: float3
    var color: float4
}
