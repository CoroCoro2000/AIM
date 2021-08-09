using UnityEngine.Rendering;

namespace UnityEngine.Experimental.Rendering.HDPipeline
{
    public class CloudSkyRenderer : SkyRenderer
    {
        Material m_CloudSkyMaterial;
        MaterialPropertyBlock m_PropertyBlock;
        CloudSky m_CloudSkyParams;

        readonly int _SunSizeParam = Shader.PropertyToID("_SunSize");
        readonly int _SunSizeConvergenceParam = Shader.PropertyToID("_SunSizeConvergence");
        readonly int _AtmoshpereThicknessParam = Shader.PropertyToID("_AtmosphereThickness");
        readonly int _SkyTintParam = Shader.PropertyToID("_SkyTint");
        readonly int _GroundColorParam = Shader.PropertyToID("_GroundColor");
        readonly int _SunColorParam = Shader.PropertyToID("_SunColor");
        readonly int _SunDirectionParam = Shader.PropertyToID("_SunDirection");

        public CloudSkyRenderer(CloudSky CloudSkyParams)
        {
            m_CloudSkyParams = CloudSkyParams;
            m_PropertyBlock = new MaterialPropertyBlock();
        }

        public override void Build()
        {
            var hdrp = GraphicsSettings.renderPipelineAsset as HDRenderPipelineAsset;
            m_CloudSkyMaterial = CoreUtils.CreateEngineMaterial(hdrp.renderPipelineResources.CloudSky);
        }

        public override void Cleanup()
        {
            CoreUtils.Destroy(m_CloudSkyMaterial);
        }

        public override void SetRenderTargets(BuiltinSkyParameters builtinParams)
        {
            if (builtinParams.depthBuffer == BuiltinSkyParameters.nullRT)
            {
                HDUtils.SetRenderTarget(builtinParams.commandBuffer, builtinParams.hdCamera, builtinParams.colorBuffer);
            }
            else
            {
                HDUtils.SetRenderTarget(builtinParams.commandBuffer, builtinParams.hdCamera, builtinParams.colorBuffer, builtinParams.depthBuffer);
            }
        }

        public override void RenderSky(BuiltinSkyParameters builtinParams, bool renderForCubemap)
        {
            CoreUtils.SetKeyword(m_CloudSkyMaterial, "_ENABLE_SUN_DISK", m_CloudSkyParams.enableSunDisk);

            Color sunColor = Color.white;
            Vector3 sunDirection = Vector3.zero;
            if (builtinParams.sunLight != null)
            {
                sunColor = builtinParams.sunLight.color * builtinParams.sunLight.intensity;
                sunDirection = -builtinParams.sunLight.transform.forward;
            }

			//----------------------------------------------------------------------------------------------------------
			m_CloudSkyMaterial.SetTexture(HDShaderIDs._Cubemap, m_CloudSkyParams.cloudCube);
			//----------------------------------------------------------------------------------------------------------
			m_CloudSkyMaterial.SetVector(HDShaderIDs._SkyParam, new Vector4(GetExposure(m_CloudSkyParams, builtinParams.debugSettings), m_CloudSkyParams.multiplier, 0.0f, 0.0f));
            m_CloudSkyMaterial.SetFloat(_SunSizeParam, m_CloudSkyParams.sunSize);
            m_CloudSkyMaterial.SetFloat(_SunSizeConvergenceParam, m_CloudSkyParams.sunSizeConvergence);
            m_CloudSkyMaterial.SetFloat(_AtmoshpereThicknessParam, m_CloudSkyParams.atmosphereThickness);
            m_CloudSkyMaterial.SetColor(_SkyTintParam, m_CloudSkyParams.skyTint);
            m_CloudSkyMaterial.SetColor(_GroundColorParam, m_CloudSkyParams.groundColor);
            m_CloudSkyMaterial.SetColor(_SunColorParam, sunColor);
            m_CloudSkyMaterial.SetVector(_SunDirectionParam, sunDirection);

            // This matrix needs to be updated at the draw call frequency.
            m_PropertyBlock.SetMatrix(HDShaderIDs._PixelCoordToViewDirWS, builtinParams.pixelCoordToViewDirMatrix);

            CoreUtils.DrawFullScreen(builtinParams.commandBuffer, m_CloudSkyMaterial, m_PropertyBlock, renderForCubemap ? 0 : 1);
        }

        public override bool IsValid()
        {
            return true;
        }
    }
}
