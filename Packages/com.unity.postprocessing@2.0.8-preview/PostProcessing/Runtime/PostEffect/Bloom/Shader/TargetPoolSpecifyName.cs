using System.Collections.Generic;

namespace UnityEngine.Rendering.PostProcessing
{

	class TargetPoolSpecifyName
	{
		readonly List<int> m_Pool;
		int m_Current;
		string m_TargetName;

		internal TargetPoolSpecifyName(string m_TargetName)
		{
			m_Pool = new List<int>();
			Get(); // Pre-warm with a default target to avoid black frame on first frame
		}

		internal int Get()
		{
			int ret = Get(m_Current);
			m_Current++;
			return ret;
		}

		int Get(int i)
		{
			int ret;

			if (m_Pool.Count > i)
			{
				ret = m_Pool[i];
			}
			else
			{
				// Avoid discontinuities
				while (m_Pool.Count <= i)
					m_Pool.Add(Shader.PropertyToID(m_TargetName + i));

				ret = m_Pool[i];
			}

			return ret;
		}

		internal void Reset()
		{
			m_Current = 0;
		}
	}
}
