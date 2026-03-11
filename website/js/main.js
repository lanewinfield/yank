import * as THREE from 'three';
import { STLLoader } from 'three/addons/loaders/STLLoader.js';

// =============================================
// Gyroscope control
// =============================================
let gyroEnabled = false;
let gyroGamma = 0; // left/right tilt
let gyroBeta = 0;  // front/back tilt

const purposefulSpan = document.querySelector('.hero-spacer .tagline .highlight');
const isMobileDevice = window.innerWidth <= 768;

// Only enable gyro click on mobile
if (purposefulSpan && isMobileDevice) {
    purposefulSpan.style.cursor = 'pointer';

    purposefulSpan.addEventListener('click', async () => {
        if (gyroEnabled) return;

        // iOS 13+ requires permission request
        if (typeof DeviceOrientationEvent !== 'undefined' &&
            typeof DeviceOrientationEvent.requestPermission === 'function') {
            try {
                const permission = await DeviceOrientationEvent.requestPermission();
                if (permission === 'granted') {
                    enableGyro();
                }
            } catch (e) {
                console.error('Gyro permission error:', e);
            }
        } else {
            // Android or older iOS - no permission needed
            enableGyro();
        }
    });
}

function enableGyro() {
    gyroEnabled = true;
    purposefulSpan.style.textDecoration = 'none';
    purposefulSpan.style.background = 'linear-gradient(90deg, #FE3231, #ff6b6b)';
    purposefulSpan.style.webkitBackgroundClip = 'text';
    purposefulSpan.style.webkitTextFillColor = 'transparent';
    purposefulSpan.style.backgroundClip = 'text';

    window.addEventListener('deviceorientation', (e) => {
        // gamma: left/right tilt (-90 to 90)
        // beta: front/back tilt (-180 to 180)
        // Store raw degrees for gravity calculation
        gyroGamma = e.gamma || 0;
        gyroBeta = e.beta || 0;
    }, { passive: true });
}

// =============================================
// Background blur on scroll + logo transition
// =============================================
const desktopLayer = document.getElementById('desktop-layer');
const mobileLogo = document.querySelector('.mobile-logo');
const heroTagline = document.querySelector('.hero-spacer .tagline');
const scrollCaret = document.querySelector('.scroll-caret');

// Show scroll caret after 3 seconds or after first pull
let caretShown = false;
function showScrollCaret() {
    if (!caretShown && scrollCaret) {
        caretShown = true;
        scrollCaret.classList.add('visible');
    }
}

// Hide caret when user starts scrolling
function hideScrollCaret() {
    if (scrollCaret) {
        scrollCaret.classList.remove('visible');
    }
}

// Click caret to scroll down
if (scrollCaret) {
    scrollCaret.addEventListener('click', () => {
        window.scrollBy({ top: window.innerHeight * 0.8, behavior: 'smooth' });
    });
}

// Auto-show after 5 seconds
setTimeout(showScrollCaret, 5000);

// Calculate when tagline meets logo
let logoScrollThreshold = 0;

function calculateLogoThreshold() {
    const viewportHeight = window.innerHeight;
    const logoHeight = mobileLogo.offsetHeight || 60;
    const taglineHeight = heroTagline.offsetHeight || 50;
    // Tagline starts at bottom of spacer (100vh - 30px padding)
    // Logo bottom is at 30px + logoHeight
    // They meet when: viewportHeight - 30 - taglineHeight - scrollY = 30 + logoHeight
    // scrollY = viewportHeight - 60 - taglineHeight - logoHeight
    logoScrollThreshold = viewportHeight - 60 - taglineHeight - logoHeight;
}

calculateLogoThreshold();
window.addEventListener('resize', calculateLogoThreshold);

// Use requestAnimationFrame to batch scroll updates and prevent jitter
let scrollTicking = false;
let lastScrollY = 0;

function applyScrollEffects(scrollY) {
    // Hide scroll caret once user starts scrolling
    if (scrollY > 10) {
        hideScrollCaret();
    }

    // Gradual blur and darken based on scroll (0 to max over 300px)
    const blurMax = 6;
    const brightnessMin = 0.4;
    const chainBrightnessMin = 0.3; // Chain/handle darken amount
    const blurRange = 300;

    const progress = Math.min(scrollY / blurRange, 1);
    const blur = progress * blurMax;
    const brightness = 1 - (progress * (1 - brightnessMin));
    const chainBrightness = 1 - (progress * (1 - chainBrightnessMin));

    desktopLayer.style.filter = `blur(${blur}px) brightness(${brightness})`;

    // Darken body background at same rate as desktop layer (using brightness)
    const r = Math.round(59 * brightness);
    const g = Math.round(90 * brightness);
    const b = Math.round(146 * brightness);
    document.body.style.backgroundColor = `rgb(${r}, ${g}, ${b})`;

    // Store for use in animation loop
    window.chainDarkenFactor = chainBrightness;

    // Logo: fixed until tagline catches up, then moves up via transform (smoother than top)
    if (scrollY >= logoScrollThreshold) {
        const offset = scrollY - logoScrollThreshold;
        mobileLogo.style.transform = `translate3d(0, ${-offset}px, 0)`;
    } else {
        mobileLogo.style.transform = 'translate3d(0, 0, 0)';
    }
}

