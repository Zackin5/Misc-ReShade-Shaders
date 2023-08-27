
uniform float LIGHTROOM_GLOBAL_BLACKS_CURVE <
	ui_type = "drag";
	ui_min = -1.00; ui_max = 1.00;
	ui_label = "Global Blacks Curve";
	ui_tooltip = "Global Blacks Curve Control";
    ui_category = "Curves";
> = -1.00;

uniform float LIGHTROOM_GLOBAL_SHADOWS_CURVE <
	ui_type = "drag";
	ui_min = -1.00; ui_max = 1.00;
	ui_label = "Global Shadows Curve";
	ui_tooltip = "Global Shadows Curve Control";
    ui_category = "Curves";
> = -0.30;

// From qUINT_lightroom
float curves(in float x)
{
	float blacks_mult   	= smoothstep(0.25, 0.00, x);
	float shadows_mult  	= smoothstep(0.00, 0.25, x) * smoothstep(0.50, 0.25, x);
	float blacks = exp2(-LIGHTROOM_GLOBAL_BLACKS_CURVE);
	float shadows = exp2(-LIGHTROOM_GLOBAL_SHADOWS_CURVE);

	x = pow(x, exp2(blacks_mult * blacks
			      + shadows_mult * shadows
			      - 1));

	return saturate(x);
}