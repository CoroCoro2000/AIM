namespace UnityEngine.Experimental.Rendering.HDPipeline
{
    [SkyUniqueID((int)SkyType.CloudSky)]
    public class CloudSky : SkySettings
    {
        public ClampedFloatParameter sunSize = new ClampedFloatParameter(0.04f, 0.0f, 1.0f);
        public ClampedFloatParameter sunSizeConvergence = new ClampedFloatParameter(5.0f, 1.0f, 10.0f);
        public ClampedFloatParameter atmosphereThickness = new ClampedFloatParameter(1.0f, 0.0f, 5.0f);
        public ColorParameter skyTint = new ColorParameter(new Color(0.5f, 0.5f, 0.5f, 1.0f));
        public ColorParameter groundColor = new ColorParameter(new Color(0.369f, 0.349f, 0.341f, 1.0f));
        public BoolParameter enableSunDisk = new BoolParameter(true);
		//-----------------------------------------------------------------------------------
		[Tooltip("Cubemap used to render the sky.")]
		public CubemapParameter cloudCube = new CubemapParameter(null);
		//-----------------------------------------------------------------------------------

		public override SkyRenderer CreateRenderer()
        {
            return new CloudSkyRenderer(this);
        }

        public override int GetHashCode()
        {
            int hash = base.GetHashCode();

            unchecked
            {
                hash = hash * 23 + sunSize.GetHashCode();
                hash = hash * 23 + sunSizeConvergence.GetHashCode();
                hash = hash * 23 + atmosphereThickness.GetHashCode();
                hash = hash * 23 + skyTint.GetHashCode();
                hash = hash * 23 + groundColor.GetHashCode();
                hash = hash * 23 + multiplier.GetHashCode();
                hash = hash * 23 + enableSunDisk.GetHashCode();
				//-------------------------------------------------------------------------
				hash = cloudCube.value != null ? hash * 23 + cloudCube.GetHashCode() : hash;
				//-------------------------------------------------------------------------
			}

            return hash;
        }
    }
}
