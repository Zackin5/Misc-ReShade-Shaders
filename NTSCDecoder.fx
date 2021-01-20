// Implemntation of https://www.shadertoy.com/view/Mdffz7

//  NTSC Decoder
//
//  Decodes composite video signal generated in Buffer A.
//
//  copyright (c) 2017-2018, John Leffingwell
//  license CC BY-SA Attribution-ShareAlike

#include "ReShade.fxh"

#define PI   3.14159265358979323846
#define TAU  6.28318530717958647693

//  TV-like adjustments
uniform float SAT < 
	ui_type = "drag";
	ui_min = 0.00; ui_max = 2.00; ui_step = 0.1;
	ui_label = "Saturation / Color";
	ui_category = "TV-like adjustments";
> = 1.0;

uniform float HUE <
	ui_type = "drag";
	ui_min = 0.00; ui_max = 2.00; ui_step = 0.1;
	ui_label = "Hue / Tint";
	ui_category = "TV-like adjustments";
> = 0.0;

uniform float BRI <
	ui_type = "drag";
	ui_min = 0.00; ui_max = 2.00; ui_step = 0.1;
	ui_label = "Brightness";
	ui_category = "TV-like adjustments";
> = 1.0;

//  Filter parameters
#define N   15       //  Filter Width

uniform int M <
	ui_type = "drag";
	ui_min = 1; ui_max = 10; ui_step = 1;
	ui_label = "Filter Middle";
	ui_category = "Filter parameters";
> = N/2;

uniform float FC <
	ui_type = "drag";
	ui_min = 0.00; ui_max = 1.00; ui_step = 0.05;
	ui_label = "Frequency Cutoff";
	ui_category = "Filter parameters";
> = 0.25;

uniform float SCF <
	ui_type = "drag";
	ui_min = 0.00; ui_max = 1.00; ui_step = 0.05;
	ui_label = "Subcarrier Frequency";
	ui_category = "Filter parameters";
> = 0.25;

//	Colorspace conversion matrix for YIQ-to-RGB
// uniform float3x3 YIQ2RGB = float3x3(1.000, 1.000, 1.000,
//                           0.956,-0.272,-1.106,
//                           0.621,-0.647, 1.703);

//	Colorspace conversion matrix for YIQ-to-RGB
static const float3x3 YIQ2RGB = float3x3(1.000, 0.956, 0.621,
                          1.000,-0.272,-0.647,
                          1.000,-1.106, 1.703);

//	TV-like adjustment matrix for Hue, Saturation, and Brightness
float3 adjust(float3 YIQ, float H, float S, float B) {
    float3x3 M = float3x3(  B,      0.0,      0.0,
                  0.0, S*cos(H),  sin(H), 
                  0.0,  -sin(H), S*cos(H) );
    return mul(M, YIQ);
}

//	Hann windowing function
float hann(float n1, float n2) {
    return 0.5 * (1.0 - cos((TAU*n1)/(n2-1.0)));
}

//	Sinc function
float sinc(float x) {
    if (x == 0.0) return 1.0;
	return sin(PI*x) / (PI*x);
}

float3 NtscDecoderMain( float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
	float2 size = ReShade::ScreenSize.xy;
        
    //  Compute sampling weights
    float weights[N];
    float sum = 0.0;
    for (int n=0; n<N; n++) {
        weights[n] = hann(float(n), float(N)) * sinc(FC * float(n-M));
        sum += weights[n];
    }
    
    //  Normalize sampling weights
    for (int n=0; n<N; n++) {
        weights[n] /= sum;
    }
    
    //	Sample composite signal and decode to YIQ
    float3 YIQ = float3(0.0, 0.0, 0.0);
    for (int n=0; n<N; n++) {
        float2 pos = texcoord + float2(float(n-M) / size.x, 0.0);
        float phase = TAU * (SCF * size.x * pos.x);
        YIQ += float3(1.0, cos(phase), sin(phase)) 
                * tex2D(ReShade::BackBuffer, pos).rgb * weights[n];
    }
    
    //  Apply TV adjustments to YIQ signal and convert to RGB
    return mul(YIQ2RGB, adjust(YIQ, HUE, SAT, BRI));
}

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

technique NtscDecoder
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = NtscDecoderMain;
	}
}