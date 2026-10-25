shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 jet_color : source_color = vec4(.2,.7,1.,1.);
void fragment() {
 float fade=pow(clamp(UV.y,0.,1.),.55);
 float flow=.85+.15*sin(UV.y*24.-TIME*35.);
 ALBEDO=jet_color.rgb;
 ALPHA=fade*flow*.30;
}
