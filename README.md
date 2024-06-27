# Forge3D
[Forge3D](https://github.com/kevinJ045/rew.forge3d) is a library to make 3D desktop apps within `rew`. Forge3D is built on top of [the node-3d project](https://github.com/node-3d/node-3d).

## Installing
You can install Forge3d from `github:kevinJ045/rew.forge3d` with either [pimmy](https://github.com/kevinJ045/rew.pimmy) or `rew`.
```bash
# pimmy
pimmy -Sa rew.forge3d
# rew
rew install github:kevinJ045/rew.forge3d
# rewpkgs
rew install @rewpkgs/rew.forge3d
```

## Basic Usage
```coffee
import * as Forge3D from "rew.forge3d";
{ Mesh, BoxGeometry, Scene } = Forge3D.Weld()

{ scene, camera, animate } = Scene::create()

box = new Mesh(new BoxGeometry)

scene.add box
animate()
```

## Advanced Usage
```coffee
using imp('rew.forge3d'), (Forge3D) ->
  using namespace Forge3D, ->
    using Scene, ->
      box = new Mesh(new BoxGeometry)
      @scene.add box

      @animate()
```

## Nixos Usage
You will have to copy `flake.nix` and `.envrc` to the root of your project and run `direnv allow`.

## More information
For more information, read the [Docs for Forge3D](https://kevinj045.github.io/rew-docs/packages/forge3d.html)