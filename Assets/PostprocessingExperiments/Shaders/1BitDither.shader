Shader "Lit/1BitDither"
{
	Properties
	{
		[HideInInspector]_MainTex("Base (RGB)", 2D) = "white" {}
		_DarkColor("Dark Color", Color) = (0,0,0,1)
		_LightColor("LightColor", Color) = (1,1,1,1)
		_DitherTex("Dither Texture", 2D) = "white" {}
		_DitherScale("Dither Scale", Float) = 1
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "LightMode" = "ForwardBase" }
		LOD 200

		Pass
		{
			Name "Dither"

			HLSLPROGRAM

			//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			#pragma vertex vert
			#pragma fragment frag

			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			// Data pertaining to _MainTex's dimensions.
			// https://docs.unity3d.com/Manual/SL-PropertiesInPrograms.html
			float4 _MainTex_TexelSize;

			TEXTURE2D(_CameraDepthNormalsTexture);
			SAMPLER(sampler_CameraDepthNormalsTexture);

			TEXTURE2D(_DitherTex);
			SAMPLER(sampler_DitherTex);
			float4 _DitherTex_ST;
			float _DitherScale;

			float3 DecodeNormal(float4 enc)
			{
				float kScale = 1.7777;
				float3 nn = enc.xyz * float3(2 * kScale, 2 * kScale, 0) + float3(-kScale, -kScale, 1);
				float g = 2.0 / dot(nn.xyz, nn.xyz);
				float3 n;
				n.xy = g * nn.xy;
				n.z = g - 1;
				return n;
			}

			struct TriplanarUV
			{
				float2 x, y, z;
			};

			struct SurfaceParams
			{
				float3 worldPosition;
				float3 normal;
			};

			TriplanarUV GetTriplanarUV(SurfaceParams params) 
			{
				TriplanarUV triUV;
				triUV.x = params.worldPosition.zy;
				triUV.y = params.worldPosition.xz;
				triUV.z = params.worldPosition.xy;

				if (params.normal.x < 0) {
					triUV.x.x = -triUV.x.x;
				}
				if (params.normal.y < 0) {
					triUV.y.x = -triUV.y.x;
				}
				if (params.normal.z < 0) {
					triUV.z.x = -triUV.z.x;
				}

				return triUV;
			}

			float3 GetTriplanarWeights(SurfaceParams params) 
			{
				float3 triW = abs(params.normal.xyz);
				float maxValue = max(triW.x, triW.y);
				maxValue = max(maxValue, triW.z);

				triW.x = triW.x - maxValue < 0 ? 0 : 1;
				triW.y = triW.y - maxValue < 0 ? 0 : 1;
				triW.z = triW.z - maxValue < 0 ? 0 : 1;
				return triW;
				//triW = pow(triW, 2);
				//return triW / (triW.x + triW.y + triW.z);
			}

			struct Attributes
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			float4 _DarkColor;
			float4 _LightColor;

			struct Varyings
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 worldDirection : TEXCOORD1;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			// Vertex shader that procedurally outputs a full screen triangle
			Varyings vert(uint vertexID : SV_VertexID)
			{
				// Render settings
				float far = _ProjectionParams.z;
				float2 orthoSize = unity_OrthoParams.xy;
				float isOrtho = unity_OrthoParams.w; // 0: perspective, 1: orthographic

				// Vertex ID -> clip space vertex position
				float x = (vertexID != 1) ? -1 : 3;
				float y = (vertexID == 2) ? -3 : 1;
				float3 vpos = float3(x, y, 1.0);

				// Perspective: view space vertex position of the far plane
				float3 rayPers = mul(unity_CameraInvProjection, vpos.xyzz * far).xyz;

				// Orthographic: view space vertex position
				float3 rayOrtho = float3(orthoSize * vpos.xy, 0);

				Varyings o;
				o.vertex = float4(vpos.x, -vpos.y, 1, 1);
				o.uv = (vpos.xy + 1) / 2;
				o.worldDirection = lerp(rayPers, rayOrtho, isOrtho);
				return o;
			}

			float3 ComputeViewSpacePosition(Varyings input)
			{
				// Render settings
				float near = _ProjectionParams.y;
				float far = _ProjectionParams.z;
				float isOrtho = unity_OrthoParams.w; // 0: perspective, 1: orthographic

				// Z buffer sample
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv);

				// Far plane exclusion
				#if !defined(EXCLUDE_FAR_PLANE)
				float mask = 1;
				#elif defined(UNITY_REVERSED_Z)
				float mask = depth > 0;
				#else
				float mask = depth < 1;
				#endif

				// Perspective: view space position = ray * depth
				float3 vposPers = input.worldDirection * Linear01Depth(depth, _ZBufferParams);

				// Orthographic: linear depth (with reverse-Z support)
				#if defined(UNITY_REVERSED_Z)
				float depthOrtho = -lerp(far, near, depth);
				#else
				float depthOrtho = -lerp(near, far, depth);
				#endif

				// Orthographic: view space position
				float3 vposOrtho = float3(input.worldDirection.xy, depthOrtho);

				// Result: view space position
				return lerp(vposPers, vposOrtho, isOrtho) * mask;
			}

			float4 frag(Varyings i) : SV_Target
			{
				//return float4(i.worldDirection, 1.0);
				
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
				// sample main texture color at uv
				float4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

				// convert to grayscale
				float intensity = dot(baseColor, half4(0.2326, 0.7152, 0.0722, 0));

				// Render settings
				float near = _ProjectionParams.y;
				float far = _ProjectionParams.z;
				float isOrtho = unity_OrthoParams.w; // 0: perspective, 1: orthographic

				// Z buffer sample
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv);

				// Far plane exclusion
				#if !defined(EXCLUDE_FAR_PLANE)
				float mask = 1;
				#elif defined(UNITY_REVERSED_Z)
				float mask = depth > 0;
				#else
				float mask = depth < 1;
				#endif

				float depth01 = Linear01Depth(depth, _ZBufferParams);

				// Perspective: view space position = ray * depth
				float3 vposPers = i.worldDirection * depth01;

				// Orthographic: linear depth (with reverse-Z support)
				#if defined(UNITY_REVERSED_Z)
				float depthOrtho = -lerp(far, near, depth);
				#else
				float depthOrtho = -lerp(near, far, depth);
				#endif

				// Orthographic: view space position
				float3 vposOrtho = float3(i.worldDirection.xy, depthOrtho);

				float3 worldPos = lerp(vposPers, vposOrtho, isOrtho) * mask;
				//float3 worldPos = ComputeViewSpacePosition(i);

				float3 normal = DecodeNormal(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, i.uv));
				float4x4 viewTranspose = transpose(UNITY_MATRIX_V);
				normal = mul(viewTranspose, float4(normal.xyz, 0)).xyz;

				SurfaceParams surface;
				surface.worldPosition = worldPos;
				surface.normal = normal;

				TriplanarUV triUV = GetTriplanarUV(surface);
			
				float3 triWeights = GetTriplanarWeights(surface); // zeros out all but one set of uvs
				float2 ditherUV = triUV.x * triWeights.x + triUV.y * triWeights.y + triUV.z * triWeights.z;
				ditherUV /= _DitherScale;
				float4 ditherColor = SAMPLE_TEXTURE2D(_DitherTex, sampler_DitherTex, ditherUV);

				// convert dither color to b&w threshold value
				float threshold = dot(ditherColor, half4(0.2326, 0.7152, 0.0722, 0));

				// threshold grayscale to 1bit b&w
				float4 color = intensity > threshold ? _LightColor : _DarkColor;
				
				// return 1 bit color
				return color;
			}
			ENDHLSL
		}
	}
	FallBack "Diffuse"
}
