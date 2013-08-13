import 'dart:html';
import 'dart:async';
import 'dart:math' as math;
import 'dart:web_gl' as GL;
import 'dart:typed_data';
import 'package:js/js.dart' as js;

import 'package:vector_math/vector_math.dart';

import 'package:asset_pack/asset_pack.dart';
import 'package:glf/glf.dart' as glf;
import 'package:glf/glf_asset_pack.dart';

const TexNormalsRandomL = "_TexNormalsRandom";
const TexNormalsRandomN = 28;
const TexVerticesL = "_TexVertices";
const TexVerticesN = 29;
const TexNormalsL = "_TexNormals";
const TexNormalsN = 30;

main(){
  var gl = (query("#canvas0") as CanvasElement).getContext3d(alpha: false, depth: true);
  if (gl == null) {
    print("webgl not supported");
    return;
  }
  //var gli = js.context.gli;
  //var result = gli.host.inspectContext(gl.canvas, gl);
  //var hostUI = new js.Proxy(gli.host.HostUI, result);
  //result.hostUI = hostUI; // just so we can access it later for debugging
  var am = initAssetManager(gl);
  new Main(new Renderer2(gl), am).start();
}

AssetManager initAssetManager(gl) {
  var tracer = new AssetPackTrace();
  var stream = tracer.asStream().asBroadcastStream();
  new ProgressControler(query("#assetload")).bind(stream);
  new EventsPrintControler().bind(stream);

  var b = new AssetManager(tracer);
  b.loaders['img'] = new ImageLoader();
  b.importers['img'] = new NoopImporter();
  registerGlfWithAssetManager(gl, b);
  return b;
}

class EventsPrintControler {

  EventsPrintControler();

  StreamSubscription bind(Stream<AssetPackTraceEvent> tracer) {
    return tracer.listen(onEvent);
  }

  void onEvent(AssetPackTraceEvent event) {
    print("AssetPackTraceEvent : ${event}");
  }
}

