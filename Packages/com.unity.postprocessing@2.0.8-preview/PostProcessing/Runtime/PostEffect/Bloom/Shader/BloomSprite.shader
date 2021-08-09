
Shader "Bloom2D/BloomSprite"
{
	HLSLINCLUDE

	#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
	TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
	TEXTURE2D_SAMPLER2D(_BloomTex, sampler_BloomTex);
	TEXTURE2D_SAMPLER2D(_SceneTex, sampler_SceneTex);
	float4 _MainTex_TexelSize;

	float4 _Color;

	float _Threshold;
	float _Intensity;

	float _Blur;

	float _Speed;

	// 0 pass-------------------------------------------------------------------------
	struct InputVertex{
		float3 position : POSITION;
		float2 texcoord: TEXCOORD0;
		float2 tex:TEXCOORD1;
	};
	struct OutputVertex{
		float4 vertex : SV_POSITION;
		float2 texcoord : TEXCOORD0;
		float2 tex:TEXCOORD1;
	};

	OutputVertex Vert(InputVertex i)
	{
		OutputVertex o = (OutputVertex)0;

		o.vertex = float4(i.position.x, - 1 * i.position.y, 0.0, 1.0);
		o.texcoord = i.texcoord;

		return o;
	}

	float4 Frag(VaryingsDefault i) : SV_Target
	{
		float4 color = float4(0.0f, 0.0f, 0.0f, 0.0f);

		color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);

		color *=  _Speed ;

		return color;
	}

	// 関数----------------------------------------------------------------------------
	half4 sampleMain(float2 uv)
	{
		return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
	}

	// 対角線上の4点からサンプリングした色の平均値を返す
	half4 sampleBox(float2 uv, float delta)
	{
		delta += _Blur;
		float4 offset = _MainTex_TexelSize.xyxy * float2(-delta, delta).xxyy;
		half4 sum = sampleMain(uv + offset.xy) + sampleMain(uv + offset.zy) + sampleMain(uv + offset.xw) + sampleMain(uv + offset.zw);
		return sum * 0.25f;
	}
	// 明度を返す
	half getBrightness(half3 color)
	{
		return max(color.r, max(color.g, color.b));
	}
	//-------------------------------------------------------------------------------
		ENDHLSL
		
		SubShader
	{
			//Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off 
			ZTest Always
			Cull Off
			//// 0 Pass ////
			Pass
		{
			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag
			ENDHLSL
		}

			//// 1 Pass////
			Pass
		{

			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment Frag1

			half4 Frag1(VaryingsDefault v) : SV_Target
			{
				half4 col = half4(1,1,1,1);
				col = sampleBox(v.texcoord, 1.0);
				half brightness = getBrightness(col.rgb);

				// 明度がThresholdより大きいピクセルだけブルームの対象とする
				half contribution = max(0, brightness - _Threshold);
				contribution /= max(brightness, 0.00001);

				col.a = 1;
				return col * contribution;
			}
			ENDHLSL
		}

			//// 2 Pass ////
			Pass
		{
			//Blend A B		A:新しい画像、B:元の画像
			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment Frag2

			half4 Frag2(VaryingsDefault v) : SV_Target
			{
				half4 col = half4(1,1,1,1);
				col = sampleBox(v.texcoord, 1.0);
				return col;

			}
			ENDHLSL
		}

				//// 3 Pass ////
			Pass
		{
			Blend One One
			//Blend A B		A:新しい画像、B:元の画像
			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment Frag3

			half4 Frag3(VaryingsDefault v) : SV_Target
			{
				half4 col = half4(1,1,1,1);
				col = sampleBox(v.texcoord, 0.5);
				return col;

			}
			ENDHLSL
		}
			/// 4 Pass ///
			Pass
		{
			//Blend A B		A:新しい画像、B:元の画像
			//Blend SrcAlpha OneMinusSrcAlpha
			//Blend SrcAlpha One
			//Blend SrcAlpha OneMinusSrcColor
			//Blend SrcAlpha OneMinusSrcAlpha
			Blend One Zero
			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment Frag4

			half4 lerp4(half4 source, half4 destination, float alpha)
			{
				half4 col = 1;
				col.r = lerp(source.r, destination.r, alpha);
				col.g = lerp(source.g, destination.g, alpha);
				col.b = lerp(source.b, destination.b, alpha);

				return col;
			}

			half4 Frag4(VaryingsDefault v) : SV_Target
			{
				half4 col = SAMPLE_TEXTURE2D(_BloomTex, sampler_BloomTex, v.texcoord);
				half4 sceneColor = SAMPLE_TEXTURE2D(_SceneTex, sampler_SceneTex, v.texcoord);

				col = lerp4(sceneColor, col, col.a);

				col += sampleBox(v.texcoord, 0.5) * _Intensity;
				
				return col;
			}

			ENDHLSL

		}
	}
}
