Shader "Custom/Diffuse"
{
    Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
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
            float3 _LightPosition;
            int indirectLighting;

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
            	float3 worldPosition = rayOrigin + RayTCurrent() * rayDirection;

            	float3 randomDirection = float3(nextRand(payload.seed), nextRand(payload.seed), nextRand(payload.seed)) * 2 -1;
            	float3 scatterDirection = normalize(worldNormal + randomDirection);
            	Payload scatter = DispatchRay(worldPosition, scatterDirection, payload);
            	
            	// Calculate light
            	float3 lightDirection = normalize(_LightPosition - worldPosition);

	            const float radiantEnergy = GetRadiantEnergy(lightDirection, worldNormal, 0.7, 0.8);
	            const float4 directLightContribution = GetDirectLightContribution(worldPosition, lightDirection, 1, payload.seed);
            	const float4 emittedLight = saturate(directLightContribution * radiantEnergy);

            	float4 test = emittedLight;
	            if (indirectLighting == 1)
	            {
		            test += scatter.color;
	            }
            	
            	payload.color =  _Color * (test);
            	payload.depth = scatter.depth;
		            
            	//payload.color = (_Color + (directLightContribution * radiantEnergy)) * scatter.color;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
