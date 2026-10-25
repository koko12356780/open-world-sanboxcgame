shader_type sky;
uniform float night_amount=0.;
void sky(){
 float h=max(EYEDIR.y,0.);
 vec3 day=mix(vec3(.64,.82,.90),vec3(.10,.32,.55),pow(h,.45));
 vec3 night=mix(vec3(.07,.16,.25),vec3(.003,.014,.055),pow(h,.4));
 vec3 col=mix(day,night,night_amount);
 float ribbon=exp(-pow((EYEDIR.y-.30-sin(EYEDIR.x*5.)*.10)/.075,2.));
 float waves=.5+.5*sin(EYEDIR.x*44.+EYEDIR.z*13.);
 col+=mix(vec3(.02,.24,.16),vec3(.18,.06,.28),waves)*ribbon*night_amount;
 if(EYEDIR.y<0.)col=mix(vec3(.46,.64,.72),vec3(.025,.06,.10),night_amount);
 COLOR=col;
}
