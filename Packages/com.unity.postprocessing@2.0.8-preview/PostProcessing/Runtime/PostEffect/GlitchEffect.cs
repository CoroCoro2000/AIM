using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine.Assertions;

namespace UnityEngine.Rendering.PostProcessing
{
	[DisallowMultipleComponent, ExecuteInEditMode, ImageEffectAllowedInSceneView]
	[AddComponentMenu("Rendering/Post-process GlitchEffect", 10000)]
	[RequireComponent(typeof(Camera))]
	public sealed class GlitchEffect : MonoBehaviour
	{
		[NonSerialized]
		private Material _material;

		[SerializeField, Tooltip("GlitShader")]
		public Shader Shader;
		public Texture2D displacementMap;

		[Header("Glitch Intensity")]
		[Range(0, 1)]
		public float intensity = 0.5f;
		[Range(0, 1)]
		public float flipIntensity = 0.5f;
		[Range(0, 1)]
		public float colorIntensity = 0.5f;
		private float _glitchup;
		private float _glitchdown;
		private float flicker;
		private float _glitchupTime = 0.05f;
		private float _glitchdownTime = 0.05f;
		private float _flickerTime = 0.5f;

		[Space(20)]
		[Range(1, 10)]
		public float _glitchSpeed = 1.0f;
		[Range(1, 10)]
		public float _glitchSwing = 1.0f;



		public void Render(PostProcessRenderContext context, int releaseTargetAfterUse = -1)
		{
			var glitchSheet = context.propertySheets.Get(Shader);
			glitchSheet.ClearKeywords();

			var cmd = context.command;
			cmd.BeginSample("BuiltinStack");

			glitchSheet.properties.SetFloat("_Intensity", intensity);
			glitchSheet.properties.SetFloat("_ColorIntensity", colorIntensity);

			flicker += Time.deltaTime * colorIntensity * _glitchSpeed;
			if (flicker > _flickerTime)
			{
				glitchSheet.properties.SetFloat("filterRadius", Random.Range(_glitchSwing * -3f, _glitchSwing * 3f) * colorIntensity);
				glitchSheet.properties.SetVector("direction", Quaternion.AngleAxis(Random.Range(0, 360) * colorIntensity, Vector3.forward) * Vector4.one);
				flicker = 0;
				_flickerTime = Random.value;
		}

			if (colorIntensity == 0)
				glitchSheet.properties.SetFloat("filterRadius", 0);

			_glitchup += Time.deltaTime * flipIntensity * _glitchSpeed;
			if (_glitchup > _glitchupTime)
			{
				if (Random.value < 0.1f * flipIntensity)
					glitchSheet.properties.SetFloat("flip_up", Random.Range(0, _glitchSwing) * flipIntensity);
				else
					glitchSheet.properties.SetFloat("flip_up", 0);

			_glitchup = 0;
				_glitchupTime = Random.value / 30f;
		}

			if (flipIntensity == 0)
				glitchSheet.properties.SetFloat("flip_up", 0);

			_glitchdown += Time.deltaTime * flipIntensity * _glitchSpeed;
			if (_glitchdown > _glitchdownTime)
			{
				if (Random.value < 0.1f * flipIntensity)
					glitchSheet.properties.SetFloat("flip_down", 1 - Random.Range(0, _glitchSwing) * flipIntensity);
				else
					glitchSheet.properties.SetFloat("flip_down", 1);

			_glitchdown = 0;
				_glitchdownTime = Random.value / 10f;
		}

			if (flipIntensity == 0)
				glitchSheet.properties.SetFloat("flip_down", 1);

			if (Random.value < 0.05 * intensity * _glitchSpeed)
			{
				glitchSheet.properties.SetFloat("displace", Random.value * intensity * _glitchSwing * _glitchSwing);
				glitchSheet.properties.SetFloat("scale", 1 - Random.value * intensity);
		}
			else
				glitchSheet.properties.SetFloat("displace", 0);

			cmd.BlitFullscreenTriangle(context.source, context.destination, glitchSheet, 0);

			cmd.EndSample("BuiltinStack");
		}
	}
}