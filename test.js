import * as three from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { init, addThreeHelpers } from '3d-core-raub';

const { doc, gl, requestAnimationFrame } = init({ isGles3: true });
addThreeHelpers(three, gl);

/**
 * @param option {options}
 */
const renderer = new three.WebGLRenderer();
renderer.setPixelRatio( doc.devicePixelRatio );
renderer.setSize( doc.innerWidth, doc.innerHeight );

const camera = new three.PerspectiveCamera(70, doc.innerWidth / doc.innerHeight, 1, 1000);
camera.position.z = 2;
const scene = new three.Scene();

const constrols = new OrbitControls(camera, doc)

const geometry = new three.BoxGeometry();
const material = new three.MeshStandardMaterial({ color: 0xFACE8D });
const mesh = new three.Mesh( geometry, material );
scene.add(mesh);

const light = new three.AmbientLight(0xffffff, 1);
scene.add(light);

// scene.add(new GridHelper)

const dlight = new three.DirectionalLight(0xffffff, 1);
dlight.position.x = 100;
dlight.position.y = 50;
dlight.position.z = 50;
scene.add(dlight);

doc.addEventListener('resize', () => {
	camera.aspect = doc.innerWidth / doc.innerHeight;
	camera.updateProjectionMatrix();
	renderer.setSize(doc.innerWidth, doc.innerHeight);
});

const animate = () => {
	requestAnimationFrame(animate);
	const time = Date.now();
	mesh.rotation.x = time * 0.0005;
	mesh.rotation.y = time * 0.001;
	
	renderer.render(scene, camera);
};

animate();