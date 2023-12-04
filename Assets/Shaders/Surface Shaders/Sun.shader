Shader "Raytracing/Sun"
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
            	payload.color = _Color;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
