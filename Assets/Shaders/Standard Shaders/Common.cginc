// Start: Acquired from https://github.com/SlightlyMad/SimpleDxrPathTracer

#ifndef COMMON_CGING
#define COMMON_CGING

#include "UnityRaytracingMeshUtils.cginc"

#ifndef SHADER_STAGE_COMPUTE
// raytracing scene
RaytracingAccelerationStructure  _ras;
#endif

#define RAYTRACING_OPAQUE_FLAG      0x0f
#define RAYTRACING_TRANSPARENT_FLAG 0xf0

#define LIGHT_FEELER_FLAG 0x00
#define LIGHT_FEELER_FIZZLED_FLAG 0x01
#define LIGHT_FEELER_GLASS_FLAG 0x02
#define PASSTHROUGH_FLAG 0x03
#define INDIRECT_LIGHT_FLAG 0x04
#define CAMERA_RAY_FLAG 0x05

enum reflect_direction
{
	specular, diffuse, refract
};

// max recursion depth
static const uint gMaxDepth = 8;

// compute random seed from one input
// http://reedbeta.com/blog/quick-and-easy-gpu-random-numbers-in-d3d11/
uint initRand(uint seed)
{
	seed = (seed ^ 61) ^ (seed >> 16);
	seed *= 9;
	seed = seed ^ (seed >> 4);
	seed *= 0x27d4eb2d;
	seed = seed ^ (seed >> 15);

	return seed;
}

// compute random seed from two inputs
// https://github.com/nvpro-samples/optix_prime_baking/blob/master/random.h
uint initRand(uint seed1, uint seed2)
{
	uint seed = 0;

	[unroll]
	for(uint i = 0; i < 16; i++)
	{
		seed += 0x9e3779b9;
		seed1 += ((seed2 << 4) + 0xa341316c) ^ (seed2 + seed) ^ ((seed2 >> 5) + 0xc8013ea4);
		seed2 += ((seed1 << 4) + 0xad90777d) ^ (seed1 + seed) ^ ((seed1 >> 5) + 0x7e95761e);
	}
	
	return seed1;
}

// next random number
// http://reedbeta.com/blog/quick-and-easy-gpu-random-numbers-in-d3d11/
float nextRand(inout uint seed)
{
	seed = 1664525u * seed + 1013904223u;
	return float(seed & 0x00FFFFFF) / float(0x01000000);
}

// ray payload
struct Payload
{
	// Color of the ray
	float4  color;
	// Random Seed
	uint seed;
	// Recursion depth
	uint depth;
	// Indicates the type of ray
	half flag;
};


// Triangle attributes
struct AttributeData
{
	// Barycentric value of the intersection
	float2 barycentrics;
};

// Macro that interpolate any attribute using barycentric coordinates
#define INTERPOLATE_RAYTRACING_ATTRIBUTE(A0, A1, A2, BARYCENTRIC_COORDINATES) (A0 * BARYCENTRIC_COORDINATES.x + A1 * BARYCENTRIC_COORDINATES.y + A2 * BARYCENTRIC_COORDINATES.z)

// Structure to fill for intersections
struct IntersectionVertex
{
	// Object space position of the vertex
	float3 positionOS;
	// Object space normal of the vertex
	float3 normalOS;
	// Object space normal of the vertex
	float3 tangentOS;
	// UV coordinates
	float2 texCoord0;
	float2 texCoord1;
	float2 texCoord2;
	float2 texCoord3;
	// Vertex color
	float4 color;
	// Value used for LOD sampling
	float  triangleArea;
	float  texCoord0Area;
	float  texCoord1Area;
	float  texCoord2Area;
	float  texCoord3Area;
};

