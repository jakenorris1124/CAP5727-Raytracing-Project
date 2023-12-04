Shader "Raytracing/Specular"
{
    Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		_Roughness ("Roughness", Range(0,200)) = 0.3
		_Shininess ("Shininess", Range(0, 100)) = 50
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
            float _Roughness;
            float _Shininess;
            float3 _LightPosition;
            float3 _CameraPosition;

            [shader("closesthit")]
            void HitShader(inout Payload payload : SV_RayPayload,
              AttributeData attributes : SV_IntersectionAttributes)
            {
               if (payload.depth + 1 == gMaxDepth || payload.flag == LIGHT_FEELER_FLAG || payload.flag == SUN_FEELER)
               {
	               payload.flag = LIGHT_FEELER_FIZZLED_FLAG;
               		return;
               }

            	IntersectionVertex current;
                GetCurrentIntersectionVertex(attributes, current);

                float3x3 objectToWorld = (float3x3) ObjectToWorld3x4();
                float3 worldNormal = normalize(mul(objectToWorld, current.normalOS));

                float3 rayOrigin = WorldRayOrigin();
                float3 rayDirection = WorldRayDirection();

            	float3 reflectDirection = reflect(rayDirection, worldNormal);
            	
            	reflectDirection = normalize(reflectDirection + (_Roughness * GetRandomDirection(payload.seed)));
            	
                float3 worldPosition = rayOrigin + RayTCurrent() * rayDirection;

            	Payload scatter = DispatchRay(worldPosition, reflectDirection, payload);
            	
            	// Calculate light
            	float3 lightDirection = normalize(_LightPosition - worldPosition);
            	float4 directLightContribution = GetDirectLightContribution(worldPosition, lightDirection, 1, payload);
				float specular = GetSpecularReflection(worldPosition, worldNormal, lightDirection, _CameraPosition, _Shininess);
            	
            	//payload.color = (_Color + (directLightContribution * specular)) * scatter.color;
            	
                payload.color =  _Color * ((directLightContribution * specular) + scatter.color);
            	payload.depth = scatter.depth;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
