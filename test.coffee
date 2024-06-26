using namespace Forge3D = imp('./main').Weld().With('controls/OrbitControls'), ->
  using Scene, ->
    new OrbitControls @camera, document

    box = new Mesh(
      new BoxGeometry 1, 1, 1
      new MeshStandardMaterial 0x09D0D0
    )
    @scene.add box

    @scene.add new AmbientLight 0xd1d1d1, 1
    @scene.addAt [100, 50, 50], new DirectionalLight 0xffffff, 1

    @on 'animate:render', (time) ->
      box.rotation.x = time * 0.0005;
      box.rotation.y = time * 0.001;

    @animate()