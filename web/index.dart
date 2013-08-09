import 'dart:html';
import 'dart:async';
import 'dart:math' as math;
import 'dart:web_gl' as GL;
import 'dart:typed_data';
import 'package:js/js.dart' as js;

import 'package:vector_math/vector_math.dart';

import '../lib/glf.dart' as glf;


main(){
  var gl = (query("#canvas0") as CanvasElement).getContext3d(alpha: false, depth: true);
  if (gl == null) {
    print("webgl not supported");
    return;
  }
  new Main(new Renderer(gl)).start();
}
aabb2points(Aabb3 aabb) {
  var b = new List<Vector3>(8);
  b[0] = new Vector3(aabb.min.x, aabb.min.y, aabb.min.z);
  b[1] = new Vector3(aabb.min.x, aabb.min.y, aabb.max.z);
  b[2] = new Vector3(aabb.min.x, aabb.max.y, aabb.min.z);
  b[3] = new Vector3(aabb.max.x, aabb.min.y, aabb.min.z);
  b[4] = new Vector3(aabb.max.x, aabb.max.y, aabb.max.z);
  b[5] = new Vector3(aabb.max.x, aabb.max.y, aabb.min.z);
  b[6] = new Vector3(aabb.max.x, aabb.min.y, aabb.max.z);
  b[7] = new Vector3(aabb.min.x, aabb.max.y, aabb.max.z);
  return b;

}
extractMinMaxProjection(List<Vector3> vs, Vector3 axis, Vector2 out) {
  var p = vs[0].dot(axis);
  out.x = p;
  out.y = p;
  for (int i = 1; i < vs.length; i++) {
    p = vs[i].dot(axis);
    if (p < out.x) out.x = p;
    if (p > out.y) out.y = p;
  }
}

class Renderer {
  final gl;

  final glf.ProgramsRunner lightRunner;
  final glf.ProgramsRunner cameraRunner;
  final glf.ProgramsRunner postRunner;

  var lightCtx = null;

  Renderer(gl) : this.gl = gl,
    lightRunner = new glf.ProgramsRunner(gl),
    cameraRunner = new glf.ProgramsRunner(gl),
    postRunner = new glf.ProgramsRunner(gl)
  ;

  var _x0, _x1, _x2;
  init() {
    _initCamera();
    _initLight();
    _initPost();
    //_x0 = gl.getExtension("OES_standard_derivatives");
    _x1 = gl.getExtension("OES_texture_float");
    //_x2 = gl.getExtension("GL_EXT_draw_buffers");
    //print(">>>> extension $_x0 $_x1 $_x2");
  }

  _initCamera() {
    // Camera default setting for perspective use canvas area full
    var viewport = new glf.ViewportCamera.defaultSettings(gl.canvas);
    viewport.camera.position.setValues(0.0, 0.0, 6.0);

    cameraRunner.register(new glf.RequestRunOn()
      ..setup= (gl) {
        if (true) {
          // opaque
          gl.disable(GL.BLEND);
          gl.depthFunc(GL.LEQUAL);
          //gl.depthFunc(GL.LESS); // default value
          gl.enable(GL.DEPTH_TEST);
//        } else {
//          // blend
//          gl.disable(GL.DEPTH_TEST);
//          gl.blendFunc(GL.SRC_ALPHA, GL.ONE);
//          gl.enable(GL.BLEND);
        }
        gl.colorMask(true, true, true, true);
      }
      ..beforeAll = (gl) {
        gl.viewport(viewport.x, viewport.y, viewport.viewWidth, viewport.viewHeight);
        //gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clearColor(1.0, 0.0, 0.0, 1.0);
        //gl.clearColor(1.0, 1.0, 1.0, 1.0);
        gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
        //gl.clear(GL.COLOR_BUFFER_BIT);
      }
//      ..onRemoveProgramCtx = (prunner, ctx) {
//        ctx.delete();
//      }
    );


    cameraRunner.register(viewport.makeRequestRunOn());
  }

