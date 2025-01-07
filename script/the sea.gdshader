shader_type spatial;
//render_mode unshaded;

uniform int wave_amount : hint_range (1, 128) = 32;
uniform vec3 base_color : source_color = vec3(0.01, 0.4, 0.333);
uniform float roughness : hint_range(0, 1) = 0.1;
uniform float metallic: hint_range(0, 1) = 1.0;
uniform float persistence: hint_range(0, 1) = 0.86;  // Controls the decay of each subsequent frequency
uniform float lacunarity = 1.115;   // Controls how much each frequency increases
uniform float normal_smooth_amount : hint_range(0.0, 1.0) = 0;


// Tiling factor to control wave repetition
uniform float tiling_factor : hint_range(0.1, 10.0) = 1.0;

// Hash function for generating pseudorandom values
float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

vec3 calc_wave(vec2 position, float phase) {
	vec3 result = vec3(0.0);

	// Loop through waves to build up the surface
	for (int k = 0; k < wave_amount; k++) {
		// Exponential decay for amplitude following fBm
		float amplitude = pow(persistence, float(k - 1)); // Amplitude decay

		// Frequency increases as a power of lacunarity
		float frequency = pow(lacunarity, float(k - 1)) / 6.0; // Adjust the base for frequency scaling

		// Deterministic angle based on k
		float angle = hash(float(k)) * TAU; // Hash value scaled to 0 - 2π
		vec2 direction = vec2(cos(angle), sin(angle)); // Generate direction from angle

		// Calculate dot product and wave height using Euler's sine wave
		float p = dot(position, direction); // Wave projection

		// Exponential sine wave
		result.y += amplitude * exp(sin(frequency * p + phase)); // Exponential sine wave

		// Calculate partial derivatives (tangent depends on vertex position)
		float cos_term = cos(frequency * p + phase); // Reusable cos value
		result.x += amplitude * frequency * direction.x * cos_term; // Dx derivative
		result.z += amplitude * frequency * direction.y * cos_term; // Dz derivative
	}

	return result;
}

varying vec2 world_position;

vec3 viewspace_normal(vec3 n, mat4 view_matrix) {
	return normalize((view_matrix * vec4(n, 0.0)).xyz);
}

void vertex() {
	// Transform vertex to world space
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * tiling_factor;

	// Update vertex position with wave displacement
	VERTEX.y += calc_wave(world_position, TIME).y;
}

void fragment() {
	vec3 wave = calc_wave(world_position, TIME);
	vec3 tangent = normalize(vec3(1.0, wave.x, 0.0)); // Assumes primary variation along x
	vec3 binormal = normalize(vec3(0.0, wave.z, 1.0)); // Assumes primary variation along z
	vec3 normal = normalize(cross(binormal, tangent)); // Normal from tangent and binormal
	
	
	
	vec3 original_normal = viewspace_normal(normal, VIEW_MATRIX);
    vec3 target_normal = normalize(vec3(0.0, 1.0, 0.0)); // Example: World up as the target
    NORMAL = normalize(mix(original_normal, target_normal, normal_smooth_amount));
	
	
	// Set material properties
	ALBEDO = base_color;
	//ALBEDO = normal;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}