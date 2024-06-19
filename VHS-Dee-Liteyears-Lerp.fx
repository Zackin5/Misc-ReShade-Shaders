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
> = 1.0;

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

uniform float vhs_res_color_mult <
	ui_type = "slider";
	ui_min = 0.01; ui_max = 3.00;
	ui_step = 0.05;
	ui_label = "Image chroma resolution multiplier";
	ui_tooltip = "Use 0.5x for longplay, or 0.25 for super longplay";
> = 1.0;

uniform float vhs_res_luma_mult <
	ui_type = "slider";
	ui_min = 0.01; ui_max = 3.00;
	ui_step = 0.05;
	ui_label = "Image luma resolution multiplier";
	ui_tooltip = "Use 0.5x for longplay, or 0.25 for super longplay";
> = 1.0;

#define vhs_color_res float2(40, 448)
#define vhs_luma_res float2(333, 448)

#ifndef vhs_lerp_sample_count
	#define vhs_lerp_sample_count 2
#endif

texture texVHSColor_Lerp		{ Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RG16F; };
texture texVHSLuma_Lerp		{ Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R16F; };
sampler texVHSColorSampler_Lerp { Texture = texVHSColor_Lerp; };
sampler texVHSLumaSampler_Lerp { Texture = texVHSLuma_Lerp; };

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

float3 Sample_Color_Downsize_offset(float2 texcoord, float2 sample_resolution, float2 sample_offset)
{
	float2 pixel_size = 1.0 / sample_resolution;
	float2 pixel_coord = floor(texcoord * sample_resolution);
	float2 pixel_sample_offset = pixel_size * sample_offset;

	float2 sub_coord00 = (pixel_coord/sample_resolution);
	float2 sub_coord10 = sub_coord00 + float2(pixel_size.x, 0);	// +x
	float2 sub_coord01 = sub_coord00 + float2(0, pixel_size.y);	// +y
	float2 sub_coord11 = sub_coord00 + pixel_size.xy;			// +xy
	float2 vector_sub_coord = abs(texcoord - sub_coord00)/(sub_coord11 - sub_coord00);

	float3 color00 = tex2D(ReShade::BackBuffer, sub_coord00 + pixel_sample_offset ).rgb;
	float3 color10 = tex2D(ReShade::BackBuffer, sub_coord10 + pixel_sample_offset ).rgb;
	float3 color01 = tex2D(ReShade::BackBuffer, sub_coord01 + pixel_sample_offset ).rgb;
	float3 color11 = tex2D(ReShade::BackBuffer, sub_coord11 + pixel_sample_offset ).rgb;

	float3 color_y0 = lerp(color00, color10, vector_sub_coord.x);
	float3 color_y1 = lerp(color01, color11, vector_sub_coord.x);
	float3 color = lerp(color_y0, color_y1, vector_sub_coord.y);

	return color;
}

float3 Sample_Color_Downsize(float2 texcoord, float2 sample_resolution)
{
	float3 color = Sample_Color_Downsize_offset(texcoord, sample_resolution, float2(0.0, 0.0));

	// Sub pixel samples if sample count is > 1
	[unroll]
	for (int i = 1; i < vhs_lerp_sample_count; i++)
	{
		float offset = (1.0 / vhs_lerp_sample_count) * i;
		float hypo_offset = sqrt(pow(offset, 2)/2.0);	// Radial curve on (1,1) sample to provide a round blur

		color += Sample_Color_Downsize_offset(texcoord, sample_resolution, float2(0.0, offset));
		color += Sample_Color_Downsize_offset(texcoord, sample_resolution, float2(offset, 0.0));
		color += Sample_Color_Downsize_offset(texcoord, sample_resolution, float2(hypo_offset, hypo_offset));
	}

	color /= 1 + ((vhs_lerp_sample_count - 1) * 3);

	color = pow(color, vhs_input_gamma);
	return saturate(color);
}


float2 VHS_Dee_Liteyears_Color_Lerp(float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
	float3 color = Sample_Color_Downsize(texcoord, vhs_color_res * vhs_res_color_mult);
	return rgb2hs(color.rgb); // Convert color to hue/saturation
}

float VHS_Dee_Liteyears_Luma_Lerp(float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
	float3 color = Sample_Color_Downsize(texcoord, vhs_luma_res * vhs_res_luma_mult);
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
}

float3 VHS_Dee_Liteyears_Blend_Lerp(float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
	float alpha = tex2D(ReShade::BackBuffer, texcoord ).a;
	float2 hs = tex2D(texVHSColorSampler_Lerp, texcoord ).rg;
	float luma = tex2D(texVHSLumaSampler_Lerp, texcoord );

	hs.y = saturate(hs.y * vhs_output_saturation);	// Saturation adjustment

	// Blend image channels
	float3 color = hsv2rgb(float3(hs.x, hs.y, luma));
	color.rgb *= vhs_output_exposure;	// Exposure adjustment
	color.rgb = pow(color.rgb, 1/vhs_output_gamma);	// Gamma adjustment
	return saturate(float4(color.rgb, alpha));
}


technique VHS_Dee_Liteyears_Lerp
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = VHS_Dee_Liteyears_Color_Lerp;
		RenderTarget = texVHSColor_Lerp;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = VHS_Dee_Liteyears_Luma_Lerp;
		RenderTarget = texVHSLuma_Lerp;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = VHS_Dee_Liteyears_Blend_Lerp;
	}
}