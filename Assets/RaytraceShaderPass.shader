Shader "Custom/RaytraceShaderPass"
{
    SubShader
    {
        Pass
        {
            Name "RaytracingPass"

            HLSLPROGRAM

            #pragma raytracing HitShader

            struct Payload
            {
                float4 color; 
            };
            
            struct AttributeData
            {
                float2 barycentrics; 
            };

            [shader("closesthit")]
            void HitShader(inout Payload payload : SV_RayPayload,
              AttributeData attributes : SV_IntersectionAttributes)
            {
                payload.color = 1;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