// Apply on page load in case the browser restores scroll position
applyScrollEffects(window.scrollY);

window.addEventListener('scroll', () => {
    lastScrollY = window.scrollY;

    if (!scrollTicking) {
        requestAnimationFrame(() => {
            applyScrollEffects(lastScrollY);
            scrollTicking = false;
        });
        scrollTicking = true;
    }
}, { passive: true });

// =============================================
// Fake Window Spawning System (disabled initially, starts after scroll)
// =============================================
const windowsContainer = document.getElementById('windows-container');
const fakeWindows = [];
const MAX_WINDOWS = 10;
let spawnTimer = null;
let spawningPaused = true; // Start paused
let windowZIndex = 10;

const firstNames = ['Alex', 'Jordan', 'Sam', 'Taylor', 'Morgan', 'Casey', 'Drew', 'Jamie', 'Pat', 'Riley', 'Quinn', 'Avery'];
const slackChannels = ['# general', '# engineering', '# design', '# random', '# product', '# standups', '# deploys', '# social'];
const slackNames = ['Sarah Chen', 'Mike R.', 'Priya S.', 'Tom B.', 'Lisa M.', 'Jake W.'];
const avatarColors = ['#e74c3c', '#3498db', '#2ecc71', '#9b59b6', '#f39c12', '#1abc9c', '#e67e22', '#8e44ad', '#2c3e50', '#d35400'];

const portraits = [
    'assets/images/portraits/IMAGE 2026-02-05 15:21:30.webp',
    'assets/images/portraits/IMAGE 2026-02-05 15:21:33.webp',
    'assets/images/portraits/IMAGE 2026-02-05 15:23:24.webp',
    'assets/images/portraits/IMAGE 2026-02-05 15:23:25.webp',
    'assets/images/portraits/IMAGE 2026-02-05 15:25:01.webp',
    'assets/images/portraits/IMAGE 2026-02-05 15:25:02.webp',
    'assets/images/portraits/IMAGE 2026-02-05 15:26:18.webp',
    'assets/images/portraits/IMAGE 2026-02-05 15:26:20.webp',
    'assets/images/portraits/IMAGE 2026-02-05 15:35:30.webp',
    'assets/images/portraits/IMAGE 2026-02-05 15:35:32.webp',
    'assets/images/portraits/IMAGE 2026-02-05 15:35:34.webp',
    'assets/images/portraits/IMAGE 2026-02-05 15:35:35.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:04:18.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:04:20.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:04:21.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:04:22.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:04:24.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:07:37.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:09:19.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:14:52.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:14:53.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:15:00.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:16:54.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:16:55.webp',
    'assets/images/portraits/IMAGE 2026-02-06 11:16:56.webp'
];

const talkerPortraits = [
    'assets/images/portraits/talker1.webp',
    'assets/images/portraits/talker2.webp',
    'assets/images/portraits/talker3.webp',
    'assets/images/portraits/talker4.webp',
    'assets/images/portraits/talker5.webp',
    'assets/images/portraits/talker6.webp',
    'assets/images/portraits/talker7.webp',
    'assets/images/portraits/talker8.webp'
];

function getPortraitsForWindow(count) {
    const portraitRatio = 0.5 + Math.random() * 0.4;
    const numRegularPortraits = Math.max(1, Math.floor(count * portraitRatio));
    const talker = pickRandom(talkerPortraits);
    const shuffledPortraits = [...portraits].sort(() => Math.random() - 0.5);
    const regularPortraits = shuffledPortraits.slice(0, numRegularPortraits);
    const allPortraits = [talker, ...regularPortraits];
    const numPortraits = allPortraits.length;
    const slots = Array.from({length: count}, (_, i) => i);
    const shuffledSlots = slots.sort(() => Math.random() - 0.5);
    const portraitSlots = new Set(shuffledSlots.slice(0, Math.min(numPortraits, count)));
    const selectedPortraits = allPortraits.sort(() => Math.random() - 0.5);
    return { selectedPortraits, portraitSlots };
}