  _initLight() {
    var _light = new glf.ViewportCamera()
      ..viewWidth = 256
      ..viewHeight = 256
      ..camera.fovRadians = degrees2radians * 55.0
      ..camera.aspectRatio = 1.0
      ..camera.position.setValues(2.0, 2.0, 4.0)
      ..camera.focusPosition.setValues(0.0, 0.0, 0.0)
      ;
    var scene = new Aabb3()
      ..min.setValues(-3.0, -3.0, 0.0)
      ..max.setValues(3.0, 3.0, 3.0)
      ;
    var axis = _light.camera.focusPosition - _light.camera.position;
    var v2 = new Vector2.zero();
    extractMinMaxProjection(aabb2points(scene), axis,v2);
    _light.camera.far = math.max(0.1, v2.y);//(_light.camera.focusPosition - _light.camera.position).length * 2;
    _light.camera.near = math.max(0.1, v2.x);//math.max(0.5, (_light.camera.focusPosition - _light.camera.position).length - 3.0);
    //_light.camera.updateProjectionViewMatrix();

    lightRunner.fbo = new glf.FBO(gl, _light.viewWidth, _light.viewHeight/*, GL.FLOAT*/);
    lightCtx = new glf.ProgramContext(gl, depthVert0, depthFrag0);
    //lightCtx = new glf.ProgramContext(gl, depthVert0, normalFrag0);
    lightRunner.register(_light.makeRequestRunOn()
      ..ctx = lightCtx
      ..beforeAll = (gl) {
        gl.viewport(0, 0, _light.viewWidth, _light.viewHeight);
        gl.clearColor(1.0, 1.0, 1.0, 1.0);
        gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
      }
      ..before =(ctx) {
        ctx.gl.uniform1f(ctx.getUniformLocation('lightFar'), _light.camera.far);
        ctx.gl.uniform1f(ctx.getUniformLocation('lightNear'), _light.camera.near);
      }
    );

    var r = new glf.RequestRunOn()
      ..autoData = (new Map()
        ..["sLightDepth"] = ((ctx) => glf.injectTexture(ctx, lightRunner.fbo.texture, 31, "sLightDepth"))
        ..["lightFar"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('lightFar'), _light.camera.far))
        ..["lightNear"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('lightNear'), _light.camera.near))
        ..["lightConeAngle"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('lightConeAngle'), _light.camera.fovRadians * radians2degrees))
        ..["lightProj"] = ((ctx) => glf.injectMatrix4(ctx, _light.camera.projectionMatrix, "lightProj"))
        ..["lightView"] = ((ctx) => glf.injectMatrix4(ctx, _light.camera.viewMatrix, "lightView"))
        ..["lightRot"] = ((ctx) => glf.injectMatrix3(ctx, _light.camera.rotMatrix, "lightRot"))
        ..["lightProjView"] = ((ctx) => glf.injectMatrix4(ctx, _light.camera.projectionViewMatrix, "lightProjView"))
      )
      ;
    cameraRunner.register(r);
    postRunner.register(r);
  }

  _initPost() {
    var _post = new glf.ViewportPlan()
    ..viewWidth = 256
    ..viewHeight = 256
    ..x = 10
    ..y = 0
    ;
    postRunner.register(_post.makeRequestRunOn());
    var md = glf.makeMeshDef_plane()
        ..normals = null
        ;
    var mesh = new glf.Mesh()..setData(gl, md);
    postRunner.register(new glf.RequestRunOn()
    //..ctx = new glf.ProgramContext(gl, texVert, texFrag2)
    ..ctx = new glf.ProgramContext(gl, texVert, texFrag)
    ..beforeAll =(ctx) {
      gl.viewport(_post.x, _post.y, _post.viewWidth, _post.viewHeight);
      //gl.clearColor(1.0, 1.0, 1.0, 1.0);
      //gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    }
    ..at =(ctx){
      if (lightRunner.fbo.texture != null) {
        glf.injectTexture(ctx, lightRunner.fbo.texture, 0);
        mesh.injectAndDraw(ctx);
      }
    }
    );
  }
  run() {
    lightRunner.run();
    cameraRunner.run();
    postRunner.run();
  }
}

class Tick {
  double _t = -1.0;
  double _tr = 0.0;
  double _dt  = 0.0;
  bool _started = false;
  get dt => _dt;
  get time => _t;
  get tr => _tr;

  update(ntr) {
    if (_started) {
      _dt = (ntr - _tr);
      _t = _t + _dt;
    } else {
      _started = true;
    }
    _tr = ntr;
  }

  reset() {
    _started = false;
    _t = 0.0;
    _tr = 0.0;
    _dt  = 0.0;
  }
}

class Main {

  final Renderer renderer;
  final Tick tick = new Tick();

