Shader "Raytracing/Diffuse"
{
    Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
	}
    SubShader
    {
    	Tags { "RenderType"="Opaque"}
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
            float3 _LightPosition;
            float3 _SunPosition;
            int hasSun;
            int indirectLighting;

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
            	float3 worldPosition = rayOrigin + RayTCurrent() * rayDirection;
            	
            	float3 scatterDirection = normalize(worldNormal + GetRandomDirection(payload.seed));
            	Payload scatter = DispatchRay(worldPosition, scatterDirection, payload);
            	
            	// Calculate light
            	float3 lightDirection = normalize(_LightPosition - worldPosition);
            	
            	float3 sunDirection;
	            if (hasSun == 1)
	            {
		            sunDirection = normalize(_SunPosition - worldPosition);
            		sunDirection = normalize(sunDirection + GetRandomDirection(payload.seed) * 0.005);
	            }

	            const float radiantEnergy = GetRadiantEnergy(lightDirection, worldNormal, 0.7, 0.8);
	            float4 directLightContribution = GetDirectLightContribution(worldPosition, lightDirection, 1, payload);
            	
	            if (hasSun == 1)
	            {
		            directLightContribution += DispatchRay(worldPosition, sunDirection, payload, SUN_FEELER).color;
	            }
            	
            	float4 emittedLight = saturate(directLightContribution * radiantEnergy);
            	
	            if (indirectLighting == 1)
	            {
		            emittedLight += scatter.color;
	            }
            	
            	payload.color =  _Color * (emittedLight);
            	payload.depth = scatter.depth;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
