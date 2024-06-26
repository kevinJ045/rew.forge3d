import * as Three from 'three';
import { init, addThreeHelpers } from '3d-core-raub';

###*
 * @patam options {TInitOpts}
*###
createDocument = (options) ->
  ctx = init(options);
  addThreeHelpers(Three, ctx.gl);
  return ctx


createScene = (ctx3d, options) ->
  ctx = {
    ...emitter()
  };
  renderer = new Three.WebGLRenderer();
  renderer.setPixelRatio( ctx3d.doc.devicePixelRatio );
  renderer.setSize( ctx3d.doc.innerWidth, ctx3d.doc.innerHeight );

  ctx.renderer = renderer;

  ctx.camera = new Three.PerspectiveCamera(options.camera?.fov or 70, ctx3d.doc.innerWidth / ctx3d.doc.innerHeight, options.camera?.near or 1, options.camera?.far or 1000);
  ctx.camera.position.z = 2;
  
  ctx.scene = new Three.Scene();

  ctx.scene.addAt = ([x, y, z], mesh) ->
    ctx.scene.add mesh
    mesh.position.x = x
    mesh.position.y = y
    mesh.position.z = z

  ctx.animate = () ->
    time = Date.now();
    ctx.emit('animate:beforeFrameRender', time);
    ctx3d.requestAnimationFrame(ctx.animate);
    ctx.emit('animate:render', time);
    renderer.render(ctx.scene, ctx.camera);
    ctx.emit('animate:afterFrameRender', time);

  return ctx


addUtils = (ctx) -> null

# import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js' assert esm: true;

###*
 * @type {(options: TInitOpts) => void}
*###
createForge3d = (options = { isGles3: true }) ->
  documentContext = createDocument options
  documentContext.canvas.getRootNode = () -> documentContext.document
  context3d = {
    ...Three,
    ...documentContext,
    modules: []
  }

  context3d.Forge3D = {};

  addUtils(context3d, options);
  context3d.Scene = Usage::create('scene3d', ((cb) -> cb.call(createScene(context3d, options))), false)

  context3d.With = (...modules) ->
    for modpath in modules
      module = require pjoin("three/examples/jsm", (if modpath.endsWith '.js' then modpath else "#{modpath}.js")), true
      context3d.modules.push modpath
      mod = {...module}
      for i of mod
        if i is 'default' then i = basename modpath
        context3d[i] = mod[i]
    context3d
  context3d

Forge3D = Usage::create 'forge3d', (options, cb) ->
  if typeof options is "function" and not cb
    cb = options
    options = { isGles3: true }
  cb createForge3d options

Forge3D.Weld = (options = { isGles3: true }) -> createForge3d options

module.exports = Forge3D