#ifndef LIGHTWEIGHT_PASS_DEPTH_ONLY_INCLUDED
#define LIGHTWEIGHT_PASS_DEPTH_ONLY_INCLUDED

#include "LWRP/ShaderLibrary/Core.hlsl"

CBUFFER_START(props)
float4 _UVColorInfo;
    CBUFFER_END

struct VertexInput
{
    float4 position : POSITION;
    float2 texcoord : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput
{
    float2 uv : TEXCOORD0;
    float4 clipPos : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

    VertexOutput DepthOnlyVertex(VertexInput v)
    {
        VertexOutput o = (VertexOutput) 0;
        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
        o.clipPos = TransformObjectToHClip(v.position.xyz);
        return o;
    }

    half4 DepthOnlyFragment(VertexOutput IN, bool facing : SV_IsFrontFace) : SV_TARGET
    {

        float4 uvInfo = _UVColorInfo;

        float2 uv = IN.uv;

        uv = float2(uv.x * uvInfo.x + uvInfo.z, uv.y * uvInfo.y + uvInfo.w);

        Alpha(SampleAlbedoAlpha(uv, TEXTURE2D_PARAM(_MainTex, sampler_MainTex)).a, _Color, _Cutoff);
        return 0;
    }
#endif
