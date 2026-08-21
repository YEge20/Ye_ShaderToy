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


#define PI     3.1415926535897921284
#define REP    25
#define d2r(x) (x * PI / 180.0)
#define WBCOL  (vec3(0.5, 0.7,  1.7))
#define WBCOL2 (vec3(0.15, 0.8, 1.7))
#define ZERO   (min(iFrame,0))

float hash( vec2 p ) {
	float h = dot( p, vec2( 127.1, 311.7 ) );
	return fract( sin( h ) * 458.325421) * 2.0 - 1.0;
}

float noise( vec2 p ) {
	vec2 i = floor( p );
	vec2 f = fract( p );
	
	f = f * f * ( 3.0 - 2.0 * f );
	
	return mix(
		mix( hash( i + vec2( 0.0, 0.0 ) ), hash( i + vec2( 1.0, 0.0 ) ), f.x ),
		mix( hash( i + vec2( 0.0, 1.0 ) ), hash( i + vec2( 1.0, 1.0 ) ), f.x ),
		f.y
	);
}

vec2 rot(vec2 p, float a) {
	return vec2(
		p.x * cos(a) - p.y * sin(a),
		p.x * sin(a) + p.y * cos(a));
}

float nac(vec3 p, vec2 F, vec3 o) {
	const float R = 0.0001;
	p += o;
	return length(max(abs(p.xy)-vec2(F),0.0)) - R;	
}


float by(vec3 p, float F, vec3 o) {
	const float R = 0.0001;
	p += o;
	return length(max(abs(mod(p.xy, 3.0))-F,0.0)) - R;	
}


float recta(vec3 p, vec3 F, vec3 o) {
	const float R = 0.0001;
	p += o;
	return length(max(abs(p)-F,0.0)) - R;	
}


float map1(vec3 p, float scale) {
	float G = 0.50;
	float F = 0.50 * scale;
	float t =  nac(p, vec2(F,F), vec3( G,  G, 0.0));
	t = min(t, nac(p, vec2(F,F), vec3( G, -G, 0.0)));
	t = min(t, nac(p, vec2(F,F), vec3(-G,  G, 0.0)));
	t = min(t, nac(p, vec2(F,F), vec3(-G, -G, 0.0)));
	return t;
}

float map2(vec3 p) {
	float t = map1(p, 0.9);
	//t = max(t, recta(p, vec3(1.0, 1.0, 0.02), vec3(0.0, 0.0, 0.0)));
    t = max(t, recta(p, vec3(1.0, 1.0, 0.02), vec3(0.0, 0.0, 0.0)));
	return t;
}


// http://glslsandbox.com/e#26840.0
float gennoise(vec2 p) {
	float d = 0.5;
	mat2 h = mat2( 1.6, 1.2, -1.2, 1.6 );
	
	float color = 0.0;
	for( int i = 0; i < 2; i++ ) {
		color += d * noise( p * 5.0 + iTime);
		p *= h;
		d /= 2.0;
	}
	return color;
}


void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    fragColor = vec4(0.0);
    for(int count = 0 ; count < 2; count++) {
        vec2 uv = -1.0 + 2.0 * ( fragCoord.xy / iResolution.xy );
        uv *= 1.4;
        uv.x += hash(uv.xy + iTime + float(count)) / 512.0;
        uv.y += hash(uv.yx + iTime + float(count)) / 512.0;
        vec3 dir = normalize(vec3(uv * vec2(iResolution.x / iResolution.y, 1.0), 1.0 + sin(iTime) * 0.01));
        dir.xz = rot(dir.xz, d2r(70.0));
        dir.xy = rot(dir.xy, d2r(90.0));
        vec3 pos    = vec3(-0.1 + sin(iTime * 0.3) * 0.1, 2.0 + cos(iTime * 0.4) * 0.1, -3.5);
        vec3  col   = vec3(0.0);
        float t     = 0.0;
        float M     = 1.002;
        float bsh   = 0.01;
        float dens  = 0.0;

        for(int i = ZERO ; i < REP * 24; i++) {
            float temp = map1(pos + dir * t, 0.6);
            if(temp < 0.2) {
                col += WBCOL * 0.005 * dens;
            }
            t += bsh * M;
            bsh *= M;
            dens += 0.025;
        }

        //windows
        t = 0.0;
        float y = 0.0;
        //for(int i = 0 ; i < REP * 50; i++)
        for(int i = ZERO ; i < REP; i++)
        {
            float temp = map2(pos + dir * t);
            if(temp < 0.025) {
                //col += WBCOL2 * 0.005;
                col += WBCOL2 * 0.5;
            }
            t += temp;
            y++;
        }
        col += ((2.0 + uv.x) * WBCOL2) + (y / (25.0 * 50.0));
        col += gennoise(dir.xz) * 0.5;
        col *= 1.0 - uv.y * 0.5;
        col *= vec3(0.05);
        col  = pow(col, vec3(0.717));
        fragColor += vec4(col, 1.0 / (t));
    }
    fragColor /= vec4(2.0);
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

    //fix_color = pow(fix_color, vec3(3.0))-vec3(0.18) + 0.45*(0.5*pow(2.0*fix_color-1.0, vec3(3.0))+0.5);
    Out_Color = vec4(fix_color, 1.0);
}