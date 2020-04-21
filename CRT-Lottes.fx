//
// PUBLIC DOMAIN CRT STYLED SCAN-LINE SHADER
//
//   by Timothy Lottes
//
// This is more along the style of a really good CGA arcade monitor.
// With RGB inputs instead of NTSC.
// The shadow mask example has the mask rotated 90 degrees for less chromatic aberration.
//
// Left it unoptimized to show the theory behind the algorithm.
//
// It is an example what I personally would want as a display option for pixel art games.
// Please take and use, change, or whatever.
//
// Ported to ReShade by Zackin5
//

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

// -- config  -- //
uniform float hardScan <
	ui_label = "hardScan";
	ui_min = -20.0; ui_max = 0.0; ui_step = 1.0;
	ui_type = "slider";
> = -8.0;

uniform float hardPix <
	ui_label = "hardPix";
	ui_min = -20.0; ui_max = 0.0; ui_step = 1.0;
	ui_type = "slider";
> = -3.0;

uniform float2 warp <
	ui_label = "warp";
	ui_min = 0.0; ui_max = 0.125; ui_step = 0.01;
	ui_type = "slider";
> = float2(0.031, 0.041);

uniform float maskDark <
	ui_label = "maskDark";
	ui_min = 0.0; ui_max = 2.0; ui_step = 0.1;
	ui_type = "slider";
> = 0.5;

uniform float maskLight <
	ui_label = "maskLight";
	ui_min = 0.0; ui_max = 2.0; ui_step = 0.1;
	ui_type = "slider";
> = 1.5;

uniform bool scaleInLinearGamma <
	ui_label = "scaleInLinearGamma";
> = true;

uniform bool simpleLinearGamma <
	ui_label = "simpleLinearGamma";
> = false;

uniform float shadowMask <
	ui_label = "shadowMask";
	ui_min = 0.0; ui_max = 4.0; ui_step = 1.0;
	ui_type = "slider";
> = 3.0;

uniform float brightboost <
	ui_label = "brightness";
	ui_min = 0.0; ui_max = 2.0; ui_step = 0.05;
	ui_type = "slider";
> = 1.0;

uniform float hardBloomPix <
	ui_label = "bloom-x soft";
	ui_min = -2.0; ui_max = -0.5; ui_step = 0.1;
	ui_type = "slider";
> = -1.5;

uniform float hardBloomScan <
	ui_label = "bloom-y soft";
	ui_min = -4.0; ui_max = -1.0; ui_step = 0.1;
	ui_type = "slider";
> = -2.0;

uniform float bloomAmount <
	ui_label = "bloom amt";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
	ui_type = "slider";
> = 0.15;

uniform float shape <
	ui_label = "filter kernel shape";
	ui_min = 0.0; ui_max = 10.0; ui_step = 0.05;
	ui_type = "slider";
> = 2.0;

uniform bool DO_BLOOM <
	ui_label = "use bloom";
> = true;

/* COMPATIBILITY
   - HLSL compilers
   - Cg   compilers
   - FX11 compilers
*/

//------------------------------------------------------------------------

// sRGB to Linear.
// Assuing using sRGB typed textures this should not be needed.
float ToLinear1(float c)
{
   return(c<=0.04045)?c/12.92:pow((c+0.055)/1.055,2.4);
}
float3 ToLinear(float3 c)
{
   if (scaleInLinearGamma || simpleLinearGamma) return c;
   return float3(ToLinear1(c.r),ToLinear1(c.g),ToLinear1(c.b));
}

// Linear to sRGB.
// Assuming using sRGB typed textures this should not be needed.
float ToSrgb1(float c)
{
   return(c<0.0031308?c*12.92:1.055*pow(c,0.41666)-0.055);
}

float3 ToSrgb(float3 c)
{
    if (simpleLinearGamma) return pow(c, 1.0 / 2.2);
    if (scaleInLinearGamma) return c;
    return float3(ToSrgb1(c.r),ToSrgb1(c.g),ToSrgb1(c.b));
}

