#include <metal_stdlib>
using namespace metal;


struct VertexIn {
  float3 position [[attribute(0)]];
    float4 color [[ attribute(1) ]];
    
};

struct RasterizerData {
    float4 position [[ position ]];
    float4 color;
};


vertex RasterizerData vertex_main(const VertexIn vertexIn [[ stage_in ]],
                                  uint vid [[vertex_id]],
                                  constant float &timer [[ buffer(1) ]]) {
    RasterizerData rd;
    rd.position = float4(vertexIn.position.xyz, 1);
    
    rd.color = vertexIn.color;

    return rd;
}



vertex RasterizerData vertex_main_chroma(const VertexIn vertexIn [[ stage_in ]],
                                  uint vid [[vertex_id]],
                                  constant float &timer [[ buffer(1) ]]) {
    RasterizerData rd;
    rd.position = float4(vertexIn.position.xyz, 1);
    
    float unique = float(vid % 3) / 3.0 ;
    float unique2 = float(vid % 2) / 3.0;

    float uniqueF = 0.15 * sin(timer * ( unique + 1.0 ) ) + 0.85;
    float uniqueF2 = 0.15 * sin(timer * ( unique2 + 1.0 ) ) + 0.85;
    float uniqueF3 = 0.15 * cos(timer * ( unique + 1.0 ) ) + 0.85;
    rd.color.r = clamp(uniqueF, .7,1.0);
    rd.color.g = uniqueF2;
    rd.color.b = uniqueF3;

    return rd;
}

fragment half4 fragment_main(const RasterizerData fragmentIn [[ stage_in ]] ) {
  return half4(fragmentIn.color);
}

