// Flattened version of Alepap's True Night Vision preset

// Prest order:
// DarkeningMask______________________________V@UIMask2.fx
// Darkening@qUINT_lightroom.fx
// DarkeningMask______________________________@UIMask2.fx
// MonoMask_______________________________________________V@UIMask.fx
// ThermalMask____________________V@UIMask3.fx
// ThermalGlass@NVMonochrome.fx
// ThermalOverlay@Outline.fx
// ThermalMask____________________@UIMask3.fx
// Autofocus@NVCinematicDOF.fx
// Infrared@PD80_04_BlacknWhite.fx
// Grain1@NVPD80_06_Film_Grain2.fx
// Grain2@NVPD80_06_Film_Grain.fx
// Bloom_AutoExposure@qUINT_bloom.fx
// LensDistortion@NVPD80_06_Chromatic_Aberration.fx
// Desaturate@PD80_04_BlacknWhite2.fx
// ColorBalance@PD80_04_Color_Balance.fx
// ExtendedColor@TVExtendedLevels.fx
// Mono_Bino_Vignette@NVVignette.fx
// MonoMask_______________________________________________@UIMask.fx

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

uniform float2 NOD_POS <
	ui_type = "drag";
	ui_min = -1.0; ui_max = 1.0;
	ui_label = "Monocle Position";
	ui_tooltip = "Adjusts position of the monocle on the display";
	step = float2(0.01f, 0.01f);
> = float2(0.0,-0.19);

uniform float NOD_POS_Z <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Monocle Depth";
	ui_tooltip = "Depth offset (emulated via zoom) of the monocle";
	step = float2(0.01f, 0.01f);
> = float(0.025);

uniform float NOD_RAD <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "Monocle Radius";
	ui_tooltip = "Adjusts the size of the monocle display";
> = 1.0;

uniform float3 NOD_COLOR <
	ui_type = "drag";
	ui_label = "Phosphor Color";
	ui_tooltip = "Color of the phosphor element.";
> = float3(1.92f,1.00f,7.47f);

uniform float NOD_GRAIN_INTENSITY <
	ui_type = "slider";
	ui_min = 0.00; ui_max = 4.00;
	ui_label = "Grain Intensity";
	ui_tooltip = "Multiplies visual noise. Use higher values to emulate lower gen equipment.";
> = 1.0;

uniform bool NOD_THERMAL <
    ui_label = "Enable";
	ui_category = "Thermal";
> = true;

uniform float NOD_THERMAL_RAD <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "Thermal Radius";
	ui_tooltip = "Adjusts the size of the thermal display";
	ui_category = "Thermal";
> = 1.0;

uniform float NOD_THERMAL_INTENSITY <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "Thermal Intensity";
	ui_tooltip = "Intensity of the thermal display";
	ui_category = "Thermal";
> = 1.0;

uniform float NOD_THERMAL_REFLECTOR <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Thermal Reflector Glow";
	ui_tooltip = "Intensity of the COTI reflector glow";
	ui_category = "Thermal";
> = 0.005;

texture2D tNVG_Backup	{ Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT;};
texture2D tNVG_Thermal	{ Width = 640; Height = 480; Format=R8;};
texture tNVG_Mask <source="nvg_alepap/NvgMask.png";> { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format=R8; };
texture tNVG_Thermal_Mask <source="nvg_alepap/ThermalMask.png";> { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format=R8; };

sampler2D sNVG_Backup	{ Texture = tNVG_Backup;	};
sampler2D sNVG_Thermal	{ Texture = tNVG_Thermal;	};
sampler sNVG_Mask { Texture = tNVG_Mask; };
sampler sNVG_Thermal_Mask { Texture = tNVG_Thermal_Mask; };

#include "nvg_alepap/thermal_monochrome.fxh"
#include "nvg_alepap/thermal_denoise.fxh"
#include "nvg_alepap/thermal_outline.fxh"

#include "nvg_alepap/nvg_blacknwhite.fxh"
#include "nvg_alepap/nvg_film_grain.fxh"
#include "nvg_alepap/nvg_bloom.fxh"
#include "nvg_alepap/nvg_lens_abberation.fxh"
#include "nvg_alepap/nvg_vignette.fxh"
#include "nvg_alepap/nvg_mask.fxh"

float2 getZoomedCoord(float2 texcoord)
{
	float2 zoomCoord = texcoord - 0.5f; // Offset to center
	zoomCoord /= 1.0f + NOD_POS_Z; // Multiply by center
	zoomCoord += 0.5f; // Recenter

	return saturate(zoomCoord);
}

float4 nvg_alepap_pass0_backup(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	return tex2D(ReShade::BackBuffer, texcoord);
}

float4 nvg_alepap_thermal_pass0(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// Get monochrome color
	float4 color = tex2D(ReShade::BackBuffer, texcoord);
	color.rgb = ThermalMonochrome(color);

	return color;
}

float4 nvg_alepap_thermal_pass1(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// Psudo thermal smooth visuals
	return Thermal_Denoise_KNN(texcoord, 0.15, 0.8, 0.03, 0.05, 50.0);
}