  var _vertexUI; // = query('#vertex') as TextAreaElement;
  var _fragmentUI; //= query('#fragment') as TextAreaElement;
  var _selectShaderUI = query('#selectShader') as SelectElement;
  var _selectMeshUI = query('#selectMesh') as SelectElement;
  var _subdivisionMeshUI = query('#subdivisionMesh') as InputElement;
  var _loadShaderUI = query('#loadShader') as ButtonElement;
  var _applyShaderUI = query('#applyShader') as ButtonElement;
  var _errorUI = query('#errorTxt') as PreElement;
  var _showWireframeUI = query('#showWireframe') as CheckboxInputElement;
  var _showNormalsUI = query('#showNormals') as CheckboxInputElement;
  var _statsUpdateUI = query('#statsUpdate') as PreElement;
  var _statsLoopUI = query('#statsLoop') as PreElement;
  var plane = new Plane();
  var obj3d = new Obj3D();
  var _programCtxCache = new glf.ProgramContextCache();
  final onUpdate = new List<Function>();

  Main(this.renderer);

  start() {
    renderer.init();

    var statsU = new StartStopWatch()
      ..displayFct = (stats, now) {
        if (now - stats.displayLast > 1000) {
          stats.displayLast = now;
          var msg = "avg : ${stats.avg}\nmax : ${stats.max}\nmin : ${stats.min}\nfps : ${1000/stats.avg}\n";
          _statsUpdateUI.text = msg;
          if (now - stats.resetLast > 3000) stats.reset();
        }
      }
    ;
    var statsL = new StartStopWatch()
      ..displayFct = (stats, now) {
        if (now - stats.displayLast > 1000) {
          stats.displayLast = now;
          var msg = "avg : ${stats.avg}\nmax : ${stats.max}\nmin : ${stats.min}\nfps : ${1000/stats.avg}\n";
          _statsLoopUI.text = msg;
          if (now - stats.resetLast > 3000) stats.reset();
        }
      }
    ;

    renderer.cameraRunner.register(new glf.RequestRunOn()
      ..autoData = (new Map()
        ..["dt"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('dt'), tick.dt))
        ..["time"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('time'), tick.time))
      )
    );
    update(t){
      statsU.start();
      window.animationFrame.then(update);
      tick.update(t);
      // rule to modify one vertice of the mesh
      //md.vertices[0] = 4.0 * (t % 3000)/3000 - 2.0;

      onUpdate.forEach((f) => f(tick));
      // render (run shader's program)
      renderer.run();
      statsU.stop();
      statsL.stop();
      statsL.start();
    };
    window.animationFrame.then(update);

    initEditors();
    bindUI();
    _selectShaderUI.selectedIndex = 0;
    loadShaderCode(_selectShaderUI.value).then((_){
      apply();
    });
    //_loadShaderUI.click();
    //_applyShaderUI.click();
  }


  initEditors() {
    _vertexUI = js.retain(js.context.CodeMirror.fromTextArea(query("#vertex"), js.map({"mode" : "glsl", "lineNumbers" : true})).doc);
    _fragmentUI = js.retain(js.context.CodeMirror.fromTextArea(query("#fragment"), js.map({"mode" : "glsl", "lineNumbers" : true})).doc);
  }

  bindUI() {
    _loadShaderUI.onClick.listen((_) => loadShaderCode(_selectShaderUI.value));
    _applyShaderUI.onClick.listen((_) => apply());
  }

  loadShaderCode(String baseUri){
    var vsUri = Uri.parse("${baseUri}.vert");
    var fsUri = Uri.parse("${baseUri}.frag");
    return Future.wait([
      HttpRequest.request(vsUri.toString(), method: 'GET'),
      HttpRequest.request(fsUri.toString(), method: 'GET')
    ])
    .then((l) {
      _vertexUI.setValue(l[0].responseText);
      _fragmentUI.setValue(l[1].responseText);
    });
  }

  makeShaderProgram(gl) => _programCtxCache.find(gl, _vertexUI.getValue(), _fragmentUI.getValue());

  makeMeshDef(){
    var sub = int.parse(_subdivisionMeshUI.value);
    var md = null;
    switch(_selectMeshUI.value) {
      case 'box24' :
        md = glf.makeMeshDef_box24Vertices(dx: 2.0, dy: 1.0, dz: 0.5, ty: 1.0);
        break;
      case 'box24-t' :
        md = glf.makeMeshDef_box24Vertices(dx: 2.0, dy: 1.0, dz: 0.5, tx: 2.0, ty: 1.0, tz: 0.5);
        break;
      case 'cube8' :
        md = glf.makeMeshDef_box8Vertices(dx: 0.5, dy: 0.5, dz: 0.5);
        break;
      case 'sphereL':
        md = glf.makeMeshDef_sphere(subdivisionsAxis : sub, subdivisionsHeight : sub);
        break;
      default:
        md = glf.makeMeshDef_box24Vertices(dx: 0.5, dy: 0.5, dz: 0.5);
    }
    if (_showWireframeUI.checked) {
      md.lines = glf.extractWireframe(md.triangles);
      md.triangles = null;
    }
    return md;
  }

  apply() {
    try {
      _errorUI.text = '';
      var ctx = makeShaderProgram(renderer.gl);
      plane.applyMaterial(renderer, ctx);
      obj3d.apply(renderer, ctx, onUpdate, makeMeshDef(), _showNormalsUI.checked);
    }catch(e) {
      _errorUI.text = e.toString();
    }
  }
}

