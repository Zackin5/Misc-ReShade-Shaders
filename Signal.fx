
#include "ReShadeUI.fxh"

uniform int MaskPattern <
	ui_min = 0; ui_max = 2;
	ui_label = "Masking Pattern";
> = int(0);

// CA vars
uniform bool CaEnabled <
	ui_label = "Enabled";
	ui_tooltip = "Enable Chromatic Abberation";
	ui_category = "Chromatic Abberation";
> = true;

uniform float3 CaShiftRgb < __UNIFORM_SLIDER_FLOAT3
	ui_min = -20; ui_max = 20;
	ui_tooltip = "Amount to shift each colour channel (RGB)";
	ui_category = "Chromatic Abberation";
> = float3(0, 10, 20);

uniform float CaStrength < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_category = "Chromatic Abberation";
> = 0.5;

uniform bool CaMask <
	ui_label = "Mask";
	ui_tooltip = "Enable abberation scaling from mask";
	ui_category = "Chromatic Abberation";
> = true;

uniform float CaCurve < __UNIFORM_SLIDER_FLOAT1
	ui_label = "Aberration curve";
	ui_min = 0.0; ui_max = 4.0; ui_step = 0.01;
	ui_category = "Chromatic Abberation";
> = 1.0;

// Signal vars
uniform bool SigEnabled <
	ui_label = "Enabled";
	ui_tooltip = "Enable Signal Distortion";
	ui_category = "Signal";
> = true;

uniform float SigStrength < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_category = "Signal";
> = 0.5;

uniform float SigCutoff < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_category = "Signal";
	ui_tooltip = "Brightness cutoff for pixel distortion";
> = 0.75;

uniform float3 SigXShiftRgb < __UNIFORM_SLIDER_FLOAT3
	ui_min = -5; ui_max = 5;
	ui_tooltip = "X range to shift each colour channel (RGB)";
	ui_category = "Signal";
> = float3(2.5, 2, 2);

uniform int3 SigOffsetRgb < __UNIFORM_SLIDER_FLOAT3
	ui_min = 0; ui_max = 64;
	ui_tooltip = "Distortion signal timing offset for each colour channel (RGB)";
	ui_category = "Signal";
> = int3(0, 24, 48);

uniform int SigYScale < __UNIFORM_SLIDER_FLOAT3
	ui_min = 1; ui_max = 50;
	ui_tooltip = "Vertical pixel height of distortion";
	ui_category = "Signal";
> = int(1);

uniform bool SigXRandomOffset <
	ui_label = "Shimmer";
	ui_tooltip = "Enable shimmering";
	ui_category = "Signal";
> = true;

uniform float SigXRandomOffsetScale < __UNIFORM_SLIDER_FLOAT1
	ui_label = "Shimmer Scale";
	ui_min = 4.0; ui_max = 100.0;
	ui_category = "Signal";
	ui_tooltip = "Shimmer distance offset scale";
> = 50;

uniform bool SigYRandomOffset <
	ui_label = "Randomize Offset";
	ui_tooltip = "Enable random offsets each frame";
	ui_category = "Signal";
> = true;

uniform bool SigMaskShimmer <
	ui_label = "Shimmer Mask";
	ui_tooltip = "Enables shimmer effect being scaled from center of screen";
	ui_category = "Signal";
> = false;

uniform bool SigMaskCutoff <
	ui_label = "Cutoff Mask";
	ui_tooltip = "Enables signal cutoff value scaling from center of screen";
	ui_category = "Signal";
> = false;

uniform float SigMaskCurve < __UNIFORM_SLIDER_FLOAT1
	ui_label = "Mask curve";
	ui_min = 0.0; ui_max = 4.0; ui_step = 0.01;
	ui_category = "Signal";
> = 1.0;

uniform float timer < source = "timer"; >;
uniform int random < source = "random"; min = -100; max = 100; >;

#include "ReShade.fxh"

float2 GetRadialCoord(float2 texcoord : TexCoord){
	// Grab Aspect Ratio
	float Aspect = ReShade::AspectRatio;
	// Grab Pixel V size
	float Pixel = ReShade::PixelSize.y;
	
	// Convert UVs to centered coordinates with correct Aspect Ratio
	float2 RadialCoord = texcoord - 0.5;
	RadialCoord.x *= Aspect;

	return RadialCoord;
}

