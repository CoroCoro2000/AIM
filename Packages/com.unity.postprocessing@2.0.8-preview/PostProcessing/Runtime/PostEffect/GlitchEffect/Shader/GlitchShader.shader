Shader "Glitch/GlitchShader"
{
	HLSLINCLUDE
	#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
	TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
	float _ChromAberrAmountX;
	float _ChromAberrAmountY;
	// 波状変位
	half4 _DisplacementAmount;
	float _WavyDisplFreq;

	// ランダムストライプ
	float _RightStripesAmount;
	float _RightStripesFill;
	float _LeftStripesAmount;
	float _LeftStripesFill;

	// ランダム数値生成
	float rand(float2 co) 
	{
		return frac(sin(dot(co, float2(12.9898, 78.233))) * 43758.5453);
	}

	half4 Frag(VaryingsDefault v) :SV_Target
	{
		half2 chromAberrAmount = half2(_ChromAberrAmountX, _ChromAberrAmountY);
	
		// ランダムストライプ
		//step a < b == 0
		//     a > b == 1
		//     a = b == 0
		//     a >= b ? 1 : 0
		float rightStripes = floor(v.texcoord.y * _RightStripesAmount);
		rightStripes = 1 - step(_RightStripesFill, rand(float2(rightStripes, rightStripes)));
		float leftStripes = floor(v.texcoord.y * _LeftStripesAmount);
		leftStripes = step(_LeftStripesFill, rand(float2(leftStripes, leftStripes)));

		// 波状変位
		
		float4 wavyDispl = lerp(half4(1, 0, 0, 1), half4(0, 1, 0, 1), (sin(v.texcoord.y * _WavyDisplFreq)+1)/2);
		float2 displUV = (_DisplacementAmount.xy * rightStripes) /*- (_DisplacementAmount.xy* leftStripes)*/;
		displUV += float2((_DisplacementAmount.zw * wavyDispl.r) - (_DisplacementAmount.zw * wavyDispl.g));
		//return float4(rightStripes, rightStripes, rightStripes, 1);

		// 色収差
		half colR = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,float2(v.texcoord + displUV + chromAberrAmount)).r;
		half colG = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, v.texcoord + displUV).g;
		half colB = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, float2(v.texcoord + displUV - chromAberrAmount)).b;
		return half4(colR, colG, colB, 1);

	}
		ENDHLSL

		SubShader
	{
		ZWrite Off
			Blend One Zero
			ZTest Always
			Cull Off
			Pass
		{
			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment Frag
			ENDHLSL
		}
	}
}
