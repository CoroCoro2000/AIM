using System;

namespace UnityEngine.Rendering.PostProcessing
{
	[Serializable]
	[PostProcess(typeof(MyMotionBlurRenderer),PostProcessEvent.AfterStack,"Custom/MyMotion Blur",false)]
	public sealed class MyMotionBulr : PostProcessEffectSettings
	{
		[Range(0f, 1f), Tooltip("残像")]
		public FloatParameter frameBlending = new FloatParameter { value = 0f };
		[Range(0f, 1f), Tooltip("奥行き")]
		public FloatParameter distance = new FloatParameter { value = 0f };

		public override bool IsEnabledAndSupported(PostProcessRenderContext context)
        {
            return enabled.value
            #if UNITY_EDITOR
                // Don't render motion blur preview when the editor is not playing as it can in some
                // cases results in ugly artifacts (i.e. when resizing the game view).
                && Application.isPlaying
            #endif
                && SystemInfo.supportsMotionVectors
                && RenderTextureFormat.RGHalf.IsSupported()
                && !RuntimeUtilities.isVREnabled;
        }
	}

	public sealed class MyMotionBlurRenderer : PostProcessEffectRenderer<MyMotionBulr>
	{
		#region Private Member
		Frame[] _frameList;
		int _lastFrameCount;
        bool _isInit;
        #endregion

		#region Struct
		struct Frame
		{
			public RenderTexture lumaTexture;
			public RenderTexture chromaTexture;
			public float time;

            RenderTargetIdentifier[] mrt;

			public float CalculateWeight(float strength, float currentTime)
			{
				if (time == 0) return 0;
				var coeff = Mathf.Lerp(80.0f, 1.0f, strength);
				return Mathf.Exp((time - currentTime) * coeff);
			}

			public void Release()
			{
                if (lumaTexture != null) RenderTexture.ReleaseTemporary(lumaTexture);
                if (chromaTexture != null) RenderTexture.ReleaseTemporary(chromaTexture);

                lumaTexture = null;
                chromaTexture = null;
            }

			public void MakeRecord(PostProcessRenderContext context, PropertySheet sheet, int index)
			{
				var cmd = context.command;
                // テクスチャ解放
                Release();

                lumaTexture = RenderTexture.GetTemporary(context.width, context.height, 0, RenderTextureFormat.R8, RenderTextureReadWrite.Linear);
                chromaTexture = RenderTexture.GetTemporary(context.width, context.height, 0, RenderTextureFormat.R8, RenderTextureReadWrite.Linear);

                if (mrt == null) mrt = new RenderTargetIdentifier[2];

				mrt[0] = new RenderTargetIdentifier(lumaTexture);
                mrt[1] = new RenderTargetIdentifier(chromaTexture);

				cmd.SetRenderTarget(mrt, lumaTexture.depthBuffer);
                cmd.DrawMesh(RuntimeUtilities.fullscreenTriangle, Matrix4x4.identity, sheet.material, 0, 0, sheet.properties);

				time = Time.time;
			}
		}
		#endregion

		#region PostProcessEffectRenderer Method
		public override DepthTextureMode GetCameraFlags()
		{
			return DepthTextureMode.Depth | DepthTextureMode.MotionVectors;
		}

        public override void Init()
        {
            _frameList = new Frame[4];
            _isInit = false;

        }

        public override void Release()
		{
            foreach (var frame in _frameList) frame.Release();
            _frameList = null;
        }

		public override void Render(PostProcessRenderContext context)
		{
			var cmd = context.command;

            ////FrameBlending//////////////////////////////////////////////////////////////////////////////////////////////

            var blendSheet = context.propertySheets.Get(context.resources.shaders.myMotionBlur);
            if (!_isInit)
            {
                _isInit = true;
                _frameList[0].MakeRecord(context, blendSheet, 0);
                _frameList[1].MakeRecord(context, blendSheet, 1);
                _frameList[2].MakeRecord(context, blendSheet, 2);
                _frameList[3].MakeRecord(context, blendSheet, 3);
            }
            var t = Time.time;

            var f1 = GetFrameRelative(-1);
            var f2 = GetFrameRelative(-2);
            var f3 = GetFrameRelative(-3);
            var f4 = GetFrameRelative(-4);

            blendSheet.properties.SetTexture("_History1LumaTex", f1.lumaTexture);
            blendSheet.properties.SetTexture("_History2LumaTex", f2.lumaTexture);
            blendSheet.properties.SetTexture("_History3LumaTex", f3.lumaTexture);
            blendSheet.properties.SetTexture("_History4LumaTex", f4.lumaTexture);

            blendSheet.properties.SetTexture("_History1ChromaTex", f1.chromaTexture);
            blendSheet.properties.SetTexture("_History2ChromaTex", f2.chromaTexture);
            blendSheet.properties.SetTexture("_History3ChromaTex", f3.chromaTexture);
            blendSheet.properties.SetTexture("_History4ChromaTex", f4.chromaTexture);

            blendSheet.properties.SetFloat("_History1Weight", f1.CalculateWeight(settings.frameBlending, t));
            blendSheet.properties.SetFloat("_History2Weight", f2.CalculateWeight(settings.frameBlending, t));
            blendSheet.properties.SetFloat("_History3Weight", f3.CalculateWeight(settings.frameBlending, t));
            blendSheet.properties.SetFloat("_History4Weight", f4.CalculateWeight(settings.frameBlending, t));

			// ブラーをかける距離
			blendSheet.properties.SetFloat("_Distance", settings.distance);

            cmd.BlitFullscreenTriangle(context.source, context.destination, blendSheet, 1);

            // Push only when actual update (do nothing while pausing)
            var frameCount = Time.frameCount;
            if (frameCount != _lastFrameCount)
            {
                // Update the frame record.
                var index = frameCount % _frameList.Length;
                _frameList[index].MakeRecord(context, blendSheet, index);
                _lastFrameCount = frameCount;
            }
        }
        #endregion
        #region private Method
        // Retrieve a frame record with relative indexing.
        // Use a negative index to refer to previous frames.
        Frame GetFrameRelative(int offset)
		{
			var index = (Time.frameCount + _frameList.Length + offset) % _frameList.Length;
			return _frameList[index];
		}
		#endregion
	}
}
