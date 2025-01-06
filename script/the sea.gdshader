shader_type spatial;

uniform int wave_amount = 12;
uniform vec3 base_color : source_color = vec3(0.01, 0.4, 0.333);
uniform float specular_intensity : hint_range(0, 1) = 0.5;
uniform float roughness : hint_range(0, 1) = 0.1;
uniform float fresnel_intensity : hint_range(0, 5) = 2.0;
uniform float reflectivity : hint_range(0, 1) = 0.5;
uniform float metallic = 1.0;
uniform float normal_smooth_factor : hint_range(0.0, 1.0) = 0.75; // Controls the strength of normal smoothing
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Tiling factor to control wave repetition
uniform float tiling_factor : hint_range(0.1, 10.0) = 1.0;

varying float Dx;
varying float Dz;

// Hash function for generating pseudorandom values
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

void vertex() {
    // Transform vertex to world space
    vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Initialize variables
    float wave = 0.0;
    Dx = 0.0;
    Dz = 0.0;
    vec2 position = world_position.xz * tiling_factor; // Tiled world-space position

    // Parameters for fBm
    float persistence = 0.5;  // Controls the decay of each subsequent frequency
    float lacunarity = 1.6;   // Controls how much each frequency increases

    // Variables to store previous wave derivatives
    float prev_Dx = 0.0;
    float prev_Dz = 0.0;

    // Loop through waves to build up the surface
    for (int k = 0; k < wave_amount; k++) {
        // Exponential decay for amplitude following fBm
        float amplitude = pow(persistence, float(k - 1)); // Amplitude decay
        
        // Frequency increases as a power of lacunarity
        float frequency = pow(lacunarity, float(k - 1)) / 6.0; // Adjust the base for frequency scaling
        
        float phase = TIME; // Time for animation
        
        // Deterministic angle based on k
        float angle = hash(float(k)) * 6.283185; // Hash value scaled to 0 - 2π
        vec2 direction = vec2(cos(angle), sin(angle)); // Generate direction from angle
        
        // Calculate dot product and wave height using Euler's sine wave
        float p = dot(position, direction); // Wave projection
        
        // Exponential sine wave
        wave += amplitude * exp(sin(frequency *	 p + phase)); // Exponential sine wave
        
        // Calculate partial derivatives (tangent depends on vertex position)
        float cos_term = cos(frequency * p + phase); // Reusable cos value
        Dx += amplitude * frequency * direction.x * cos_term; // Dx derivative
        Dz += amplitude * frequency * direction.y * cos_term; // Dz derivative
        
        // Combine the derivative with the previous wave's derivatives (for wave interaction)
        Dx += prev_Dx * amplitude * 0.5; // Influence from the previous wave's Dx
        Dz += prev_Dz * amplitude * 0.5; // Influence from the previous wave's Dz
        
        // Store the current wave's derivatives to influence the next wave
        prev_Dx = Dx;
        prev_Dz = Dz;
    }

    vec3 tangent = normalize(vec3(1.0, Dx, 0.0)); // Assumes primary variation along x
    vec3 binormal = normalize(vec3(0.0, Dz, 1.0)); // Assumes primary variation along z
    vec3 normal = normalize(cross(binormal, tangent)); // Normal from tangent and binormal
	
	// Smooth out the normal by blending it with the default up vector (0, 1, 0)
    vec3 default_up = vec3(0.0, 1.0, 0.0);
    normal = normalize(mix(normal, default_up, normal_smooth_factor));
	
    NORMAL = normal;

    // Update vertex position with wave displacement
    VERTEX.y += wave;
}

void fragment() {
    // View direction in world space
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD);

    // Calculate Fresnel effect
    float fresnel = pow(1.0 - dot(NORMAL, view_dir), fresnel_intensity);

    // Sample the PanoramaSky reflections
    vec3 reflection = textureLod(SCREEN_TEXTURE, reflect(view_dir, NORMAL).xz, 0.0).rgb;

    // Mix base color and reflection based on Fresnel
    vec3 final_color = mix(base_color, reflection, fresnel * reflectivity);

    // Set material properties
    ALBEDO = final_color;
    ROUGHNESS = roughness;
    SPECULAR = specular_intensity;
    METALLIC = metallic;
}
