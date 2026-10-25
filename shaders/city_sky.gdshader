shader_type sky;
uniform float night_amount=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void sky(){
 float h=max(EYEDIR.y,0.0);
 vec3 day=mix(vec3(.78,.61,.44),vec3(.18,.35,.55),pow(h,.38));
 vec3 night=mix(vec3(.065,.09,.15),vec3(.005,.014,.037),pow(h,.45));
 vec3 col=mix(day,night,night_amount);
 vec2 p=EYEDIR.xz/max(EYEDIR.y+.12,.08)*1.8;
 float cloud=noise(p*.65)*.55+noise(p*1.4)*.27+noise(p*3.2)*.13+noise(p*7.)*.05;
 float mask=smoothstep(.49,.69,cloud)*smoothstep(.015,.16,h);
 col=mix(col,mix(vec3(.76,.73,.68),vec3(.055,.069,.10),night_amount),mask*.72);
 vec3 sun_dir=normalize(vec3(.46,.29,-.84));
 float sun=pow(max(dot(EYEDIR,sun_dir),0.),1100.);
 col+=vec3(1.,.66,.32)*sun*(1.-night_amount)*4.;
 float moon=pow(max(dot(EYEDIR,normalize(vec3(-.32,.54,-.7))),0.),2200.);
 col+=vec3(.65,.76,1.)*moon*night_amount;
 float stars=step(.9988,hash(floor(SKY_COORDS*vec2(2200,1100))))*smoothstep(.14,.6,h);
 col+=stars*night_amount*.35;
 if(EYEDIR.y<0.) col=mix(vec3(.13,.14,.14),vec3(.006,.012,.02),night_amount);
 COLOR=col;
}
