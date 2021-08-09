	//
	//Œ©‚É‚­‚¢‚Ì‚Å•ª‚¯‚é
	///
	#ifndef LIGHTUP_INCLUDE
	#define LIGHTUP_INCLUDE

	#include "UnityCG.cginc"
	#include "Common.cginc"

	struct InputVertex
	{
		float4 vertex : POSITION;
		float4 color : COLOR;
		half2 uv	: TEXCOORD0;
	};

	struct OutputVertex
	{
		float4 position : SV_POSITION;
		float2 uv : TEXCOORD0;
		float4 color : TEXCOORD1;
	};

	OutputVertex Vert(InputVertex v)
	{
		OutputVertex o = (OutputVertex)0;
		o.position = UnityObjectToClipPos(v.vertex);
		o.uv = v.uv;
		o.color = v.color;
		return o;
	}

	fixed4 BloomSprite(float2 uv)
	{
		fixed4 color = fixed4(0.0f, 0.0f, 0.0f, 0.0f);
		fixed4 input0 = tex2D(_Input0, uv);
		fixed4 input1 = tex2D(_Input1, uv);

		color = tex2D(_MainTex, uv);

		fixed4 c0 = _Color0 * (input0.a * _Intensity0);
		fixed4 c1 = _Color1 * (input1.a * _Intensity1);
		color = 0.5f * (c0 + c1);
		return color;
	}

	fixed4 Frag(OutputVertex i) : SV_Target
	{
		float2 uv = i.uv;
		fixed4 c = BloomSprite(uv) * i.color;

		return c;
	}
#endif
