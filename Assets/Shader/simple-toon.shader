//blinn-phong based toon-shading
Shader "Toon/simple-toon"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Main Tex", 2D) = "white"{}
        _RampTex("Ramp Texture", 2D) = "white"{}

        [HDR]
        _AmbientLight("Ambient Light", Color) = (0.4, 0.4, 0.4, 1)

        [HDR]
        _RimColor("Rim Color", Color) = (1,1,1,1)
        _RimAmount("Rim Amount", Range(0.5, 1)) = 0.73
        _RimWidth("Rim Width", Range(0.01, 0.2)) = 0.1
        _RimThreshold("Rim Threshold", Range(0.01, 0.2)) = 0.1

        _Gloss("Gloss", Float) = 1.0

        [Toggle(ENABLE_RAMP)] _EnableRamp("Enable Ramp?", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "LightMode"="ForwardBase" "PassFlags"="OnlyDirectional" }

        Pass
        {

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature ENABLE_RAMP
            #pragma multi_compile_fwdbase

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal: NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 normal: VAR_NORMAL;
                float3 world_pos : VAR_WORLD_POS;
                float2 uv : TEXCOORD0;
                SHADOW_COORDS(2)
            };

            float4 _Color;
            float4 _AmbientLight;
            float _Gloss;

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _RampTex;

            float4 _RimColor;
            float _RimAmount;
            float _RimWidth;
            float _RimThreshold;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.world_pos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                TRANSFER_SHADOW(o)
                return o;
            }



            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal);
                float3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.world_pos));
                float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 worldHalfDir = normalize(worldViewDir +  worldLightDir);
                float nh = dot(normal, worldHalfDir);
                float specularIntensity = pow(max(0, nh), _Gloss * _Gloss);
                float specularIntensitySmooth = smoothstep(0.005, 0.01, specularIntensity);

                float nl = dot(normal, worldLightDir);

#if ENABLE_RAMP
                float2 rampuv = float2( 1 - (nl * 0.5 + 0.5), 0.5);
                float diffuseIntensity = tex2D(_RampTex, rampuv).r;
#else
                //float diffuseIntensity = nl > 0 ? 1 : 0; //two-band
                float diffuseIntensity = smoothstep(0, 0.05, nl);
#endif

                float shadow = SHADOW_ATTENUATION(i);
                float4 lightColor = (diffuseIntensity + specularIntensitySmooth )* _LightColor0 * shadow;

                float rimDot = (1 - dot(worldViewDir, normal)) * pow(max(0,nl), _RimThreshold);
                float rimIntensity = smoothstep(_RimAmount - _RimWidth, _RimAmount + _RimWidth, rimDot);
                float4 rimColor = rimIntensity * _RimColor;


                return _Color * (_AmbientLight + lightColor) + rimColor;
            }
            ENDHLSL
        }

        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}
