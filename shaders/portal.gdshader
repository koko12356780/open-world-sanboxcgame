shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void fragment(){
 vec2 p=(UV-.5)*2.; float r=length(p);
 if(r>1.)discard;
 float swirl=.5+.5*sin(r*25.-TIME*4.+atan(p.y,p.x)*3.);
 ALBEDO=mix(vec3(.025,.2,.95),vec3(.25,.85,1.),swirl);
 ALPHA=(1.-smoothstep(.78,1.,r))*(.22+.30*swirl);
}
