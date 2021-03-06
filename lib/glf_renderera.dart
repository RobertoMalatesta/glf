library glf_renderera;

import 'package:glf/glf.dart' as glf;
import 'package:vector_math/vector_math.dart';
import 'dart:web_gl' as WebGL;

class Renderer2SolidCache {
  Geometry geometry;
  Material material;
  glf.RequestRunOn cameraReq;
  glf.RequestRunOn geomReq;

  Renderer2SolidCache(this.geometry, this.material) {
    cameraReq = new glf.RequestRunOn()
    ..ctx = material.ctx
    ..at = (ctx) {
      if (material.cfg != null) material.cfg(ctx);
      geometry.injectAndDraw(ctx);
    }
    ;
    geomReq = new glf.RequestRunOn()
    ..atEach = geometry.injectAndDraw
    ;
  }
}

class RendererA {
  final gl;

  final glf.ProgramsRunner _preRunner;
  final glf.ProgramsRunner _cameraRunner;
  final glf.ProgramsRunner _cameraRunnerOpaque; // for opaque
  final glf.ProgramsRunner _cameraRunnerTransparent; // for transparent solid
  glf.Filter2DRunner _post2d;
  final clearColor = new Vector4(1.0, 0.0, 0.0, 1.0);

  List<glf.Filter2D>  get filters2d => _post2d.filters;


  glf.ViewportCamera _cameraViewport;
  final _cameraFbo;
  var _cameraRro = new List<glf.RequestRunOn>();
  get cameraViewport => _cameraViewport;
  set cameraViewport(glf.ViewportCamera v) =>_setViewport(v);

  var _reqs = new Map<Geometry, Renderer2SolidCache>();

  RendererA(gl) : this.gl = gl,
    _preRunner = new glf.ProgramsRunner(gl),
    _cameraRunner = new glf.ProgramsRunner(gl),
    _cameraRunnerOpaque = new glf.ProgramsRunner(gl),
    _cameraRunnerTransparent = new glf.ProgramsRunner(gl),
    _cameraFbo = new glf.FBO(gl)
  //TODO support resize
  {
    _cameraRunnerOpaque.parent = _cameraRunner;
    _cameraRunnerTransparent.parent = _cameraRunner;
  }

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
    if (e.material.pre) addPrepare(e.geomReq);
    if (e.material.transparent) {
      _cameraRunnerTransparent.register(e.cameraReq);
    } else {
      _cameraRunnerOpaque.register(e.cameraReq);
    }
  }

  removeSolid(Geometry geometry) {
    var e = _reqs[geometry];
    if (e != null) {
      removePrepare(e.geomReq);
      if (e.material.transparent) {
        _cameraRunnerTransparent.unregister(e.cameraReq);
      } else {
        _cameraRunnerOpaque.unregister(e.cameraReq);
      }
      _reqs[geometry] = null;
    }
  }

  var _x0, _x1, _x2;
  init() {
    //_x0 = gl.getExtension("OES_standard_derivatives");
    _x1 = gl.getExtension("OES_texture_float");
    //_x2 = gl.getExtension("GL_EXT_draw_buffers");
    _initPostW0();
    _initPre();
  }


  _setViewport(viewport) {
    // remove previous viewport
    _cameraRro.forEach((x) => _cameraRunner.unregister(x));
    _cameraFbo.dispose();

    // set new viewport
    _cameraViewport = viewport;

    if (_cameraViewport == null) return;

    _cameraFbo.make(width : viewport.viewWidth, height : viewport.viewHeight);

    var rro0 = new glf.RequestRunOn()
    ..beforeEach =  viewport.injectUniforms
    ;

    _cameraRro
    ..add(rro0)
    ..add(new glf.RequestRunOn()
      ..setup= (gl) {
        gl.colorMask(true, true, true, true);
        gl.depthFunc(WebGL.LEQUAL);
        //gl.depthFunc(WebGL.LESS); // default value
        gl.enable(WebGL.DEPTH_TEST);
        viewport.setup(gl);
        _cameraRunnerOpaque.register(rro0);
      }
      ..beforeAll = (gl) {
        gl.bindFramebuffer(WebGL.FRAMEBUFFER, _cameraFbo.buffer);
        gl.viewport(viewport.x, viewport.y, viewport.viewWidth, viewport.viewHeight);
        gl.clearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a);
        gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);
      }
    )
    ..add(new glf.RequestRunOn()
      ..setup = (gl) {
        gl.cullFace(WebGL.FRONT);
        gl.frontFace(WebGL.CW);
      }
      ..beforeAll = (gl) {
        // opaque
        //gl.enable(WebGL.CULL_FACE);
        gl.disable(WebGL.BLEND);
        gl.enable(WebGL.DEPTH_TEST);
        _cameraRunnerOpaque.run();
      }
      ..afterAll = (gl) {
      }
      ..teardown = (gl) {
        _cameraRunnerOpaque.unregister(rro0);
      }
    )
    ..add(new glf.RequestRunOn()
      ..setup = (gl) {
        _cameraRunnerTransparent.register(rro0);
        gl.blendFunc(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA);
        gl.blendEquation(WebGL.FUNC_ADD);
      }
      ..beforeAll = (gl) {
        // transparent
        //gl.disable(WebGL.DEPTH_TEST);
        //gl.disable(WebGL.CULL_FACE);
        gl.enable(WebGL.BLEND);
        _cameraRunnerTransparent.run();
        // not optimal but secure
        //gl.enable(WebGL.CULL_FACE);
        gl.disable(WebGL.BLEND);
      }
      ..teardown = (gl) {
        _cameraRunnerTransparent.unregister(rro0);
      }
    )
    ;
    _cameraRro.forEach((x) => _cameraRunner.register(x));
    _post2d.texInit = _cameraFbo.texture;
  }

  _initPre() {
  }


  _initPostW0() {
    var view2d = new glf.ViewportPlan()..fullCanvas(gl.canvas);
    _post2d = new glf.Filter2DRunner(gl, view2d);
  }

  run() {
    _preRunner.run();
    _cameraRunner.run();
    _post2d.run();
  }

}

class Geometry {
  final transforms = new Matrix4.identity();
  final normalMatrix = new Matrix3.zero();
  final mesh = new glf.Mesh();
  var _md = null;
  var meshNeedUpdate = true;
  var verticesNeedUpdate = false;
  var normalMatrixNeedUpdate = true;
  get meshDef => _md;
  set meshDef(glf.MeshDef v) {
    _md = v;
    meshNeedUpdate = true;
  }

  injectAndDraw(glf.ProgramContext ctx) {
    if (meshNeedUpdate && _md != null) {
      mesh.setData(ctx.gl, _md);
      meshNeedUpdate = false;
      verticesNeedUpdate = false;
    }
    if (verticesNeedUpdate && _md != null) {
      mesh.vertices.setData(ctx.gl, _md.vertices);
      verticesNeedUpdate = false;
    }
    if (normalMatrixNeedUpdate) {
      glf.makeNormalMatrix(transforms, normalMatrix);
      normalMatrixNeedUpdate = false;
    }
    glf.injectMatrix4(ctx, transforms, glf.SFNAME_MODELMATRIX);
    glf.injectMatrix3(ctx, normalMatrix, glf.SFNAME_NORMALMATRIX);
    mesh.inject(ctx);
    mesh.draw(ctx);
  }
}

class Material {
  glf.ProgramContext ctx = null;
  glf.RunOnProgramContext cfg = null;
  bool transparent = false;
  bool pre = true;
}