// Fetch the intersetion vertex data for the target vertex
void FetchIntersectionVertex(uint vertexIndex, out IntersectionVertex outVertex)
{
	outVertex.positionOS = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributePosition);
	outVertex.normalOS   = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributeNormal);
	outVertex.tangentOS  = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributeTangent);
	outVertex.texCoord0  = UnityRayTracingFetchVertexAttribute2(vertexIndex, kVertexAttributeTexCoord0);
	outVertex.texCoord1  = UnityRayTracingFetchVertexAttribute2(vertexIndex, kVertexAttributeTexCoord1);
	outVertex.texCoord2  = UnityRayTracingFetchVertexAttribute2(vertexIndex, kVertexAttributeTexCoord2);
	outVertex.texCoord3  = UnityRayTracingFetchVertexAttribute2(vertexIndex, kVertexAttributeTexCoord3);
	outVertex.color      = UnityRayTracingFetchVertexAttribute4(vertexIndex, kVertexAttributeColor);
}

void GetCurrentIntersectionVertex(AttributeData attributeData, out IntersectionVertex outVertex)
{
	// Fetch the indices of the currentr triangle
	uint3 triangleIndices = UnityRayTracingFetchTriangleIndices(PrimitiveIndex());

	// Fetch the 3 vertices
	IntersectionVertex v0, v1, v2;
	FetchIntersectionVertex(triangleIndices.x, v0);
	FetchIntersectionVertex(triangleIndices.y, v1);
	FetchIntersectionVertex(triangleIndices.z, v2);

	// Compute the full barycentric coordinates
	float3 barycentricCoordinates = float3(1.0 - attributeData.barycentrics.x - attributeData.barycentrics.y, attributeData.barycentrics.x, attributeData.barycentrics.y);

	// Interpolate all the data
	outVertex.positionOS = INTERPOLATE_RAYTRACING_ATTRIBUTE(v0.positionOS, v1.positionOS, v2.positionOS, barycentricCoordinates);
	outVertex.normalOS   = INTERPOLATE_RAYTRACING_ATTRIBUTE(v0.normalOS, v1.normalOS, v2.normalOS, barycentricCoordinates);
	outVertex.tangentOS  = INTERPOLATE_RAYTRACING_ATTRIBUTE(v0.tangentOS, v1.tangentOS, v2.tangentOS, barycentricCoordinates);
	outVertex.texCoord0  = INTERPOLATE_RAYTRACING_ATTRIBUTE(v0.texCoord0, v1.texCoord0, v2.texCoord0, barycentricCoordinates);
	outVertex.texCoord1  = INTERPOLATE_RAYTRACING_ATTRIBUTE(v0.texCoord1, v1.texCoord1, v2.texCoord1, barycentricCoordinates);
	outVertex.texCoord2  = INTERPOLATE_RAYTRACING_ATTRIBUTE(v0.texCoord2, v1.texCoord2, v2.texCoord2, barycentricCoordinates);
	outVertex.texCoord3  = INTERPOLATE_RAYTRACING_ATTRIBUTE(v0.texCoord3, v1.texCoord3, v2.texCoord3, barycentricCoordinates);
	outVertex.color      = INTERPOLATE_RAYTRACING_ATTRIBUTE(v0.color, v1.color, v2.color, barycentricCoordinates);

	// Compute the lambda value (area computed in object space)
	outVertex.triangleArea  = length(cross(v1.positionOS - v0.positionOS, v2.positionOS - v0.positionOS));
	outVertex.texCoord0Area = abs((v1.texCoord0.x - v0.texCoord0.x) * (v2.texCoord0.y - v0.texCoord0.y) - (v2.texCoord0.x - v0.texCoord0.x) * (v1.texCoord0.y - v0.texCoord0.y));
	outVertex.texCoord1Area = abs((v1.texCoord1.x - v0.texCoord1.x) * (v2.texCoord1.y - v0.texCoord1.y) - (v2.texCoord1.x - v0.texCoord1.x) * (v1.texCoord1.y - v0.texCoord1.y));
	outVertex.texCoord2Area = abs((v1.texCoord2.x - v0.texCoord2.x) * (v2.texCoord2.y - v0.texCoord2.y) - (v2.texCoord2.x - v0.texCoord2.x) * (v1.texCoord2.y - v0.texCoord2.y));
	outVertex.texCoord3Area = abs((v1.texCoord3.x - v0.texCoord3.x) * (v2.texCoord3.y - v0.texCoord3.y) - (v2.texCoord3.x - v0.texCoord3.x) * (v1.texCoord3.y - v0.texCoord3.y));
}