// Nearest emulated sample given floating point position and texel offset.
// Also zero's off screen.
float3 Fetch(float2 pos, float2 off, float2 texture_size){
    pos=(floor(pos*texture_size.xy+off)+float2(0.5,0.5))/texture_size.xy;

    if (simpleLinearGamma)
        return ToLinear(brightboost * pow(tex2D(ReShade::BackBuffer,pos.xy).rgb, 2.2));
    else
        return ToLinear(brightboost * tex2D(ReShade::BackBuffer,pos.xy).rgb);
}

// Distance in emulated pixels to nearest texel.
float2 Dist(float2 pos, float2 texture_size){pos=pos*texture_size.xy;return -((pos-floor(pos))-float2(0.5, 0.5));}
    
// 1D Gaussian.
float Gaus(float pos,float scale){return exp2(scale*pow(abs(pos),shape));}

// 3-tap Gaussian filter along horz line.
float3 Horz3(float2 pos, float off, float2 texture_size){
  float3 b=Fetch(pos,float2(-1.0,off),texture_size);
  float3 c=Fetch(pos,float2( 0.0,off),texture_size);
  float3 d=Fetch(pos,float2( 1.0,off),texture_size);
  float dst=Dist(pos, texture_size).x;
  // Convert distance to weight.
  float scale=hardPix;
  float wb=Gaus(dst-1.0,scale);
  float wc=Gaus(dst+0.0,scale);
  float wd=Gaus(dst+1.0,scale);
  // Return filtered sample.
  return (b*wb+c*wc+d*wd)/(wb+wc+wd);}
  
// 5-tap Gaussian filter along horz line.
float3 Horz5(float2 pos, float off, float2 texture_size){
  float3 a=Fetch(pos,float2(-2.0,off),texture_size);
  float3 b=Fetch(pos,float2(-1.0,off),texture_size);
  float3 c=Fetch(pos,float2( 0.0,off),texture_size);
  float3 d=Fetch(pos,float2( 1.0,off),texture_size);
  float3 e=Fetch(pos,float2( 2.0,off),texture_size);
  float dst=Dist(pos, texture_size).x;
  // Convert distance to weight.
  float scale=hardPix;
  float wa=Gaus(dst-2.0,scale);
  float wb=Gaus(dst-1.0,scale);
  float wc=Gaus(dst+0.0,scale);
  float wd=Gaus(dst+1.0,scale);
  float we=Gaus(dst+2.0,scale);
  // Return filtered sample.
  return (a*wa+b*wb+c*wc+d*wd+e*we)/(wa+wb+wc+wd+we);}

// 7-tap Gaussian filter along horz line.
float3 Horz7(float2 pos, float off, float2 texture_size){
  float3 a=Fetch(pos,float2(-3.0,off),texture_size);
  float3 b=Fetch(pos,float2(-2.0,off),texture_size);
  float3 c=Fetch(pos,float2(-1.0,off),texture_size);
  float3 d=Fetch(pos,float2( 0.0,off),texture_size);
  float3 e=Fetch(pos,float2( 1.0,off),texture_size);
  float3 f=Fetch(pos,float2( 2.0,off),texture_size);
  float3 g=Fetch(pos,float2( 3.0,off),texture_size);
  float dst=Dist(pos, texture_size).x;
  // Convert distance to weight.
  float scale=hardBloomPix;
  float wa=Gaus(dst-3.0,scale);
  float wb=Gaus(dst-2.0,scale);
  float wc=Gaus(dst-1.0,scale);
  float wd=Gaus(dst+0.0,scale);
  float we=Gaus(dst+1.0,scale);
  float wf=Gaus(dst+2.0,scale);
  float wg=Gaus(dst+3.0,scale);
  // Return filtered sample.
  return (a*wa+b*wb+c*wc+d*wd+e*we+f*wf+g*wg)/(wa+wb+wc+wd+we+wf+wg);}

