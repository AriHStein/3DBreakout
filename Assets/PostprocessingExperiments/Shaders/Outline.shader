Shader "Unlit/Outline"
{
    Properties
    {
        [HideInInspector]_MainTex ("Base (RGB)", 2D) = "white" {}
        _Scale ("Scale", int) = 1
        _DepthThreshold ("Depth Threshold", Float) = 0.2
        _NormalThreshold ("Normal Threshold", Range(0,1)) = 0.4
        _DepthNormalThreshold ("DepthNormal Threshold", Range(0,1)) = 0.5
        _DepthNormalThresholdScale ("DepthNormal Threshold Scale", Float) = 7
        [HDR]_Color("Outline Color", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 200
        
        Pass
        {
            Name "Outline"

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            // _CameraNormalsTexture contains the view space normals transformed
            // to be in the 0...1 range.
            TEXTURE2D(_CameraDepthNormalsTexture);
            SAMPLER(sampler_CameraDepthNormalsTexture);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            // Data pertaining to _MainTex's dimensions.
            // https://docs.unity3d.com/Manual/SL-PropertiesInPrograms.html
            float4 _MainTex_TexelSize;

            float _Scale;

            float _DepthThreshold;
            float _NormalThreshold;
            float _DepthNormalThreshold;
            float _DepthNormalThresholdScale;
            float4 _Color;

            //float4x4 _ClipToView;

            // Combines the top and bottom colors using normal blending.
            // https://en.wikipedia.org/wiki/Blend_modes#Normal_blend_mode
            // This performs the same operation as Blend SrcAlpha OneMinusSrcAlpha.
            float4 alphaBlend(float4 top, float4 bottom)
            {
                float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
                float alpha = top.a + bottom.a * (1 - top.a);

                return float4(color, alpha);
            }

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

            struct Attributes
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
                float3 viewSpaceDir : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert (Attributes v)
            {
                Varyings o;
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = vertexInput.positionCS;
                o.texcoord = v.uv;

#if UNITY_UV_STARTS_AT_TOP
                if (_MainTex_TexelSize.y < 0)
                    o.texcoord.y = 1 - o.texcoord.y;
                //o.texcoord = o.texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
#endif

                o.viewSpaceDir = mul(unity_CameraInvProjection, o.vertex).xyz;

                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                // Stepping out 1 pixel at a time asymetrically so each increase in scale only expands by 1 pixel instead of 2
                // As scale increases, floor++, then ceil++, then floor++, etc.
                float halfScaleFloor = floor(_Scale * 0.5);
                float halfScaleCeil = ceil(_Scale * 0.5);

                // Find UV coords offset by the correct scale from our pixel
                float2 bottomLeftUV = i.texcoord - float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y) * halfScaleFloor;
                float2 topRightUV = i.texcoord + float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y) * halfScaleCeil;
                float2 bottomRightUV = i.texcoord + float2(_MainTex_TexelSize.x * halfScaleCeil, -_MainTex_TexelSize.y * halfScaleFloor);
                float2 topLeftUV = i.texcoord + float2(-_MainTex_TexelSize.x * halfScaleFloor, _MainTex_TexelSize.y * halfScaleCeil);


                // Find edges by combining two techniques:
                // Find large changes in scene depth and large changes in normals
                // We're essentially finding a numberical solution to the derevative of the depth and normals functions,
                // And outputing the magnitude of that derivative
                // For large derivative values (rapid changes) we interpret that as an edge and draw that pixel in our line color

                /////////////////// SAMPLE DEPTH ////////////////////////////
                float depth0 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, bottomLeftUV).r;
                float depth1 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, topRightUV).r;
                float depth2 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, bottomRightUV).r;
                float depth3 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, topLeftUV).r;

                // Robert's cross -- find the difference in depth between the uvs in an X pattern
                // Then take the sum of their squares and sqrt it
                // * 100 is a brightness factor
                float depthFiniteDifference0 = depth1 - depth0;
                float depthFiniteDifference1 = depth3 - depth2;

                // Combine depth derivatives together with arbitrary math operation
                float edgeDepth = sqrt(pow(depthFiniteDifference0, 2) + pow(depthFiniteDifference1, 2)) * 100;

                ////////////////// SAMPLE NORMALS //////////////////////////////
                float3 normal0 = DecodeNormal(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, bottomLeftUV));
                float3 normal1 = DecodeNormal(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, topRightUV));
                float3 normal2 = DecodeNormal(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, bottomRightUV));
                float3 normal3 = DecodeNormal(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, topLeftUV));

                float3 normalFiniteDifference0 = normal1 - normal0;
                float3 normalFiniteDifference1 = normal3 - normal2;

                // arbitrary math again
                float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));

                // Threshold edgeDepth to crush greys that appear along surfaces close to perpendicular to the camera plane
                // Since the depthBuffer is non-linear, the threshold needs to be remapped onto a similar non-linear scale.
                // Multilying by the current depth is a easy, hacky way to do that.
                // Additionally, surfaces close to perpendicular to the camera view plane have rapidly changing depth values
                // We want to avoid reading thoes as edges, so we also remap the threshold value based on the surface normals
                
                // Transform view normal to be in [-1,1] range to match viewSpaceDir for dot
                float3 viewNormal = normal0 * 2 - 1; 
                float NdotV = 1 - dot(viewNormal, -i.viewSpaceDir);

                float depthNormalThreshold01 = saturate((NdotV - _DepthNormalThreshold) / (1 - _DepthNormalThreshold));
                float depthNormalThreshold = depthNormalThreshold01 * _DepthNormalThresholdScale + 1;

                float depthThreshold = _DepthThreshold * depth0 * depthNormalThreshold;
                edgeDepth = edgeDepth > depthThreshold ? 1 : 0;
                edgeNormal = edgeNormal > _NormalThreshold ? 1 : 0;
                
                
                ///////////// COMBINE RESULTS AND DRAW EDGES ///////////////////////////

                // If either the depth method or normal method is telling us there is an edge
                // assume there is an edge
                float edge = max(edgeDepth, edgeNormal);

                float4 edgeColor = float4(_Color.rgb, _Color.a * edge);
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);

                return alphaBlend(edgeColor, color);
            }
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
