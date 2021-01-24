Shader "Toon/toon-skybox"
{
    Properties
    {
        [Header(Sun)]
        _SunInnerDIsc("Sun Inner Disc", Range(0.95, 1)) = 0.1
        _SunRimContrast("Sun Rim Contrast", Float) = 3
        _HaloDisc("Halo Disc", Float) = 1
        _Value1("Value1", Float) = 1
        _Value2("Value2", Range(0, 2)) = 1
        [HDR]_SunRise("Sun Rise Color", Color) = (1,1,1,1)
        [HDR]_SunSet("Sun Set Color", Color) = (1,1,1,1)
        [HDR]_SunMid("Sun Mid Color", Color) = (1,1,1,1)

        [Header(Moon)]
        _MoonDisc("Moon Disc", Float) = 0.1
        _CresentMoon("Cresent Moon", Range(0, 1)) = 1
        [HDR]_MoonColor("Moon Color", Color) = (1,1,1,1)

        [Header(Sky)]
        [HDR]_DayTopColor("Day Top Color", Color) = (1,1,1,1)
        [HDR]_DayBottomColor("Day Bottom Color", Color) = (1,1,1,1)
        [HDR]_NightTopColor("Night Top Color", Color) = (1,1,1,1)
        [HDR]_NightBottomColor("Night Bottom Color", Color) = (1,1,1,1)

        [Header(Star)]
        _StarTex("Star Texture", 2D) = "grey"{}
        _StarSppeed("Star Moving Speed", Range(0, 1)) = 0.2

        [Header(Cloud)]
        _BaseNoise("Base Noise", 2D) = "white"{}
        //_FirstNoise("Distort Noise", 2D) = "white"{}
        //_SecondNoise("Second Noise", 2D) = "white"{}
        _CloudOcculision("Cloud Occulision", Float) = 0.3
        _CloudMin("Cloud Min", Range(0, 1)) = 0.3
        _CloudMax("Cloud Max", Range(0, 1)) = 0.5
        [HDR]_CloudMaxColor("Cloud Max Color", Color) = (1,1,1,1)
        [HDR]_CloudMinColor("Cloud Min Color", Color) = (1,1,1,1)
        [HDR]_CloudMaxColorNight("Cloud Max Color Night", Color) = (1,1,1,1)
        [HDR]_CloudMinColorNight("Cloud Min Color Night", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 uv : TEXCOORD0;
            };

            struct v2f
            {
                float3 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos : VAR_WORLD_POS;
            };

            float _SunInnerDIsc;
            float _SunRimContrast;
            float _HaloDisc;
            float4 _SunRise;
            float4 _SunSet;
            float4 _SunMid;
            float _Value1;
            float _Value2;


            float _MoonDisc;
            float _CresentMoon;
            float4 _MoonColor;

            float4 _DayTopColor;
            float4 _DayBottomColor;
            float4 _NightTopColor;
            float4 _NightBottomColor;

            sampler2D _StarTex;
            float _StarSppeed;

            sampler2D _BaseNoise;
            float4 _BaseNoise_ST;
            /*
            sampler2D _FirstNoise;
            float4 _FirstNoise_ST;
            sampler2D _SecondNoise;
            float4 _SecondNoise_ST;
            */
            float _CloudOcculision;
            float _CloudMin;
            float _CloudMax;
            float4 _CloudMaxColor;
            float4 _CloudMinColor;
            float4 _CloudMaxColorNight;
            float4 _CloudMinColorNight;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = (v.uv);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }

            float4 GetSunColor(v2f i)
            {
                float sunDist = dot(normalize(i.uv.xyz), _WorldSpaceLightPos0);
                float sizeAmplifier = 1 + _WorldSpaceLightPos0.y * 2;
                float sunInner = sunDist - (_SunInnerDIsc + _WorldSpaceLightPos0.y / 500);
                sunInner = sunInner > 0 ? sunInner : 0;
                sunInner = pow(sunInner * _Value1, _Value2);
                float sunOuter = pow( saturate(sunDist * _HaloDisc), _SunRimContrast) * (pow(_WorldSpaceLightPos0.y, 5)+10);//saturate(pow(sunDist / sizeAmplifier, _SunRimContrast));

                float4 col1 = lerp(_SunMid, _SunRise, saturate(-_WorldSpaceLightPos0.z));
                float4 col2 = lerp(_SunMid, _SunSet, pow(saturate(_WorldSpaceLightPos0.z), 2.5));
                float4 sunColor = lerp(sunOuter , sunInner + sunOuter, sunDist) * lerp(col1, col2, step(0, _WorldSpaceLightPos0.z));
                return sunColor;
            }

            float4 GetMoonColor(v2f i)
            {
                float moonDic = saturate(dot(normalize(i.uv.xyz), -_WorldSpaceLightPos0));
                float moon = step(_MoonDisc, moonDic);

                float cresentDic = dot(normalize(float3(i.uv.x + _CresentMoon, i.uv.yz)), -_WorldSpaceLightPos0);
                float cresentMoonColor = step(_MoonDisc, cresentDic);

                float4 moonColor = saturate(moon - cresentMoonColor) * _MoonColor;
                return moonColor;
            }

            float4 GetSkyGradient(v2f i)
            {
                float4 gradientDay = lerp(_DayBottomColor, _DayTopColor, saturate(i.uv.y));
                float4 gradientNight = lerp(_NightBottomColor, _NightTopColor, saturate(i.uv.y));
                float4 skyGradient = lerp(gradientNight, gradientDay, saturate(_WorldSpaceLightPos0.y)) ;

                return skyGradient;
            }

            float4 GetSunRiseSunSetColor(v2f i)
            {
                float3 viewDir = UNITY_MATRIX_IT_MV[2].xyz;
                float horizon = abs(i.uv.y - clamp(-_WorldSpaceLightPos0.y, 0, 0.05));
                float horizonGlow = pow(1 - horizon, 5) * 0.1 *  smoothstep(0.1, 0, abs(_WorldSpaceLightPos0.y));
                float4 horizonGlowColor = horizonGlow * step(0,  -viewDir.z * _WorldSpaceLightPos0.z) * lerp(_SunRise, _SunSet, step( _WorldSpaceLightPos0.z, 0)) ;

                return horizonGlowColor;
            }

            float4 GetStar(v2f i)
            {
                //float3 viewDir = normalize(i.uv);
				//float2 skyUV = float2((atan2(viewDir.x, viewDir.z) + UNITY_PI) / UNITY_TWO_PI,acos(viewDir.y) / UNITY_PI);
                float2 skyUV = i.worldPos.xz / i.worldPos.y;
                float4 starTex = tex2D(_StarTex, skyUV - _StarSppeed * _Time.xx);
                starTex *= 1 - saturate(_WorldSpaceLightPos0.y);
                return starTex;
            }

            void GetCloud(v2f i, inout float noise, inout float4 color)
            {
                float3 viewDir = normalize(i.uv);
				float2 skyUV = float2((atan2(viewDir.x, viewDir.z) + UNITY_PI) / UNITY_TWO_PI,acos(viewDir.y) / UNITY_PI);
                float2 uv = skyUV;

                float _sin = sin(_BaseNoise_ST.x * _Time.x);
				float _cos = cos(_BaseNoise_ST.y * _Time.x);
				uv = float2((_cos*uv.x+_sin*uv.y),-_sin*uv.x+_cos*uv.y);

                float baseNoise = 1 - tex2D(_BaseNoise, uv).r;
                noise = smoothstep(_CloudMin, _CloudMax, baseNoise);
                float4 colorDay = lerp(_CloudMinColor, _CloudMaxColor, noise);
                float4 colorNight = lerp(_CloudMinColorNight, _CloudMaxColorNight, noise);
                color = lerp(colorNight, colorDay, saturate(_WorldSpaceLightPos0.y)) ;
            }

            fixed4 frag (v2f i) : SV_Target
            {

                float4 sunColor = GetSunColor(i);
                float4 moonColor = GetMoonColor(i);
                float4 skyGradient = GetSkyGradient(i);
                float4 sunRiseSunColor = GetSunRiseSunSetColor(i);
                float4 starTex = GetStar(i);

                float cloud;
                float4 cloudColor;
                GetCloud(i, cloud, cloudColor);

                fixed4 finalColor = (sunColor + moonColor * _LightColor0 + starTex) * (pow(1 - cloud,  _CloudOcculision - _WorldSpaceLightPos0.y * 5))+ skyGradient + sunRiseSunColor + cloudColor;
                return finalColor;
            }
            ENDCG
        }
    }
}
