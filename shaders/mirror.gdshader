shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D view_texture : source_color;
void fragment() {
 ALBEDO = texture(view_texture,vec2(1.0-UV.x,UV.y)).rgb*vec3(0.86,0.93,0.96);
}
