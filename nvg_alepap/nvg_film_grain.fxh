/*
    Description : PD80 06 Film Grain for Reshade https://reshade.me/
    Author      : prod80 (Bas Veth)
    License     : MIT, Copyright (c) 2020 prod80

    Additional credits
    - Noise/Grain code adopted, modified, and adjusted from Stefan Gustavson.
      License: MIT, Copyright (c) 2011 stegu
      

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

//// TEXTURES ///////////////////////////////////////////////////////////////////
texture texPerm < source = "pd80_permtexture.png"; > { Width = 256; Height = 256; Format = RGBA8; };
//// SAMPLERS ///////////////////////////////////////////////////////////////////
sampler samplerPermTex { Texture = texPerm; };
#define LumCoeff float3(0.212656, 0.715158, 0.072186)
#define permTexSize 256
#define permONE     1.0f / 256.0f
#define permHALF    0.5f * permONE
//// FUNCTIONS //////////////////////////////////////////////////////////////////
uniform float Timer < source = "timer"; >;

float getLuminance( in float3 x )
{
	return dot( x, LumCoeff );
}

float4 rnm( float2 tc, float t ) 
{
	float noise       = sin( dot( tc, float2( 12.9898, 78.233 ))) * ( 43758.5453 + t );
	float noiseR      = frac( noise ) * 2.0 - 1.0;
	float noiseG      = frac( noise * 1.2154 ) * 2.0 - 1.0; 
	float noiseB      = frac( noise * 1.3453 ) * 2.0 - 1.0;
	float noiseA      = frac( noise * 1.3647 ) * 2.0 - 1.0;
	return float4( noiseR, noiseG, noiseB, noiseA );
}

float fade( float t )
{
	return t * t * t * ( t * ( t * 6.0 - 15.0 ) + 10.0 );
}

float pnoise3D( float3 p, float t, float grainSize)
{
	float3 pi         = permONE * floor( p ) + permHALF;
	pi.xy             *= permTexSize;
	pi.xy             = round(( pi.xy - permHALF ) / grainSize ) * grainSize;
	pi.xy             /= permTexSize;
	float3 pf         = frac( p );
	// Noise contributions from (x=0, y=0), z=0 and z=1
	float perm00      = rnm( pi.xy, t ).x;
	float3 grad000    = tex2D( samplerPermTex, float2( perm00, pi.z )).xyz * 4.0 - 1.0;
	float n000        = dot( grad000, pf );
	float3 grad001    = tex2D( samplerPermTex, float2( perm00, pi.z + permONE )).xyz * 4.0 - 1.0;
	float n001        = dot( grad001, pf - float3( 0.0, 0.0, 1.0 ));
	// Noise contributions from (x=0, y=1), z=0 and z=1
	float perm01      = rnm( pi.xy + float2( 0.0, permONE ), t ).y ;
	float3  grad010   = tex2D( samplerPermTex, float2( perm01, pi.z )).xyz * 4.0 - 1.0;
	float n010        = dot( grad010, pf - float3( 0.0, 1.0, 0.0 ));
	float3  grad011   = tex2D( samplerPermTex, float2( perm01, pi.z + permONE )).xyz * 4.0 - 1.0;
	float n011        = dot( grad011, pf - float3( 0.0, 1.0, 1.0 ));
	// Noise contributions from (x=1, y=0), z=0 and z=1
	float perm10      = rnm( pi.xy + float2( permONE, 0.0 ), t ).z ;
	float3  grad100   = tex2D( samplerPermTex, float2( perm10, pi.z )).xyz * 4.0 - 1.0;
	float n100        = dot( grad100, pf - float3( 1.0, 0.0, 0.0 ));
	float3  grad101   = tex2D( samplerPermTex, float2( perm10, pi.z + permONE )).xyz * 4.0 - 1.0;
	float n101        = dot( grad101, pf - float3( 1.0, 0.0, 1.0 ));
	// Noise contributions from (x=1, y=1), z=0 and z=1
	float perm11      = rnm( pi.xy + float2( permONE, permONE ), t ).w ;
	float3  grad110   = tex2D( samplerPermTex, float2( perm11, pi.z )).xyz * 4.0 - 1.0;
	float n110        = dot( grad110, pf - float3( 1.0, 1.0, 0.0 ));
	float3  grad111   = tex2D( samplerPermTex, float2( perm11, pi.z + permONE )).xyz * 4.0 - 1.0;
	float n111        = dot( grad111, pf - float3( 1.0, 1.0, 1.0 ));
	// Blend contributions along x
	float4 n_x        = lerp( float4( n000, n001, n010, n011 ), float4( n100, n101, n110, n111 ), fade( pf.x ));
	// Blend contributions along y
	float2 n_xy       = lerp( n_x.xy, n_x.zw, fade( pf.y ));
	// Blend contributions along z
	float n_xyz       = lerp( n_xy.x, n_xy.y, fade( pf.z ));
	// We're done, return the final noise value
	return n_xyz;
}

//// PIXEL SHADERS //////////////////////////////////////////////////////////////
float FilmGrain(float color, float2 texcoord, float grainSize, float grainDensity, float grainIntensity)
{
	float timer       = Timer % 1000.0f;
	float2 uv         = texcoord.xy * float2( BUFFER_WIDTH, BUFFER_HEIGHT );
	float3 noise      = pnoise3D( float3( uv.xy, 1 ), timer, grainSize);
	noise.y           = pnoise3D( float3( uv.xy, 2 ), timer, grainSize);
	noise.z           = pnoise3D( float3( uv.xy, 3 ), timer, grainSize);

	// Old, practically does the same as grainAmount below
	// Added back on request
	noise.xyz         *= grainIntensity;

	// Noise saturation
	noise.xyz         = dot( noise.xyz, 1.0f );
	
	// Control noise density
	noise.xyz         = pow( abs( noise.xyz ), max( 11.0f - grainDensity, 0.1f )) * sign( noise.xyz );

	// Mixing options
	// noise.xyz         = lerp( noise.xyz * grainIntClamp.x, noise.xyz * grainIntClamp.y, fade( color )); // Noise adjustments based on average intensity
	// color             = lerp( color, color + ( noise.xyz ), grainAmount );
	color             = color + ( noise.xyz );
	return color;
}