class Obj3D {
  var cameraReq;
  var cameraReqN;
  var lightReq;
  var upd0;

  apply(renderer, ctx, onUpdate, glf.MeshDef md, showNormals) {
    _remove(renderer, ctx, onUpdate);
    _add(renderer, ctx, onUpdate, md, showNormals);
  }

  _remove(renderer, ctx, onUpdate) {
    if (lightReq != null) {
      renderer.lightRunner.unregister(lightReq);
      lightReq = null;
    }
    if (cameraReq != null) {
      renderer.cameraRunner.unregister(cameraReq);
      cameraReq = null;
    }
    if (cameraReqN != null) {
      renderer.cameraRunner.unregister(cameraReqN);
      cameraReqN = null;
    }
    if (upd0 != null) {
      onUpdate.remove(upd0);
      upd0 = null;
    }
  }

  _add(renderer, ctx, onUpdate, md, showNormals) {
    // Create a cube geometry +  a texture + a transform + a shader program to display all
    // same parameter with other transforms can be reused to display several cubes
    var transforms = new Matrix4.identity();
    var normalMatrix = new Matrix3.zero();

    var mesh = new glf.Mesh()..setData(ctx.gl, md);

    // keep ref to RequestRunOn to be able to register/unregister (show/hide)
    var tex = glf.createTexture(ctx.gl, new Uint8List.fromList([120, 120, 120, 255]), Uri.parse("_images/dirt.jpg"));
    var texNormal = glf.createTexture(ctx.gl, new Uint8List.fromList([0, 0, 120]), Uri.parse("_images/shaders_offest_normalmap.jpg"));
    var texDissolve0 = glf.createTexture(ctx.gl, new Uint8List.fromList([120, 120, 120, 255]), Uri.parse("_images/burnMap.png"));
    var texDissolve1 = glf.createTexture(ctx.gl, new Uint8List.fromList([120, 120, 120, 255]), Uri.parse("_images/growMap.gif"));
    var texDissolve2 = glf.createTexture(ctx.gl, new Uint8List.fromList([120, 120, 120, 255]), Uri.parse("_images/linear.png"));
    var texMatCap = glf.createTexture(ctx.gl, new Uint8List.fromList([120, 120, 120, 255]), Uri.parse("_images/matcap0.png"));

    cameraReq = new glf.RequestRunOn()
      ..ctx = ctx
      ..at = (ctx) {
        ctx.gl.uniform3f(ctx.getUniformLocation(glf.SFNAME_COLORS), 0.5, 0.5, 0.5);
        glf.makeNormalMatrix(transforms, normalMatrix);
        glf.injectMatrix4(ctx, transforms, glf.SFNAME_MODELMATRIX);
        glf.injectMatrix3(ctx, normalMatrix, glf.SFNAME_NORMALMATRIX);
        glf.injectTexture(ctx, tex, 0);
        glf.injectTexture(ctx, texNormal, 1, '_NormalMap0');
        glf.injectTexture(ctx, texMatCap, 2, '_MatCap0');
        glf.injectTexture(ctx, texDissolve0, 3, '_DissolveMap0');
        glf.injectTexture(ctx, texDissolve1, 4, '_DissolveMap1');
        glf.injectTexture(ctx, texDissolve2, 5, '_DissolveMap2');
        // vertices of the mesh can be modified in update loop, so update the data to GPU
        //mesh.vertices.setData(ctx.gl, md.vertices);
        mesh.injectAndDraw(ctx);
      }
    ;
    renderer.cameraRunner.register(cameraReq);

    lightReq = new glf.RequestRunOn()
      ..ctx = renderer.lightCtx
      ..at = (ctx) {
        glf.makeNormalMatrix(transforms, normalMatrix);
        glf.injectMatrix4(ctx, transforms, glf.SFNAME_MODELMATRIX);
        glf.injectMatrix3(ctx, normalMatrix, glf.SFNAME_NORMALMATRIX);
        mesh.injectAndDraw(ctx);
      }
    ;
    renderer.lightRunner.register(lightReq);

    upd0 = (tick){
      transforms.setIdentity();
      transforms.rotateY((tick.time % 5000.0) / 5000.0 * 2 * math.PI);
    };
    onUpdate.add(upd0);

    if (showNormals) {
      var mdNormal = glf.extractNormals(md);
      var meshNormal = new glf.Mesh()..setData(ctx.gl, mdNormal);
      var programCtxN = glf.loadProgramContext(ctx.gl, Uri.parse("packages/glf/shaders/default.vert"), Uri.parse("packages/glf/shaders/default.vert"));

      programCtxN.then((ctxN) {
        cameraReqN = new glf.RequestRunOn()
          ..ctx = ctxN
          ..at = (ctx) {
            ctx.gl.uniform3f(ctx.getUniformLocation(glf.SFNAME_COLORS), 0.8, 0.8, 0.8);
            glf.makeNormalMatrix(transforms, normalMatrix);
            glf.injectMatrix4(ctx, transforms, glf.SFNAME_MODELMATRIX);
            glf.injectMatrix3(ctx, normalMatrix, glf.SFNAME_NORMALMATRIX);
            glf.injectTexture(ctx, tex, 0);
            glf.injectTexture(ctx, texNormal, 1);
            // vertices of the mesh can be modified in update loop, so update the data to GPU
            //mesh2.vertices.setData(ctx.gl, md2.vertices);
            meshNormal.injectAndDraw(ctx);
          }
        ;
        renderer.cameraRunner.register(cameraReqN);
      });
    }

  }
}

