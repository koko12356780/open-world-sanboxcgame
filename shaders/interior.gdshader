shader_type spatial;
uniform vec4 leather : source_color = vec4(0.035,0.04,0.04,1.0);
varying vec3 p;
void vertex() { p = VERTEX; }
void fragment() {
 float grain = fract(sin(dot(floor(p.xy*1000.0)+floor(p.yz*713.0),vec2(12.9898,78.233)))*43758.5453);
 ALBEDO = leather.rgb*(0.89+grain*0.18);
 ROUGHNESS = 0.82;
}
