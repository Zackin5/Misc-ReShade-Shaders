
#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform int colorSource <
	ui_label = "Color Source";
	ui_type = "combo";
	ui_label = "";
	ui_items = "Custom\0Scene\0Scene Average\0";
> = 0;

uniform float3 ambColor <
	ui_label = "Custom Color";
	ui_min = 0.0; ui_max = 1.0;	ui_step = 0.01;
    ui_type = "slider";
> = float3(1.0, 1.0, 1.0);

uniform float roughness <
	ui_label = "Surface Roughness";
	ui_min = 0.0; ui_max = 1.0;	ui_step = 0.1;
    ui_type = "slider";
> = 1.0;

uniform float specular <
	ui_label = "Surface Specular";
	ui_min = 0.0; ui_max = 1.0;	ui_step = 0.1;
    ui_type = "slider";
> = 1.0;

uniform bool display_spec <
	ui_label = "DEBUG Display Specular";
> = false;

texture2D ReflectionTex 	{ Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; AddressU = MIRROR;};
sampler2D ReflectionBuffer	{ Texture = ReflectionTex;	};

///////////////
// Functions //
///////////////

float GetDepth(float2 texcoord)
{
    return ReShade::GetLinearizedDepth(texcoord);
}

float3 NormalVector(float2 texcoord)
{
	float3 offset = float3(ReShade::PixelSize.xy, 0.0);
	float2 posCenter = texcoord.xy;
	float2 posNorth  = posCenter - offset.zy;
	float2 posEast   = posCenter + offset.xz;

	float3 vertCenter = float3(posCenter - 0.5, 1) * GetDepth(posCenter);
	float3 vertNorth  = float3(posNorth - 0.5,  1) * GetDepth(posNorth);
	float3 vertEast   = float3(posEast - 0.5,   1) * GetDepth(posEast);

	return normalize(cross(vertCenter - vertNorth, vertCenter - vertEast)) * 0.5 + 0.5;
}

// Sample algorithms
float3 SampleScreenAverage()
{
    float3 sampleAvg = float3(0,0,0);
    // Corners
    sampleAvg += tex2D(ReShade::BackBuffer, float2(0,0)).rgb;
    sampleAvg += tex2D(ReShade::BackBuffer, float2(0,0.5)).rgb;
    sampleAvg += tex2D(ReShade::BackBuffer, float2(0,1)).rgb;
    sampleAvg += tex2D(ReShade::BackBuffer, float2(0,0.75)).rgb;
    sampleAvg += tex2D(ReShade::BackBuffer, float2(1,1)).rgb;
    sampleAvg += tex2D(ReShade::BackBuffer, float2(1,0)).rgb;
    sampleAvg += tex2D(ReShade::BackBuffer, float2(0.5,0)).rgb;
    sampleAvg += tex2D(ReShade::BackBuffer, float2(0.75,0)).rgb;
    
    // Midpoints
    sampleAvg += tex2D(ReShade::BackBuffer, float2(0.5,0.5)).rgb;
    sampleAvg += tex2D(ReShade::BackBuffer, float2(0.25,0.5)).rgb;
    sampleAvg += tex2D(ReShade::BackBuffer, float2(0.75,0.5)).rgb;
    sampleAvg += tex2D(ReShade::BackBuffer, float2(0.5,0.25)).rgb;
    sampleAvg += tex2D(ReShade::BackBuffer, float2(0.5,0.75)).rgb;

    return sampleAvg / 13.0f;
}

// Black ops BRDF
float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
{
    return F0 + (max((1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}   

float a1vf( float g )
{
	return ( 0.25 * g + 0.75 );
}

float a004( float g, float vdotN )
{
	float t = min( 0.475 * g, exp2( -9.28 * vdotN ) );
	return ( t + 0.0275 ) * g + 0.015;
}

float a0r(float g, float VdotN)
{
    g = 1.0 - g;
    return ((a004(g, VdotN) - a1vf(g) * 0.04) / 0.96);
}

float2 EnvironmentBRDF( float g, float vdotN )
{
    g = 1.0 - g;
	float4 t = float4( 1.0 / 0.96, 0.475, ( 0.0275 - 0.25 * 0.04 ) / 0.96, 0.25 );
	t *= float4( g, g, g, g );
	t += float4( 0.0, 0.0, ( 0.015 - 0.75 * 0.04 ) / 0.96, 0.75 );
	float a0 = t.x * min( t.y, exp2( -9.28 * vdotN ) ) + t.z;
	float a1 = t.w;
	
	return float2(a0, a1);
}

float3 EnvironmentBRDF( float g, float vdotN, float3 color )
{
    g = 1.0 - g;
	float4 t = float4( 1.0 / 0.96, 0.475, ( 0.0275 - 0.25 * 0.04 ) / 0.96, 0.25 );
	t *= float4( g, g, g, g );
	t += float4( 0.0, 0.0, ( 0.015 - 0.75 * 0.04 ) / 0.96, 0.75 );
	float a0 = t.x * min( t.y, exp2( -9.28 * vdotN ) ) + t.z;
	float a1 = t.w;
	
	return saturate( a0 + color * ( a1 - a0 ) );
}

////////////
// Passes //
////////////

float4 PS_reflection(float2 texcoord : TexCoord) : SV_TARGET
{
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
    float3 specColor;

    if(colorSource == 1)
        specColor = color;
    else if(colorSource == 2)
    {
        specColor = SampleScreenAverage(); 
    }
    else
        specColor = ambColor;

    return float4(specColor, 1);
}

float4 PS_brdf(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float4 color = tex2D(ReShade::BackBuffer, texcoord);
    float3 specColor = tex2D(ReflectionBuffer, texcoord).rgb;
    float3 normal = NormalVector(texcoord);
    float vdotN = normal.z;

    float F0 = specular / 25.0f + 0.04f;
    float3 F = fresnelSchlickRoughness(vdotN, F0, roughness);
    float2 brdf = EnvironmentBRDF(roughness, vdotN);

    float3 spec = saturate((brdf.x * specColor) + specColor * (F * (brdf.y - brdf.x)));

    if(display_spec)
        return float4(spec.rgb, color.a);
    else
        return float4(color.rgb + spec, color.a);
}

technique BRDF
{
	pass Reflection
	{
		VertexShader=PostProcessVS;
		PixelShader=PS_reflection;
		RenderTarget = ReflectionTex;
	}
	pass BRDF
	{
		VertexShader=PostProcessVS;
		PixelShader=PS_brdf;
	}
}