class Plane {
  var cameraReq;
  var cameraReqN;
  var lightReq;

  applyMaterial(renderer, ctx) {
    _remove(renderer, ctx);
    _add(renderer, ctx);
  }

  _remove(renderer, ctx) {
    if (lightReq != null) {
      renderer.lightRunner.unregister(lightReq);
      lightReq = null;
    }
    if (cameraReq != null) {
      renderer.cameraRunner.unregister(cameraReq);
      cameraReq = null;
    }
    if (cameraReqN != null) {
      renderer.cameraRunner.unregister(cameraReqN);
      cameraReqN = null;
    }
  }

  _add(renderer, ctx) {
    var md = glf.makeMeshDef_plane(dx: 3.0, dy: 3.0);
    var mesh = new glf.Mesh()..setData(ctx.gl, md);

    var transforms = new Matrix4.identity();
    transforms.translate(0.0, 0.0, 0.0);
    //transforms.rotateX(math.PI * -0.5);
    var normalMatrix = new Matrix3.zero();

    cameraReq = new glf.RequestRunOn()
      ..ctx = ctx
      ..at = (ctx) {
        ctx.gl.uniform3f(ctx.getUniformLocation(glf.SFNAME_COLORS), 0.0, 0.5, 0.5);
        glf.makeNormalMatrix(transforms, normalMatrix);
        glf.injectMatrix4(ctx, transforms, glf.SFNAME_MODELMATRIX);
        glf.injectMatrix3(ctx, normalMatrix, glf.SFNAME_NORMALMATRIX);
        mesh.injectAndDraw(ctx);
      }
    ;
    renderer.cameraRunner.register(cameraReq);

    lightReq = new glf.RequestRunOn()
      ..ctx = renderer.lightCtx
      ..at = (ctx) {
        glf.makeNormalMatrix(transforms, normalMatrix);
        glf.injectMatrix4(ctx, transforms, glf.SFNAME_MODELMATRIX);
        glf.injectMatrix3(ctx, normalMatrix, glf.SFNAME_NORMALMATRIX);
        mesh.injectAndDraw(ctx);
      }
    ;
    renderer.lightRunner.register(lightReq);
  }

}

// in milliseconds ( like window.performance.now() )
class StartStopWatch {
  Function displayFct;
  double displayLast = 0.0;
  double resetLast = 0.0;
  double min;
  double max;
  double total;
  int count;
  double _pstart;

  final _perf = window.performance;

  get avg => (count == 0) ? 0.0 : total/count;

  StartStopWatch() {
    reset();
    start();
  }

  start() {
    _pstart = _perf.now();
  }

  stop() {
    var now = _perf.now();
    store(now - _pstart);
    if (displayFct != null) {
      displayFct(this, now);
    }
  }

  store(double t) {
    if (min > t) min = t;
    if (max < t) max = t;
    count++;
    total += t;
  }

