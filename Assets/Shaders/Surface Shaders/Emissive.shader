Shader "Custom/Emissive"
{
    Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		_Brightness ("Brightness", Range(0,1)) = 1
	}
    SubShader
    {
    	Tags {"RenderType"="Opaque"}
        Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "Assets/Shaders/Standard Shaders/SimpleLit.cginc"
			ENDCG
		}
        Pass
        {
            Name "RaytracingPass"

            HLSLPROGRAM

            #pragma raytracing HitShader
            #include "Assets/Shaders/Standard Shaders/Common.cginc"

            float4 _Color;
            float _Brightness;

            [shader("closesthit")]
            void HitShader(inout Payload payload : SV_RayPayload, AttributeData attributes : SV_IntersectionAttributes)
            {
                if (payload.depth + 1 == gMaxDepth || payload.flag == LIGHT_FEELER_FLAG)
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
            	
            	Payload scatter = DispatchRay(worldPosition, reflectDirection, payload);
            	
                
                payload.color = _Color * _Brightness;
            	payload.depth = scatter.depth;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
