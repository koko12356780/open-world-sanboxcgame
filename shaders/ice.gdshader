shader_type spatial;
uniform float snow=0.;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=world.xz;
 float grain=hash(floor(p*55.));
 float streak=sin(p.x*.28+p.y*.09+sin(p.y*.14))*sin(p.y*.12);
 float cracks=pow(1.-abs(sin(p.x*.9+sin(p.y*.31))),28.);
 vec3 ice=mix(vec3(.15,.35,.43),vec3(.28,.55,.64),streak*.5+.5)*(1.-cracks*.3);
 ALBEDO=mix(ice,vec3(.74,.84,.88)*(.94+grain*.06),snow);
 ROUGHNESS=mix(.32,.94,snow); METALLIC=(1.-snow)*.12;
 SPECULAR=.35;
}
