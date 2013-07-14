attribute vec3 _Vertex;
attribute vec3 _Normal;

uniform mat4 _ProjectionViewMatrix;
uniform mat4 _ModelMatrix;
uniform mat3 _NormalMatrix;

varying vec3 normal;

void main(void) {
  normal = normalize(_NormalMatrix * _Normal);
  gl_Position = _ProjectionViewMatrix * _ModelMatrix * vec4(_Vertex, 1.0);
}