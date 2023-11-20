Shader "Custom/Emissive"
{
    Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		_Brightness ("Brightness", Range(0,1)) = 1
	}
    SubShader
    {
        Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "SimpleLit.cginc"
			ENDCG
		}
        Pass
        {
            Name "RaytracingPass"

            HLSLPROGRAM

            #pragma raytracing HitShader
            #include "Common.cginc"

            float4 _Color;
            float _Brightness;

            [shader("closesthit")]
            void HitShader(inout Payload payload : SV_RayPayload, AttributeData attributes : SV_IntersectionAttributes)
            {
                if (payload.depth + 1 == gMaxDepth || payload.isFeeler)
                {
                	payload.color = _Color * _Brightness;
                    return;
                }
                
                IntersectionVertex current;
                GetCurrentIntersectionVertex(attributes, current);

                float3x3 objectToWorld = (float3x3) ObjectToWorld3x4();
                float3 worldNormal = normalize(mul(objectToWorld, current.normalOS));

                float3 rayOrigin = WorldRayOrigin();
                float3 rayDirection = WorldRayDirection();

                float3 reflectDirection = normalize(worldNormal);
            	
                float3 worldPosition = rayOrigin + RayTCurrent() * rayDirection;

                RayDesc ray;
                ray.Origin = worldPosition; 
                ray.Direction = reflectDirection; 
                ray.TMin = 0.001;
                ray.TMax = 100;
                
                Payload scatter;
                scatter.color = float4(0, 0, 0, 0);
                scatter.depth = payload.depth + 1;
            	scatter.seed = payload.seed;
            	scatter.isFeeler = false;
                
                TraceRay(_ras, 0, 0xFFFFFFF, 0, 1, 0, ray, scatter);
                
                payload.color = _Color * _Brightness;
            	payload.depth = scatter.depth;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
