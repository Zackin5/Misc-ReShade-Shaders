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

uniform float Curve <
	ui_type = "slider";
	ui_label = "Curve";
	ui_min = 0; ui_max = 2;
> = 1;

uniform bool IgnoreSky <
	ui_label = "Ignore Sky";
	ui_tooltip = "May cause an abrubt transition at the horizon.";
> = 0;

void DesaturateDepthMain( float4 pos : SV_Position, float2 texcoord : TexCoord, out float4 color : SV_Target )
{
	float depth = ReShade::GetLinearizedDepth(texcoord);

	if(IgnoreSky && depth >= 1)
	{
		discard;
	}

	float4 bufColor = tex2D(ReShade::BackBuffer, texcoord);
	float4 greyColor = dot(float3(0.3, 0.59, 0.11), bufColor) * Brightness;
	greyColor.rgb = (greyColor.rgb - 0.5) * Contrast + 0.5;

	color = lerp(bufColor, greyColor, pow(depth,Curve));
}

technique DesaturateDepth
{
	pass DesaturateDepth0
	{
		VertexShader = PostProcessVS;
		PixelShader = DesaturateDepthMain;
	}
}