#version 450 core

layout(std140, binding = 1) uniform STRendererData
{
    vec4 iMouse;
    vec4 iChannelResolution[4];
    vec4 iResolution;
    float iTime;
    float iTimeDelta;
    float iFrameRate;
    int iFrame;
};
layout(binding = 0) uniform sampler2D iChannel0;
layout(binding = 1) uniform sampler2D iChannel1;
layout(binding = 2) uniform sampler2D iChannel2;
layout(binding = 3) uniform sampler2D iChannel3;

layout(location = 0) out vec4 Out_Color;
/*

A quick experiment with rain drop ripples.

This effect was written for and used in the launch scene of the
64kB PC intro "H - Immersion", by Ctrl-Alt-Test.

 > http://www.ctrl-alt-test.fr/productions/h-immersion/
 > https://www.youtube.com/watch?v=27PN1SsXbjM

-- 
Zavie / Ctrl-Alt-Test

*/

// Maximum number of cells a ripple can cross.
#define MAX_RADIUS 2

// Set to 1 to hash twice. Slower, but less patterns.
#define DOUBLE_HASH 0

// Hash functions shamefully stolen from:
// https://www.shadertoy.com/view/4djSRW
#define HASHSCALE1 .1031
#define HASHSCALE3 vec3(.1031, .1030, .0973)

float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * HASHSCALE1);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p)
{
	vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
    p3 += dot(p3, p3.yzx+19.19);
    return fract((p3.xx+p3.yz)*p3.zy);

}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float resolution = 10. * exp2(-3.*iMouse.x/iResolution.x);
	vec2 uv = fragCoord.xy / iResolution.y * resolution;
    vec2 p0 = floor(uv);

    vec2 circles = vec2(0.);
    for (int j = -MAX_RADIUS; j <= MAX_RADIUS; ++j)
    {
        for (int i = -MAX_RADIUS; i <= MAX_RADIUS; ++i)
        {
			vec2 pi = p0 + vec2(i, j);
            #if DOUBLE_HASH
            vec2 hsh = hash22(pi);
            #else
            vec2 hsh = pi;
            #endif
            vec2 p = pi + hash22(hsh);

            float t = fract(0.3*iTime + hash12(hsh));
            vec2 v = p - uv;
            float d = length(v) - (float(MAX_RADIUS) + 1.)*t;

            float h = 1e-3;
            float d1 = d - h;
            float d2 = d + h;
            float p1 = sin(31.*d1) * smoothstep(-0.6, -0.3, d1) * smoothstep(0., -0.3, d1);
            float p2 = sin(31.*d2) * smoothstep(-0.6, -0.3, d2) * smoothstep(0., -0.3, d2);
            circles += 0.5 * normalize(v) * ((p2 - p1) / (2. * h) * (1. - t) * (1. - t));
        }
    }
    circles /= float((MAX_RADIUS*2+1)*(MAX_RADIUS*2+1));

    float intensity = mix(0.01, 0.15, smoothstep(0.1, 0.6, abs(fract(0.05*iTime + 0.5)*2.-1.)));
    vec3 n = vec3(circles, sqrt(1. - dot(circles, circles)));
    vec3 color = texture(iChannel0, uv/resolution - intensity*n.xy).rgb + 5.*pow(clamp(dot(n, normalize(vec3(1., 0.7, 0.5))), 0., 1.), 6.);
	fragColor = vec4(color, 1.0);
}

//调整最终显示的画面在这里下面:

//rgb->hsl转换函数
vec3 rgb2hsl(vec3 c)
{
    float r = c.r;
    float g = c.g;
    float b = c.b;

    float minC = min(min(r, g), b);
    float maxC = max(max(r, g), b);
    float delta = maxC - minC;

    // 亮度 L
    float l = (maxC + minC) / 2.0;
    float h = 0.0;
    float s = 0.0;

    // 灰度：max == min，无色彩，饱和度为0
    if (delta == 0.0)
    {
        return vec3(h, s, l);
    }

    // 饱和度 S
    s = l > 0.5 
        ? delta / (2.0 - maxC - minC)
        : delta / (maxC + minC);

    // 色相 H
    if (maxC == r)
        h = ((g - b) / delta) + (g < b ? 6.0 : 0.0);
    else if (maxC == g)
        h = ((b - r) / delta) + 2.0;
    else // maxC == b
        h = ((r - g) / delta) + 4.0;

    h /= 6.0; // 缩放到 0~1

    return vec3(h, s, l);
}
//hue工具函数
float hueHelper(float p, float q, float t)
{
  if (t < 0.0) t += 1.0;
  if (t > 1.0) t -= 1.0;
  if (t < 1.0/6.0) return p + (q - p) * 6.0 * t;
  if (t < 1.0/2.0) return q;
  if (t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
  return p;
}
//hsl->rgb转换函数
vec3 hsl2rgb(vec3 c)
{
    float h = c.x;
    float s = c.y;
    float l = c.z;

    // 无饱和度，直接灰度
    if (s == 0.0)
        return vec3(l);

    float q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
    float p = 2.0 * l - q;

    float r = hueHelper(p, q, h + 1.0/3.0);
    float g = hueHelper(p, q, h);
    float b = hueHelper(p, q, h - 1.0/3.0);

    return vec3(r, g, b);
}
//调整颜色饱和度(satFactor>1变鲜艳，<1变灰),亮度
vec3 adjustSaturationBrightness(vec3 rgb, float satFactor, float brightness)
{
    vec3 hsl = rgb2hsl(rgb);
    hsl.y *= satFactor;
    hsl.y = clamp(hsl.y, 0.0, 1.0);
    hsl.z += brightness;
    hsl.z = clamp(hsl.z, 0.0, 1.0);
    return hsl2rgb(hsl);
}

void main()
{
	vec4 test_color = vec4(0.0);
	mainImage(test_color, gl_FragCoord.xy);
    vec3 fix_color = test_color.rgb;

    fix_color = adjustSaturationBrightness(fix_color, 1.2, 0.0);
    Out_Color = vec4(fix_color, 1.0);
}