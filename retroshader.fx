// Reshade port of Indecom's Retro FX with Dither shader for GZDoom, with some minor tweaks
// Original GZDoom WAD is available at https://forum.zdoom.org/viewtopic.php?t=60127
// By Zackin5

#include "ReShadeUI.fxh"
#include "ReShade.fxh"

texture BayerTex < source = "Bayer.png"; > { Width = 320; Height = 200; };
texture BlueNoiseTex < source = "BlueNoise.png"; > { Width = 470; Height = 470; };

sampler Bayer { 
    Texture = BayerTex; 
    AddressU = REPEAT;
    AddressV = REPEAT;
    AddressW = REPEAT;
	MagFilter = POINT;
	MinFilter = POINT;
	MipFilter = POINT;
};
sampler BlueNoise { 
    Texture = BlueNoiseTex; 
    AddressU = REPEAT;
    AddressV = REPEAT;
    AddressW = REPEAT;
	MagFilter = POINT;
	MinFilter = POINT;
	MipFilter = POINT;
};

// Pixelate options
uniform bool EnablePixelate <
	ui_label = "Enable Pixelation";
	ui_category = "Pixelation";
> = true;

uniform float PixelCount < __UNIFORM_SLIDER_FLOAT1
	ui_min = 1.0; ui_max = 16.0; ui_step = 0.5;
	ui_label = "Pixel Scale";
	ui_category = "Pixelation";
> = 1.5;

uniform bool ScaleNearest <
	ui_label = "Enable Nearest Neighbor Scaling";
	ui_category = "Pixelation";
> = true;

// Posterization options
uniform bool EnablePosterization <
	ui_label = "Enable Bit Depth Scaling";
	ui_category = "Posterization";
> = true;

uniform float Posterization < __UNIFORM_SLIDER_FLOAT1
	ui_min = 3.0; ui_max = 32.0; ui_step = 1.0;
	ui_label = "Bit Depth";
	ui_category = "Posterization";
> = 11;

uniform int NoisePattern <
	ui_label = "Dither Pattern";
	ui_type = "combo";
	ui_label = "";
	ui_items = "Bayer\0Blue Noise\0";
	ui_category = "Posterization";
> = 0;

uniform float DitherSpread < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 32.0; ui_step = 0.5;
	ui_label = "Dither Spread";
	ui_category = "Posterization";
> = 2.5;

uniform float DitherGamma < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
	ui_label = "Gamma";
	ui_category = "Posterization";
> = 0.46;

float3 Pixelate(float2 texcoord, float spread)
{
	float2 ssize = ReShade::ScreenSize;
					
	float2 targtres = ssize / PixelCount;

    // Calculate screen sample res coord
    float2 coord;

#if __RENDERER__ < 0xa000 && !__RESHADE_PERFORMANCE_MODE__
	[flatten]
#endif
    if (ScaleNearest)
	    coord = float2( (floor(texcoord.x*targtres.x)+0.5)/targtres.x ,
                        (floor(texcoord.y*targtres.y)+0.5)/targtres.y);
    else
	    coord = float2( ceil(texcoord.x*targtres.x)/targtres.x,
                        ceil(texcoord.y*targtres.y)/targtres.y);

    // Calculate dither texture sample coord
	float2 dsize;

#if __RENDERER__ < 0xa000 && !__RESHADE_PERFORMANCE_MODE__
	[flatten]
#endif
	if(NoisePattern == 1)
		dsize = tex2Dsize(BlueNoise);
	else
		dsize = tex2Dsize(Bayer);

	float2 dcoord = float2( (texcoord.x*targtres.x) ,
				            (texcoord.y*targtres.y) ) / (dsize);
    
    // Dither tex tiling?
	dcoord.x -= ( floor(float(dcoord.x/dsize.x)) )*dsize.x;
	dcoord.y -= ( floor(float(dcoord.y/dsize.y)) )*dsize.y;

    // Sample tex
	float noiseTexel;

#if __RENDERER__ < 0xa000 && !__RESHADE_PERFORMANCE_MODE__
	[flatten]
#endif
	if(NoisePattern == 1)
		noiseTexel = tex2D(BlueNoise, dcoord ).r;
	else
		noiseTexel = tex2D(Bayer, dcoord ).r;

    // Combine dither and screenspace colors
	float dth = 1.0+(0.5-noiseTexel)/(33.5-spread);

	return tex2D(ReShade::BackBuffer, coord).rgb*dth;
}

float3 RetroPass(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{    
#if __RENDERER__ < 0xa000 && !__RESHADE_PERFORMANCE_MODE__
	[flatten]
#endif
	if ( EnablePixelate )
	{

#if __RENDERER__ < 0xa000 && !__RESHADE_PERFORMANCE_MODE__
	    [flatten]
#endif
		if ( EnablePosterization )
		{
			float3 c = Pixelate(texcoord, DitherSpread);
			c = pow(c, float3(DitherGamma, DitherGamma, DitherGamma));
			c = c * Posterization;
			c = floor(c);
			c = c / Posterization;
			c = pow(c, float3(1.0/DitherGamma, 1.0/DitherGamma, 1.0/DitherGamma));
			return c;
		}

        return Pixelate(texcoord, DitherSpread);
	}

#if __RENDERER__ < 0xa000 && !__RESHADE_PERFORMANCE_MODE__
	    [flatten]
#endif
    if( !EnablePosterization)
        return tex2D(ReShade::BackBuffer, texcoord.xy).rgb;

    float3 c = tex2D(ReShade::BackBuffer, texcoord.xy).rgb;
    c = pow(c, float3(DitherGamma, DitherGamma, DitherGamma));
    c = c * Posterization;
    c = floor(c);
    c = c / Posterization;
    c = pow(c, float3(1.0/DitherGamma, 1.0/DitherGamma, 1.0/DitherGamma));
    return c;
}

technique retroshader
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = RetroPass;
	}
}