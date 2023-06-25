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
// Additional tweaks taken from RSRetroArch repo
//

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

// -- config  -- //
uniform float hardScan <
	ui_label = "Scanline Hardness";
	ui_min = -20.0; ui_max = 0.0; ui_step = 1.0;
	ui_type = "slider";
	ui_category = "Image";
> = -8.0;

uniform float hardPix <
	ui_label = "Pixel Hardness";
	ui_min = -20.0; ui_max = 0.0; ui_step = 1.0;
	ui_type = "slider";
	ui_category = "Image";
> = -3.0;

uniform float downsizeDevisor <
	ui_label = "Downscale Devisor";
	ui_min = 1; ui_max = 16.0; ui_step = 0.25;
	ui_type = "slider";
	ui_category = "Image";
> = 2;

uniform float shadowMask <
	ui_label = "Mask Type";
	ui_min = 0.0; ui_max = 4.0; ui_step = 1.0;
	ui_type = "slider";
	ui_category = "Shadow Mask";
> = 3.0;

uniform bool maskRotate <
	ui_label = "Rotate Mask";
	ui_category = "Shadow Mask";
> = false;

uniform bool maskUseDownscale <
	ui_label = "Use Downscale Res";
	ui_category = "Shadow Mask";
> = false;

uniform float maskDark <
	ui_label = "Dark Level";
	ui_min = 0.0; ui_max = 2.0; ui_step = 0.1;
	ui_type = "slider";
	ui_category = "Shadow Mask";
> = 0.5;

uniform float maskLight <
	ui_label = "Light Level";
	ui_min = 0.0; ui_max = 2.0; ui_step = 0.1;
	ui_type = "slider";
	ui_category = "Shadow Mask";
> = 1.5;

uniform bool DO_BLOOM <
	ui_label = "Enable";
	ui_category = "Bloom";
> = true;

uniform float bloomAmount <
	ui_label = "Bloom Amount";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
	ui_type = "slider";
	ui_category = "Bloom";
> = 0.15;

uniform float shape <
	ui_label = "Filter Kernel Shape";
	ui_min = 0.0; ui_max = 10.0; ui_step = 0.05;
	ui_type = "slider";
	ui_category = "Bloom";
> = 2.0;

uniform float brightboost <
	ui_label = "Brightness Boost";
	ui_min = 0.0; ui_max = 2.0; ui_step = 0.05;
	ui_type = "slider";
	ui_category = "Bloom";
> = 1.0;

uniform float hardBloomPix <
	ui_label = "Bloom Pixel Softness";
	ui_min = -2.0; ui_max = -0.5; ui_step = 0.1;
	ui_type = "slider";
	ui_category = "Bloom";
> = -1.5;

uniform float hardBloomScan <
	ui_label = "Bloom Scanline Softness";
	ui_min = -4.0; ui_max = -1.0; ui_step = 0.1;
	ui_type = "slider";
	ui_category = "Bloom";
> = -2.0;

uniform float2 warp <
	ui_label = "Screen Warp";
	ui_min = 0.0; ui_max = 0.125; ui_step = 0.01;
	ui_type = "slider";
> = float2(0.031, 0.041);

uniform bool scaleInLinearGamma <
	ui_label = "Scale in Linear Gamma";
	ui_category = "Final Output";
> = true;

//------------------------------------------------------------------------

// sRGB to Linear.
// Assuing using sRGB typed textures this should not be needed.
float ToLinear1(float c)
{
   return scaleInLinearGamma==0 ? c : (c<=0.04045)?c/12.92:pow((c+0.055)/1.055,2.4);
}
float3 ToLinear(float3 c)
{
   return scaleInLinearGamma==0 ? c : float3(ToLinear1(c.r),ToLinear1(c.g),ToLinear1(c.b));
}

// Linear to sRGB.
// Assuming using sRGB typed textures this should not be needed.
float ToSrgb1(float c)
{
   return scaleInLinearGamma==0 ? c : (c<0.0031308?c*12.92:1.055*pow(c,0.41666)-0.055);
}

