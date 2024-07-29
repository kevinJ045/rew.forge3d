import * as Three from 'three';
import { init, addThreeHelpers } from '3d-core-raub';

###*
 * @patam options {TInitOpts}
*###
createDocument = (options) ->
  ctx = init(options);
  addThreeHelpers(Three, ctx.gl) if options.three isnt false
  return ctx


createScene = (ctx3d, options, useListener) ->
  target = emitter();
  ctx = if useListener then {
    ...target
  } else {
    listener: target
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
    target.emit('animate:beforeFrameRender', time);
    ctx3d.requestAnimationFrame(ctx.animate);
    target.emit('animate:render', time);
    renderer.render(ctx.scene, ctx.camera);
    target.emit('animate:afterFrameRender', time);

  addSceneUtils(ctx3d, ctx);

  return ctx

customMesh = (ctx, scene, mesh) ->
  mesh.toScene = () ->
    scene.scene.add(this)
    return this
  return mesh

addSceneUtils = (ctx, scene) ->

  MESH_TYPES =
    box: ctx.BoxGeometry

  scene.mat = (options) ->
    if typeis(options, num) or typeis(options, str) then options = { color: options }
    return new ctx.MeshStandardMaterial options

  scene.mesh = (type, options) ->

    if type of MESH_TYPES then type = MESH_TYPES[type]
    return customMesh ctx, scene, new ctx.Mesh(new type(...options.size), options.material)

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
  context3d.Forge3D = context3d;
  context3d.__pathname = pjoin dirname(module.filepath), './node_modules/three'

  addUtils(context3d, options);
  context3d.Scene = Usage::create('scene3d', ((cb) -> cb.call(createScene(context3d, options, true))), false)
  context3d.Scene.prototype = {};
  context3d.Scene::create = () -> createScene(context3d, options)

  context3d.With = (...modules) ->
    for modpath in modules
      if typeof modpath is 'string'
        module = require pjoin("three/examples/jsm", (if modpath.endsWith '.js' then modpath else "#{modpath}.js")), true
        context3d.modules.push modpath
        mod = {...module}
        for i of mod
          if i is 'default' then i = basename modpath
          context3d[i] = mod[i]
      else if typeof modpath == 'object'
        for i of modpath
          context3d[i] = modpath[i]
    context3d

  context3d.Compose = (cb) ->
    if typeof cb == "function"
      namespace.group [context3d, cb], Use: () -> using namespace this
    else
      (cb2) -> Usage::group cb, cb2

  if Array.isArray options.with
    context3d.With options.with...
  context3d

Forge3D = Usage::create 'forge3d', (options, cb) ->
  if Array.isArray options
    options = { with: options, isGles3: true }
  if typeof options is "function" and not cb
    cb = options
    options = { isGles3: true }
  cb createForge3d options

Forge3D.Weld = (options = { isGles3: true }) -> createForge3d options

module.exports = Forge3D