float GetMask(float curve, float2 texcoord : TexCoord){
	if(MaskPattern == 0)
	{
		// Radial mask
		float2 RadialCoord = GetRadialCoord(texcoord);
		
		// Grab Aspect Ratio
		float Aspect = ReShade::AspectRatio;

		// Generate radial mask from center (0) to the corner of the screen (1)
		return pow(2.0 * length(RadialCoord) * rsqrt(Aspect * Aspect + 1.0), curve);
	}
	else if(MaskPattern == 1)
	{
		// Vertical gradiant
		float2 RadialCoord = GetRadialCoord(texcoord);
		
		// Grab Aspect Ratio
		float Aspect = ReShade::AspectRatio;

		return pow(2.0 * length(RadialCoord.y) * rsqrt(Aspect * Aspect + 1.0), curve);
	}
	else
	{
		// Horz gradiant
		float2 RadialCoord = GetRadialCoord(texcoord);
		
		// Grab Aspect Ratio
		float Aspect = ReShade::AspectRatio;

		return pow(2.0 * length(RadialCoord.x) * rsqrt(Aspect * Aspect + 1.0), curve);
	}
}

// Mixmaster CA effect from Prism.fx and ChromaticAberration.fx
float3 ChromaticAberrationPass(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	if(!CaEnabled)
		return tex2D(ReShade::BackBuffer, texcoord).rgb;
		
	float2 Mask = float2(1,0);

	if(CaMask)
	{
		float2 RadialCoord = GetRadialCoord(texcoord);
		Mask = GetMask(CaCurve, texcoord) * RadialCoord;
	}

	float3 color, colorInput = tex2D(ReShade::BackBuffer, texcoord).rgb;

	// Sample the color components
	color.r = tex2D(ReShade::BackBuffer, texcoord - (ReShade::PixelSize * Mask * CaShiftRgb.r)).r;
	color.g = tex2D(ReShade::BackBuffer, texcoord - (ReShade::PixelSize * Mask * CaShiftRgb.g)).g;
	color.b = tex2D(ReShade::BackBuffer, texcoord - (ReShade::PixelSize * Mask * CaShiftRgb.b)).b;

	// Adjust the strength of the effect
	return lerp(colorInput, color, CaStrength);
}

// Precalculated list of random offsets to reduce computation overhead
static const int offsetsLength = 64;
static const int offsets[] = { 2 , 4, 3, 3, -3 , 2, 3, -2 , -5 , 0, 0, -5 , 3, -4 , 0, 2, 3, 3, 0, 0, 1, 3, 3, -4 , 2, -2 , 4, 0, 2, 4, 0, 0, 1, -3 , 2, 2, 4, -4 , 2, -5 , -1 , 2, -4 , 2, 4, 3, -3 , -5 , 2, -4 , 1, 0, -2 , -4 , 3, 3, 3, -1 , -5 , -3 , -2 , 3, -3 , -3};

float2 GetSignalOffset(float channelOffset, int offsetIndex, float2 texcoord : TexCoord){
	// Get an index of the random offset array and use it to calculate a new offset
	float rOffset = offsets[offsetIndex];

	if(SigXRandomOffset)
		rOffset += random / SigXRandomOffsetScale;

	float xOffset = ReShade::PixelSize.x * rOffset * channelOffset;

	// Apply signal mask if enabled
	if(SigMaskShimmer){
		float Mask = GetMask(SigMaskCurve, texcoord);

		xOffset *= Mask;
	}

	return texcoord + float2(xOffset, 0);
}

float3 SignalPass(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	if(!SigEnabled)
		return tex2D(ReShade::BackBuffer, texcoord).rgb;

	float3 color, colorInput = tex2D(ReShade::BackBuffer, texcoord).rgb;

	// Calulate offset array indexes for getting "random" pixel offsets
	int yPixel = (texcoord.y / SigYScale) * ReShade::ScreenSize.y;

	if(SigYRandomOffset)
		yPixel += random;

	int offsetRindex = (yPixel + SigOffsetRgb.r) % offsetsLength;
	int offsetGindex = (yPixel + SigOffsetRgb.g) % offsetsLength;
	int offsetBindex = (yPixel + SigOffsetRgb.b) % offsetsLength;

	// Sample the color components
	color.r = tex2D(ReShade::BackBuffer, GetSignalOffset(SigXShiftRgb.r, offsetRindex, texcoord)).r;
	color.g = tex2D(ReShade::BackBuffer, GetSignalOffset(SigXShiftRgb.g, offsetGindex, texcoord)).g;
	color.b = tex2D(ReShade::BackBuffer, GetSignalOffset(SigXShiftRgb.b, offsetBindex, texcoord)).b;

	// Apply signal cutoffs
	float cutoffScale = SigCutoff;

	if(SigMaskCutoff){
		float Mask = GetMask(SigMaskCurve, texcoord);

		cutoffScale -= Mask;
	}

	if(cutoffScale > color.r)
		color.r = colorInput.r;
	if(cutoffScale > color.g)
		color.g = colorInput.g;
	if(cutoffScale > color.b)
		color.b = colorInput.b;

	// Adjust the strength of the effect
	return lerp(colorInput, color, SigStrength);
}

technique Signal
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = ChromaticAberrationPass;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = SignalPass;
	}
}