float3 ToSrgb(float3 c)
{
    return scaleInLinearGamma==0 ? c : float3(ToSrgb1(c.r),ToSrgb1(c.g),ToSrgb1(c.b));
}

// Nearest emulated sample given floating point position and texel offset.
// Also zero's off screen.
float3 Fetch(float2 pos, float2 off, float2 texture_size){
    pos=(floor(pos*texture_size.xy+off)+float2(0.5,0.5))/texture_size.xy;
    if(max(abs(pos.x-0.5),abs(pos.y-0.5))>0.5)return float3(0.0,0.0,0.0);
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
float3 Tri(float2 posWarped, float2 pos, float2 texture_size){
  float3 a=Horz3(posWarped,-1.0, texture_size);
  float3 b=Horz5(posWarped, 0.0, texture_size);
  float3 c=Horz3(posWarped, 1.0, texture_size);
  float wa=Scan(pos,-1.0, texture_size);
  float wb=Scan(pos, 0.0, texture_size);
  float wc=Scan(pos, 1.0, texture_size);
  return a*wa+b*wb+c*wc;}
  
// Small bloom.
float3 Bloom(float2 posWarped, float2 pos, float2 texture_size){
  float3 a=Horz5(posWarped,-2.0, texture_size);
  float3 b=Horz7(posWarped,-1.0, texture_size);
  float3 c=Horz7(posWarped, 0.0, texture_size);
  float3 d=Horz7(posWarped, 1.0, texture_size);
  float3 e=Horz5(posWarped, 2.0, texture_size);
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

  float2 mask_pos;
  if (maskRotate)
    mask_pos = float2(pos.y, pos.x);
  else
    mask_pos = pos;

  // Very compressed TV style shadow mask.
  if (shadowMask == 1) {
    float mask_line = maskLight;
    float odd=0.0;
    if(frac(mask_pos.x/6.0)<0.5) odd = 1.0;
    if(frac((mask_pos.y+odd)/2.0)<0.5) mask_line = maskDark;  
    mask_pos.x=frac(mask_pos.x/3.0);
   
    if(mask_pos.x<0.333)mask.r=maskLight;
    else if(mask_pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
    mask *= mask_line;  
  } 

  // Aperture-grille.
  else if (shadowMask == 2) {
    mask_pos.x=frac(mask_pos.x/3.0);

    if(mask_pos.x<0.333)mask.r=maskLight;
    else if(mask_pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
  } 

  // Stretched VGA style shadow mask (same as prior shaders).
  else if (shadowMask == 3) {
    mask_pos.x+=mask_pos.y*3.0;
    mask_pos.x=frac(mask_pos.x/6.0);

    if(mask_pos.x<0.333)mask.r=maskLight;
    else if(mask_pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
  }

  // VGA style shadow mask.
  else if (shadowMask == 4) {
    mask_pos.xy=floor(mask_pos.xy*float2(1.0,0.5));
    mask_pos.x+=mask_pos.y*3.0;
    mask_pos.x=frac(mask_pos.x/6.0);

    if(mask_pos.x<0.333)mask.r=maskLight;
    else if(mask_pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
  }

  return mask;
}    

float4 crt_lottes(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{    
    float2 videoRes = ReShade::ScreenSize;
    float2 downsizedRes = (videoRes / downsizeDevisor);
    float2 pos = texcoord.xy*(downsizedRes/videoRes)*(videoRes/downsizedRes);
    float2 posWarped = Warp(texcoord.xy*(downsizedRes/videoRes)*(videoRes/downsizedRes));
    float3 outColor = Tri(posWarped, pos, downsizedRes);

    if(DO_BLOOM)
        //Add Bloom
        outColor.rgb+=Bloom(posWarped, pos, downsizedRes)*bloomAmount;

    if(shadowMask) {
        float2 maskRes = maskUseDownscale == 1 ? downsizedRes : videoRes;
        outColor.rgb*=Mask(floor(texcoord*maskRes)+float2(0.5,0.5));
	}

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