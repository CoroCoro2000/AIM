#if SHADERPASS != SHADERPASS_DISTORTION
#error SHADERPASS_is_not_correctly_define
#endif

#include "VertMesh.hlsl"

	UNITY_INSTANCING_BUFFER_START(Props)
	UNITY_DEFINE_INSTANCED_PROP(float,_DelayTime)
	UNITY_INSTANCING_BUFFER_END(unity_TrembleLeaf)

sampler2D _WaveEffectTex;
float _WaveCycleX;
float _WaveAmountX;
float _WaveCycleY;
float _WaveAmountY;
float _WaveCycleZ;
float _WaveAmountZ;

PackedVaryingsType Vert(AttributesMesh inputMesh)
{
    VaryingsType varyingsType;
    varyingsType.vmesh = VertMesh(inputMesh);
    return PackVaryingsType(varyingsType);
}

#ifdef TESSELLATION_ON

PackedVaryingsToPS VertTesselation(VaryingsToDS input)
{
    VaryingsToPS output;
    output.vmesh = VertMeshTesselation(input.vmesh);
    return PackVaryingsToPS(output);
}

#include "TessellationShare.hlsl"

#endif // TESSELLATION_ON

float4 Frag(PackedVaryingsToPS packedInput) : SV_Target
{
    FragInputs input = UnpackVaryingsMeshToFragInputs(packedInput.vmesh);

    // input.positionSS is SV_Position
    PositionInputs posInput = GetPositionInput(input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS);

#ifdef VARYINGS_NEED_POSITION_WS
    float3 V = GetWorldSpaceNormalizeViewDir(input.positionRWS);
#else
    float3 V = 0; // Avoid the division by 0
#endif

    // Perform alpha testing + get distortion
    SurfaceData surfaceData;
    BuiltinData builtinData;
    GetSurfaceAndBuiltinData(input, V, posInput, surfaceData, builtinData);

    float4 outBuffer;
    // Mark this pixel as eligible as source for distortion
    EncodeDistortion(builtinData.distortion, builtinData.distortionBlur, true, outBuffer);
    return outBuffer;
}
