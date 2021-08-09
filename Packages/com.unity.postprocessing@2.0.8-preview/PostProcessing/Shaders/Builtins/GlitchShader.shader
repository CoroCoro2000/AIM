// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// This work is licensed under a Creative Commons Attribution 3.0 Unported License.
// http://creativecommons.org/licenses/by/3.0/deed.en_GB
//
// You are free:
//
// to copy, distribute, display, and perform the work
// to make derivative works
// to make commercial use of the work


Shader "Hidden/PostProcessing/GlitchShader" {
	Properties{
		_DispTex("Base (RGB)", 2D) = "bump" {}
		_Intensity("Glitch Intensity", Range(0.1, 1.0)) = 1
		_ColorIntensity("Color Bleed Intensity", Range(0.1, 1.0)) = 0.2
	}

				
	HLSLINCLUDE
	#include "../StdLib.hlsl"

	TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);


	uniform sampler2D _DispTex;
	float _Intensity;
	float _ColorIntensity;

	half4 direction;

	float filterRadius;
	float flip_up, flip_down;
	float displace;
	float scale;

	half4 Frag(VaryingsDefault i) : SV_Target
	{
		half4 normal = tex2D(_DispTex, i.texcoordStereo.xy * scale);

		i.texcoordStereo.y -= (1 - (i.texcoordStereo.y + flip_up)) * step(i.texcoordStereo.y, flip_up) + (1 - (i.texcoordStereo.y - flip_down)) * step(flip_down, i.texcoordStereo.y);

		i.texcoordStereo.xy += (normal.xy - 0.5) * displace * _Intensity;

		half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);
		half4 redcolor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo.xy + direction.xy * 0.01 * filterRadius * _ColorIntensity);
		half4 greencolor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo.xy - direction.xy * 0.01 * filterRadius * _ColorIntensity);

		color += half4(redcolor.r, redcolor.b, redcolor.g, 1) *  step(filterRadius, -0.001);
		color *= 1 - 0.5 * step(filterRadius, -0.001);

		color += half4(greencolor.g, greencolor.b, greencolor.r, 1) *  step(0.001, filterRadius);
		color *= 1 - 0.5 * step(0.001, filterRadius);

		return color;
	}


	ENDHLSL

	SubShader
	{
		Cull Off ZWrite Off ZTest Always

			// 0 - Fullscreen triangle copy
		Pass
		{
			HLSLPROGRAM

			#pragma vertex VertDefault
			#pragma fragment Frag

		ENDHLSL
		}

	}
}