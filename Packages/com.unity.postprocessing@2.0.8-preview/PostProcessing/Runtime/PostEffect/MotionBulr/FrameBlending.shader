//
// Kino/Motion - Motion blur effect
//
// Copyright (C) 2016 Keijiro Takahashi
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
Shader "Motion/FrameBlending"
{
	HLSLINCLUDE
#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
	// 元の画像
	TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
	float4 _MainTex_TexelSize;
	// 深度テクスチャ
	TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);

	// フレーム画像保存用
	TEXTURE2D_SAMPLER2D(_History1LumaTex, sampler_History1LumaTex);
	TEXTURE2D_SAMPLER2D(_History2LumaTex, sampler_History2LumaTex);
	TEXTURE2D_SAMPLER2D(_History3LumaTex, sampler_History3LumaTex);
	TEXTURE2D_SAMPLER2D(_History4LumaTex, sampler_History4LumaTex);

	TEXTURE2D_SAMPLER2D(_History1ChromaTex, sampler_History1ChromaTex);
	TEXTURE2D_SAMPLER2D(_History2ChromaTex, sampler_History2ChromaTex);
	TEXTURE2D_SAMPLER2D(_History3ChromaTex, sampler_History3ChromaTex);
	TEXTURE2D_SAMPLER2D(_History4ChromaTex, sampler_History4ChromaTex);

	// 強さ
	half _History1Weight;
	half _History2Weight;
	half _History3Weight;
	half _History4Weight;

	// 距離
	half _Distance;

#if !SHADER_API_GLES

	// MRT を使い画像を分解して保存(圧縮)
	struct CompressorOutput
	{
		half4 luma : SV_Target0;
		half4 chroma : SV_Target1;
	};

	CompressorOutput frag_FrameCompress(VaryingsDefault i)
	{
		float sw = _ScreenParams.x;     // Screen width
		float pw = _ScreenParams.z - 1; // Pixel width

		// RGB to YCbCr convertion matrix
		const half3 kY = half3(0.299, 0.587, 0.114);
		const half3 kCB = half3(-0.168736, -0.331264, 0.5);
		const half3 kCR = half3(0.5, -0.418688, -0.081312);

		// 0: even column, 1: odd column
		half odd = frac(i.texcoord.x * sw * 0.5) > 0.5;

		// Calculate UV for chroma componetns.
		// It's between the even and odd columns.
		float2 uv_c = i.texcoord.xy;
		uv_c.x = (floor(uv_c.x * sw * 0.5) * 2 + 1) * pw;

		// Sample the source texture.
		half3 rgb_y = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord).rgb;
		half3 rgb_c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv_c).rgb;


		// Convertion and subsampling
		CompressorOutput o = (CompressorOutput)0;
		o.luma = dot(kY, rgb_y);
		o.chroma = dot(lerp(kCB, kCR, odd), rgb_c) + 0.5;

		
		return o;
	}

#else

	// MRT might not be supported. Replace it with a null shader.
	half4 frag_FrameCompress(v2f_img i) : SV_Target
	{
		return 0;
	}

#endif
		struct VaryingsMulti
	{
		float4 vertex : SV_POSITION;
		float2 texcoord0 : TEXCOORD0;
		float2 texcoord1 : TEXCOORD1;
	};

	VaryingsMulti VertMulti(AttributesDefault v)
	{
		VaryingsMulti o;
		o.vertex = float4(v.vertex.xy, 0.0, 1.0);
		o.texcoord0 = TransformTriangleVertexToUV(v.vertex.xy);
		o.texcoord1 = TransformTriangleVertexToUV(v.vertex.xy);

#if UNITY_UV_STARTS_AT_TOP
		o.texcoord0 = o.texcoord0 * float2(1.0, -1.0) + float2(0.0, 1.0);
		o.texcoord1.y = 1.0 - o.texcoord1.y;
#endif
		return o;
	}

	// Sample luma-chroma textures and convert to RGB
	half3 DecodeHistory(float2 uvLuma, float2 uvCb, float2 uvCr, Texture2D lumaTex, SamplerState lumaSampler , Texture2D chromaTex, SamplerState chromaSampler)
	{
		half y = SAMPLE_TEXTURE2D(lumaTex, lumaSampler, uvLuma).r;
		half cb = SAMPLE_TEXTURE2D(chromaTex,chromaSampler, uvCb).r - 0.5;
		half cr = SAMPLE_TEXTURE2D(chromaTex, chromaSampler, uvCr).r - 0.5;
		return y + half3(1.402 * cr, -0.34414 * cb - 0.71414 * cr, 1.772 * cb);
	}

	// Frame blending fragment shader
	half4 frag_FrameBlending(VaryingsMulti i) : SV_Target
	{
		float sw = _MainTex_TexelSize.z; // Texture width
		float pw = _MainTex_TexelSize.x; // Texel width

		// UV for luma
		float2 uvLuma = i.texcoord1;

		// UV for Cb (even columns)
		float2 uvCb = i.texcoord1;
		uvCb.x = (floor(uvCb.x * sw * 0.5) * 2 + 0.5) * pw;

		// UV for Cr (even columns)
		float2 uvCr = uvCb;
		uvCr.x += pw;

		// 元画像取得
		half4 src = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord0);
		half3 acc = src.rgb;
		// 距離の設定
		half depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord0);
		// lerp(a,b,c)c = 0 => a, c = 1 => b
		depth = lerp(depth,1,_Distance);
		/*lerp(depth, 1, x); = depth ~ 1   if x= 1 => 1
		lerp(0, depth, x); = 0 ~ depth
		lerp(0,1,depth)*/

		// 圧縮したフレーム画像をもとに戻して元画像に合成
		acc += DecodeHistory(uvLuma, uvCb, uvCr, _History1LumaTex, sampler_History1LumaTex, _History1ChromaTex, sampler_History1ChromaTex) * _History1Weight * depth;
		acc += DecodeHistory(uvLuma, uvCb, uvCr, _History2LumaTex, sampler_History2LumaTex, _History2ChromaTex, sampler_History2ChromaTex) * _History2Weight * depth;
		acc += DecodeHistory(uvLuma, uvCb, uvCr, _History3LumaTex, sampler_History3LumaTex, _History3ChromaTex, sampler_History3ChromaTex) * _History3Weight * depth;
		acc += DecodeHistory(uvLuma, uvCb, uvCr, _History4LumaTex, sampler_History4LumaTex, _History4ChromaTex, sampler_History4ChromaTex) * _History4Weight * depth;
		acc /= 1 + (_History1Weight + _History2Weight + _History3Weight + _History4Weight)*depth;

		return half4(acc, src.a);
	}

		ENDHLSL

		Subshader
	{
		// Pass 0: Frame compression
		Pass
		{
			ZTest Always Cull Off ZWrite Off
			HLSLPROGRAM
			#pragma multi_compile _ UNITY_COLORSPACE_GAMMA
			#pragma vertex VertDefault
			#pragma fragment frag_FrameCompress
			ENDHLSL
		}
			// Pass 1: Frame blending
			Pass
		{
			ZTest Always Cull Off ZWrite Off
			HLSLPROGRAM
			#pragma multi_compile _ UNITY_COLORSPACE_GAMMA
			#pragma vertex VertMulti
			#pragma fragment frag_FrameBlending
			#pragma target 3.0
			ENDHLSL
		}
	}
}