aabbToPoints(Aabb3 aabb) {
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
extractMinMaxProjection(List<Vector3> vs, Vector3 axis, Vector3 origin, Vector2 out) {
  var tmp = new Vector3.zero();
  tmp.setFrom(vs[0]).sub(origin);
  var p = tmp.dot(axis);
  out.x = p;
  out.y = p;
  for (int i = 1; i < vs.length; i++) {
    tmp.setFrom(vs[i]).sub(origin);
    p = tmp.dot(axis);
    if (p < out.x) out.x = p;
    if (p > out.y) out.y = p;
  }
}

//class Renderer {
//  final gl;
//
//  final glf.ProgramsRunner lightRunner;
//  final glf.ProgramsRunner cameraRunner;
//  final glf.ProgramsRunner postRunner;
//
//  var lightCtx = null;
//
//  Renderer(gl) : this.gl = gl,
//    lightRunner = new glf.ProgramsRunner(gl),
//    cameraRunner = new glf.ProgramsRunner(gl),
//    postRunner = new glf.ProgramsRunner(gl)
//  ;
//
//  var _x0, _x1, _x2;
//  init() {
//    //_x0 = gl.getExtension("OES_standard_derivatives");
//    //_x1 = gl.getExtension("OES_texture_float");
//    //_x2 = gl.getExtension("GL_EXT_draw_buffers");
//    //print(">>>> extension $_x0 $_x1 $_x2");
//    _initCamera();
//    _initLight();
//    _initPost();
//  }
//
//  _initCamera() {
//    // Camera default setting for perspective use canvas area full
//    var viewport = new glf.ViewportCamera.defaultSettings(gl.canvas);
//    viewport.camera.position.setValues(0.0, 0.0, 6.0);
//
//    cameraRunner.register(new glf.RequestRunOn()
//      ..setup= (gl) {
//        if (true) {
//          // opaque
//          gl.disable(GL.BLEND);
//          gl.depthFunc(GL.LEQUAL);
//          //gl.depthFunc(GL.LESS); // default value
//          gl.enable(GL.DEPTH_TEST);
////        } else {
////          // blend
////          gl.disable(GL.DEPTH_TEST);
////          gl.blendFunc(GL.SRC_ALPHA, GL.ONE);
////          gl.enable(GL.BLEND);
//        }
//        gl.colorMask(true, true, true, true);
//      }
//      ..beforeAll = (gl) {
//        gl.viewport(viewport.x, viewport.y, viewport.viewWidth, viewport.viewHeight);
//        //gl.clearColor(0.0, 0.0, 0.0, 1.0);
//        gl.clearColor(1.0, 0.0, 0.0, 1.0);
//        //gl.clearColor(1.0, 1.0, 1.0, 1.0);
//        gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
//        //gl.clear(GL.COLOR_BUFFER_BIT);
//      }
////      ..onRemoveProgramCtx = (prunner, ctx) {
////        ctx.delete();
////      }
//    );
//
//
//    cameraRunner.register(viewport.makeRequestRunOn());
//  }
//
//  _initLight() {
//    var _light = new glf.ViewportCamera()
//      ..viewWidth = 256
//      ..viewHeight = 256
//      ..camera.fovRadians = degrees2radians * 55.0
//      ..camera.aspectRatio = 1.0
//      ..camera.position.setValues(2.0, 2.0, 4.0)
//      ..camera.focusPosition.setValues(0.0, 0.0, 0.0)
//      ;
//    var scene = new Aabb3()
//      ..min.setValues(-3.0, -3.0, 0.0)
//      ..max.setValues(3.0, 3.0, 3.0)
//      ;
//    var axis = _light.camera.focusPosition - _light.camera.position;
//    var v2 = new Vector2.zero();
//    extractMinMaxProjection(aabbToPoints(scene), axis,v2);
//    _light.camera.far = math.max(0.1, v2.y);//(_light.camera.focusPosition - _light.camera.position).length * 2;
//    _light.camera.near = math.max(0.1, v2.x);//math.max(0.5, (_light.camera.focusPosition - _light.camera.position).length - 3.0);
//    //_light.camera.updateProjectionViewMatrix();
//
//    lightFbo = new glf.FBO(gl)..make(width : _light.viewWidth, height : _light.viewHeight);
//    lightCtx = new glf.ProgramContext(gl, depthVert0, depthFrag0);
//    //lightCtx = new glf.ProgramContext(gl, depthVert0, normalFrag0);
//    lightRunner.register(_light.makeRequestRunOn()
//      ..ctx = lightCtx
//      ..beforeAll = (gl) {
//        gl.viewport(0, 0, _light.viewWidth, _light.viewHeight);
//        gl.clearColor(1.0, 1.0, 1.0, 1.0);
//        gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
//      }
//      ..before =(ctx) {
//        ctx.gl.uniform1f(ctx.getUniformLocation('lightFar'), _light.camera.far);
//        ctx.gl.uniform1f(ctx.getUniformLocation('lightNear'), _light.camera.near);
//      }
//    );
//
//    var r = new glf.RequestRunOn()
//      ..autoData = (new Map()
//        ..["sLightDepth"] = ((ctx) => glf.injectTexture(ctx, lightFbo.texture, 31, "sLightDepth"))
//        ..["lightFar"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('lightFar'), _light.camera.far))
//        ..["lightNear"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('lightNear'), _light.camera.near))
//        ..["lightConeAngle"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('lightConeAngle'), _light.camera.fovRadians * radians2degrees))
//        ..["lightProj"] = ((ctx) => glf.injectMatrix4(ctx, _light.camera.projectionMatrix, "lightProj"))
//        ..["lightView"] = ((ctx) => glf.injectMatrix4(ctx, _light.camera.viewMatrix, "lightView"))
//        ..["lightRot"] = ((ctx) => glf.injectMatrix3(ctx, _light.camera.rotMatrix, "lightRot"))
//        ..["lightProjView"] = ((ctx) => glf.injectMatrix4(ctx, _light.camera.projectionViewMatrix, "lightProjView"))
//      )
//      ;
//    cameraRunner.register(r);
//    postRunner.register(r);
//  }
//
//  _initPost() {
//    var view2d = new glf.ViewportPlan()
//    ..viewWidth = 256
//    ..viewHeight = 256
//    ..x = 10
//    ..y = 0
//    ;
//    var post2d = new glf.Filter2DRunner(gl, view2d)
//    ..texInit = _lightFbo.texture
//    ..add(texFrag)
//    ;
//    //postRunner.register(_post.makeRequestRunOn());
//    postRunner.register(new glf.RequestRunOn()
//    //..ctx = new glf.ProgramContext(gl, texVert, texFrag2)
//    //..ctx = new glf.ProgramContext(gl, texVert, texFrag)
//    ..afterAll =(gl){
//      post2d.run();
//    }
//    );
//    var kernel = new Float32List.fromList(
//        [-0.125,-0.125,-0.125,-0.125,1.0,-0.125,-0.125,-0.125,-0.125]
//        //[0.045,0.122,0.045,0.122,0.332,0.122,0.045,0.122,0.045]
//        );
//    var offset = 0.0;
//    Future.wait([
//      //HttpRequest.request("packages/glf/shaders/filters_2d/convolution3x3.frag", method: 'GET'),
//      HttpRequest.request("packages/glf/shaders/filters_2d/x_waves.frag", method: 'GET'),
//    ])
//    .then((l) {
//      post2d.add(
//        l[0].responseText,
//        //(ctx) => ctx.gl.uniform1fv(ctx.getUniformLocation('_Kernel[0]'), kernel)
//        (ctx){
//          ctx.gl.uniform1f(ctx.getUniformLocation('_Offset'), offset);
//          offset = (offset + 1.0) % 1000;
//        }
//      );
//    });
//  }
//  run() {
//    lightRunner.run();
//    cameraRunner.run();
//    postRunner.run();
//  }
//}

class Renderer2SolidCache {
  Geometry geometry;
  Material material;
  glf.RequestRunOn cameraReq;
  glf.RequestRunOn geomReq;

  Renderer2SolidCache(this.geometry, this.material) {
    cameraReq = new glf.RequestRunOn()
    ..ctx = material.ctx
    ..at = (ctx) {
      material.cfg(ctx);
      geometry.injectAndDraw(ctx);
    }
    ;
    geomReq = new glf.RequestRunOn()
    ..atEach = geometry.injectAndDraw
    ;
  }
}
var lightCtx00 = null;

class Renderer2 {
  final gl;

  final glf.ProgramsRunner _preRunner;
  final glf.ProgramsRunner _cameraRunner;
  glf.Filter2DRunner _post2d;
  glf.Filter2DRunner _post2dw1;

  get filters2d => _post2d.filters;

  get debugView => _post2dw1.texInit;
  set debugView(GL.Texture tex) => _post2dw1.texInit = tex;

  final cameraViewport;

  var _reqs = new Map<Geometry, Renderer2SolidCache>();

  /// Aabb of the scene used to adjust some parameter (like near, far shadowMapping)
  /// it is not updated when solid is add (or updated or removed).
  final sceneAabb = new Aabb3()
  ..min.setValues(-4.0, -4.0, -1.0)
  ..max.setValues(4.0, 4.0, 4.0)
  ;

  Renderer2(gl) : this.gl = gl,
    _preRunner = new glf.ProgramsRunner(gl),
    _cameraRunner = new glf.ProgramsRunner(gl),
    cameraViewport = new glf.ViewportCamera.defaultSettings(gl.canvas)
  ;

  addPrepare(glf.RequestRunOn req) {
    _preRunner.register(req);
  }

  removePrepare(glf.RequestRunOn req) {
    _preRunner.unregister(req);
  }

  add(glf.RequestRunOn req) {
    _cameraRunner.register(req);
  }

  remove(glf.RequestRunOn req) {
    _cameraRunner.unregister(req);
  }

  addSolid(Geometry geometry, Material material) {
    var e = new Renderer2SolidCache(geometry, material);
    _reqs[geometry] = e;
    addPrepare(e.geomReq);
    add(e.cameraReq);
  }

  removeSolid(Geometry geometry) {
    var e = _reqs[geometry];
    if (e != null) {
      removePrepare(e.geomReq);
      remove(e.cameraReq);
      _reqs[geometry] = null;
    }
  }

  var _x0, _x1, _x2;
  init() {
    //_x0 = gl.getExtension("OES_standard_derivatives");
    _x1 = gl.getExtension("OES_texture_float");
    //_x2 = gl.getExtension("GL_EXT_draw_buffers");
    _initPostW0();
    _initPostW1();
    _initCamera();
    _initPre();
  }

  _initCamera() {
    // Camera default setting for perspective use canvas area full
    var viewport = cameraViewport;
    var camera = viewport.camera;
    camera.position.setValues(0.0, 0.0, 6.0);
    camera.focusPosition.setValues(0.0, 0.0, 0.0);
    var axis = (camera.focusPosition - camera.position).normalized();
    var v2 = new Vector2.zero();
    extractMinMaxProjection(aabbToPoints(sceneAabb), axis, camera.position,v2);
    camera.far = math.max(0.1, v2.y);
    camera.near = math.max(0.1, v2.x);
    //TODO support resize
    var cameraFbo = new glf.FBO(gl)..make(width : viewport.viewWidth, height : viewport.viewHeight);
    var r = new glf.RequestRunOn()
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
        viewport.setup(gl);
      }
      ..beforeAll = (gl) {
        gl.bindFramebuffer(GL.FRAMEBUFFER, cameraFbo.buffer);
        gl.viewport(viewport.x, viewport.y, viewport.viewWidth, viewport.viewHeight);
        //gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clearColor(1.0, 0.0, 0.0, 1.0);
        //gl.clearColor(1.0, 1.0, 1.0, 1.0);
        gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
        //gl.clear(GL.COLOR_BUFFER_BIT);
      }
      ..beforeEach =  viewport.injectUniforms
//      ..onRemoveProgramCtx = (prunner, ctx) {
//        ctx.delete();
//      }
    ;
    add(r);
    _post2d.texInit = cameraFbo.texture;
  }

  _initPre() {
  }

  _initPostW1() {
    var view2d = new glf.ViewportPlan()
    ..viewWidth = 256
    ..viewHeight = 256
    ..x = 10
    ..y = 0
    ;
    _post2dw1 = new glf.Filter2DRunner(gl, view2d);
    HttpRequest.request('packages/glf/shaders/filters_2d/identity.frag', method: 'GET').then((r) {
      _post2dw1.filters.add(new glf.Filter2D(gl, r.responseText));
    });
  }

  _initPostW0() {
    var view2d = new glf.ViewportPlan()..fullCanvas(gl.canvas);
    _post2d = new glf.Filter2DRunner(gl, view2d);
  }

  run() {
    _preRunner.run();
    _cameraRunner.run();
    _post2d.run();
    if (_post2dw1.texInit != null) _post2dw1.run();
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

  final Renderer2 renderer;
  final AssetManager am;
  final Factory_Filter2D factory_filter2d;

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

  Main(this.renderer, am) :
    am = am,
    factory_filter2d = new Factory_Filter2D()..am = am
  ;

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

    renderer.add(new glf.RequestRunOn()
      ..autoData = (new Map()
        ..["dt"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('dt'), tick.dt))
        ..["time"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('time'), tick.time))
      )
    );
    _loadAssets().then((x){
      renderer.filters2d.add(factory_filter2d.makeIdentity());
      //renderer.filters2d.add(factory_filter2d.makeBrightness(brightness : 0.0, contrast : 1.0, gamma : 2.2));
      //renderer.filters2d.add(factory_filter2d.makeConvolution3(Factory_Filter2D.c3_boxBlur));
      //renderer.filters2d.add(factory_filter2d.makeXWaves(() => tick.time / 1000.0));
      _initRendererPre();
    });

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
    }catch (e, stackTrace) {
      _errorUI.text = e.toString();
      print(e);
      print(stackTrace);
    }
  }

  Future<AssetManager> _loadAssets() {
    return Future.wait([
      factory_filter2d.init(),
      am.loadAndRegisterAsset('shader_depth_light', 'shaderProgram', 'packages/glf/shaders/depth_light{.vert,.frag}', null, null),
      am.loadAndRegisterAsset('shader_deferred_normals', 'shaderProgram', 'packages/glf/shaders/deferred{.vert,_normals.frag}', null, null),
      am.loadAndRegisterAsset('shader_deferred_vertices', 'shaderProgram', 'packages/glf/shaders/deferred{.vert,_vertices.frag}', null, null),
      am.loadAndRegisterAsset('filter2d_blend_ssao', 'filter2d', 'packages/glf/shaders/filters_2d/blend_ssao.frag', null, null),
      am.loadAndRegisterAsset('texNormalsRandom', 'tex2d', 'normalmap.png', null, null)
    ]).then((l) => am);
  }
  _initRendererPre() {
    _initRendererPreLight();
    _initRendererPreDeferred();
  }
  _initRendererPreLight() {
    var light = new glf.ViewportCamera()
      ..viewWidth = 256
      ..viewHeight = 256
      ..camera.fovRadians = degrees2radians * 55.0
      ..camera.aspectRatio = 1.0
      ..camera.position.setValues(2.0, 2.0, 4.0)
      ..camera.focusPosition.setValues(0.0, 0.0, 0.0)
      ;
    var axis = light.camera.focusPosition - light.camera.position;
    var v2 = new Vector2.zero();
    extractMinMaxProjection(aabbToPoints(renderer.sceneAabb), axis, light.camera.position,v2);
    light.camera.far = math.max(0.1, v2.y);//(_light.camera.focusPosition - _light.camera.position).length * 2;
    light.camera.near = math.max(0.1, v2.x);//math.max(0.5, (_light.camera.focusPosition - _light.camera.position).length - 3.0);

    var lightFbo = new glf.FBO(renderer.gl)..make(width : light.viewWidth, height : light.viewHeight);
    var lightCtx = am['shader_depth_light'];
    var lightR = light.makeRequestRunOn()
      ..ctx = lightCtx
      ..setup = light.setup
      ..before =(ctx) {
        ctx.gl.bindFramebuffer(GL.FRAMEBUFFER, lightFbo.buffer);
        ctx.gl.viewport(light.x, light.y, light.viewWidth, light.viewHeight);
        ctx.gl.clearColor(1.0, 1.0, 1.0, 1.0);
        ctx.gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
        light.injectUniforms(ctx);
      }
    ;

    var r = new glf.RequestRunOn()
      ..autoData = (new Map()
        ..["sLightDepth"] = ((ctx) => glf.injectTexture(ctx, lightFbo.texture, 31, "sLightDepth"))
        ..["lightFar"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('lightFar'), light.camera.far))
        ..["lightNear"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('lightNear'), light.camera.near))
        ..["lightConeAngle"] = ((ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('lightConeAngle'), light.camera.fovRadians * radians2degrees))
        ..["lightProj"] = ((ctx) => glf.injectMatrix4(ctx, light.camera.projectionMatrix, "lightProj"))
        ..["lightView"] = ((ctx) => glf.injectMatrix4(ctx, light.camera.viewMatrix, "lightView"))
        ..["lightRot"] = ((ctx) => glf.injectMatrix3(ctx, light.camera.rotMatrix, "lightRot"))
        ..["lightProjView"] = ((ctx) => glf.injectMatrix4(ctx, light.camera.projectionViewMatrix, "lightProjView"))
        //..["lightVertex"] = ((ctx) => ctx.gl.uniform1fv(ctx.getUniformLocation('lightVertex'), light.camera.position.storage))
      )
      ;
    renderer.add(r);
    renderer.addPrepare(r);
    renderer.addPrepare(lightR);
    renderer.debugView = lightFbo.texture;
  }

  _initRendererPreDeferred() {
    var fboN = _initRendererPreDeferred0(renderer.cameraViewport, am['shader_deferred_normals'], TexNormalsL, TexNormalsN);
    var fboV = _initRendererPreDeferred0(renderer.cameraViewport, am['shader_deferred_vertices'], TexVerticesL, TexVerticesN);
    //renderer.debugView = fboV.texture;
    _initSSAO(fboN.texture, fboV.texture, am['texNormalsRandom']);
  }

  _initRendererPreDeferred0(vp, ctx, texName, texNum) {
    var fbo = new glf.FBO(renderer.gl)..make(width : vp.viewWidth, height : vp.viewHeight, type: GL.FLOAT);
    var pre = new glf.RequestRunOn()
      ..ctx = ctx
      ..before =(ctx) {
        ctx.gl.bindFramebuffer(GL.FRAMEBUFFER, fbo.buffer);
        ctx.gl.viewport(vp.x, vp.y, vp.viewWidth, vp.viewHeight);
        ctx.gl.clearColor(1.0, 1.0, 1.0, 1.0);
        ctx.gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
        vp.injectUniforms(ctx);
      }
    ;

    var r = new glf.RequestRunOn()
      ..autoData = (new Map()
        ..[texName] = ((ctx) => glf.injectTexture(ctx, fbo.texture, texNum, texName))
      )
      ;
    renderer.add(r);
    renderer.addPrepare(r);
    renderer.addPrepare(pre);
    return fbo;
  }

  _initSSAO(GL.Texture texNormals, GL.Texture texVertices, GL.Texture texNormalsRandom) {
    var ssao = new glf.Filter2D.copy(am['filter2d_blend_ssao'])
    ..cfg = (ctx) {
      ctx.gl.uniform2f(ctx.getUniformLocation('_Attenuation'), 1.0, 5.0); // (0,0) -> (2, 10) def (1.0, 5.0)
      ctx.gl.uniform1f(ctx.getUniformLocation('_SamplingRadius'), 15.0); // 0 -> 40
      ctx.gl.uniform1f(ctx.getUniformLocation('_OccluderBias'), 0.05); // 0.0 -> 0.2, def 0.05
      glf.injectTexture(ctx, texNormals, TexNormalsN, TexNormalsL);
      glf.injectTexture(ctx, texVertices, TexVerticesN, TexVerticesL);
      glf.injectTexture(ctx, texNormalsRandom, TexNormalsRandomN, TexNormalsRandomL);
    };
    renderer.filters2d.insert(0, ssao);
  }
}