// End: acquired from https://github.com/SlightlyMad/SimpleDxrPathTracer

float GetMagnitude(float3 input)
{
	float sum = pow(input.x, 2) + pow(input.y, 2) + pow(input.z, 2);

	return sqrt(sum);
}

float GetDistance(float3 start, float3 end)
{
	float xDifferenceSquared = pow(end.x - start.x, 2);
	float yDifferenceSquared = pow(end.y - start.y, 2);
	float zDifferenceSquared = pow(end.z - start.z, 2);

	return sqrt(xDifferenceSquared + yDifferenceSquared + zDifferenceSquared);
}

float3 GetRandomDirection(inout uint seed)
{
	return  float3(nextRand(seed), nextRand(seed), nextRand(seed)) * 2 - 1;
}

Payload DispatchRay(float3 worldPosition, float3 scatterDirection, Payload previous, int flag = INDIRECT_LIGHT_FLAG)
{
	RayDesc ray;
	ray.Origin = worldPosition; 
	ray.Direction = scatterDirection; 
	ray.TMin = 0.001;
	ray.TMax = 100;
                
	Payload payload;
	payload.color = float4(0, 0, 0, 0);
	payload.depth = previous.depth + 1;
	payload.seed = previous.seed;
	payload.flag = flag;

	if (flag == PASSTHROUGH_FLAG && previous.flag == CAMERA_RAY_FLAG)
	{
		payload.depth = 0;
	}

	if (payload.depth + 1 < gMaxDepth)
	{
		TraceRay(_ras, 0, 0xFFFFFFF, 0, 1, 0, ray, payload);
	}
	
	return payload;
}

float3 GetClosestLight(float3 worldPosition, float3 lightPositions[20], int numLights)
{
	float closest = 9999999;
	float closestIdx = 0;

	for (int i = 0; i < numLights; i++)
	{
		float magnitude = GetMagnitude(lightPositions[i] - worldPosition);

		if (magnitude < closest)
		{
			closest = magnitude;
			closestIdx = i;
		}
	}

	return lightPositions[closestIdx];
}

float4 GetDirectLightContribution(float3 worldPosition, float3 lightDirection, int samples, Payload previous)
{
	float4 directLightContribution = float4(0,0,0,0);
	
	for (int i = 0; i < samples; i++)
	{
		float3 feelerDirection = normalize(lightDirection + (GetRandomDirection(previous.seed) * 0.05));

		Payload feeler = DispatchRay(worldPosition, feelerDirection, previous, LIGHT_FEELER_FLAG);

		if (feeler.flag == LIGHT_FEELER_FLAG)
		{
			directLightContribution += feeler.color;
		}
	}

	directLightContribution /= samples;

	return directLightContribution;
}

float GetSpecularReflection(float3 worldPosition, float3 worldNormal, float3 lightDirection, float3 cameraPosition, float shininess)
{
	float3 specReflect = normalize(reflect(lightDirection, worldNormal));
	float3 eyeDirection = normalize(worldPosition - cameraPosition);

	float angle = saturate(dot(specReflect, eyeDirection));
	return pow(angle, (100 - shininess));
}


float GetRadiantEnergy(float3 lightDirection, float3 worldNormal, float lightIntensity, float diffuseCoefficient)
{
	float angle = dot(lightDirection, worldNormal) / (GetMagnitude(lightDirection) * GetMagnitude(worldNormal));
	return lightIntensity * diffuseCoefficient * angle;
}

#endif // COMMON_CGING