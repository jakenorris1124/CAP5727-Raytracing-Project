Shader "Custom/Specular"
{
    Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		_Roughness ("Roughness", Range(0,200)) = 0.3
	}
    SubShader
    {
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
            float3 _LightPosition;
            float3 _CameraPosition;

            [shader("closesthit")]
            void HitShader(inout Payload payload : SV_RayPayload,
              AttributeData attributes : SV_IntersectionAttributes)
            {
               if (payload.depth + 1 == gMaxDepth || payload.isFeeler)
                {
                	payload.isFeeler = false;
                    return;
                }
                
                IntersectionVertex current;
                GetCurrentIntersectionVertex(attributes, current);

                float3x3 objectToWorld = (float3x3) ObjectToWorld3x4();
                float3 worldNormal = normalize(mul(objectToWorld, current.normalOS));

                float3 rayOrigin = WorldRayOrigin();
                float3 rayDirection = WorldRayDirection();

            	float3 reflectDirection = reflect(rayDirection, worldNormal);
            	float3 randomDirection = float3(nextRand(payload.seed), nextRand(payload.seed), nextRand(payload.seed)) * 2 -1;
            	
            	reflectDirection = normalize(reflectDirection + (_Roughness * randomDirection));
            	
                float3 worldPosition = rayOrigin + RayTCurrent() * rayDirection;

            	Payload scatter = DispatchRay(worldPosition, reflectDirection, payload);
            	
            	// Calculate light
            	float3 lightDirection = normalize(_LightPosition - worldPosition);
            	float3 specReflect = reflect(lightDirection, worldNormal);
            	float3 eyeDirection = normalize(abs(_CameraPosition - worldPosition));

            	float4 directLightContribution = GetDirectLightContribution(worldPosition, lightDirection, 1, payload.seed);

            	float angle = dot(eyeDirection, specReflect);
            	float lightIntensity = 0.7;
				float specularCoefficient = 0.2;
				float specular = lightIntensity * specularCoefficient * angle;
            	
            	//payload.color = (_Color + (directLightContribution * specular)) * scatter.color;
            	
                payload.color =  _Color * (scatter.color + (directLightContribution * specular));
            	payload.depth = scatter.depth;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
