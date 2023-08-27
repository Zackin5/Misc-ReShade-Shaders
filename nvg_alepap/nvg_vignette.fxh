/**
 * Vignette version 1.3
 * by Christian Cann Schuldt Jensen ~ CeeJay.dk
 *
 * Darkens the edges of the image to make it look more like it was shot with a camera lens.
 * May cause banding artifacts.
 */

float3 NvgVignette(float3 color, float2 tex, float amount, float slope, float radius)
{
	// Set the center
	float2 center = float2(0.5, 0.5) + (NOD_POS * NOD_RAD);
	float2 distance_xy = tex - center;

	// Adjust the ratio
	distance_xy *= float2((BUFFER_RCP_HEIGHT / BUFFER_RCP_WIDTH), 1.0f);

	// Calculate the distance
	distance_xy /= radius * NOD_RAD;
	float distance = dot(distance_xy, distance_xy);

	// Apply the vignette
	return color * (1.0 + pow(distance, slope * 0.5) * amount); //pow - multiply
}