precision mediump float;

varying vec3 vNormal;
varying vec4 vVertex;

void main(void) {

    // calc the dot product and clamp
    // 0 -> 1 rather than -1 -> 1
    vec3 lightPosition = vec3(1.5,4.0,4.0);
      
    // ensure it's normalized
    vec3 light = lightPosition - vVertex.xzy;
  
    // calculate the dot product of
    // the light to the vertex normal
    float lightW = max(0.0, dot(normalize(vNormal), normalize(light)));
      
    // use the distance of the light  
    float lightLMax = 20.0; // maximum distance of light
    float lightL = length(light);
    lightW = lightW * max(0.0, (lightLMax - lightL)/lightLMax);
  
    // feed into our frag colour
    vec3 albedo = vec3(1.0, 1.0, 1.0);
    gl_FragColor = vec4(albedo.rgb * lightW, 1.0);
}