// Return scanline weight.
float Scan(float2 pos,float off, float2 texture_size){
  float dst=Dist(pos, texture_size).y;
  return Gaus(dst+off,hardScan);}
  
  // Return scanline weight for bloom.
float BloomScan(float2 pos,float off, float2 texture_size){
  float dst=Dist(pos, texture_size).y;
  return Gaus(dst+off,hardBloomScan);}

// Allow nearest three lines to effect pixel.
float3 Tri(float2 pos, float2 texture_size){
  float3 a=Horz3(pos,-1.0, texture_size);
  float3 b=Horz5(pos, 0.0, texture_size);
  float3 c=Horz3(pos, 1.0, texture_size);
  float wa=Scan(pos,-1.0, texture_size);
  float wb=Scan(pos, 0.0, texture_size);
  float wc=Scan(pos, 1.0, texture_size);
  return a*wa+b*wb+c*wc;}
  
// Small bloom.
float3 Bloom(float2 pos, float2 texture_size){
  float3 a=Horz5(pos,-2.0, texture_size);
  float3 b=Horz7(pos,-1.0, texture_size);
  float3 c=Horz7(pos, 0.0, texture_size);
  float3 d=Horz7(pos, 1.0, texture_size);
  float3 e=Horz5(pos, 2.0, texture_size);
  float wa=BloomScan(pos,-2.0, texture_size);
  float wb=BloomScan(pos,-1.0, texture_size);
  float wc=BloomScan(pos, 0.0, texture_size);
  float wd=BloomScan(pos, 1.0, texture_size);
  float we=BloomScan(pos, 2.0, texture_size);
  return a*wa+b*wb+c*wc+d*wd+e*we;}

// Distortion of scanlines, and end of screen alpha.
float2 Warp(float2 pos){
  pos=pos*2.0-1.0;    
  pos*=float2(1.0+(pos.y*pos.y)*warp.x,1.0+(pos.x*pos.x)*warp.y);
  return pos*0.5+0.5;}

// Shadow mask 
float3 Mask(float2 pos){
  float3 mask=float3(maskDark,maskDark,maskDark);

  // Very compressed TV style shadow mask.
  if (shadowMask == 1) {
    float mask_line = maskLight;
    float odd=0.0;
    if(frac(pos.x/6.0)<0.5) odd = 1.0;
    if(frac((pos.y+odd)/2.0)<0.5) mask_line = maskDark;  
    pos.x=frac(pos.x/3.0);
   
    if(pos.x<0.333)mask.r=maskLight;
    else if(pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
    mask *= mask_line;  
  } 

  // Aperture-grille.
  else if (shadowMask == 2) {
    pos.x=frac(pos.x/3.0);

    if(pos.x<0.333)mask.r=maskLight;
    else if(pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
  } 

  // Stretched VGA style shadow mask (same as prior shaders).
  else if (shadowMask == 3) {
    pos.x+=pos.y*3.0;
    pos.x=frac(pos.x/6.0);

    if(pos.x<0.333)mask.r=maskLight;
    else if(pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
  }

  // VGA style shadow mask.
  else if (shadowMask == 4) {
    pos.xy=floor(pos.xy*float2(1.0,0.5));
    pos.x+=pos.y*3.0;
    pos.x=frac(pos.x/6.0);

    if(pos.x<0.333)mask.r=maskLight;
    else if(pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
  }

  return mask;
}    

float4 crt_lottes(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{    
    float2 pos = Warp(texcoord);
    float3 outColor = Tri(pos, ReShade::ScreenSize);

    if(DO_BLOOM)
        //Add Bloom
        outColor.rgb+=Bloom(pos, ReShade::ScreenSize)*bloomAmount;

    if(shadowMask)
        outColor.rgb*=Mask(floor(texcoord*ReShade::ScreenSize)+float2(0.5,0.5));

    return float4(ToSrgb(outColor.rgb),1.0);
}

technique CRT_Lottes
{
	pass CRT_Lottes
	{
		VertexShader=PostProcessVS;
		PixelShader=crt_lottes;
	}
}