function randomBetween(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

function pickRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

function getInitials(name) {
    return name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
}

function trafficLightsHTML() {
    return `<div class="traffic-lights">
        <div class="traffic-light tl-red"></div>
        <div class="traffic-light tl-yellow"></div>
        <div class="traffic-light tl-green"></div>
    </div>`;
}

function createZoomWindow(w, h) {
    const participantCount = randomBetween(4, 6);
    const cols = participantCount <= 4 ? 2 : 3;
    const rows = Math.ceil(participantCount / cols);
    const { selectedPortraits, portraitSlots } = getPortraitsForWindow(participantCount);
    let portraitIndex = 0;
    let participantsHTML = '';
    for (let i = 0; i < participantCount; i++) {
        if (portraitSlots.has(i)) {
            const portrait = selectedPortraits[portraitIndex++];
            participantsHTML += `<div class="zoom-participant" style="background: url('${portrait}') center center / cover no-repeat;"></div>`;
        } else {
            const name = pickRandom(firstNames);
            const color = pickRandom(avatarColors);
            participantsHTML += `<div class="zoom-participant" style="background:${color}22;">${getInitials(name)}</div>`;
        }
    }
    return `<div class="zoom-titlebar">${trafficLightsHTML()}<span class="zoom-title">Zoom Meeting</span></div>
    <div class="zoom-body" style="grid-template-columns: repeat(${cols}, 1fr); grid-template-rows: repeat(${rows}, 1fr);">${participantsHTML}</div>
    <div class="me-video"></div>
    <div class="zoom-controls"><div class="zoom-controls-left"><div class="zoom-btn">🎤</div><div class="zoom-btn">📹</div></div><div class="zoom-btn end">✕</div></div>`;
}

function createMeetWindow(w, h) {
    const participantCount = randomBetween(3, 6);
    const cols = participantCount <= 3 ? Math.min(participantCount, 3) : 3;
    const rows = Math.ceil(participantCount / cols);
    const { selectedPortraits, portraitSlots } = getPortraitsForWindow(participantCount);
    let portraitIndex = 0;
    let participantsHTML = '';
    for (let i = 0; i < participantCount; i++) {
        if (portraitSlots.has(i)) {
            const portrait = selectedPortraits[portraitIndex++];
            participantsHTML += `<div class="meet-participant" style="background: url('${portrait}') center center / cover no-repeat;"></div>`;
        } else {
            const name = pickRandom(firstNames);
            const color = pickRandom(avatarColors);
            participantsHTML += `<div class="meet-participant"><div class="meet-avatar" style="background:${color};">${getInitials(name)}</div></div>`;
        }
    }
    return `<div class="chrome-tab-bar"><div class="chrome-tab"><div class="tab-dot"></div><span>Meet - abc-defg-hij</span></div></div>
    <div class="chrome-toolbar"><div class="nav-btn"></div><div class="nav-btn"></div><div class="url-bar">&#128274; meet.google.com/abc-defg-hij</div></div>
    <div class="meet-body" style="grid-template-columns: repeat(${cols}, 1fr); grid-template-rows: repeat(${rows}, 1fr);">${participantsHTML}</div>
    <div class="me-video"></div>`;
}

function createSlackWindow(w, h) {
    const participantCount = randomBetween(2, 5);
    const cols = participantCount <= 2 ? participantCount : (participantCount <= 4 ? 2 : 3);
    const rows = Math.ceil(participantCount / cols);
    const channelName = pickRandom(slackChannels).replace('# ', '#');
    const { selectedPortraits, portraitSlots } = getPortraitsForWindow(participantCount);
    let portraitIndex = 0;
    let participantsHTML = '';
    for (let i = 0; i < participantCount; i++) {
        if (portraitSlots.has(i)) {
            const portrait = selectedPortraits[portraitIndex++];
            participantsHTML += `<div class="huddle-participant" style="background: url('${portrait}') center center / cover no-repeat;"></div>`;
        } else {
            const name = pickRandom(slackNames);
            const color = pickRandom(avatarColors);
            participantsHTML += `<div class="huddle-participant"><div class="huddle-avatar" style="background:${color};">${getInitials(name)}</div></div>`;
        }
    }
    return `<div class="slack-titlebar">${trafficLightsHTML()}<div class="huddle-title"><div class="huddle-icon">&#9741;</div><span>${channelName}</span></div><div></div></div>
    <div class="huddle-body" style="grid-template-columns: repeat(${cols}, 1fr); grid-template-rows: repeat(${rows}, 1fr);">${participantsHTML}</div>
    <div class="me-video"></div>
    <div class="huddle-controls"><div class="huddle-btn"></div><div class="huddle-btn"></div><div class="huddle-btn end"></div></div>`;
}

let lastWindowType = null;

function getWindowPositions() {
    return fakeWindows.map(win => ({
        x: parseInt(win.style.left) + parseInt(win.style.width) / 2,
        y: parseInt(win.style.top) + parseInt(win.style.height) / 2
    }));
}

function findLeastCrowdedPosition(w, h, minX, maxX, minY, maxY) {
    const existingPositions = getWindowPositions();
    if (existingPositions.length === 0) {
        return {
            x: randomBetween(minX, maxX),
            y: randomBetween(minY, maxY)
        };
    }

    // Try several random positions and pick the one furthest from existing windows
    let bestPos = null;
    let bestMinDist = -1;

    for (let i = 0; i < 10; i++) {
        const testX = randomBetween(minX, maxX);
        const testY = randomBetween(minY, maxY);
        const centerX = testX + w / 2;
        const centerY = testY + h / 2;

        // Find minimum distance to any existing window
        let minDist = Infinity;
        for (const pos of existingPositions) {
            const dist = Math.sqrt((centerX - pos.x) ** 2 + (centerY - pos.y) ** 2);
            if (dist < minDist) minDist = dist;
        }

        if (minDist > bestMinDist) {
            bestMinDist = minDist;
            bestPos = { x: testX, y: testY };
        }
    }

    return bestPos;
}

function spawnWindow() {
    if (spawningPaused) return;
    if (fakeWindows.length >= MAX_WINDOWS) return;

    const types = ['zoom', 'meet', 'slack'];
    const availableTypes = types.filter(t => t !== lastWindowType);
    const type = pickRandom(availableTypes);
    lastWindowType = type;
    const w = randomBetween(320, 560);
    const h = randomBetween(220, 420);

    const el = document.createElement('div');
    el.className = `fake-window ${type}-window`;
    el.style.width = w + 'px';
    el.style.height = h + 'px';

    const minX = isMobile ? -w * 0.3 : -w * 0.4;
    const maxX = window.innerWidth - w * 0.6;
    const minY = 20;
    const maxY = Math.max(20, window.innerHeight - h - 20);

    const pos = findLeastCrowdedPosition(w, h, minX, Math.max(minX + 100, maxX), minY, maxY);
    el.style.left = pos.x + 'px';
    el.style.top = pos.y + 'px';
    el.style.zIndex = windowZIndex++;

    let innerHTML = '';
    switch (type) {
        case 'zoom': innerHTML = createZoomWindow(w, h); break;
        case 'meet': innerHTML = createMeetWindow(w, h); break;
        case 'slack': innerHTML = createSlackWindow(w, h); break;
    }
    el.innerHTML = innerHTML;

    windowsContainer.appendChild(el);
    fakeWindows.push(el);
    scheduleNextSpawn();
}

function scheduleNextSpawn() {
    if (spawnTimer) clearTimeout(spawnTimer);
    const delay = randomBetween(3000, 5000);
    spawnTimer = setTimeout(spawnWindow, delay);
}

function closeAllWindows() {
    spawningPaused = true;
    if (spawnTimer) clearTimeout(spawnTimer);

    const windowsCopy = [...fakeWindows];
    windowsCopy.forEach((win, i) => {
        setTimeout(() => {
            if (win.parentNode) win.parentNode.removeChild(win);
            const idx = fakeWindows.indexOf(win);
            if (idx > -1) fakeWindows.splice(idx, 1);
        }, i * 30);
    });

    const totalCloseTime = windowsCopy.length * 30;
    setTimeout(() => {
        spawningPaused = false;
        windowZIndex = 10;
        if (!isDragging) {
            spawnWindow();
        }
    }, totalCloseTime + 1000);
}

// Start spawning immediately on page load
spawningPaused = false;
setTimeout(spawnWindow, 1000);

// =============================================
// Three.js Scene - Centered, 1.5x bigger handle
// =============================================
const container = document.getElementById('canvas-container');
const scene = new THREE.Scene();

// Use visualViewport on mobile for accurate height (accounts for URL bar)
const isMobileViewport = window.innerWidth <= 768;

function getViewportSize() {
    const vv = window.visualViewport;
    if (isMobileViewport && vv) {
        return { width: vv.width, height: vv.height };
    }
    return { width: window.innerWidth, height: window.innerHeight };
}

const viewportSize = getViewportSize();
const camera = new THREE.PerspectiveCamera(45, viewportSize.width / viewportSize.height, 0.1, 1000);
camera.position.set(0, 0, 15);

const renderer = new THREE.WebGLRenderer({ antialias: false, alpha: true });
renderer.setSize(viewportSize.width, viewportSize.height);
renderer.setPixelRatio(1);
renderer.shadowMap.enabled = false;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.2;
renderer.outputColorSpace = THREE.DisplayP3ColorSpace;
container.appendChild(renderer.domElement);

// Environment map for reflections
const pmremGenerator = new THREE.PMREMGenerator(renderer);
const envScene = new THREE.Scene();
envScene.background = new THREE.Color(0x333344);
const envLight1 = new THREE.PointLight(0xffffff, 50);
envLight1.position.set(5, 5, 5);
envScene.add(envLight1);
const envLight2 = new THREE.PointLight(0x8888ff, 30);
envLight2.position.set(-5, 3, -3);
envScene.add(envLight2);
const envTexture = pmremGenerator.fromScene(envScene).texture;
scene.environment = envTexture;
pmremGenerator.dispose();

// Lighting
const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
scene.add(ambientLight);

const mainLight = new THREE.DirectionalLight(0xffffff, 1.2);
mainLight.position.set(3, -3, 8);
scene.add(mainLight);

const fillLight = new THREE.DirectionalLight(0x4488ff, 0.4);
fillLight.position.set(-5, 5, -5);
scene.add(fillLight);

const rimLight = new THREE.DirectionalLight(0xff4444, 0.3);
rimLight.position.set(0, -5, 5);
scene.add(rimLight);

// Check if mobile
const isMobile = window.innerWidth <= 768;

// Debug mode via URL param
const urlParams = new URLSearchParams(window.location.search);
const debugMode = urlParams.get('debug') === 'true';

// Switch positioning
const switchScale = isMobile ? 1.125 : 1.1;
let switchAnchorY = isMobile ? 8.7 : 8.4;

// Debug panel for height positioning
if (debugMode) {
    const debugPanel = document.createElement('div');
    debugPanel.style.cssText = `
        position: fixed;
        top: 10px;
        right: 10px;
        background: rgba(0,0,0,0.8);
        color: white;
        padding: 15px;
        border-radius: 8px;
        font-family: monospace;
        font-size: 12px;
        z-index: 9999;
        min-width: 200px;
    `;

    debugPanel.innerHTML = `
        <div style="margin-bottom: 10px; font-weight: bold;">Debug Panel</div>
        <label>
            Anchor Y: <span id="anchorYValue">${switchAnchorY}</span>
            <br>
            <input type="range" id="anchorYSlider" min="5" max="12" step="0.1" value="${switchAnchorY}" style="width: 100%;">
        </label>
    `;

    document.body.appendChild(debugPanel);

    const anchorYSlider = document.getElementById('anchorYSlider');
    const anchorYValueDisplay = document.getElementById('anchorYValue');

    anchorYSlider.addEventListener('input', (e) => {
        const newY = parseFloat(e.target.value);
        switchAnchorY = newY;
        anchorYValueDisplay.textContent = newY.toFixed(1);

        // Update anchor position and reset chain
        window.updateAnchorY && window.updateAnchorY(newY);
    });
}

// Chain configuration
const ballCount = 32;
const sizeMultiplier = switchScale;
const ballRadius = 0.065 * sizeMultiplier;
const segmentLength = 0.17 * sizeMultiplier;
const connectorRadius = 0.0125 * sizeMultiplier;

// Materials
const chainMaterial = new THREE.MeshPhysicalMaterial({
    color: 0xe6e6e6,
    metalness: 0.85,
    roughness: 0.4,
    reflectivity: 1.0,
    clearcoat: 1.0,
    clearcoatRoughness: 0.05
});

// HDR red
const handleMaterial = new THREE.MeshStandardMaterial({
    color: new THREE.Color().setRGB(1.2, 0.15, 0.15, THREE.DisplayP3ColorSpace),
    metalness: 0.2,
    roughness: 0.35,
    emissive: new THREE.Color().setRGB(1.0, 0.0, 0.0, THREE.DisplayP3ColorSpace),
    emissiveIntensity: 0.8
});

// Store original colors for scroll darkening
const chainOriginalColor = chainMaterial.color.clone();
const handleOriginalColor = handleMaterial.color.clone();
const handleOriginalEmissive = handleMaterial.emissive.clone();
window.chainDarkenFactor = 1;

// Pulsing outer glow effect if handle not pulled after 5 seconds
let handleGlowActive = false;
let handleInteracted = false;

// Create a point light for the outer glow effect
const handleGlowLight = new THREE.PointLight(0xff3333, 0, 8);
handleGlowLight.visible = false;
scene.add(handleGlowLight);

function startHandleGlow() {
    if (!handleInteracted) {
        handleGlowActive = true;
        handleGlowLight.visible = true;
    }
}

function stopHandleGlow() {
    handleInteracted = true;
    handleGlowActive = false;
    handleGlowLight.visible = false;
    handleGlowLight.intensity = 0;
}

// Glow disabled for now
// setTimeout(startHandleGlow, 5000);

// Physics particles
const particles = [];
const prevPositions = [];

// Position - centered on both mobile and desktop
let anchorX = 0;
let anchorY = switchAnchorY;

for (let i = 0; i <= ballCount; i++) {
    particles.push(new THREE.Vector3(0, anchorY - i * segmentLength, 0));
    prevPositions.push(new THREE.Vector3(0, anchorY - i * segmentLength, 0));
}

// Function to update anchor Y and reset chain (for debug panel)
window.updateAnchorY = function(newY) {
    anchorY = newY;
    for (let i = 0; i <= ballCount; i++) {
        particles[i].set(0, anchorY - i * segmentLength, 0);
        prevPositions[i].set(0, anchorY - i * segmentLength, 0);
    }
};

// Chain meshes
const chainBalls = [];
const chainConnectors = [];

for (let i = 0; i < ballCount; i++) {
    const ballGeometry = new THREE.SphereGeometry(ballRadius, 16, 16);
    const ball = new THREE.Mesh(ballGeometry, chainMaterial);
    ball.visible = false;
    chainBalls.push(ball);
    scene.add(ball);
}

const connectorGeometry = new THREE.CylinderGeometry(connectorRadius, connectorRadius, 1, 8);
for (let i = 0; i < ballCount - 1; i++) {
    const connector = new THREE.Mesh(connectorGeometry, chainMaterial);
    connector.visible = false;
    chainConnectors.push(connector);
    scene.add(connector);
}

// Handle - 1.5x bigger
let handle = null;
let handleLoaded = false;

const loader = new STLLoader();
loader.load(
    'assets/models/handle.stl',
    (geometry) => {
        geometry.computeVertexNormals();
        geometry.center();

        const bbox = new THREE.Box3().setFromBufferAttribute(geometry.attributes.position);
        const size = new THREE.Vector3();
        bbox.getSize(size);
        const maxDim = Math.max(size.x, size.y, size.z);
        const scale = (3.5 * sizeMultiplier) / maxDim;
        geometry.scale(scale, scale, scale);

        geometry.rotateY(Math.PI / 2);

        geometry.computeBoundingBox();
        const topY = geometry.boundingBox.max.y;
        geometry.translate(0, -topY, 0);

        handle = new THREE.Mesh(geometry, handleMaterial);
        handle.visible = false;
        scene.add(handle);
        handleLoaded = true;

        startDropAnimation();
    },
    undefined,
    (error) => {
        console.error('Error loading STL:', error);
        const fallbackGeometry = new THREE.CylinderGeometry(0.6 * sizeMultiplier, 0.5 * sizeMultiplier, 1.5 * sizeMultiplier, 32);
        handle = new THREE.Mesh(fallbackGeometry, handleMaterial);
        handle.visible = false;
        scene.add(handle);
        handleLoaded = true;
        startDropAnimation();
    }
);

// Drop animation
let isDropping = true;
let dropStartTime = 0;
let physicsFrozen = true;

function startDropAnimation() {
    isDropping = true;
    physicsFrozen = true;
    dropStartTime = Date.now();

    const side = Math.random() > 0.5 ? 1 : -1;
    const angle = side * (Math.PI / 2 - dropAngle); // dropAngle=0 is horizontal, higher = more vertical

    for (let i = 0; i <= ballCount; i++) {
        const dist = i * segmentLength;
        particles[i].set(
            anchorX + Math.sin(angle) * dist,
            anchorY - Math.cos(angle) * dist,
            0
        );
        // Offset prev positions to give initial downward velocity
        prevPositions[i].set(
            particles[i].x,
            particles[i].y + swingVelocity * (i / ballCount), // Was higher, so will drop down
            0
        );
    }

    chainBalls.forEach(b => b.visible = true);
    chainConnectors.forEach(c => c.visible = true);
    if (handle) handle.visible = true;

    container.classList.add('ready');

    setTimeout(() => { physicsFrozen = false; }, 100);
}

// Physics constants
const gravityStrength = 70;
const gravity = new THREE.Vector3(0, -gravityStrength, 0);
const damping = 0.95;
const handleDamping = 0.96;
const constraintIterations = 15;
const dropDamping = 0.95;
const dropAngle = 0.1;
const swingVelocity = 0.5;
const settleThreshold = 0.00032;
const settleTime = 4000;
const restLerpSlow = 0.006;
const settlingEnabled = true;

// Interaction state
let isDragging = false;
let dragTarget = new THREE.Vector3();
let clickSoundPlayed = false;
const maxPullDistance = 0.6 * sizeMultiplier;
let lastDragEndTime = 0;
let pullStartY = 0;
let hasTriggeredClick = false;

const raycaster = new THREE.Raycaster();
const mouse = new THREE.Vector2();
const plane = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0);

