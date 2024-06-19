// Simple VHS effect inspired by a Dee Liteyears post: https://twitter.com/DeeLiteyears/status/1445430753836347392
// Modified to use a Gaussian blur

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

#define source_res float2(640, 480)
#define color_res float2(40, 448)
#define luma_res float2(333, 448)

#ifndef sample_count
	#define sample_count 16
#endif

#define sample_edge_curve 48


texture texVHSColor_Gauss		{ Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
texture texVHSLuma_Gauss		{ Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R16F; };
sampler texVHSColorSampler_Gauss { Texture = texVHSColor_Gauss; };
sampler texVHSLumaSampler_Gauss { Texture = texVHSLuma_Gauss; };


float3 sample_filtered_pix(float2 pixel_coord, float2 offset, float2 sample_res)
{
	float2 texCoord = (pixel_coord + offset)/sample_res;

	float3 color = pow(tex2D(ReShade::BackBuffer, texCoord).rgb, vhs_input_gamma);

	// Fade colors that are sourced from out of frame
	float edge_lerp = saturate(1 + (texCoord * sample_edge_curve)) * saturate(1 - ((texCoord - 1) * sample_edge_curve));
	return lerp(float3(0,0,0), color, edge_lerp);
}

float3 sample_gaussian(float2 texCoord, float2 sample_width, float2 sample_res)
{
	// float2 pixel_coord = floor(texCoord * sample_res);
	float2 pixel_coord = texCoord * sample_res;
	float3 sample_orig = pow(tex2D(ReShade::BackBuffer, (pixel_coord)/sample_res).rgb, vhs_input_gamma);

	// Gaussian pass
	float3 sample_plan = float3(0,0,0);
	float3 sample_diag = float3(0,0,0);
	float3 sample_blurred = float3(0,0,0);
	[unroll]
	for (int x=0; x < sample_count; x++) {
		// Left / Right
		sample_plan += sample_filtered_pix(pixel_coord, float2( x *  (sample_width.x / sample_count), 0), sample_res);
		sample_plan += sample_filtered_pix(pixel_coord, float2( x * -(sample_width.x / sample_count), 0), sample_res);

		// Up / Down
		sample_plan += sample_filtered_pix(pixel_coord, float2( 0, x *  (sample_width.y / sample_count)), sample_res);
		sample_plan += sample_filtered_pix(pixel_coord, float2( 0, x * -(sample_width.y / sample_count)), sample_res);

		// Diagonal
		sample_diag += sample_filtered_pix(pixel_coord,
			float2(
				x *  (sample_width.x / sample_count), 
				x * (sample_width.x / sample_count)
			), sample_res);
		sample_diag += sample_filtered_pix(pixel_coord,
			float2(
				x * -(sample_width.x / sample_count), 
				x * (sample_width.x / sample_count)
			), sample_res);
		sample_diag += sample_filtered_pix(pixel_coord,
			float2(
				x *  (sample_width.x / sample_count), 
				x * -(sample_width.x / sample_count)
			), sample_res);
		sample_diag += sample_filtered_pix(pixel_coord,
			float2(
				x * -(sample_width.x / sample_count), 
				x * -(sample_width.x / sample_count)
			), sample_res);

		sample_blurred += (sample_diag + 2 * sample_plan + 4 * sample_orig) * 0.0625;
	}

	sample_blurred /= sample_count * (sample_count / 4.0);

	return sample_blurred;
}


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


float4 VHS_Dee_Liteyears_Color_Gaussian(float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
	float2 pixel_coord = (texcoord * color_res);
	float2 pixel_screen_coord = floor(texcoord * ReShade::ScreenSize);
	float2 sample_width = floor(source_res / 4) / color_res;

	return float4(sample_gaussian(texcoord, sample_width / vhs_res_color_mult, color_res), 1.0);
}

float VHS_Dee_Liteyears_Luma_Gaussian(float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
	float2 pixel_coord = (texcoord * luma_res);
	float2 pixel_screen_coord = floor(texcoord * ReShade::ScreenSize);
	float2 sample_width = source_res / luma_res;

	float3 color = sample_gaussian(texcoord, sample_width / vhs_res_luma_mult, luma_res);
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
}

float3 VHS_Dee_Liteyears_Blend_Gaussian(float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
	float alpha = tex2D(ReShade::BackBuffer, texcoord ).a;
	float3 color = tex2D(texVHSColorSampler_Gauss, texcoord ).rgb;
	float luma = tex2D(texVHSLumaSampler_Gauss, texcoord );

	float2 hs = rgb2hs(color.rgb);		// Convert color to hue/saturation
	hs.y = saturate(hs.y * vhs_output_saturation);

	// Blend image channels
	color = hsv2rgb(float3(hs.x, hs.y, luma));
	color.rgb *= vhs_output_exposure;	// Exposure adjustment
	color.rgb = pow(color.rgb, 1/vhs_output_gamma);	// Gamma adjustment
	return saturate(float4(color.rgb, alpha));
}


technique VHS_Dee_Liteyears_Gaussian
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = VHS_Dee_Liteyears_Color_Gaussian;
		RenderTarget = texVHSColor_Gauss;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = VHS_Dee_Liteyears_Luma_Gaussian;
		RenderTarget = texVHSLuma_Gauss;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = VHS_Dee_Liteyears_Blend_Gaussian;
	}
}