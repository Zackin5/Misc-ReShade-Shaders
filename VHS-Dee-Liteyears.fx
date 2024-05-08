// Simple VHS effect inspired by a Dee Liteyears post: https://twitter.com/DeeLiteyears/status/1445430753836347392

#include "ReShade.fxh"


uniform float vhs_output_saturation <
	ui_type = "slider";
	ui_min = 0.00; ui_max = 2.00;
	ui_label = "Output Saturation";
> = 1.1;

uniform float vhs_output_exposure <
	ui_type = "slider";
	ui_min = 0.00; ui_max = 2.00;
	ui_label = "Output Exposure";
> = 1.6;

uniform float vhs_input_gamma <
	ui_type = "slider";
	ui_min = 1.00; ui_max = 3.00;
	ui_label = "Input image gamma";
	ui_tooltip = "Most monitors/images use a value of 2.2";
> = 2.2;

uniform float vhs_output_gamma <
	ui_type = "slider";
	ui_min = 1.00; ui_max = 3.00;
	ui_label = "Output image gamma";
	ui_tooltip = "Most monitors/images use a value of 2.2";
> = 2.2;


texture texVHSColor		{ Width = 40; Height = 448; Format = RGBA16F; };
texture texVHSLuma		{ Width = 333; Height = 448; Format = R16F; };
sampler texVHSColorSampler { Texture = texVHSColor; };
sampler texVHSLumaSampler { Texture = texVHSLuma; };


// both of the following from https://web.archive.org/web/20200207113336/http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl
float2 rgb2hs(float3 c)
{
	float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
	float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return float2(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e));
}


float3 hsv2rgb(float3 c)
{
	float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


float3 VHS_Dee_Liteyears_Color_downsize(float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
	return pow(tex2D(ReShade::BackBuffer, texcoord ).rgb, vhs_input_gamma);
}

float3 VHS_Dee_Liteyears_Luma_downsize(float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
	float3 color = pow(tex2D(ReShade::BackBuffer, texcoord ).rgb, vhs_input_gamma);
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
}


float3 VHS_Dee_Liteyears_blend(float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
	float alpha = tex2D(ReShade::BackBuffer, texcoord ).a;
	float3 color = tex2D(texVHSColorSampler, texcoord ).rgb;
	float luma = tex2D(texVHSLumaSampler, texcoord );

	float2 hs = rgb2hs(color.rgb);		// Convert color to hue/saturation
	hs.y *= vhs_output_saturation;

	// Blend image channels
	color = hsv2rgb(float3(hs.x, hs.y, luma));
	color.rgb *= vhs_output_exposure;	// Exposure adjustment
	color.rgb = pow(color.rgb, 1/vhs_output_gamma);	// Gamma adjustment
	return saturate(float4(color.rgb, alpha));
}


technique VHS_Dee_Liteyears
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = VHS_Dee_Liteyears_Color_downsize;
		RenderTarget = texVHSColor;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = VHS_Dee_Liteyears_Color_downsize;
		RenderTarget = texVHSLuma;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = VHS_Dee_Liteyears_blend;
	}
}