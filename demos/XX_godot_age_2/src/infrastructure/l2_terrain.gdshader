shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// --- Configuração Global de Tiling e Iluminação ---
uniform float base_tiling : hint_range(1.0, 128.0) = 32.0;
uniform bool has_lightmap = false;
uniform float lightmap_intensity : hint_range(0.0, 4.0) = 1.3;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float specular : hint_range(0.0, 1.0) = 0.10;

// --- Macro Lightmap e Splatmaps RGBA ---
uniform sampler2D lightmap_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D splatmap_0 : filter_linear_mipmap, repeat_disable;
uniform sampler2D splatmap_1 : filter_linear_mipmap, repeat_disable;
uniform sampler2D splatmap_2 : filter_linear_mipmap, repeat_disable;

// --- Textura Base (Camada 0) ---
uniform sampler2D tex_base : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_base = vec2(1.0, 1.0);

// --- Camadas 1 a 4 (Splatmap 0: R, G, B, A) ---
uniform sampler2D tex_layer_1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_1 = vec2(1.0, 1.0);

uniform sampler2D tex_layer_2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_2 = vec2(1.0, 1.0);

uniform sampler2D tex_layer_3 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_3 = vec2(1.0, 1.0);

uniform sampler2D tex_layer_4 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_4 = vec2(1.0, 1.0);

// --- Camadas 5 a 8 (Splatmap 1: R, G, B, A) ---
uniform sampler2D tex_layer_5 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_5 = vec2(1.0, 1.0);

uniform sampler2D tex_layer_6 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_6 = vec2(1.0, 1.0);

uniform sampler2D tex_layer_7 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_7 = vec2(1.0, 1.0);

uniform sampler2D tex_layer_8 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_8 = vec2(1.0, 1.0);

// --- Camada 9 (Splatmap 2: R) ---
uniform sampler2D tex_layer_9 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_9 = vec2(1.0, 1.0);


void fragment() {
	vec2 uv = UV;

	// 1. Amostra os pesos dos Splatmaps
	vec4 s0 = texture(splatmap_0, uv);
	vec4 s1 = texture(splatmap_1, uv);
	vec4 s2 = texture(splatmap_2, uv);

	// 2. Inicia com a Camada Base (com fallback caso não haja textura)
	vec3 base_tex_sample = texture(tex_base, uv * uv_scale_base * base_tiling).rgb;
	vec3 color = base_tex_sample;

	// 3. Aplica a mistura linear (Mix) das camadas sobrepostas
	if (s0.r > 0.001) {
		color = mix(color, texture(tex_layer_1, uv * uv_scale_1 * base_tiling).rgb, s0.r);
	}
	if (s0.g > 0.001) {
		color = mix(color, texture(tex_layer_2, uv * uv_scale_2 * base_tiling).rgb, s0.g);
	}
	if (s0.b > 0.001) {
		color = mix(color, texture(tex_layer_3, uv * uv_scale_3 * base_tiling).rgb, s0.b);
	}
	if (s0.a > 0.001) {
		color = mix(color, texture(tex_layer_4, uv * uv_scale_4 * base_tiling).rgb, s0.a);
	}

	if (s1.r > 0.001) {
		color = mix(color, texture(tex_layer_5, uv * uv_scale_5 * base_tiling).rgb, s1.r);
	}
	if (s1.g > 0.001) {
		color = mix(color, texture(tex_layer_6, uv * uv_scale_6 * base_tiling).rgb, s1.g);
	}
	if (s1.b > 0.001) {
		color = mix(color, texture(tex_layer_7, uv * uv_scale_7 * base_tiling).rgb, s1.b);
	}
	if (s1.a > 0.001) {
		color = mix(color, texture(tex_layer_8, uv * uv_scale_8 * base_tiling).rgb, s1.a);
	}

	if (s2.r > 0.001) {
		color = mix(color, texture(tex_layer_9, uv * uv_scale_9 * base_tiling).rgb, s2.r);
	}

	// 4. Modulação com Lightmap (com fallback de luz quando não houver)
	vec3 lm = vec3(1.0);
	if (has_lightmap) {
		vec3 raw_lm = texture(lightmap_tex, uv).rgb;
		lm = mix(vec3(1.0), raw_lm * lightmap_intensity, 0.7);
	}

	ALBEDO = color * lm;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
