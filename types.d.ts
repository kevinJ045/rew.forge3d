
declare module "rew.forge3d" {
	const Weld: () => {
		Mesh: new () => {},
		Geometry: new () => {},
		BoxGeometry: Geometry,
		Scene: new () => {
			scene: {
				add: () => void
			}, camera: {}, animate: () => void 
		}
	}
}