class Factory_Filter2D {
  static const c3_identity =         const[ 0.0000, 0.0000, 0.0000, 0.0000, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000];
  static const c3_gaussianBlur =     const[ 0.0450, 0.1220, 0.0450, 0.1220, 0.3320, 0.1220, 0.0450, 0.1220, 0.0450];
  static const c3_gaussianBlur2 =    const[ 1.0000, 2.0000, 1.0000, 2.0000, 4.0000, 2.0000, 1.0000, 2.0000, 1.0000];
  static const c3_gaussianBlur3 =    const[ 0.0000, 1.0000, 0.0000, 1.0000, 1.0000, 1.0000, 0.0000, 1.0000, 0.0000];
  static const c3_unsharpen =        const[-1.0000,-1.0000,-1.0000,-1.0000, 9.0000,-1.0000,-1.0000,-1.0000,-1.0000];
  static const c3_sharpness =        const[ 0.0000,-1.0000, 0.0000,-1.0000, 5.0000,-1.0000, 0.0000,-1.0000, 0.0000];
  static const c3_sharpen =          const[-1.0000,-1.0000,-1.0000,-1.0000,16.0000,-1.0000,-1.0000,-1.0000,-1.0000];
  static const c3_edgeDetect =       const[-0.1250,-0.1250,-0.1250,-0.1250, 1.0000,-0.1250,-0.1250,-0.1250,-0.1250];
  static const c3_edgeDetect2 =      const[-1.0000,-1.0000,-1.0000,-1.0000, 8.0000,-1.0000,-1.0000,-1.0000,-1.0000];
  static const c3_edgeDetect3 =      const[-5.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 5.0000];
  static const c3_edgeDetect4 =      const[-1.0000,-1.0000,-1.0000, 0.0000, 0.0000, 0.0000, 1.0000, 1.0000, 1.0000];
  static const c3_edgeDetect5 =      const[-1.0000,-1.0000,-1.0000, 2.0000, 2.0000, 2.0000,-1.0000,-1.0000,-1.0000];
  static const c3_edgeDetect6 =      const[-5.0000,-5.0000,-5.0000,-5.0000,39.0000,-5.0000,-5.0000,-5.0000,-5.0000];
  static const c3_sobelHorizontal =  const[ 1.0000, 2.0000, 1.0000, 0.0000, 0.0000, 0.0000,-1.0000,-2.0000,-1.0000];
  static const c3_sobelVertical =    const[ 1.0000, 0.0000,-1.0000, 2.0000, 0.0000,-2.0000, 1.0000, 0.0000,-1.0000];
  static const c3_previtHorizontal = const[ 1.0000, 1.0000, 1.0000, 0.0000, 0.0000, 0.0000,-1.0000,-1.0000,-1.0000];
  static const c3_previtVertical =   const[ 1.0000, 0.0000,-1.0000, 1.0000, 0.0000,-1.0000, 1.0000, 0.0000,-1.0000];
  static const c3_boxBlur =          const[ 0.1110, 0.1110, 0.1110, 0.1110, 0.1110, 0.1110, 0.1110, 0.1110, 0.1110];
  static const c3_triangleBlur =     const[ 0.0625, 0.1250, 0.0625, 0.1250, 0.2500, 0.1250, 0.0625, 0.1250, 0.0625];
  static const c3_emboss =           const[-2.0000,-1.0000, 0.0000,-1.0000, 1.0000, 1.0000, 0.0000, 1.0000, 2.0000];