// Audio
let audioContext = null;
let switchDownBuffer = null;
let switchUpBuffer = null;

async function initAudio() {
    try {
        audioContext = new (window.AudioContext || window.webkitAudioContext)();
        if (navigator.audioSession) {
            try {
                navigator.audioSession.type = 'playback';
            } catch (e) {}
        }

        const loadSound = async (url) => {
            const response = await fetch(url);
            const arrayBuffer = await response.arrayBuffer();
            return await audioContext.decodeAudioData(arrayBuffer);
        };

        [switchDownBuffer, switchUpBuffer] = await Promise.all([
            loadSound('assets/audio/switch-down.mp3'),
            loadSound('assets/audio/switch-up.mp3')
        ]);
    } catch (e) {
        console.error('Audio init failed:', e);
    }
}

function playBuffer(buffer) {
    if (!audioContext || !buffer) return;
    if (audioContext.state === 'suspended') {
        audioContext.resume();
    }
    const source = audioContext.createBufferSource();
    source.buffer = buffer;
    source.connect(audioContext.destination);
    source.start(0);
}

function playSwitchDown() {
    playBuffer(switchDownBuffer);
    closeAllWindows();
    showScrollCaret();
}

function playSwitchUp() {
    playBuffer(switchUpBuffer);
}

initAudio();

