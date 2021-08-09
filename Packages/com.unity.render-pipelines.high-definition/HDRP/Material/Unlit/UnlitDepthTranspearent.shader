/*====================================================*/
// 内容		：ゴースト用シェーダー
// ファイル	：UnlitDepthTransparent.shader
//
// Copyright (C) 根本 勇斗 All Rights Reserved.
/*----------------------------------------------------*/
//〔更新履歴〕
// 2018/1/11 〔根本 勇斗〕新規作成
// 2018/2/01 〔根本 勇斗〕カメラとの距離が近づいたときディザ抜きする処理を追加
// 2018/2/03 〔根本 勇斗〕ディザ抜きの計算式を変更
/*====================================================*/
Shader "HDRenderPipeline/UnlitDepthTransparent"
{
	Properties
	{
		// Versioning of material to help for upgrading
		[HideInInspector] _HdrpVersion("_HdrpVersion", Float) = 1

		// Be careful, do not change the name here to _Color. It will conflict with the "fake" parameters (see end of properties) required for GI.
		_UnlitColor("Color", Color) = (1,1,1,1)
		_UnlitColorMap("ColorMap", 2D) = "white" {}

	_Position("Position",vector)=(0,0,0,0)

	[HDR] _EmissiveColor("EmissiveColor", Color) = (0, 0, 0)
		_EmissiveColorMap("EmissiveColorMap", 2D) = "white" {}

	_DistortionVectorMap("DistortionVectorMap", 2D) = "black" {}
	[ToggleUI] _DistortionEnable("Enable Distortion", Float) = 0.0
		[ToggleUI] _DistortionOnly("Distortion Only", Float) = 0.0
		[ToggleUI] _DistortionDepthTest("Distortion Depth Test Enable", Float) = 1.0
		[Enum(Add, 0, Multiply, 1)] _DistortionBlendMode("Distortion Blend Mode", Int) = 0
		[HideInInspector] _DistortionSrcBlend("Distortion Blend Src", Int) = 0
		[HideInInspector] _DistortionDstBlend("Distortion Blend Dst", Int) = 0
		[HideInInspector] _DistortionBlurSrcBlend("Distortion Blur Blend Src", Int) = 0
		[HideInInspector] _DistortionBlurDstBlend("Distortion Blur Blend Dst", Int) = 0
		[HideInInspector] _DistortionBlurBlendMode("Distortion Blur Blend Mode", Int) = 0
		_DistortionScale("Distortion Scale", Float) = 1
		_DistortionVectorScale("Distortion Vector Scale", Float) = 2
		_DistortionVectorBias("Distortion Vector Bias", Float) = -1
		_DistortionBlurScale("Distortion Blur Scale", Float) = 1
		_DistortionBlurRemapMin("DistortionBlurRemapMin", Float) = 0.0
		_DistortionBlurRemapMax("DistortionBlurRemapMax", Float) = 1.0

		// Transparency
		[ToggleUI] _PreRefractionPass("PreRefractionPass", Float) = 0.0

		[ToggleUI]  _AlphaCutoffEnable("Alpha Cutoff Enable", Float) = 0.0
		_AlphaCutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
		_TransparentSortPriority("_TransparentSortPriority", Float) = 0

		// Blending state
		[HideInInspector] _SurfaceType("__surfacetype", Float) = 0.0
		[HideInInspector] _BlendMode("__blendmode", Float) = 0.0
		[HideInInspector] _SrcBlend("__src", Float) = 1.0
		[HideInInspector] _DstBlend("__dst", Float) = 0.0
		[HideInInspector] _ZWrite("__zw", Float) = 1.0
		[HideInInspector] _CullMode("__cullmode", Float) = 2.0
		[HideInInspector] _ZTestModeDistortion("_ZTestModeDistortion", Int) = 8

		[ToggleUI] _EnableFogOnTransparent("Enable Fog", Float) = 0.0
		[ToggleUI] _DoubleSidedEnable("Double sided enable", Float) = 0.0

		// Stencil state
		[HideInInspector] _StencilRef("_StencilRef", Int) = 2 // StencilLightingUsage.RegularLighting  (fixed at compile time)
		[HideInInspector] _StencilWriteMask("_StencilWriteMask", Int) = 7 // StencilMask.Lighting  (fixed at compile time)
		[HideInInspector] _StencilRefMV("_StencilRefMV", Int) = 128 // StencilLightingUsage.RegularLighting  (fixed at compile time)
		[HideInInspector] _StencilWriteMaskMV("_StencilWriteMaskMV", Int) = 128 // StencilMask.ObjectsVelocity  (fixed at compile time)

																				// Caution: C# code in BaseLitUI.cs call LightmapEmissionFlagsProperty() which assume that there is an existing "_EmissionColor"
																				// value that exist to identify if the GI emission need to be enabled.
																				// In our case we don't use such a mechanism but need to keep the code quiet. We declare the value and always enable it.
																				// TODO: Fix the code in legacy unity so we can customize the beahvior for GI
		_EmissionColor("Color", Color) = (1, 1, 1)

		// HACK: GI Baking system relies on some properties existing in the shader ("_MainTex", "_Cutoff" and "_Color") for opacity handling, so we need to store our version of those parameters in the hard-coded name the GI baking system recognizes.
		_MainTex("Albedo", 2D) = "white" {}
	_Color("Color", Color) = (1,1,1,1)
		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
	}

		HLSLINCLUDE

#pragma target 4.5
#pragma only_renderers d3d11 ps4 xboxone vulkan metal switch

		//-------------------------------------------------------------------------------------
		// Variant
		//-------------------------------------------------------------------------------------

#pragma shader_feature _ALPHATEST_ON
		// #pragma shader_feature _DOUBLESIDED_ON - We have no lighting, so no need to have this combination for shader, the option will just disable backface culling

#pragma shader_feature _EMISSIVE_COLOR_MAP

		// Keyword for transparent
#pragma shader_feature _SURFACE_TYPE_TRANSPARENT
#pragma shader_feature _ _BLENDMODE_ALPHA _BLENDMODE_ADD _BLENDMODE_PRE_MULTIPLY
#pragma shader_feature _ENABLE_FOG_ON_TRANSPARENT

		//enable GPU instancing support
#pragma multi_compile_instancing

		//-------------------------------------------------------------------------------------
		// Define
		//-------------------------------------------------------------------------------------

#define UNITY_MATERIAL_UNLIT // Need to be define before including Material.hlsl

		//-------------------------------------------------------------------------------------
		// Include
		//-------------------------------------------------------------------------------------

#include "CoreRP/ShaderLibrary/Common.hlsl"
#include "../../ShaderVariables.hlsl"
#include "../../ShaderPass/FragInputs.hlsl"
#include "../../ShaderPass/ShaderPass.cs.hlsl"

		//-------------------------------------------------------------------------------------
		// variable declaration
		//-------------------------------------------------------------------------------------

#include "../../Material/Unlit/UnlitProperties.hlsl"

		// All our shaders use same name for entry point
#pragma vertex Vert
#pragma fragment Frag

		ENDHLSL

		SubShader
	{
		// This tags allow to use the shader replacement features
		Tags{ "RenderPipeline" = "HDRenderPipeline" "RenderType" = "HDUnlitShader" }

		// Caution: The outline selection in the editor use the vertex shader/hull/domain shader of the first pass declare. So it should not be the meta pass.

		Pass
	{
		Name "SceneSelectionPass"
		Tags{ "LightMode" = "SceneSelectionPass" }

		Cull[_CullMode]

		ZWrite On

		HLSLPROGRAM

		// Note: Require _ObjectId and _PassValue variables

#define SHADERPASS SHADERPASS_DEPTH_ONLY
#define SCENESELECTIONPASS // This will drive the output of the scene selection shader
#include "../../Material/Material.hlsl"
#include "ShaderPass/UnlitDepthPass.hlsl"
#include "UnlitData.hlsl"
#include "../../ShaderPass/ShaderPassDepthOnly.hlsl"

		ENDHLSL
	}
			
			Pass
		{
			Name "ZPrePass"
			Tags{"LightMode" = "ZPrePass"}

			Cull[_CullMode]

			ZWrite On

			ColorMask 0 // We don't have WRITE_NORMAL_BUFFER for unlit, but as we bind a buffer we shouldn't write into it.

			HLSLPROGRAM

#define SHADERPASS SHADERPASS_DEPTH_ONLY
#include "../../Material/Material.hlsl"
#include "ShaderPass/UnlitDepthPass.hlsl"
#include "UnlitData.hlsl"
#if (SHADERPASS != SHADERPASS_DEPTH_ONLY && SHADERPASS != SHADERPASS_SHADOWS)
#error SHADERPASS_is_not_correctly_define
#endif

#include "../../ShaderPass/VertMesh.hlsl"

			PackedVaryingsType Vert(AttributesMesh inputMesh)
		{
			VaryingsType varyingsType;
			varyingsType.vmesh = VertMesh(inputMesh);
			return PackVaryingsType(varyingsType);
		}

		sampler3D _DitherMaskLOD;
		vector _Position;
		void Frag(PackedVaryingsToPS packedInput,float4 vpos : SV_Position,
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

			//ディザ画像が4*4*16pixelなのでx,yを4分の一に割る
			vpos *= 0.25;

			//カメラとの距離10からフェードする(渡されるのがポジションの中心なので少しずらす)
			float dist = distance(_Position.xyz, _WorldSpaceCameraPos) / 10.5 - 0.05;

			//範囲制限(0~1を超えるとUVがループしてフェードがおかしくなるため)
			float clipDest = (int)(dist >= 1.0);
			clipDest -= (int)(dist < 0.0);

			//カメラとの距離でUVをずらしたディザ画像のa値を参照し、計算結果が0未満ならピクセルを描画しない
			clip(-0.5 + tex3D(_DitherMaskLOD, float3(vpos.xy, dist * 0.9375)).a +clipDest);

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

			ENDHLSL
}

		Pass
	{
		Name "Depth prepass"
		Tags{ "LightMode" = "DepthForwardOnly" }

		Cull[_CullMode]

		ZWrite On

		ColorMask 0 // We don't have WRITE_NORMAL_BUFFER for unlit, but as we bind a buffer we shouldn't write into it.

		HLSLPROGRAM

#define SHADERPASS SHADERPASS_DEPTH_ONLY
#include "../../Material/Material.hlsl"
#include "ShaderPass/UnlitDepthPass.hlsl"
#include "UnlitData.hlsl"
#if (SHADERPASS != SHADERPASS_DEPTH_ONLY && SHADERPASS != SHADERPASS_SHADOWS)
#error SHADERPASS_is_not_correctly_define
#endif

#include "../../ShaderPass/VertMesh.hlsl"

			PackedVaryingsType Vert(AttributesMesh inputMesh)
		{
			VaryingsType varyingsType;
			varyingsType.vmesh = VertMesh(inputMesh);
			return PackVaryingsType(varyingsType);
		}

		sampler3D _DitherMaskLOD;
		vector _Position;
		void Frag(PackedVaryingsToPS packedInput,float4 vpos : SV_Position,
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

			vpos *= 0.25;

			float dist = distance(_Position.xyz, _WorldSpaceCameraPos) / 10.5 - 0.05;
			float clipDest = (int)(dist >= 1.0);
			clipDest -= (int)(dist < 0.0);

			clip(-0.5 + tex3D(_DitherMaskLOD, float3(vpos.xy, dist * 0.9375)).a + clipDest);

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
		ENDHLSL
	}

		// Unlit shader always render in forward
		Pass
	{
		Name "Forward Unlit"
		Tags{ "LightMode" = "ForwardOnly" }

		Blend[_SrcBlend][_DstBlend]
		ZWrite[_ZWrite]
		Cull[_CullMode]

		HLSLPROGRAM

#pragma multi_compile _ DEBUG_DISPLAY

#ifdef DEBUG_DISPLAY
#include "../../Debug/DebugDisplay.hlsl"
#endif

#define SHADERPASS SHADERPASS_FORWARD_UNLIT
#include "../../Material/Material.hlsl"
#include "ShaderPass/UnlitSharePass.hlsl"
#include "UnlitData.hlsl"
#pragma target 3.0
#if SHADERPASS != SHADERPASS_FORWARD_UNLIT
#error SHADERPASS_is_not_correctly_define
#endif

#include "../../ShaderPass/VertMesh.hlsl"

			PackedVaryingsType Vert(AttributesMesh inputMesh)
		{
			VaryingsType varyingsType;
			varyingsType.vmesh = VertMesh(inputMesh);
			return PackVaryingsType(varyingsType);
		}

		sampler3D _DitherMaskLOD;
		vector _Position;
		float4 Frag(PackedVaryingsToPS packedInput,float4 vpos : SV_Position) : SV_Target
		{
			FragInputs input = UnpackVaryingsMeshToFragInputs(packedInput.vmesh);

		vpos *= 0.25;
		float dist = distance(_Position.xyz, _WorldSpaceCameraPos) / 10.5-0.05;
		float clipDest = (int)(dist >= 1.0);
		clipDest -= (int)(dist < 0.0);

		clip(-0.5 + tex3D(_DitherMaskLOD, float3(vpos.xy, dist * 0.9375)).a + clipDest);

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

		// Not lit here (but emissive is allowed)
		BSDFData bsdfData = ConvertSurfaceDataToBSDFData(input.positionSS.xy, surfaceData);

		// TODO: we must not access bsdfData here, it break the genericity of the code!
		float4 outColor = ApplyBlendMode(bsdfData.color + builtinData.emissiveColor, builtinData.opacity);
		outColor = EvaluateAtmosphericScattering(posInput, outColor);

#ifdef DEBUG_DISPLAY
		// Same code in ShaderPassForward.shader
		if (_DebugViewMaterial != 0)
		{
			float3 result = float3(1.0, 0.0, 1.0);
			bool needLinearToSRGB = false;

			GetPropertiesDataDebug(_DebugViewMaterial, result, needLinearToSRGB);
			GetVaryingsDataDebug(_DebugViewMaterial, input, result, needLinearToSRGB);
			GetBuiltinDataDebug(_DebugViewMaterial, builtinData, result, needLinearToSRGB);
			GetSurfaceDataDebug(_DebugViewMaterial, surfaceData, result, needLinearToSRGB);
			GetBSDFDataDebug(_DebugViewMaterial, bsdfData, result, needLinearToSRGB);

			// TEMP!
			// For now, the final blit in the backbuffer performs an sRGB write
			// So in the meantime we apply the inverse transform to linear data to compensate.
			if (!needLinearToSRGB)
				result = SRGBToLinear(max(0, result));

			outColor = float4(result, 1.0);
		}
#endif

		return outColor;
		}
		ENDHLSL
	}

		// Extracts information for lightmapping, GI (emission, albedo, ...)
		// This pass it not used during regular rendering.
		Pass
	{
		Name "META"
		Tags{ "LightMode" = "Meta" }

		Cull Off

		HLSLPROGRAM

		// Lightmap memo
		// DYNAMICLIGHTMAP_ON is used when we have an "enlighten lightmap" ie a lightmap updated at runtime by enlighten.This lightmap contain indirect lighting from realtime lights and realtime emissive material.Offline baked lighting(from baked material / light,
		// both direct and indirect lighting) will hand up in the "regular" lightmap->LIGHTMAP_ON.

#define SHADERPASS SHADERPASS_LIGHT_TRANSPORT
#include "../../Material/Material.hlsl"
#include "ShaderPass/UnlitSharePass.hlsl"
#include "UnlitData.hlsl"
#include "../../ShaderPass/ShaderPassLightTransport.hlsl"

		ENDHLSL
	}

		Pass
	{
		Name "Distortion" // Name is not used
		Tags{ "LightMode" = "DistortionVectors" } // This will be only for transparent object based on the RenderQueue index

		Blend[_DistortionSrcBlend][_DistortionDstBlend],[_DistortionBlurSrcBlend][_DistortionBlurDstBlend]
		BlendOp Add,[_DistortionBlurBlendOp]
		ZTest[_ZTestModeDistortion]
		ZWrite off
		Cull[_CullMode]

		HLSLPROGRAM

#define SHADERPASS SHADERPASS_DISTORTION
#include "../../Material/Material.hlsl"
#include "ShaderPass/UnlitDistortionPass.hlsl"
#include "UnlitData.hlsl"
#include "../../ShaderPass/ShaderPassDistortion.hlsl"

		ENDHLSL
	}
	}

		CustomEditor "Experimental.Rendering.HDPipeline.UnlitGUI"
}