  AssetManager am;

  init() {
    return Future.wait([
      am.loadAndRegisterAsset('filter2d_identity', 'filter2d', 'packages/glf/shaders/filters_2d/identity.frag', null, null),
      am.loadAndRegisterAsset('filter2d_brightness', 'filter2d', 'packages/glf/shaders/filters_2d/brightness.frag', null, null),
      am.loadAndRegisterAsset('filter2d_convolution3x3', 'filter2d', 'packages/glf/shaders/filters_2d/convolution3x3.frag', null, null),
      am.loadAndRegisterAsset('filter2d_x_waves', 'filter2d', 'packages/glf/shaders/filters_2d/x_waves.frag', null, null),
    ]).then((l) => am);

    /* An alternative to AssetManager would be to use :
     * HttpRequest.request("packages/glf/shaders/filters_2d/convolution3x3.frag", method: 'GET').then((r) {
     *    var filter2d = new glf.Filter2D(gl, r.responseText);
     * });
     */
  }

  makeIdentity() {
    return am['filter2d_identity'];
  }

  makeBrightness({double brightness : 0.0, contrast : 1.0, gamma : 2.2}) {
    return new glf.Filter2D.copy(am['filter2d_brightness'])
    ..cfg = (ctx) {
      ctx.gl.uniform1f(ctx.getUniformLocation('_Brightness'), brightness);
      ctx.gl.uniform1f(ctx.getUniformLocation('_Contrast'), contrast);
      ctx.gl.uniform1f(ctx.getUniformLocation('_InvGamma'), 1.0/gamma);
    };
  }

