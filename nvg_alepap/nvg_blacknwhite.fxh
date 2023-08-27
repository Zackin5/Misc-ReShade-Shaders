/*
    Description : PD80 04 Black & White for Reshade https://reshade.me/
    Author      : prod80 (Bas Veth)
    License     : MIT, Copyright (c) 2020 prod80


    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    
*/

float3 RGBToHCV( in float3 RGB )
{
    // Based on work by Sam Hocevar and Emil Persson
    float4 P         = ( RGB.g < RGB.b ) ? float4( RGB.bg, -1.0f, 2.0f/3.0f ) : float4( RGB.gb, 0.0f, -1.0f/3.0f );
    float4 Q1        = ( RGB.r < P.x ) ? float4( P.xyw, RGB.r ) : float4( RGB.r, P.yzx );
    float C          = Q1.x - min( Q1.w, Q1.y );
    float H          = abs(( Q1.w - Q1.y ) / ( 6.0f * C + 0.000001f ) + Q1.z );
    return float3( H, C, Q1.x );
}

float3 RGBToHSL( in float3 RGB )
{
    RGB.xyz          = max( RGB.xyz, 0.000001f );
    float3 HCV       = RGBToHCV(RGB);
    float L          = HCV.z - HCV.y * 0.5f;
    float S          = HCV.y / ( 1.0f - abs( L * 2.0f - 1.0f ) + 0.000001f);
    return float3( HCV.x, S, L );
}

// Credit to user 'iq' from shadertoy
// See https://www.shadertoy.com/view/MdBfR1
float curve( float x, float k )
{
	float s = sign( x - 0.5f );
	float o = ( 1.0f + s ) / 2.0f;
	return o - 0.5f * s * pow( 2.0f * ( o - s * x ), k );
}

float ProcessBW( float3 col, float r, float y, float g, float c, float b, float m, float curve_str )
{
	float3 hsl         = RGBToHSL( col.xyz );
	// Inverse of luma channel to no apply boosts to intensity on already intense brightness (and blow out easily)
	float lum          = 1.0f - hsl.z;

	// Calculate the individual weights per color component in RGB and CMY
	// Sum of all the weights for a given hue is 1.0
	float weight_r     = curve( max( 1.0f - abs(  hsl.x               * 6.0f ), 0.0f ), curve_str ) +
							curve( max( 1.0f - abs(( hsl.x - 1.0f      ) * 6.0f ), 0.0f ), curve_str );
	float weight_y     = curve( max( 1.0f - abs(( hsl.x - 0.166667f ) * 6.0f ), 0.0f ), curve_str );
	float weight_g     = curve( max( 1.0f - abs(( hsl.x - 0.333333f ) * 6.0f ), 0.0f ), curve_str );
	float weight_c     = curve( max( 1.0f - abs(( hsl.x - 0.5f      ) * 6.0f ), 0.0f ), curve_str );
	float weight_b     = curve( max( 1.0f - abs(( hsl.x - 0.666667f ) * 6.0f ), 0.0f ), curve_str );
	float weight_m     = curve( max( 1.0f - abs(( hsl.x - 0.833333f ) * 6.0f ), 0.0f ), curve_str );

	// No saturation (greyscale) should not influence B&W image
	float sat          = hsl.y * ( 1.0f - hsl.y ) + hsl.y;
	float ret          = hsl.z;
	ret                += ( hsl.z * ( weight_r * r ) * sat * lum );
	ret                += ( hsl.z * ( weight_y * y ) * sat * lum );
	ret                += ( hsl.z * ( weight_g * g ) * sat * lum );
	ret                += ( hsl.z * ( weight_c * c ) * sat * lum );
	ret                += ( hsl.z * ( weight_b * b ) * sat * lum );
	ret                += ( hsl.z * ( weight_m * m ) * sat * lum );

	return saturate( ret );
}
