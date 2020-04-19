// Loose Connection shader
// by hunterk
// adapted from drmelon's VHS Distortion shadertoy:
// https://www.shadertoy.com/view/4dBGzK
// ryk's VCR Distortion shadertoy:
// https://www.shadertoy.com/view/ldjGzV
// and Vladmir Storm's VHS Tape Noise shadertoy:
// https://www.shadertoy.com/view/MlfSWr
// Ported from RetroArch shader

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

uniform float magnitude <
	ui_label = "Distortion Magnitude";
	ui_min = 0.0; ui_max = 25.0; ui_step = 0.1;
	ui_type = "slider";
> = 0.9;

uniform float timer < source = "timer"; >;

float fmod(float a, float b) {
	float c = frac(abs(a / b)) * abs(b);
	return a < 0 ? -c : c;
}

float rand(float2 co)
{
     float a = 12.9898;
     float b = 78.233;
     float c = 43758.5453;
     float dt= dot(co.xy ,float2(a,b));
     float sn= fmod(dt,3.14);
    return frac(sin(sn) * c);
}

//random hash
float4 hash42(float2 p){
    
	float4 p4 = frac(float4(p.xyxy) * float4(443.8975,397.2973, 491.1871, 470.7827));
    p4 += dot(p4.wzxy, p4+19.19);
    return frac(float4(p4.x * p4.y, p4.x*p4.z, p4.y*p4.w, p4.x*p4.w));
}

float hash( float n ){
    return frac(sin(n)*43758.5453123);
}

// 3d noise function (iq's)
float n( in float3 x ){
    float3 p = floor(x);
    float3 f = frac(x);
    f = f*f*(3.0-2.0*f);
    float n = p.x + p.y*57.0 + 113.0*p.z;
    float res = lerp(lerp(lerp( hash(n+  0.0), hash(n+  1.0),f.x),
                        lerp( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y),
                    lerp(lerp( hash(n+113.0), hash(n+114.0),f.x),
                        lerp( hash(n+170.0), hash(n+171.0),f.x),f.y),f.z);
    return res;
}

//tape noise
float nn(float2 p, float framecount){
    float y = p.y;
    float s = fmod(framecount * 0.15, 4837.0);
    
    float v = (n( float3(y*.01 +s, 			1., 1.0) ) + .0)
          	 *(n( float3(y*.011+1000.0+s, 	1., 1.0) ) + .0) 
          	 *(n( float3(y*.51+421.0+s, 	1., 1.0) ) + .0)   
        ;
   	v*= hash42(   float2(p.x +framecount*0.01, p.y) ).x +.3 ;

    
    v = pow(v+.3, 1.);
	if(v<.99) v = 0.;  //threshold
    return v;
}

float3 distort(sampler tex, float2 uv, float size, float framecount){
	float mag = size * 0.0001;

	float2 offset_x = float2(uv.x, uv.x);
	offset_x.x += rand(float2(fmod(framecount, 9847.0) * 0.03, uv.y * 0.42)) * 0.001 + sin(rand(float2(fmod(framecount, 5583.0) * 0.2, uv.y))) * mag;
	offset_x.y += rand(float2(fmod(framecount, 5583.0) * 0.004, uv.y * 0.002)) * 0.004 + sin(fmod(framecount, 9847.0) * 9.0) * mag;
	
	return float3(tex2D(tex, float2(offset_x.x, uv.y)).r,
				tex2D(tex, float2(offset_x.y, uv.y)).g,
				tex2D(tex, uv).b);
}

float onOff(float a, float b, float c, float framecount)
{
	return step(c, sin((framecount * 0.001) + a*cos((framecount * 0.001)*b)));
}

float2 jumpy(float2 uv, float framecount)
{
	float2 look = uv;
	float window = 1./(1.+80.*(look.y-fmod(framecount/4.,1.))*(look.y-fmod(framecount/4.,1.)));
	look.x += 0.05 * sin(look.y*10. + framecount)/20.*onOff(4.,4.,.3, framecount)*(0.5+cos(framecount*20.))*window;
	float vShift = 0.4*onOff(2.,3.,.9, framecount)*(sin(framecount)*sin(framecount*20.) + 
										 (0.5 + 0.1*sin(framecount*200.)*cos(framecount)));
	look.y = fmod(look.y - 0.01 * vShift, 1.);
	return look;
}

float4 loose_connection(float2 video_size, float2 texCoord)
{
    float3 res = distort(ReShade::BackBuffer, jumpy(texCoord, timer), magnitude, timer);
	float col = nn(-texCoord * video_size.y * 4.0, timer);

	float4 final = float4(res + clamp(float3(col, col, col), 0.0, 0.5), 1.0);
	return final;
}

float4 main_fragment(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	return loose_connection(ReShade::ScreenSize, texcoord);
}

technique LooseConnection
{
	pass LooseConnection
	{
		VertexShader=PostProcessVS;
		PixelShader=main_fragment;
	}
}