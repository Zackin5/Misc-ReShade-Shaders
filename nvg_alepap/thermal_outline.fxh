/**
 * Depth-buffer based cel shading for ENB by kingeric1992
 * http://enbseries.enbdev.com/forum/viewtopic.php?f=7&t=3244#p53168
 *
 * Modified and optimized for ReShade by JPulowski
 * http://reshade.me/forum/shader-presentation/261
 *
 * Do not distribute without giving credit to the original author(s).
 * 
 * 1.0  - Initial release/port
 * 1.1  - Replaced depth linearization algorithm with another one by crosire
 *        Added an option to tweak accuracy
 *        Modified the code to make it compatible with SweetFX 2.0 Preview 7 and new Operation Piggyback which should give some performance increase
 * 1.1a - Framework port
 * 1.2  - Changed the name to "Outline" since technically this is not Cel shading (See https://en.wikipedia.org/wiki/Cel_shading)
 *        Added custom outline and background color support
 *        Added a threshold and opacity modifier
 * 1.2a - Now uses the depth buffer linearized by ReShade therefore it should work with pseudo/logaritmic/negative/flipped depth
 *        It is now possible to use the color texture for edge detection
 *        Rewritten and simplified some parts of the code
 * 1.3  - Rewritten for ReShade 3.0 by crosire
 */

uniform int NOD_Thermal_EdgeDetectionMode <
	ui_type = "combo";
	ui_items = "Color edge detection\0Normal-depth edge detection\0";
	ui_label = "Edge Detection Mode";
	ui_category = "Thermal";
> = 1;

uniform float Thermal_monochrome_threshold <
	ui_label = "Color Edge Threshold";
	ui_category = "Thermal";
	ui_type = "slider";
	ui_min = 0.00; ui_max = 10.00;
> = 6.125f;

uniform float Thermal_monochrome_contrast <
	ui_label = "Color Edge Contrast";
	ui_category = "Thermal";
	ui_type = "slider";
	ui_min = 0.00; ui_max = 10.00;
> = 1.0f;

uniform bool NOD_THERMAL_DEBUG <
    ui_label = "Edge Debug";
	ui_category = "Thermal";
> = false;

float3 GetEdgeSample(float2 coord)
{
	if (NOD_Thermal_EdgeDetectionMode)
	{
		float4 depth = float4(
			ReShade::GetLinearizedDepth(coord + ReShade::PixelSize * float2(1, 0)),
			ReShade::GetLinearizedDepth(coord - ReShade::PixelSize * float2(1, 0)),
			ReShade::GetLinearizedDepth(coord + ReShade::PixelSize * float2(0, 1)),
			ReShade::GetLinearizedDepth(coord - ReShade::PixelSize * float2(0, 1))
		);

		return normalize(float3(float2(depth.x - depth.y, depth.z - depth.w) * ReShade::ScreenSize, 1.0));
	}
	else
	{
		float3 color = tex2D(sNVG_Thermal, coord).rgb;
		color = pow(abs(color * 2.0 - 1.0), 1.0 / max(Thermal_monochrome_contrast, 0.0001f)) * sign(color - 0.5) + 0.5; // Contrast
		return normalize(color);
	}
}

float ThermalOutline(float2 texcoord, float edgeDetectionAccuracy)
{
	// Sobel operator matrices
	const float3 Gx[3] =
	{
		float3(-1.0, 0.0, 1.0),
		float3(-2.0, 0.0, 2.0),
		float3(-1.0, 0.0, 1.0)
	};
	const float3 Gy[3] =
	{
		float3( 1.0,  2.0,  1.0),
		float3( 0.0,  0.0,  0.0),
		float3(-1.0, -2.0, -1.0)
	};
	
	float3 dotx = 0.0, doty = 0.0;
	
	// Edge detection
	for (int i = 0, j; i < 3; i++)
	{
		j = i - 1;

		dotx += Gx[i].x * GetEdgeSample(texcoord + ReShade::PixelSize * float2(-1, j));
		dotx += Gx[i].y * GetEdgeSample(texcoord + ReShade::PixelSize * float2( 0, j));
		dotx += Gx[i].z * GetEdgeSample(texcoord + ReShade::PixelSize * float2( 1, j));
		
		doty += Gy[i].x * GetEdgeSample(texcoord + ReShade::PixelSize * float2(-1, j));
		doty += Gy[i].y * GetEdgeSample(texcoord + ReShade::PixelSize * float2( 0, j));
		doty += Gy[i].z * GetEdgeSample(texcoord + ReShade::PixelSize * float2( 1, j));
	}
	
	// Boost edge detection
	dotx *= edgeDetectionAccuracy;
	doty *= edgeDetectionAccuracy;

	// Return custom color when weight over threshold
	float edgeProduct = sqrt(dot(dotx, dotx) + dot(doty, doty));

	if (NOD_THERMAL_DEBUG)
		return saturate(edgeProduct);
	else
		return saturate(edgeProduct - Thermal_monochrome_threshold);
}