function getMouseWorld(event) {
    const rect = renderer.domElement.getBoundingClientRect();
    const clientX = event.clientX ?? event.touches?.[0]?.clientX;
    const clientY = event.clientY ?? event.touches?.[0]?.clientY;

    mouse.x = ((clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((clientY - rect.top) / rect.height) * 2 + 1;

    raycaster.setFromCamera(mouse, camera);
    const target = new THREE.Vector3();
    raycaster.ray.intersectPlane(plane, target);
    return target;
}

function onPointerDown(event) {
    if (!handle) return;

    const rect = renderer.domElement.getBoundingClientRect();
    const clientX = event.clientX ?? event.touches?.[0]?.clientX;
    const clientY = event.clientY ?? event.touches?.[0]?.clientY;

    mouse.x = ((clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((clientY - rect.top) / rect.height) * 2 + 1;

    raycaster.setFromCamera(mouse, camera);
    const intersects = raycaster.intersectObject(handle);

    if (intersects.length > 0) {
        const handlePos = particles[ballCount];
        pullStartY = handlePos.y;

        playSwitchDown();
        clickSoundPlayed = true;
        hasTriggeredClick = true;

        const pullDistance = maxPullDistance * 3;
        dragTarget.set(handlePos.x, handlePos.y - pullDistance, handlePos.z);
        isDragging = true;
        stopHandleGlow();

        event.preventDefault();
    }
}

function onPointerMove(event) {
    if (!isDragging) return;
    event.preventDefault();

    const pos = getMouseWorld(event);
    if (pos) {
        dragTarget.copy(pos);
        const currentY = particles[ballCount].y;
        const pullDistance = pullStartY - currentY;

        if (pullDistance >= maxPullDistance && !clickSoundPlayed) {
            playSwitchDown();
            clickSoundPlayed = true;
            hasTriggeredClick = true;
        }
    }
}

function onPointerUp(event) {
    if (!isDragging) return;

    playSwitchUp();
    isDragging = false;
    lastDragEndTime = Date.now();

    if (!spawningPaused && fakeWindows.length === 0) {
        setTimeout(spawnWindow, 1200);
    }
}

renderer.domElement.addEventListener('mousedown', onPointerDown);
window.addEventListener('mousemove', onPointerMove);
window.addEventListener('mouseup', onPointerUp);

renderer.domElement.addEventListener('touchstart', onPointerDown, { passive: false });
window.addEventListener('touchmove', (e) => {
    if (isDragging) {
        onPointerMove(e);
    }
}, { passive: false });
window.addEventListener('touchend', onPointerUp);

// Physics simulation
function simulatePhysics(dt) {
    let frameMaxVel = 0;
    if (physicsFrozen) return;

    particles[0].set(anchorX, anchorY, 0);

    for (let i = 1; i <= ballCount; i++) {
        const current = particles[i];
        const prev = prevPositions[i];

        // Different damping during drop animation, gyro, or normal
        let baseDamping = i > ballCount - 5 ? handleDamping : damping;
        if (isDropping) baseDamping = dropDamping;
        const particleDamping = gyroEnabled ? 0.98 : baseDamping;
        const velocity = current.clone().sub(prev).multiplyScalar(particleDamping);
        const velSq = velocity.lengthSq();

        if (velSq > frameMaxVel) frameMaxVel = velSq;

        prev.copy(current);
        current.add(velocity);
        current.add(gravity.clone().multiplyScalar(dt * dt));
    }

    if (isDragging) {
        const handleParticle = particles[ballCount];
        const toTarget = dragTarget.clone().sub(handleParticle);
        handleParticle.add(toTarget.multiplyScalar(0.3));
    }

    // Update gravity direction based on gyroscope
    if (gyroEnabled) {
        // Convert device tilt to gravity direction
        // gamma: left/right tilt (-90 to 90 degrees)
        const gammaRad = gyroGamma * Math.PI / 180;
        const tiltX = Math.sin(gammaRad);
        const tiltY = -Math.cos(gammaRad);

        gravity.set(
            tiltX * gravityStrength,
            tiltY * gravityStrength,
            0
        );
    } else {
        gravity.set(0, -gravityStrength, 0);
    }

    for (let iter = 0; iter < constraintIterations; iter++) {
        particles[0].set(anchorX, anchorY, 0);

        for (let i = 0; i < ballCount; i++) {
            const p1 = particles[i];
            const p2 = particles[i + 1];

            const diff = p2.clone().sub(p1);
            const distance = diff.length();
            if (distance < 0.001) continue;

            const correction = (distance - segmentLength) / distance;

            if (i === 0) {
                p2.sub(diff.multiplyScalar(correction));
            } else {
                const halfCorrection = diff.multiplyScalar(correction * 0.5);
                p1.add(halfCorrection);
                p2.sub(halfCorrection);
            }
        }
    }

    // Skip settling behavior when gyro is active or settling disabled
    if (settlingEnabled && !isDragging && !isDropping && !gyroEnabled) {
        const timeSinceDrag = Date.now() - lastDragEndTime;
        const isSettled = frameMaxVel < settleThreshold && timeSinceDrag > settleTime;
        const restLerp = isSettled ? 1.5 : restLerpSlow;
        for (let i = 1; i <= ballCount; i++) {
            const current = particles[i];
            const prev = prevPositions[i];
            prev.lerp(current, restLerp);
        }
    }
}

function updateMeshes() {
    for (let i = 0; i < ballCount; i++) {
        const p1 = particles[i];
        const p2 = particles[i + 1];
        chainBalls[i].position.lerpVectors(p1, p2, 0.5);
    }

    for (let i = 0; i < ballCount - 1; i++) {
        const ball1 = chainBalls[i].position;
        const ball2 = chainBalls[i + 1].position;

        const connector = chainConnectors[i];
        connector.position.lerpVectors(ball1, ball2, 0.5);

        const direction = ball2.clone().sub(ball1);
        const length = direction.length() - ballRadius * 2;
        connector.scale.set(1, Math.max(0.01, length), 1);

        connector.quaternion.setFromUnitVectors(
            new THREE.Vector3(0, 1, 0),
            direction.normalize()
        );
    }

    if (handle && handleLoaded) {
        const lastParticle = particles[ballCount];
        const secondLast = particles[ballCount - 1];

        handle.position.copy(lastParticle);

        const chainDir = lastParticle.clone().sub(secondLast).normalize();
        handle.quaternion.setFromUnitVectors(new THREE.Vector3(0, -1, 0), chainDir);
    }
}

// Handle resize - use visualViewport on mobile for accurate sizing
let lastWidth = window.innerWidth;

function handleResize() {
    const size = getViewportSize();
    if (size.width !== lastWidth) {
        lastWidth = size.width;
    }
    camera.aspect = size.width / size.height;
    camera.updateProjectionMatrix();
    renderer.setSize(size.width, size.height);
}

window.addEventListener('resize', handleResize);

// On mobile, also listen to visualViewport resize (URL bar show/hide)
if (isMobile && window.visualViewport) {
    window.visualViewport.addEventListener('resize', handleResize);
}

// Animation loop
let lastTime = Date.now();

function animate() {
    requestAnimationFrame(animate);

    const now = Date.now();
    const rawDt = (now - lastTime) / 1000;
    lastTime = now;

    if (rawDt > 0.018) {
        renderer.render(scene, camera);
        return;
    }
    const dt = rawDt;

    // Darken chain and handle based on scroll (lerp toward dark)
    const darken = window.chainDarkenFactor || 1;
    const darkAmount = 1 - darken; // 0 = no darkening, 0.7 = max darkening
    const darkColor = new THREE.Color(0x000000);
    const fadedRed = new THREE.Color(0x331111); // Faded dark red for handle

    chainMaterial.color.copy(chainOriginalColor).lerp(darkColor, darkAmount);
    handleMaterial.color.copy(handleOriginalColor).lerp(fadedRed, darkAmount);
    handleMaterial.emissive.copy(handleOriginalEmissive).lerp(darkColor, darkAmount);
    handleMaterial.emissiveIntensity = 0.8 * darken; // Reduce glow on scroll

    // Pulse outer glow if active
    if (handleGlowActive && handle) {
        const pulse = Math.sin(now * 0.003) * 0.5 + 0.5; // 0 to 1
        handleGlowLight.intensity = pulse * 3;
        // Position light at handle
        const handlePos = particles[ballCount];
        handleGlowLight.position.copy(handlePos);
    }

    if (handleLoaded) {
        if (isDropping) {
            const elapsed = (now - dropStartTime) / 1000;
            if (elapsed > 3) {
                isDropping = false;
            }
        }

        simulatePhysics(dt);
        updateMeshes();
    }

    renderer.render(scene, camera);
}

animate();

