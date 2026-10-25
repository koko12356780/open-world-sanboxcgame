shader_type spatial;
uniform vec4 tint:source_color=vec4(.24,.51,.66,1.);
uniform float night_amount=0.;
varying vec3 world; varying vec3 norm;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;norm=normalize(mat3(MODEL_MATRIX)*NORMAL);}
void fragment(){
 float x=abs(norm.x)>.5?world.z:world.x;
 vec2 c=fract(vec2(x/3.4,world.y/4.));
 float pane=step(.19,c.x)*step(c.x,.81)*step(.25,c.y)*step(c.y,.82)*step(abs(norm.y),.2);
 float veins=pow(.5+.5*sin(x*2.1+sin(world.y*.9)*3.),18.);
 ALBEDO=mix(tint.rgb*(.8+veins*.25),vec3(.055,.16,.25),pane);
 ROUGHNESS=.22;METALLIC=.22;
 EMISSION=vec3(.14,.51,.70)*pane*(.08+night_amount*.38);
}
