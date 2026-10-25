shader_type spatial;
uniform vec4 base_color : source_color;
uniform float kind = 0.0;
uniform float night_amount = 0.0;
uniform sampler2D road_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world.xz;
 if (kind<0.5) {
  vec3 aggregate=texture(road_tex,p/7.5).rgb;
  float lane=min(abs(mod(p.x+36.0,72.0)-36.0),abs(mod(p.y+36.0,72.0)-36.0));
  float edge=smoothstep(4.8,7.0,lane);
  float tyre=exp(-pow((lane-3.5)/1.2,2.0));
  float patch=hash(floor(p/4.0));
  ALBEDO=aggregate*base_color.rgb*2.0*(1.0-edge*.25-tyre*.12);
  NORMAL_MAP=texture(normal_tex,p/7.5).rgb;
  NORMAL_MAP_DEPTH=.32;
  float wet=smoothstep(.04,.14,texture(road_tex,p/19.).r);
  ROUGHNESS=mix(.76+patch*.15,.19+patch*.12,wet*night_amount*.85);
  SPECULAR=mix(.35,.75,night_amount*wet);
 } else {
  vec2 tile=fract(p/1.5);
  float seam=1.0-smoothstep(.005,.022,min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y)));
  float variation=hash(floor(p/1.5));
  vec3 stone=texture(concrete_tex,p/4.5).rgb;
  ALBEDO=stone*base_color.rgb*1.35*(.88+variation*.17)*(1.0-seam*.35);
  ROUGHNESS=.93;
 }
}
