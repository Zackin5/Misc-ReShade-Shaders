/*------------------.
| :: Description :: |
'-------------------/

	Monochrome (version 1.1)

	Author: CeeJay.dk
	License: MIT

	About:
	Removes color making everything monochrome.

	Ideas for future improvement:
	* Tinting
	* Select a hue to keep its color, thus making it stand out against a monochrome background
	* Try Lab colorspace
	* Apply color gradient
	* Add an option to normalize the coefficients
	* Publish best-selling book titled "256 shades of grey"

	History:
	(*) Feature (+) Improvement	(x) Bugfix (-) Information (!) Compatibility
	
	Version 1.0
	* Converts image to monochrome
	* Allows users to add saturation back in.

	Version 1.1 
	* Added many presets based on B/W camera films
	+ Improved settings UI
	! Made settings backwards compatible with SweetFX

*/

uniform int Thermal_monochrome_mode <
	ui_type = "combo";
	ui_label = "Monocrome Preset";
	ui_tooltip = "Choose a preset";
	ui_category = "Thermal";
	ui_items = "Custom\0"
	"sRGB monitor\0"
	"Equal weight\0";
> = 0;

uniform float3 Thermal_monochrome_conversion_values < __UNIFORM_COLOR_FLOAT3
	ui_label = "Monocrome Custom Preset values";
	ui_category = "Thermal";
> = float3(1.00, 1.00, 1.00);

float ThermalMonochrome(float3 color)
{
	float3 Coefficients = float3(0.21, 0.72, 0.07);

	float3 Coefficients_array[3] = 
	{
		Thermal_monochrome_conversion_values, //Custom
		float3(0.21, 0.72, 0.07), //sRGB monitor
		float3(0.3333333, 0.3333334, 0.3333333) //Equal weight
	};

	Coefficients = Coefficients_array[Thermal_monochrome_mode];

	// Calculate monochrome
	return dot(Coefficients, color);
}
