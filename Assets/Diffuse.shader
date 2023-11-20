Shader "Custom/Diffuse"
{
    Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		_LightPosition ("Light Position", Vector) = (0, 0, 0)
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
            float3 _LightPosition;

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

            	// Calculate light
            	float3 lightDirection = normalize(_LightPosition - worldPosition);

            	float angle = dot(lightDirection, worldNormal) / (GetMagnitude(lightDirection) * GetMagnitude(worldNormal));
            	float lightIntensity = 0.7;
				float diffuseCoefficient = 0.8;
				float radiantEnergy = lightIntensity * diffuseCoefficient * angle;

            	float4 directLightContribution = GetDirectLightContribution(worldPosition, lightDirection, 1, payload.seed);
            	
            	Payload scatter = DispatchRay(worldPosition, scatterDirection, payload);
            	payload.color =  _Color * (directLightContribution * radiantEnergy);
            	payload.depth = scatter.depth;
		            
            	//payload.color = (_Color + (directLightContribution * radiantEnergy)) * scatter.color;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
