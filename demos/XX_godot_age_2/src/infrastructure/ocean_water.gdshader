shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_always;

// --- Configurações Globais do Oceano ---
uniform vec4 deep_color : source_color = vec4(0.02, 0.08, 0.20, 0.95);
uniform vec4 shallow_color : source_color = vec4(0.12, 0.45, 0.58, 0.65);
uniform vec4 foam_color : source_color = vec4(0.90, 0.95, 1.0, 0.85);

uniform float wave_speed : hint_range(0.0, 0.5) = 0.03;
uniform float wave_scale : hint_range(0.001, 1.0) = 0.06;
uniform float foam_thickness : hint_range(0.0, 5.0) = 0.8;
uniform float water_murkiness : hint_range(0.001, 1.0) = 0.08;

uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;


// Função procedural ultra-rápida de ondas para normais de alta fidelidade sem texturas extras
vec3 calculate_wave_normal(vec2 world_xz, float time) {
	vec2 p1 = world_xz * wave_scale + vec2(time * wave_speed, time * wave_speed * 0.7);
	vec2 p2 = world_xz * wave_scale * 1.5 - vec2(time * wave_speed * 0.8, time * wave_speed * 1.2);
	
	float d_x = sin(p1.x * 6.28) * 0.15 + cos(p2.x * 6.28) * 0.1;
	float d_z = cos(p1.y * 6.28) * 0.15 + sin(p2.y * 6.28) * 0.1;
	
	return normalize(vec3(d_x, 1.0, d_z));
}


void fragment() {
	// 1. Coordenadas de Mundo para animação contínua e sem costura entre chunks
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// 2. Cálculo da profundidade da água em relação ao terreno subjacente
	float depth_raw = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_space = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_space.xyz /= view_space.w;
	
	float linear_depth = -view_space.z;
	float water_depth = max(0.0, linear_depth + VERTEX.z);
	
	// 3. Gradiente de Cor por Profundidade (Depth Fade)
	float depth_factor = clamp(water_depth * water_murkiness, 0.0, 1.0);
	vec4 base_water_color = mix(shallow_color, deep_color, depth_factor);
	
	// 4. Espuma nas Margens e Contato com Falésias/Praias (Shore Foam)
	float foam_factor = 0.0;
	if (water_depth < foam_thickness) {
		float foam_p = (1.0 - (water_depth / foam_thickness));
		float noise = sin(world_pos.x * 0.5 + TIME * 2.0) * cos(world_pos.z * 0.5 + TIME * 1.5);
		foam_factor = clamp(foam_p + noise * 0.2, 0.0, 1.0);
	}
	
	vec3 final_color = mix(base_water_color.rgb, foam_color.rgb, foam_factor);
	float final_alpha = mix(base_water_color.a, foam_color.a, foam_factor);
	
	// 5. Ondulação Normal para Reflexão PBR da Luz Solar
	vec3 wave_n = calculate_wave_normal(world_pos.xz, TIME);
	
	ALBEDO = final_color;
	ALPHA = final_alpha;
	NORMAL = (VIEW_MATRIX * vec4(wave_n, 0.0)).xyz;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = 0.6;
}