  reset() {
    resetLast = _perf.now();
    min = double.MAX_FINITE;
    max = double.MIN_POSITIVE;
    total = 0.0;
    count = 0;
  }

}
var texVert = """
attribute vec3 _Vertex;
attribute vec2 _TexCoord0;
varying vec2 vTexCoord0;
void main() {
vTexCoord0 = _TexCoord0.xy;
gl_Position = vec4(vTexCoord0 * 2.0 - 1.0, 0.0, 1.0);
}""";
var texFrag = """
#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D _Tex0;
varying vec2 vTexCoord0;
void main() {
//gl_FragColor = vec4(vTexCoord0.xy, 1.0, 1.0);
gl_FragColor = texture2D(_Tex0, vTexCoord0);
}
""";
var depthVert0 = """
uniform mat4 _ProjectionViewMatrix;
uniform mat4 _ModelMatrix;
uniform mat3 _NormalMatrix;

attribute vec3 _Vertex;
varying vec4 vVertex;

attribute vec3 _Normal;
varying vec3 vNormal;

void main(){
  vVertex = _ModelMatrix * vec4(_Vertex, 1.0);
  vNormal = _NormalMatrix * _Normal;
  gl_Position = _ProjectionViewMatrix * vVertex;
}
""";
var depthFrag0 = """
precision mediump float;

//#define SHADOW_VSM 1

uniform mat4 _ProjectionMatrix, _ViewMatrix;
uniform mat4 _ModelMatrix;
uniform mat3 _NormalMatrix;

varying vec4 vVertex;
varying vec3 vNormal;
varying vec2 vTexCoord0;

uniform mat4 lightProj, lightView;
uniform float lightFar, lightNear;

""" + libFrag + """

void main(){
  mat4 lightView = _ViewMatrix;
  vec3 lPosition = (lightView * vVertex).xyz;
  float depth = depthOf(lPosition, lightNear, lightFar);
#ifdef SHADOW_VSM
  float moment2 = depth * depth;
  gl_FragColor = vec4(packHalf(depth), packHalf(moment2));
#else
  gl_FragColor =  pack(depth);
#endif
}

""";
var normalFrag0 = """
precision mediump float;

uniform mat4 _ProjectionMatrix, _ViewMatrix;
varying vec3 vNormal;
varying vec4 vVertex;

void main(){
  vec3 normal = normalize(vNormal);
  vec4 v = _ViewMatrix * vVertex;
  gl_FragColor = vec4(normal.x, normal.y, normal.z, 1.0);
}

""";
var libFrag = """
const float PI = 3.14159265358979323846264;

/// Pack a floating point value into an RGBA (32bpp).
/// Used by SSM, PCF, and ESM.
///
/// Note that video cards apply some sort of bias (error?) to pixels,
/// so we must correct for that by subtracting the next component's
/// value from the previous component.
/// @see http://devmaster.net/posts/3002/shader-effects-shadow-mapping#sthash.l86Qm4bE.dpuf
vec4 pack (float v) {
  const vec4 bias = vec4(1.0 / 255.0, 1.0 / 255.0, 1.0 / 255.0, 0.0);
  float r = v;
  float g = fract(r * 255.0);
  float b = fract(g * 255.0);
  float a = fract(b * 255.0);
  vec4 color = vec4(r, g, b, a);
  return color - (color.yzww * bias);
}


/// Unpack an RGBA pixel to floating point value.
float unpack (vec4 color) {
  const vec4 bitShifts = vec4(1.0, 1.0 / 255.0, 1.0 / (255.0 * 255.0), 1.0 / (255.0 * 255.0 * 255.0));
  return dot(color, bitShifts);
}

/// Pack a floating point value into a vec2 (16bpp).
/// Used by VSM.
vec2 packHalf (float v) {
  const vec2 bias = vec2(1.0 / 255.0, 0.0);
  vec2 color = vec2(v, fract(v * 255.0));
  return color - (color.yy * bias);
}

/// Unpack a vec2 to a floating point (used by VSM).
float unpackHalf (vec2 color) {
  return color.x + (color.y / 255.0);
}

float depthOf(vec3 position, float near, float far) {
  //float depth = (position.z - near) / (far - near);
  float depth = (length(position) - near)/(far - near);
  return clamp(depth, 0.0, 1.0);
}

///------------ Light (basic)

float attenuation(vec3 dir){
  float dist = length(dir);
  float radiance = 1.0/(1.0+pow(dist/10.0, 2.0));
  return clamp(radiance*10.0, 0.0, 1.0);
}
  
float influence(vec3 normal, float coneAngle){
  float minConeAngle = ((360.0-coneAngle-10.0)/360.0)*PI;
  float maxConeAngle = ((360.0-coneAngle)/360.0)*PI;
  return smoothstep(minConeAngle, maxConeAngle, acos(normal.z));
}

float lambert(vec3 surfaceNormal, vec3 lightDirNormal){
  return max(0.0, dot(surfaceNormal, lightDirNormal));
}
  
vec3 skyLight(vec3 normal){
  return vec3(smoothstep(0.0, PI, PI-acos(normal.y)))*0.4;
}

vec3 gamma(vec3 color){
  return pow(color, vec3(2.2));
}

const float rimStart = 0.5;
const float rimEnd = 1.0;
const float rimMultiplier = 0.1;
vec3  rimColor = vec3(0.0, 0.0, 0.5);

vec3 rimLight(vec3 position, vec3 normal, vec3 viewPos) {
  float normalToCam = 1.0 - dot(normalize(normal), normalize(viewPos.xyz - position.xyz));
  float rim = smoothstep(rimStart, rimEnd, normalToCam) * rimMultiplier;
  return (rimColor * rim);
}

///---------- Depth (for shadow, ...)

vec2 uvProjection(vec3 position, mat4 proj) {
  vec4 device = proj * vec4(position, 1.0);
  vec2 deviceNormal = device.xy / device.w;
  return deviceNormal * 0.5 + 0.5;
}

vec4 valueFromTexture(vec3 position, mat4 proj, sampler2D tex) {
  return texture2D(tex, uvProjection(position, proj));
}


/// Calculate Chebychev's inequality.
///  moments.x = mean
///  moments.y = mean^2
///  `t` Current depth value.
/// returns The upper bound (0.0, 1.0), or rather the amount
/// to shadow the current fragment colour.
float ChebychevInequality (vec2 moments, float t) {
  // No shadow if depth of fragment is in front
  if ( t <= moments.x ) return 1.0;
  // Calculate variance, which is actually the amount of
  // error due to precision loss from fp32 to RG/BA
  // (moment1 / moment2)
  float variance = moments.y - (moments.x * moments.x);
  variance = max(variance, 0.02);
  // Calculate the upper bound
  float d = t - moments.x;
  return variance / (variance + d * d);
}

/// VSM can suffer from light bleeding when shadows overlap. This method
/// tweaks the chebychev upper bound to eliminate the bleeding, but at the
/// expense of creating a shadow with sharper, darker edges.
float VsmFixLightBleed (float pMax, float amount) {
  return clamp((pMax - amount) / (1.0 - amount), 0.0, 1.0);
}
 
float shadowOf(vec3 position, mat4 texProj, sampler2D tex, float near, float far, float bias) {
  vec4 texel = valueFromTexture(position, texProj, tex);
  float depth = depthOf(position, near, far);

#ifdef SHADOW_VSM
  // Variance shadow map algorithm
  vec2 moments = vec2(unpackHalf(texel.xy), unpackHalf(texel.zw));
  return ChebychevInequality(moments, depth);
  //shadow = VsmFixLightBleed(shadow, 0.1);
#else
  // hard shadow
  //float bias = 0.001;
  return step(depth, unpack(texel) + bias);
#endif
}

///--- Animation Effect

//uniform float time;

uniform sampler2D dissolveMap;

float dissolve(float threshold, vec2 uv) {
  float v = texture2D(dissolveMap, uv).r;
  if (v < threshold) discard;
  return v;
}


""";

