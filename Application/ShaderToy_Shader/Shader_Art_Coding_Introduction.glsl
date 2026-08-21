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

/* This animation is the material of my first youtube tutorial about creative 
   coding, which is a video in which I try to introduce programmers to GLSL 
   and to the wonderful world of shaders, while also trying to share my recent 
   passion for this community.
                                       Video URL: https://youtu.be/f4s1h2YETNY
*/

//https://iquilezles.org/articles/palettes/
vec3 palette( float t ) {
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.263,0.416,0.557);

    return a + b*cos( 6.28318*(c*t+d) );
}

//https://www.shadertoy.com/view/mtyGWy
void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    vec2 uv0 = uv;
    vec3 finalColor = vec3(0.0);
    
    for (float i = 0.0; i < 4.0; i++) {
        uv = fract(uv * 1.5) - 0.5;

        float d = length(uv) * exp(-length(uv0));

        vec3 col = palette(length(uv0) + i*.4 + iTime*.4);

        d = sin(d*8. + iTime)/8.;
        d = abs(d);

        d = pow(0.01 / d, 1.2);

        finalColor += col * d;
    }
        
    fragColor = vec4(finalColor, 1.0);
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
    vec3 fix_color = adjustSaturationBrightness(test_color.rgb, 2.0, 0.0);

    Out_Color = vec4(fix_color, 1.0);
}