// 404 page: a blenny peeking out of the hero's cave.
import { createSpriteBlenny } from './sprite-blenny.js';

const fish = createSpriteBlenny({ base: '/', sizes: '200px' });
document.getElementById('hole').append(fish.el);
addEventListener('pointermove', (e) => fish.lookAt(e.clientX, e.clientY));
