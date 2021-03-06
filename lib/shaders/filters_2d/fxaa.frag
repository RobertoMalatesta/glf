/**
 * NVIDIA FXAA by Timothy Lottes
 * http://timothylottes.blogspot.com/2011/06/fxaa3-source-released.html
 * - WebGL port by @supereggbert
 * http://www.glge.org/demos/fxaa/
 */
precision highp float;

uniform sampler2D _Tex0;
varying vec2 vTexCoord0;
uniform vec3 _PixelSize; // (1.0/width, 1.0/height, width/height)
#define FXAA_REDUCE_MIN     (1.0/128.0)
#define FXAA_REDUCE_MUL     (1.0/8.0)
#define FXAA_SPAN_MAX   8.0
  
void main(){
  vec2 xy = gl_FragCoord.xy;//gl_FragCoord.xy;vTexCoord0
  vec2 psxy = _PixelSize.xy;
  vec3 rgbNW = texture2D(_Tex0, (xy + vec2(-1.0,-1.0)) * psxy).xyz;
  vec3 rgbNE = texture2D(_Tex0, (xy + vec2(1.0,-1.0)) * psxy).xyz;
  vec3 rgbSW = texture2D(_Tex0, (xy + vec2(-1.0,1.0)) * psxy).xyz;
  vec3 rgbSE = texture2D(_Tex0, (xy + vec2(1.0,1.0)) * psxy).xyz;
  vec4 rgbaM = texture2D(_Tex0, xy  * psxy );
  vec3 rgbM  = rgbaM.xyz;
  float opacity  = rgbaM.w;
  
  vec3 luma = vec3(0.299, 0.587, 0.114);
  float lumaNW = dot(rgbNW, luma);
  float lumaNE = dot(rgbNE, luma);
  float lumaSW = dot(rgbSW, luma);
  float lumaSE = dot(rgbSE, luma);
  float lumaM   = dot(rgbM,   luma);
  float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
  float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
    
  vec2 dir;
  dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
  dir.y =   ((lumaNW + lumaSW) - (lumaNE + lumaSE));
    
  float dirReduce = max(
    (lumaNW + lumaNE + lumaSW + lumaSE) * (0.25 * FXAA_REDUCE_MUL),
    FXAA_REDUCE_MIN);
    
  float rcpDirMin = 1.0/(min(abs(dir.x), abs(dir.y)) + dirReduce);
  dir = min(vec2( FXAA_SPAN_MAX,   FXAA_SPAN_MAX),
  max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
  dir * rcpDirMin)) * psxy;
        
  vec3 rgbA = 0.5 * (
    texture2D(_Tex0,     xy   * psxy + dir * (1.0/3.0 - 0.5)).xyz +
    texture2D(_Tex0,     xy   * psxy + dir * (2.0/3.0 - 0.5)).xyz);
    
  vec3 rgbB = rgbA * 0.5 + 0.25 * (
  texture2D(_Tex0,   xy   * psxy + dir *   - 0.5).xyz +
    texture2D(_Tex0,   xy   * psxy + dir * 0.5).xyz);
  float lumaB = dot(rgbB, luma);
  gl_FragColor.rgb = ((lumaB < lumaMin) || (lumaB > lumaMax)) ? rgbA : rgbB;
  gl_FragColor.a = opacity;
}