float4 nvg_alepap_thermal_pass2(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// Render outline
	return ThermalOutline(texcoord, 1.1f);
}

float4 nvg_alepap_pass1(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	float2 zoomCoord = getZoomedCoord(texcoord);
	float4 color = tex2D(ReShade::BackBuffer, zoomCoord);
	
	float colorInfrared = ProcessBW(color, -0.4, 2.0, 3.0, 0.0, -0.6, -0.2, 4); // Infrared pass
	colorInfrared = FilmGrain(colorInfrared, texcoord, 2, 0.0, 0.8 * NOD_GRAIN_INTENSITY); // Big grain pass
	colorInfrared = FilmGrain(colorInfrared, texcoord, 1, 8.0, 0.6 * NOD_GRAIN_INTENSITY); // Small grain pass
	
	color = float4(colorInfrared, colorInfrared, colorInfrared, color.a);

	// Join thermal
	if (NOD_THERMAL){
		float4 thermalCol = color + (tex2D(sNVG_Thermal, zoomCoord) * NOD_THERMAL_INTENSITY) + NOD_THERMAL_REFLECTOR;
		color.rgb = ApplyMask(color, thermalCol, sNVG_Thermal_Mask, texcoord, NOD_RAD * NOD_THERMAL_RAD, NOD_POS).rgb;
	}
	return saturate(color);
}

float4 nvg_alepap_pass2(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	float4 color = tex2D(ReShade::BackBuffer, texcoord);
	
	float colorInfrared = Lens_Abberation(color, texcoord); // Chromatic abberation
	colorInfrared = ProcessBW(colorInfrared, -0.7, 0.9, 0.6, 0.1, -0.4, -0.4, 1.5); // Desaturate
	color.rgb = pow(abs(colorInfrared), (NOD_COLOR)); // Color Correction
	color.rgb = NvgVignette(color.rgb, texcoord, -2.0f, 100, 0.386f); // NVG Vignette

	return color;
}

float4 nvg_alepap_pass3(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// Final scene mask merge
	float4 color = tex2D(ReShade::BackBuffer, texcoord);
	float4 colorScene = tex2D(sNVG_Backup, texcoord);

	return ApplyMask(colorScene, color, sNVG_Mask, texcoord, NOD_RAD, NOD_POS);
}

technique nvg_alepap
{
	pass
	{
		VertexShader=PostProcessVS;
		PixelShader=nvg_alepap_pass0_backup;
		RenderTarget = tNVG_Backup;
	}

	// Thermal passes
	pass
	{
		VertexShader=PostProcessVS;
		PixelShader=nvg_alepap_thermal_pass0;
		RenderTarget = tNVG_Thermal;
	}

	pass
	{
		VertexShader=PostProcessVS;
		PixelShader=nvg_alepap_thermal_pass1;
		RenderTarget = tNVG_Thermal;
	}

	pass
	{
		VertexShader=PostProcessVS;
		PixelShader=nvg_alepap_thermal_pass2;
		RenderTarget = tNVG_Thermal;
	}

	// Night vision
	pass
	{
		VertexShader=PostProcessVS;
		PixelShader=nvg_alepap_pass1;
	}

	// qUINT bloom pass
	// TODO: replace?
    pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = PS_BloomPrepass;
		RenderTarget0 = MXBLOOM_BloomTexSource;
	}

	#define PASS_DOWNSAMPLE(i) pass { VertexShader = PostProcessVS; PixelShader  = PS_Downsample##i; RenderTarget0 = MXBLOOM_BloomTex##i; }

	PASS_DOWNSAMPLE(1)
	PASS_DOWNSAMPLE(2)
	PASS_DOWNSAMPLE(3)
	PASS_DOWNSAMPLE(4)
	PASS_DOWNSAMPLE(5)
	PASS_DOWNSAMPLE(6)
	PASS_DOWNSAMPLE(7)

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = PS_AdaptStoreLast;
		RenderTarget0 = MXBLOOM_BloomTexAdapt;
	}

	#define PASS_UPSAMPLE(i,j) pass {VertexShader = PostProcessVS;PixelShader  = PS_Upsample##i;RenderTarget0 = MXBLOOM_BloomTex##j;ClearRenderTargets = false;BlendEnable = true;BlendOp = ADD;SrcBlend = ONE;DestBlend = SRCALPHA;}

	PASS_UPSAMPLE(1,6)
	PASS_UPSAMPLE(2,5)
	PASS_UPSAMPLE(3,4)
	PASS_UPSAMPLE(4,3)
	PASS_UPSAMPLE(5,2)
	PASS_UPSAMPLE(6,1)

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = NVG_Bloom_Combine;
	}
	// End qUINT bloom pass

	pass
	{
		VertexShader=PostProcessVS;
		PixelShader=nvg_alepap_pass2;
	}

	pass
	{
		VertexShader=PostProcessVS;
		PixelShader=nvg_alepap_pass3;
	}
}