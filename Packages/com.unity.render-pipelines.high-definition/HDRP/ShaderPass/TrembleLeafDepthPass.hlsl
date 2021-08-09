#if (SHADERPASS != SHADERPASS_DEPTH_ONLY && SHADERPASS != SHADERPASS_SHADOWS)
#error SHADERPASS_is_not_correctly_define
#endif

#include "VertMesh.hlsl"

	UNITY_INSTANCING_BUFFER_START(Props)
	UNITY_DEFINE_INSTANCED_PROP(float,_DelayTime)
	UNITY_DEFINE_INSTANCED_PROP(float,_WaveAmountX)
	UNITY_DEFINE_INSTANCED_PROP(float,_WaveAmountY)
	UNITY_DEFINE_INSTANCED_PROP(float,_WaveAmountZ)
	UNITY_INSTANCING_BUFFER_END(unity_TrembleLeaf)

sampler2D _WaveEffectTex;
float _WaveCycleX;
float _WaveCycleY;
float _WaveCycleZ;

PackedVaryingsType Vert(AttributesMesh inputMesh)
{
	float3 p = inputMesh.positionOS;
	half3 waveColor = tex2Dlod(_WaveEffectTex, float4(inputMesh.uv0, 0, 0));

    float waveByUV = (inputMesh.uv0.x + 1 - inputMesh.uv0.y)/2;

    p.x += cos(((_Time.y + UNITY_ACCESS_INSTANCED_PROP(unity_TrembleLeaf, _DelayTime) + waveColor.r * 5) * _WaveCycleX)) * UNITY_ACCESS_INSTANCED_PROP(unity_TrembleLeaf, _WaveAmountX) * inputMesh.normalOS.x * waveByUV;
    p.y += sin(((_Time.y + UNITY_ACCESS_INSTANCED_PROP(unity_TrembleLeaf, _DelayTime) + waveColor.r * 5) * _WaveCycleY)) * UNITY_ACCESS_INSTANCED_PROP(unity_TrembleLeaf, _WaveAmountY) * inputMesh.normalOS.y * waveByUV;
    p.z += cos(((_Time.y + UNITY_ACCESS_INSTANCED_PROP(unity_TrembleLeaf, _DelayTime) + waveColor.r * 5) * _WaveCycleZ)) * UNITY_ACCESS_INSTANCED_PROP(unity_TrembleLeaf, _WaveAmountZ) * inputMesh.normalOS.z * waveByUV;

	inputMesh.positionOS = p;

	VaryingsType varyingsType;
	varyingsType.vmesh = VertMesh(inputMesh);
	return PackVaryingsType(varyingsType);
}

void Frag(PackedVaryingsToPS packedInput,
#ifdef WRITE_NORMAL_BUFFER
	OUTPUT_NORMALBUFFER(outNormalBuffer)
#else
	out float4 outColor : SV_Target
#endif
#ifdef _DEPTHOFFSET_ON
	, out float outputDepth : SV_Depth
#endif
)
{
	FragInputs input = UnpackVaryingsMeshToFragInputs(packedInput.vmesh);

	// input.positionSS is SV_Position
	PositionInputs posInput = GetPositionInput(input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS);

#ifdef VARYINGS_NEED_POSITION_WS
	float3 V = GetWorldSpaceNormalizeViewDir(input.positionRWS);
#else
	float3 V = 0; // Avoid the division by 0
#endif

	SurfaceData surfaceData;
	BuiltinData builtinData;
	GetSurfaceAndBuiltinData(input, V, posInput, surfaceData, builtinData);

#ifdef _DEPTHOFFSET_ON
	outputDepth = posInput.deviceDepth;
#endif

#ifdef WRITE_NORMAL_BUFFER
	ENCODE_INTO_NORMALBUFFER(surfaceData, posInput.positionSS, outNormalBuffer);
#elif defined(SCENESELECTIONPASS)
	// We use depth prepass for scene selection in the editor, this code allow to output the outline correctly
	outColor = float4(_ObjectId, _PassValue, 1.0, 1.0);
#else
	outColor = float4(0.0, 0.0, 0.0, 0.0);
#endif
}
