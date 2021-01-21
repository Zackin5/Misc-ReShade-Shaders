// A shader to emulate Apple II color rendering technique (use with a second NTSC shader pass like NTSCDEcoder.fx)

#include "ReShade.fxh"

uniform bool EnableBoolColors <
	ui_label = "Enable Boolean Colors";
	ui_category = "Boolean Colors";
> = true;

uniform float BoolColorThreshold <
	ui_type = "drag";
	ui_min = 0.00; ui_max = 1.00; ui_step = 0.01;
	ui_label = "Color Cutoff";
	ui_category = "Boolean Colors";
> = 0.25;

float GetPixelPower(int pixelOffset, float3 color)
{
    if(pixelOffset == 0)
        return color.r;
    else if(pixelOffset == 1)
        return color.b;
    else if(pixelOffset == 2)
        return color.g;
    else if(pixelOffset == 3)
        return ((color.r * 0.2126) + (color.g * 0.7152));   // numbers from luminosity conversion
    else
        return 0;
}

float3 AppleIIPixMain( float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
    int2 pixel = texcoord * ReShade::ScreenSize.xy;
    int pixelOffset = pixel.x % 4;
    int2 parentPixel = pixel - int2(pixelOffset, 0);
    float2 parentCoord = parentPixel / ReShade::ScreenSize.xy;

    float3 color = tex2D(ReShade::BackBuffer, parentCoord).rgb;

    float pixPower = GetPixelPower(pixelOffset, color);

    if(EnableBoolColors)
        return pixPower > BoolColorThreshold;
    else
        return pixPower;
}

technique AppleIIPix
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = AppleIIPixMain;
	}
}