  makeConvolution3(List<double> c3_matrix) {
    var kernel = new Float32List.fromList(c3_matrix);
    return new glf.Filter2D.copy(am['filter2d_convolution3x3'])
    ..cfg = (ctx) => ctx.gl.uniform1fv(ctx.getUniformLocation('_Kernel[0]'), kernel)
    ;
  }

  makeXWaves(double offset()) {
    return new glf.Filter2D.copy(am['filter2d_x_waves'])
    ..cfg = (ctx) => ctx.gl.uniform1f(ctx.getUniformLocation('_Offset'), offset())
    ;
  }

}

class Geometry {
  final transforms = new Matrix4.identity();
  final normalMatrix = new Matrix3.zero();
  final _mesh = new glf.Mesh();
  var _md = null;
  var meshNeedUpdate = true;
  var verticesNeedUpdate = false;
  get meshDef => _md;
  set meshDef(glf.MeshDef v) {
    _md = v;
    meshNeedUpdate = true;
  }

  injectAndDraw(glf.ProgramContext ctx) {
    if (meshNeedUpdate && _md != null) {
      _mesh.setData(ctx.gl, _md);
      meshNeedUpdate = false;
      verticesNeedUpdate = false;
    }
    if (verticesNeedUpdate && _md != null) {
      _mesh.vertices.setData(ctx.gl, _md.vertices);
      verticesNeedUpdate = false;
    }
    glf.injectMatrix4(ctx, transforms, glf.SFNAME_MODELMATRIX);
    glf.injectMatrix3(ctx, normalMatrix, glf.SFNAME_NORMALMATRIX);
    _mesh.inject(ctx);
    _mesh.draw(ctx);
  }
}

