#include "ReShade.fxh"

uniform float Desaturation <
	ui_type = "slider";
	ui_label = "Desaturation";
	ui_min = 0; ui_max = 1;
> = 0.5;

uniform float Brightness <
	ui_type = "slider";
	ui_label = "Brightness";
	ui_min = 0; ui_max = 2;
> = 1;

uniform float Contrast <
	ui_type = "slider";
	ui_label = "Contrast";
	ui_min = 0; ui_max = 2;
> = 1;

uniform float DepthCurve <
	ui_type = "slider";
	ui_label = "Depth Curve";
	ui_min = 0; ui_max = 2;
> = 1;

uniform float DepthCutoff <
	ui_type = "slider";
	ui_label = "Depth Cutoff";
	ui_min = 0; ui_max = 1;
> = 0;

uniform bool IgnoreSky <
	ui_label = "Ignore Sky";
	ui_tooltip = "May cause an abrubt transition at the horizon.";
> = 0;

uniform float SkyCutoff <
	ui_type = "slider";
	ui_label = "Sky Cutoff";
	ui_min = 0; ui_max = 1;
> = 1;

uniform bool Debug <
	ui_label = "Debug Display";
> = 0;

void DesaturateDepthMain( float4 pos : SV_Position, float2 texcoord : TexCoord, out float4 color : SV_Target )
{
	float depth = ReShade::GetLinearizedDepth(texcoord);

	if(IgnoreSky && depth >= SkyCutoff)
	{
		discard;
	}

	float4 bufColor = tex2D(ReShade::BackBuffer, texcoord);
	// float4 greyColor = dot(float3(0.3, 0.59, 0.11), bufColor) * Brightness;
	// float4 greyColor = dot(0.333, bufColor) * Brightness;
	float4 greyColor = 0.2126f * bufColor.r + 0.7152 * bufColor.g + 0.0722 * bufColor.b;
	float4 desatColor = lerp(bufColor, greyColor, Desaturation);
	desatColor.rgb *= Brightness;
	desatColor.rgb = (desatColor.rgb - 0.5) * Contrast + 0.5;

	if(Debug)
		desatColor.rgb = float3(0,0,0);

	color = lerp(bufColor, desatColor, saturate((depth * DepthCurve) - DepthCutoff));
}

technique DesaturateDepth
{
	pass DesaturateDepth0
	{
		VertexShader = PostProcessVS;
		PixelShader = DesaturateDepthMain;
	}
}