// Hackish port of NTSC shader from RetroArch
// Has some color/timing issues due to the difference in design goals?

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

uniform float NTSC_CRT_GAMMA <
	ui_label = "CRT Gamma";
	ui_min = 0.0; ui_max = 10.0; ui_step = 0.1;
	ui_type = "slider";
> = 2.5;

uniform float NTSC_MONITOR_GAMMA <
	ui_label = "Monitor Gamma";
	ui_min = 0.0; ui_max = 10.0; ui_step = 0.1;
	ui_type = "slider";
> = 2.0;

uniform bool NTSC_SIGNAL_MOD <
    ui_label = "Enable Signal Modulation";
    ui_category = "Signal Modulation";
> = true;

uniform bool NTSC_FLICKER_DISABLE <
	ui_label = "Constant Time";
    ui_tooltip = "Disables signal flicker";
    ui_category = "Signal Modulation";
> = false;

uniform float NTSC_SATURATION <
	ui_label = "Phase Saturation";
    ui_category = "Signal Modulation";
	ui_min = 0.0; ui_max = 2.0; ui_step = 0.1;
	ui_type = "slider";
> = 1.0;

uniform float NTSC_BRIGHTNESS <
	ui_label = "Phase Brightness";
    ui_category = "Signal Modulation";
	ui_min = 0.0; ui_max = 2.0; ui_step = 0.1;
	ui_type = "slider";
> = 1.0;

uniform int2 NTSC_SIGNAL_RES <
    ui_category = "Signal Modulation";
	ui_label = "Signal Resolution";
> = int2(320, 400);

uniform bool NTSC_THREE_PHASE <
    ui_category = "Signal Modulation";
    ui_label = "Three-Phase";
    ui_tooltip = "Use three-phase instead of two-phase";
> = false;

uniform bool NTSC_COMPONENT <
    ui_category = "Signal Modulation";
    ui_label = "Component Video";
    ui_tooltip = "Use Component video instead of SVideo";
> = false;

uniform int framecount  < source = "framecount"; >;
uniform int frametime  < source = "frametime"; >;

// NTSC Param
#define PI 3.14159265

float fmod(float a, float b) {
	float c = frac(abs(a / b)) * abs(b);
	return a < 0 ? -c : c;
}

float3x3 mix_mat(){
    float NTSC_FRINGING = 0.0;
    float NTSC_ARTIFACTING = 0.0;

    if(NTSC_COMPONENT){
        NTSC_FRINGING = 1.0;
        NTSC_ARTIFACTING = 1.0;
    }

    return float3x3(
      NTSC_BRIGHTNESS, NTSC_FRINGING, NTSC_FRINGING,
      NTSC_ARTIFACTING, 2.0 * NTSC_SATURATION, 0.0,
      NTSC_ARTIFACTING, 0.0, 2.0 * NTSC_SATURATION 
    );
}

// NTSC RGBYUV
static const float3x3 yiq2rgb_mat = float3x3(
   1.0, 0.956, 0.619,
   1.0, -0.272, -0.647,
   1.0, -1.106, 1.703
);

float3 yiq2rgb(float3 yiq)
{
   return mul(yiq2rgb_mat, yiq);
}

static const float3x3 yiq_mat = float3x3(
      0.2990, 0.5870, 0.1140,
      0.5959, -0.2746, -0.3213,
      0.2115, -0.5227, 0.3112
);

float3 rgb2yiq(float3 rgb)
{
   return mul(yiq_mat, rgb);
}

// NTSC Pass 1 (composite 2-phase)
float4 ntsc_pass1_composite_2phase(float2 texture_size, float frame_count, float2 tex, sampler s0)
{
    float3 col = tex2D(s0, tex).rgb;
    float3 yiq = rgb2yiq(col);

    if(!NTSC_SIGNAL_MOD)
        return float4(yiq, 1.0);

    float chroma_phase;
    float CHROMA_MOD_FREQ;

    if(NTSC_THREE_PHASE){
        chroma_phase = 0.6667 * PI * (fmod(texture_size.y, 3.0) + frame_count);
        CHROMA_MOD_FREQ = (PI / 3.0);
    }
    else{
        // Two-phase
        chroma_phase = PI * (fmod(texture_size.y, 2.0) + frame_count);
        CHROMA_MOD_FREQ = (4.0 * PI / 15.0);
    }

    float mod_phase = chroma_phase + texture_size.x * CHROMA_MOD_FREQ;

    float i_mod = cos(mod_phase);
    float q_mod = sin(mod_phase);

    yiq.yz *= float2(i_mod, q_mod); // Modulate.
    yiq = mul(mix_mat(), yiq); // Cross-talk.
    yiq.yz *= float2(i_mod, q_mod); // Demodulate.

    return float4(yiq, 1.0);
}