class Material {
  glf.ProgramContext ctx = null;
  glf.RunOnProgramContext cfg = null;
}

class Obj3D {
  var cameraReqN;
  var upd0;
  var geometry = new Geometry();
  var material;

  apply(renderer, ctx, onUpdate, glf.MeshDef md, showNormals) {
    _remove(renderer, onUpdate);
    _add(renderer, ctx, onUpdate, md, showNormals);
  }

  _remove(renderer, onUpdate) {
    renderer.removeSolid(geometry);
    if (cameraReqN != null) {
      renderer.remove(cameraReqN);
      cameraReqN = null;
    }
    if (upd0 != null) {
      onUpdate.remove(upd0);
      upd0 = null;
    }
  }

  _add(renderer, ctx, onUpdate, md, showNormals) {

    geometry.meshDef = md;

    // keep ref to RequestRunOn to be able to register/unregister (show/hide)
    var tex = glf.createTexture(ctx.gl, new Uint8List.fromList([120, 120, 120, 255]), Uri.parse("_images/dirt.jpg"));
    var texNormal = glf.createTexture(ctx.gl, new Uint8List.fromList([0, 0, 120]), Uri.parse("_images/shaders_offest_normalmap.jpg"));
    var texDissolve0 = glf.createTexture(ctx.gl, new Uint8List.fromList([120, 120, 120, 255]), Uri.parse("_images/burnMap.png"));
    var texDissolve1 = glf.createTexture(ctx.gl, new Uint8List.fromList([120, 120, 120, 255]), Uri.parse("_images/growMap.png"));
    var texDissolve2 = glf.createTexture(ctx.gl, new Uint8List.fromList([120, 120, 120, 255]), Uri.parse("_images/linear.png"));
    var texMatCap0 = glf.createTexture(ctx.gl, new Uint8List.fromList([120, 120, 120, 255]), Uri.parse("_images/matcap/matcap0.png"));
    var texMatCap1 = glf.createTexture(ctx.gl, new Uint8List.fromList([120, 120, 120, 255]), Uri.parse("_images/matcap/matcap1.png"));
    var texMatCap2 = glf.createTexture(ctx.gl, new Uint8List.fromList([120, 120, 120, 255]), Uri.parse("_images/matcap/matcap2.jpg"));

    var material = new Material()
      ..ctx = ctx
      ..cfg = (ctx) {
        // material (fake variation)
        ctx.gl.uniform3f(ctx.getUniformLocation(glf.SFNAME_COLORS), 0.5, 0.5, 0.5);
        glf.injectTexture(ctx, tex, 0);
        glf.injectTexture(ctx, texNormal, 1, '_NormalMap0');
        glf.injectTexture(ctx, texDissolve0, 3, '_DissolveMap0');
        glf.injectTexture(ctx, texDissolve1, 4, '_DissolveMap1');
        glf.injectTexture(ctx, texDissolve2, 5, '_DissolveMap2');
        glf.injectTexture(ctx, texMatCap0, 10, '_MatCap0');
        glf.injectTexture(ctx, texMatCap1, 11, '_MatCap1');
        glf.injectTexture(ctx, texMatCap2, 12, '_MatCap2');
      }
    ;
    renderer.addSolid(geometry, material);

//    cameraRunner.register(cameraReq);

//    lightReq = new glf.RequestRunOn()
//      ..ctx = renderer.lightCtx
//      ..at = geometry.injectAndDraw
//    ;
//    renderer.lightRunner.register(lightReq);

    upd0 = (tick){
      geometry.transforms.setIdentity();
      geometry.transforms.rotateY((tick.time % 5000.0) / 5000.0 * 2 * math.PI);
      glf.makeNormalMatrix(geometry.transforms, geometry.normalMatrix);
    };
    onUpdate.add(upd0);

    if (showNormals) {
      var mdNormal = glf.extractNormals(geometry.meshDef);
      var meshNormal = new glf.Mesh()..setData(ctx.gl, mdNormal);
      var programCtxN = glf.loadProgramContext(ctx.gl, Uri.parse("packages/glf/shaders/default.vert"), Uri.parse("packages/glf/shaders/default.vert"));

      programCtxN.then((ctxN) {
        cameraReqN = new glf.RequestRunOn()
          ..ctx = ctxN
          ..at = (ctx) {
            ctx.gl.uniform3f(ctx.getUniformLocation(glf.SFNAME_COLORS), 0.8, 0.8, 0.8);
            glf.makeNormalMatrix(geometry.transforms, geometry.normalMatrix);
            glf.injectMatrix4(ctx, geometry.transforms, glf.SFNAME_MODELMATRIX);
            glf.injectMatrix3(ctx, geometry.normalMatrix, glf.SFNAME_NORMALMATRIX);
            glf.injectTexture(ctx, tex, 0);
            glf.injectTexture(ctx, texNormal, 1);
            // vertices of the mesh can be modified in update loop, so update the data to GPU
            //mesh2.vertices.setData(ctx.gl, md2.vertices);
            meshNormal.inject(ctx);
            meshNormal.draw(ctx);
          }
        ;
        renderer.add(cameraReqN);
      });
    }

  }
}

class Plane {
  var geometry = new Geometry();

  applyMaterial(renderer, ctx) {
    renderer.removeSolid(geometry);
    _add(renderer, ctx);
  }


  _add(renderer, ctx) {
    geometry.meshDef = glf.makeMeshDef_plane(dx: 3.0, dy: 3.0);
    glf.makeNormalMatrix(geometry.transforms, geometry.normalMatrix);
    var material = new Material()
    ..ctx = ctx
    ..cfg = (ctx) {
      ctx.gl.uniform3f(ctx.getUniformLocation(glf.SFNAME_COLORS), 0.0, 0.5, 0.5);
    }
    ;
    renderer.addSolid(geometry, material);
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
