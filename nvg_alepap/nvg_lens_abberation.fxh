/*
    Description : PD80 06 Chromatic Aberration for Reshade https://reshade.me/
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

#define CA_sampleSTEPS     96  // [0 to 96]

float Lens_Abberation(float color, float2 texcoord)
{
	float outColor;
	float px          = BUFFER_RCP_WIDTH;
	float py          = BUFFER_RCP_HEIGHT;
	float aspect      = float( BUFFER_WIDTH * BUFFER_RCP_HEIGHT );
	
	float CA = -150.0;
	float CA_width_n  = 1.6; // NOD_RAD
	float CA_curve = 12;

	// TODO: offset ratio isn't accurate
	float downsizeMultipler = 2.0f / NOD_RAD;
	float offsetRatio = downsizeMultipler / 2.0f;
	float2 coords     = texcoord.xy * downsizeMultipler - float2( NOD_POS.x + offsetRatio, NOD_POS.y + offsetRatio ); // Let it ripp, and not clamp!
	float2 uv         = coords.xy;
	coords.xy         /= float2( 1.0 / aspect, 1.0 );
	float2 caintensity= length( coords.xy ) * CA_width_n;
	caintensity.y     = caintensity.x * caintensity.x + 1.0f;
	caintensity.x     = 1.0f - ( 1.0f / ( caintensity.y * caintensity.y ));
	caintensity.x     = pow( caintensity.x, CA_curve );

	int degrees      = 360;
	int degreesY      = degrees;
	float c           = 0.0f;
	float s           = 0.0f;
		degreesY      = degrees + 90 > 360 ? degreesY = degrees + 90 - 360 : degrees + 90;
		c             = cos( radians( degrees )) * uv.x;
		s             = sin( radians( degreesY )) * uv.y;

	float huecolor   = 0.0f;
	float3 temp       = 0.0f;
	float o1          = CA_sampleSTEPS - 1.0f;
	float o2          = 0.0f;
	float d          = 0.0f;

	// Scale CA (hackjob!)
	float caWidth     = CA * ( max( BUFFER_WIDTH, BUFFER_HEIGHT ) / 1920.0f ); // Scaled for 1920, raising resolution in X or Y should raise scale

	float offsetX     = px * c * caintensity.x;
	float offsetY     = py * s * caintensity.x;
	float sampst      = CA_sampleSTEPS;
	[unroll]
	for( float i = 0; i < CA_sampleSTEPS; i++ )
	{
		huecolor      = i / sampst;
		o2            = lerp( -caWidth, caWidth, i / o1 );
		temp.xyz      = tex2D( ReShade::BackBuffer, texcoord.xy + float2( o2 * offsetX, o2 * offsetY )).xyz;
		outColor      += temp.xyz * huecolor;
		d             += huecolor;
	}
	outColor           /= d; // seems so-so OK
	// outColor           = caintensity.x + ( 1.0f - caintensity.x );
	return outColor;
}