var texFrag2="""
#ifdef GL_ES
precision mediump float;
#endif
//#define SHADOW_VSM 1

uniform mat4 _ViewMatrix;

uniform mat4 lightProj, lightView;
uniform mat3 lightRot;
uniform float lightFar,lightNear;
uniform float lightConeAngle;
uniform sampler2D sLightDepth;

varying vec2 vTexCoord0;
"""
+ libFrag
+ """

/*
* Toon Lines shader by Luiz Felipe M. Pereira(felipearts)
* Based on Toon Lines shader by Jose I. Romero (cyborg_ar)
* released under the terms of the GNU General Public License version 2
* updated 09/11/11
* 
* The original code is (c) Blender Foundation.
*/
//Performance Tips:  If possible use * and +(in that order) in the same calculation instead of / and -;
//use dot product and avoid unecessary calculations or info splitting
//(Ex: for a vec4 calculation use split.abcd instead of split.abc and split.d)

//uniform float near; // The camera clipstart value, know in GLSL as near plane
//uniform float far; // The camera clipend value, know in GLSL as far plane
//uniform sampler2D bgl_RenderedTexture; // Gets the offscreen texture representating the current camera view contents
//uniform sampler2D bgl_DepthTexture; // Gets the offscreen texture representating the current fragments depth
//uniform vec2 bgl_TextureCoordinateOffset[9];

const float edgeForce = 0.6; // The force of the outline blackness
const float baseThresh = 2.0; // The initial(near value) edge threshold value for inking

// A custom function, which returns the linearized depth value of the a given point in the depth texture,
// linearization seems to be a way of having more uniform values for the fragments far from the camera;
// as it is logical which greater depth values would give greater results, also linearization compensates
// lack of accurancy for fragments distant to the camera, as by default a lot of accurancy is allocated to
// fragments near the camera. 
float LinearizeDepth(in float z)
{
  return (2.0 * lightNear) / (lightFar + lightNear - z * (lightFar - lightNear));
}

// The fragment shader loop
void main(void)
{

// Assign these variables now because they will be used next
float sample[9];
//vec4 texcol = texture2D(bgl_RenderedTexture, gl_TexCoord[0].st);
vec4 texcol = vec4(0.0,0.0,1.0,1.0);//texture2D(sLightDepth, vTexCoord0.st);
  

// Current fragment depth
//float base = LinearizeDepth( float( texture2D(bgl_DepthTexture, gl_TexCoord[0].st) ) );
//float base = LinearizeDepth(unpack(texture2D(sLightDepth, vTexCoord0.st)) );
//float base = length(texture2D(sLightDepth, vTexCoord0.st));
vec4 p = texture2D(sLightDepth, vTexCoord0.st);
vec3 p3 =  normalize(p.xyz);
float colDifForce = 0.0;


// Gets all neighboring fragments depths stored into the depth texture
float offset = 1.0 / 256.0;
for (int j = -1; j < 2; j++)  
for (int i = -1; i < 2; i++)
{
//sample[i] = LinearizeDepth( float( texture2D(bgl_DepthTexture, gl_TexCoord[0].st + bgl_TextureCoordinateOffset[i]) ) );
//sample[i+j*3] = LinearizeDepth( float( texture2D(sLightDepth, vTexCoord0.st + vec2(i,j)/*bgl_TextureCoordinateOffset[i]*/) ) );
//sample[i+j*3] = LinearizeDepth( unpack(texture2D(sLightDepth, vTexCoord0.st + vec2(float(i) * offset,float(j) * offset))) );
//sample[i+j*3] = unpack(texture2D(sLightDepth, vTexCoord0.st + vec2(float(i) * offset,float(j) * offset)));  
//sample[i+j*3] = length(texture2D(sLightDepth, vTexCoord0.st + vec2(float(i) * offset,float(j) * offset)));  
//  sample[i] = depthFromTexture()
vec4 v = texture2D(sLightDepth, vTexCoord0.st + vec2(float(i) * offset,float(j) * offset));
vec3 v3 = normalize(v.xyz);

colDifForce += step(abs(dot(p3, v3)), 0.8);
//colDifForce += step(0.0000000001, abs(v.w - p.w));
}


// The result fragment sample matrix is as below, where x is the current fragment(4)
// 0 1 2
// 3 x 5
// 6 7 8


// From all the neighbor fragments gets the one with the greatest and lowest depths and place them
// into two variables so a subtract can be made later. The check is huge, but GLSL built-in functions
// are optimized for the GPU
//float areaMx = max(sample[0], max(sample[1], max(sample[2], max(sample[3], max(sample[5], max(sample[6], max(sample[7], sample [8])))))));

//float areaMn = min(sample[0], min(sample[1], min(sample[2], min(sample[3], min(sample[5], min(sample[6], min(sample[7], sample [8])))))));


//float colDifForce = areaMx - areaMn; // Gets the average value between the maximum and minimum depths


//Check for heavy depth difference to darken the current fragment; 
//we do not want to mess with transparency, so leave alpha alone
//edgeForce variable control the outline transparency, so 1.0 would be full black.
// ? : is the same as if else
// abs is short of absolute value, it tells to disconsider the negativity of a value if it exists
//gl_FragColor = colDifForce * (lightFar - lightNear) > 0.3  ?  vec4(0.0,0.8,0.0,1.0) : vec4(vec3(base), 1.0);
//gl_FragColor = vec4(vec3(base), 1.0);
//gl_FragColor = texture2D(sLightDepth, vTexCoord0);
gl_FragColor = colDifForce > 1.0  ?  vec4(1.0,1.0,1.0,1.0) : vec4(p3, 1.0);
}
""";