float4 ntsc_pass1(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float frameDelta = float(framecount);

    if(NTSC_FLICKER_DISABLE){
        if(NTSC_THREE_PHASE)
            frameDelta = 1.6;
        else
            frameDelta = 0.0;
    }

	return ntsc_pass1_composite_2phase(NTSC_SIGNAL_RES, frameDelta, texcoord, ReShade::BackBuffer);
}

// NTSC Decode filter (2-phase)
#define TAPS 32
static const float luma_filter[TAPS + 1] = {
   -0.000174844,
   -0.000205844,
   -0.000149453,
   -0.000051693,
   0.000000000,
   -0.000066171,
   -0.000245058,
   -0.000432928,
   -0.000472644,
   -0.000252236,
   0.000198929,
   0.000687058,
   0.000944112,
   0.000803467,
   0.000363199,
   0.000013422,
   0.000253402,
   0.001339461,
   0.002932972,
   0.003983485,
   0.003026683,
   -0.001102056,
   -0.008373026,
   -0.016897700,
   -0.022914480,
   -0.021642347,
   -0.008863273,
   0.017271957,
   0.054921920,
   0.098342579,
   0.139044281,
   0.168055832,
   0.178571429};

static const float chroma_filter[TAPS + 1] = {
   0.001384762,
   0.001678312,
   0.002021715,
   0.002420562,
   0.002880460,
   0.003406879,
   0.004004985,
   0.004679445,
   0.005434218,
   0.006272332,
   0.007195654,
   0.008204665,
   0.009298238,
   0.010473450,
   0.011725413,
   0.013047155,
   0.014429548,
   0.015861306,
   0.017329037,
   0.018817382,
   0.020309220,
   0.021785952,
   0.023227857,
   0.024614500,
   0.025925203,
   0.027139546,
   0.028237893,
   0.029201910,
   0.030015081,
   0.030663170,
   0.031134640,
   0.031420995,
   0.031517031};


// NTSC Pass 2 (2-phase gamma)
#define fetch_offset(offset, one_x) \
   tex2D(s0, tex + float2((offset) * (one_x), 0.0)).xyz

float4 ntsc_pass2_2phase_gamma(float2 texture_size, float2 tex, sampler s0)
{
    float one_x = ReShade::PixelSize.x;
    float3 signal = float3(0.0, 0.0, 0.0);
    for (int i = 0; i < TAPS; i++)
    {
        float offset = float(i);

        float3 sums = fetch_offset(offset - float(TAPS), one_x) +
            fetch_offset(float(TAPS) - offset, one_x);

        signal += sums * float3(luma_filter[i], chroma_filter[i], chroma_filter[i]);
    }
    signal += tex2D(s0, tex).xyz *
    float3(luma_filter[TAPS], chroma_filter[TAPS], chroma_filter[TAPS]);
    float3 rgb = yiq2rgb(signal);
    float3 gamma_mod = float3(NTSC_CRT_GAMMA / NTSC_MONITOR_GAMMA, NTSC_CRT_GAMMA / NTSC_MONITOR_GAMMA, NTSC_CRT_GAMMA / NTSC_MONITOR_GAMMA);
    return float4(pow(rgb, gamma_mod), 1.0);
}

float4 ntsc_pass2(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	return ntsc_pass2_2phase_gamma(ReShade::ScreenSize, texcoord, ReShade::BackBuffer);
}

technique NTSC
{
	pass NTSC1
	{
		VertexShader=PostProcessVS;
		PixelShader=ntsc_pass1;
	}
	pass NTSC2
	{
		VertexShader=PostProcessVS;
		PixelShader=ntsc_pass2;
	}
}