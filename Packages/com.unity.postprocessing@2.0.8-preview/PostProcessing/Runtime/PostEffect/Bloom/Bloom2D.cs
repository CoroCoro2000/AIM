using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UnityEngine.Rendering.PostProcessing
{
	[DisallowMultipleComponent, ExecuteInEditMode, ImageEffectAllowedInSceneView]
	[AddComponentMenu("Rendering/Post-process BloomEffect", 10000)]
	[RequireComponent(typeof(Camera))]
	public class Bloom2D : MonoBehaviour
	{
		#region Struct
		// 点滅の時間を管理
		struct StartManage
		{
			public bool isStart;
			public float startTime;
			public float time;
			public StartManage(bool flag = false, float start = 0.0f, float time = 0.0f)
			{
				this.isStart = flag;
				this.startTime = start;
				this.time = time;
			}
		}
		#endregion
		#region InspectorVariable		
		[SerializeField]
		private bool isActive = true;
		[SerializeField, Tooltip("数字の画像を入れてください")]
		private Sprite[] numberSprites;
		[SerializeField, Tooltip("番号")]
		private int number;
		[SerializeField]
		private float size;
		[SerializeField, Range(0, 1), Tooltip("閾値")]
		private float threshold;
		[SerializeField, Range(1, 30), Tooltip("輝き具合")]
		private int iteration = 1;
		[SerializeField, Range(1, 5), Tooltip("ぼかし")]
		private float blur;

		[SerializeField]
		private float intensity;
		[SerializeField]
		private AnimationCurve speed;
		#endregion
		#region PrivateVariable
		
		private List<int> _sampleRenderTargets = new List<int>();
		private StartManage _startManage = new StartManage();
		private TargetPoolSpecifyName _targetPool;
		private PropertySheet _sheet;

		// Sprite変換用
		private General _general = new General();
		#endregion
		#region PublicVariable
		[HideInInspector]
		public Shader _shader;
		public bool IsActive { set { isActive = value; } }
		public int Number { set { number = value; } }
			
		#endregion

		#region UnityMethod
		void Awake()
		{
			_shader = Shader.Find("Bloom2D/BloomSprite");
			_targetPool = new TargetPoolSpecifyName("_BloomTargetPool");

		}
		#endregion
		private void Update()
		{
			if(Input.GetKeyDown(KeyCode.B))
			{
				IsActive = true;
			}
		}
		public void Render(PostProcessRenderContext context)
		{
			if (numberSprites.Length <= number || 0 > number)
			{
				Debug.LogWarning("Bloom2Dに設定されている画像の範囲を超えています。");
				return;
			}

			if (!isActive) { return; }
			_sheet = _general.GetSheet(_shader);
			_sheet.ClearKeywords();

			var cmd = context.command;


			Flash("_Speed", speed, ref _startManage);
			_sheet.properties.SetFloat("_Threshold", 1 - threshold);
			_sheet.properties.SetFloat("_Intensity", intensity);
			_sheet.properties.SetFloat("_Blur", blur);

			var width = context.camera.pixelWidth;
			var height = context.camera.pixelHeight;
			int currentSource;

			var pathIndex = 0;
			var sampCount = 0;
			int currentDest;

			// SpriteをMeshに変更--------------------------------------------------------------------
			var matrics = Matrix4x4.TRS(new Vector3(0, 0, 0), Quaternion.identity, Vector3.one);
			var mesh = _general.SpriteToMesh(numberSprites[number]);

			// メッシュのサイズの調整-----------------------------------------------------------------
			Vector3[] vv = mesh.vertices;
			for (int i = 0; i < vv.Length; i++)
			{
				// ここで拡大、縮小を行う。
				vv[i].x = vv[i].x * size / width;
				vv[i].y = vv[i].y * size / height;
				vv[i].z = vv[i].z * size;
			}
			mesh.vertices = vv;

			// 法線とバウンドを合わせる
			mesh.RecalculateNormals();
			mesh.RecalculateBounds();

			// 0 パス===============================================================================
			// 0パスのレンダリング先を作成
			var bloomTarget0 = currentSource = _targetPool.Get();
			context.GetScreenSpaceTemporaryRT(cmd, bloomTarget0, 0, context.sourceFormat);

			// 0パスでレンダリング
			cmd.SetRenderTarget(bloomTarget0);
			cmd.ClearRenderTarget(true, true, Color.clear);     // これやらないと前のレンダリング結果が残ったままになる
			cmd.SetGlobalTexture(ShaderIDs.MainTex, numberSprites[number].texture);

			cmd.DrawMesh(mesh, Matrix4x4.identity, _sheet.material, 0, 0, _sheet.properties);

			// 1 パス、　2 パス===============================================================================
			// ダウンサンプリング
			for (; sampCount < iteration; sampCount++)
			{
				width /= 2;
				height /= 2;
				if (width < 2 || height < 2) { break; }
				currentDest = _targetPool.Get();
				_sampleRenderTargets.Add(currentDest);
				context.GetScreenSpaceTemporaryRT(cmd, currentDest, 0, context.sourceFormat, RenderTextureReadWrite.Default,
												  FilterMode.Bilinear, width, height);

				// 最初の一回は明度抽出用のパスを使ってダウンサンプリングする
				pathIndex = sampCount == 0 ? 1 : 2;
				cmd.BlitFullscreenTriangle(currentSource, currentDest, _sheet, pathIndex);

				currentSource = currentDest;
			}

			// 3 パス========================================================================================
			// アップサンプリング
			for (sampCount -= 2; sampCount >= 0; sampCount--)
			{
				currentDest = _sampleRenderTargets[sampCount];

				// Blit時にマテリアルとパスを指定する
				cmd.BlitFullscreenTriangle(currentSource, currentDest, _sheet, 3);

				currentSource = currentDest;
			}

			// 最終パス=======================================================================================
			// Bloom前のスプライト画像を送る
			cmd.SetGlobalTexture("_BloomTex", bloomTarget0);
			cmd.SetGlobalTexture("_SceneTex", context.source);
			// 画面にレンダリング
			cmd.BlitFullscreenTriangle(currentSource, context.destination, _sheet, 4);

			// レンダーテクスチャの解放
			cmd.ReleaseTemporaryRT(bloomTarget0);
			for (int i = 0; _sampleRenderTargets.Count > i; i++)
			{
				cmd.ReleaseTemporaryRT(_sampleRenderTargets[i]);
			}
			_targetPool.Reset();
			_sampleRenderTargets.Clear();
		}

		#region privateMethod
		private void Flash(string id, AnimationCurve curve, ref StartManage startManage)
		{
			if (!startManage.isStart)
			{
				startManage.startTime = Time.time;
				startManage.isStart = true;
			}
			float t = Time.time - startManage.startTime;

			if (t > GetMaxTime(curve))
			{
				t = 0.0f;
				startManage.isStart = false;
				isActive = false;

			}
			_sheet.properties.SetFloat(id, curve.Evaluate(t));
		}

		private float GetMaxTime(AnimationCurve curve)
		{
			Keyframe[] keyframes = curve.keys;
			return keyframes[keyframes.Length - 1].time;
		}

		

		#endregion
	}
}
