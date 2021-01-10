Shader "Lit/1BitDither"
{
	Properties
	{
		[HideInInspector]_MainTex("Base (RGB)", 2D) = "white" {}
		_DarkColor("Dark Color", Color) = (0,0,0,1)
		_LightColor("LightColor", Color) = (1,1,1,1)
		_DitherTex("Dither Texture", 2D) = "white" {}
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
		LOD 200

		Pass
		{
			Name "Dither"

			HLSLPROGRAM

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

			#pragma vertex vert
			#pragma fragment frag

			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);

			// Data pertaining to _MainTex's dimensions.
			// https://docs.unity3d.com/Manual/SL-PropertiesInPrograms.html
			float4 _MainTex_TexelSize;
			float4 _DitherTex_ST;

			TEXTURE2D(_DitherTex);
			SAMPLER(sampler_DitherTex);

			struct Attributes
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			float4 _DarkColor;
			float4 _LightColor;

			const float4 _ToGray = float4(0.2126729, 0.7151522, 0.0721750, 1);

			struct Varyings
			{
				float4 vertex : SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float2 ditherUV : TEXCOORD1;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			Varyings vert(Attributes v) 
			{
				Varyings o;
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
				o.vertex = vertexInput.positionCS;
				o.texcoord = v.uv;

#if UNITY_UV_STARTS_AT_TOP
				if (_MainTex_TexelSize.y < 0)
					o.texcoord.y = 1 - o.texcoord.y;
#endif

				float2 worldXY = mul(unity_ObjectToWorld, v.vertex).xy;
				o.ditherUV = TRANSFORM_TEX(worldXY, _DitherTex);

				return o;
			}

			float4 frag(Varyings i) : SV_Target
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
				// sample main texture color at uv
				float4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
				//return baseColor;

				// convert to grayscale
				float baseValue = (baseColor.r + baseColor.g + baseColor.b) / 3;//, _ToGray);

				// sample dither texture
				float4 ditherColor = SAMPLE_TEXTURE2D(_DitherTex, sampler_DitherTex, i.ditherUV);
				//return ditherColor;

				// convert dither color to b&w threshold value
				float threshold = (ditherColor.x + ditherColor.y + ditherColor.z)/3;

				// threshold grayscale to 1bit b&w
				float4 color = baseValue > threshold ? _LightColor : _DarkColor;
				
				// return 1 bit color
				return color;
			}
			ENDHLSL
		}
	}
	FallBack "Diffuse"
}
