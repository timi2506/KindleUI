import Foundation

extension KindlePreviewServer {
    // MARK: - Studio HTML Application

    internal func buildStudioIndexHTML() -> String {
        return #"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>KindleUI Live Preview Studio</title>
<style>
:root {
    --studio-bg: #141518;
    --studio-panel: #1f2127;
    --studio-border: #313540;
    --studio-text: #eef0f4;
    --studio-muted: #9ba1b0;
}
* {
    box-sizing: border-box;
}
html, body {
    margin: 0;
    padding: 0;
    width: 100%;
    height: 100%;
    background: var(--studio-bg);
    color: var(--studio-text);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, sans-serif;
    overflow: hidden;
}
.studio-shell {
    display: flex;
    flex-direction: column;
    width: 100vw;
    height: 100vh;
}
.studio-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 8px 16px;
    background: var(--studio-panel);
    border-bottom: 1px solid var(--studio-border);
    flex-shrink: 0;
    flex-wrap: wrap;
}
.toolbar-group {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
}
.studio-brand {
    font-weight: 700;
    font-size: 14px;
    letter-spacing: 0.02em;
    display: flex;
    align-items: center;
    gap: 8px;
}
.live-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #22c55e;
    box-shadow: 0 0 8px #22c55e;
}
.live-dot.offline {
    background: #ef4444;
    box-shadow: none;
}
.studio-select, .studio-btn {
    background: #2a2d36;
    color: var(--studio-text);
    border: 1px solid #3d4251;
    border-radius: 6px;
    padding: 5px 10px;
    font-size: 12.5px;
    font-weight: 500;
    cursor: pointer;
}
.studio-btn:hover, .studio-select:hover {
    background: #353945;
}
.studio-btn.active {
    background: #f3f4f6;
    color: #111827;
    border-color: #f3f4f6;
}
.studio-slider-label {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    color: var(--studio-muted);
}
.studio-slider-label input[type="range"] {
    width: 72px;
    accent-color: #e5e7eb;
}
.studio-meta {
    font-size: 11.5px;
    color: var(--studio-muted);
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}
.studio-stage {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: auto;
    padding: 20px;
    position: relative;
}
.kindle-bezel {
    background: #23252a;
    border: 2px solid #3a3d46;
    border-radius: 28px;
    padding: 22px 22px 34px 22px;
    box-shadow: 0 24px 60px rgba(0, 0, 0, 0.65), inset 0 1px 1px rgba(255, 255, 255, 0.08);
    display: flex;
    flex-direction: column;
    align-items: center;
    position: relative;
}
.kindle-viewport-scaler {
    position: relative;
    overflow: hidden;
    border-radius: 6px;
    box-shadow: inset 0 0 0 2px #111;
    background: #ffffff;
}
.kindle-bezel-chin {
    margin-top: 10px;
    font-family: "Georgia", serif;
    font-size: 13px;
    letter-spacing: 0.18em;
    color: #7c818e;
    text-transform: lowercase;
    user-select: none;
}

/* 1860x2480 Logical E-Ink Screen Container (Exact GTK2Renderer Grid) */
#eink-screen {
    width: 1860px;
    height: 2480px;
    transform-origin: top left;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    position: relative;
    user-select: none;
    -webkit-font-smoothing: antialiased;
}
#eink-warmth-overlay {
    pointer-events: none;
    position: absolute;
    inset: 0;
    z-index: 9999;
    mix-blend-mode: multiply;
    transition: background-color 0.15s ease;
}
#eink-flash-overlay {
    pointer-events: none;
    position: absolute;
    inset: 0;
    z-index: 10000;
    opacity: 0;
}
#eink-flash-overlay.flashing {
    animation: einkFullFlash 0.34s steps(2, end) forwards;
}
@keyframes einkFullFlash {
    0%   { opacity: 1; background: #000000; }
    45%  { opacity: 1; background: #ffffff; }
    80%  { opacity: 0.4; background: #000000; }
    100% { opacity: 0; background: transparent; }
}

/* KindleUI Node Layout Rules */
.k-vbox {
    display: flex;
    flex-direction: column;
    box-sizing: border-box;
    width: 100%;
    min-height: 0;
}
.k-hbox {
    display: flex;
    flex-direction: row;
    box-sizing: border-box;
    min-width: 0;
}
.k-zstack {
    display: grid;
    grid-template-columns: 100%;
    grid-template-rows: 100%;
    width: 100%;
    height: 100%;
    flex: 1 1 0;
    min-height: 0;
    position: relative;
}
.k-zlayer {
    grid-area: 1 / 1 / 2 / 2;
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
    min-height: 0;
}
.k-zoverlay {
    z-index: 2;
}
.k-scroll-view {
    flex: 1 1 0;
    min-height: 0;
    min-width: 0;
    width: 100%;
    display: flex;
    flex-direction: column;
}
.k-scroll-content {
    display: flex;
    flex-direction: column;
    width: 100%;
    flex: 0 0 auto;
}
.k-scroll-no-indicators::-webkit-scrollbar {
    display: none;
}
.k-scroll-indicators::-webkit-scrollbar {
    width: 12px;
    height: 12px;
}
.k-scroll-indicators::-webkit-scrollbar-thumb {
    background: #555;
    border-radius: 6px;
}
.k-label {
    box-sizing: border-box;
    max-width: 100%;
    min-width: 0;
}
.k-tt {
    font-family: 'JetBrains Mono', 'SF Mono', 'Menlo', monospace;
    background: rgba(128, 128, 128, 0.14);
    padding: 0 6px;
    border-radius: 4px;
}
.k-btn {
    display: inline-flex;
    flex-direction: column;
    justify-content: center;
    box-sizing: border-box;
    cursor: pointer;
    text-align: center;
    outline: none;
    transition: filter 0.04s linear;
}
.k-btn:active:not(:disabled) {
    filter: invert(1);
}
.k-btn:disabled {
    cursor: default;
}
.k-slider-wrap {
    width: 100%;
    display: flex;
    align-items: center;
    padding: 8px 0;
}
.k-slider {
    -webkit-appearance: none;
    appearance: none;
    width: 100%;
    height: 14px;
    border-radius: 7px;
    border: 2px solid var(--slider-fg, #000);
    background: linear-gradient(to right, var(--slider-fg, #000) 0%, var(--slider-fg, #000) var(--slider-pct, 50%), var(--slider-track, #ccc) var(--slider-pct, 50%), var(--slider-track, #ccc) 100%);
    outline: none;
}
.k-slider::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    width: 38px;
    height: 38px;
    border-radius: 50%;
    background: var(--slider-bg, #fff);
    border: 4px solid var(--slider-fg, #000);
    cursor: pointer;
}
.k-progress-track {
    width: 100%;
    overflow: hidden;
    position: relative;
}
.k-progress-fill {
    height: 100%;
}
.k-texteditor {
    padding: 14px;
    resize: none;
    outline: none;
}
</style>
</head>
<body>
<div class="studio-shell">
    <header class="studio-toolbar">
        <div class="toolbar-group">
            <div class="studio-brand">
                <span id="live-dot" class="live-dot" title="SSE Live Stream"></span>
                <span>KindleUI Preview</span>
            </div>
            <select id="scene-select" class="studio-select" title="Active Scene / Preview" onchange="window.changeScene(this.value)"></select>
            <select id="device-select" class="studio-select" title="Kindle Hardware Profile" onchange="window.changeDevice(this.value)">
                <option value="pw5">Kindle Paperwhite 5 (1236×1648 · 300 PPI)</option>
                <option value="scribe">Kindle Scribe (1860×2480 · 300 PPI)</option>
                <option value="basic">Kindle Basic / PW4 (1072×1448 · 300 PPI)</option>
                <option value="oasis">Kindle Oasis 10th Gen (1264×1680 · 300 PPI)</option>
                <option value="touch">Kindle Touch / PW2 (758×1024 · 212 PPI)</option>
            </select>
            <button id="orient-btn" class="studio-btn" onclick="window.toggleOrientation()" title="Rotate Portrait / Landscape">Portrait ↕</button>
            <select id="zoom-select" class="studio-select" title="Viewport Zoom" onchange="window.updateViewportScale()">
                <option value="fit">Fit Window</option>
                <option value="0.35">35%</option>
                <option value="0.5">50%</option>
                <option value="0.665">67% (PW5 1:1)</option>
                <option value="1.0">100% (1860×2480)</option>
            </select>
        </div>

        <div class="toolbar-group">
            <button id="swipe-right-btn" class="studio-btn" onclick="window.triggerSwipe('swipeRight')" title="Swipe Right (Previous Page)">◀ Prev Page</button>
            <button id="swipe-left-btn" class="studio-btn" onclick="window.triggerSwipe('swipeLeft')" title="Swipe Left (Next Page)">Next Page ▶</button>
            <button id="scheme-btn" class="studio-btn" onclick="window.toggleColorScheme()" title="Toggle E-Ink Dark Mode">☾ Dark</button>
            <button class="studio-btn" onclick="window.triggerFullRefresh()" title="Trigger Full GC16 E-Ink Flash Refresh">⚡ GC16 Flash</button>
            <label class="studio-slider-label" title="Kindle Frontlight Brightness (0–24)">
                <span>💡</span>
                <input id="fl-slider" type="range" min="0" max="24" value="12" oninput="window.changeLight()" />
            </label>
            <label class="studio-slider-label" title="Kindle Warmth / Amber LEDs (0–24)">
                <span>🔥</span>
                <input id="warmth-slider" type="range" min="0" max="24" value="6" oninput="window.changeLight()" />
            </label>
            <span id="studio-meta" class="studio-meta">1236×1648 · Scale 0.665</span>
        </div>
    </header>

    <main id="studio-stage" class="studio-stage">
        <div id="kindle-bezel" class="kindle-bezel">
            <div id="viewport-scaler" class="kindle-viewport-scaler">
                <div id="eink-screen">
                    <div id="eink-root" style="display:flex;flex-direction:column;width:100%;height:100%;flex:1;min-height:0;"></div>
                    <div id="eink-warmth-overlay"></div>
                    <div id="eink-flash-overlay"></div>
                </div>
            </div>
            <div class="kindle-bezel-chin">kindle</div>
        </div>
    </main>
</div>

<script>
(function() {
    let currentState = {
        logicalWidth: 1860,
        logicalHeight: 2480,
        physicalWidth: 1236,
        physicalHeight: 1648,
        isLandscape: false,
        colorScheme: "light",
        keyboardVisible: false,
        frontlight: 12,
        warmth: 6
    };

    const rootEl = document.getElementById('eink-root');
    const screenEl = document.getElementById('eink-screen');
    const scalerEl = document.getElementById('viewport-scaler');
    const stageEl = document.getElementById('studio-stage');
    const flashEl = document.getElementById('eink-flash-overlay');
    const warmthEl = document.getElementById('eink-warmth-overlay');
    const liveDot = document.getElementById('live-dot');
    const sceneSelect = document.getElementById('scene-select');
    const deviceSelect = document.getElementById('device-select');
    const orientBtn = document.getElementById('orient-btn');
    const zoomSelect = document.getElementById('zoom-select');
    const schemeBtn = document.getElementById('scheme-btn');
    const flSlider = document.getElementById('fl-slider');
    const warmthSlider = document.getElementById('warmth-slider');
    const metaEl = document.getElementById('studio-meta');

    let savedScrollPositions = {};
    let lastScrollPositionReset = 0;

    function postAction(payload) {
        return fetch('/action', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        }).then(r => r.json()).then(applyFrame).catch(() => {});
    }

    window.kindleTap = function(id, ev) {
        if (ev) ev.stopPropagation();
        postAction({ type: 'tap', id: id });
    };

    window.kindleToggle = function(id, value, ev) {
        if (ev) ev.stopPropagation();
        postAction({ type: 'toggle', id: id, value: value });
    };

    let sliderTimer = null;
    window.kindleSliderInput = function(inputEl, ended) {
        const val = parseFloat(inputEl.value);
        const min = parseFloat(inputEl.min || '0');
        const max = parseFloat(inputEl.max || '100');
        const pct = ((val - min) / Math.max(0.0001, max - min)) * 100;
        if (inputEl.parentElement) {
            inputEl.parentElement.style.setProperty('--slider-pct', pct.toFixed(2) + '%');
        }
        const id = inputEl.getAttribute('data-action-id');
        if (ended) {
            if (sliderTimer) clearTimeout(sliderTimer);
            postAction({ type: 'slider', id: id, value: val, ended: true });
        } else {
            if (sliderTimer) clearTimeout(sliderTimer);
            sliderTimer = setTimeout(() => {
                postAction({ type: 'slider', id: id, value: val, ended: false });
            }, 45);
        }
    };

    let textTimer = null;
    window.kindleTextInput = function(inputEl) {
        const id = inputEl.getAttribute('data-action-id');
        const val = inputEl.value;
        if (textTimer) clearTimeout(textTimer);
        textTimer = setTimeout(() => {
            postAction({ type: 'text', id: id, value: val });
        }, 90);
    };

    window.changeScene = function(sceneID) {
        savedScrollPositions = {};
        postAction({ type: 'device', sceneID: sceneID });
    };

    window.changeDevice = function(model) {
        postAction({ type: 'device', model: model });
    };

    window.toggleOrientation = function() {
        postAction({ type: 'device', landscape: !currentState.isLandscape });
    };

    window.toggleColorScheme = function() {
        const next = currentState.colorScheme === 'dark' ? 'light' : 'dark';
        postAction({ type: 'device', colorScheme: next });
    };

    window.triggerFullRefresh = function() {
        postAction({ type: 'device', fullRefresh: true });
    };

    window.triggerSwipe = function(dir) {
        postAction({ type: dir, id: '' });
    };

    window.changeLight = function() {
        const fl = parseInt(flSlider.value, 10);
        const wm = parseInt(warmthSlider.value, 10);
        updatePaperLighting(fl, wm);
        postAction({ type: 'device', frontlight: fl, warmth: wm });
    };

    function updatePaperLighting(fl, warmth) {
        const dimAlpha = ((24 - fl) / 24) * 0.14;
        const warmAlpha = (warmth / 24) * 0.14;
        const r = Math.round(255 - dimAlpha * 180);
        const g = Math.round(255 - dimAlpha * 185 - warmAlpha * 28);
        const b = Math.round(255 - dimAlpha * 195 - warmAlpha * 75);
        warmthEl.style.backgroundColor = `rgb(${r}, ${g}, ${b})`;
    }

    window.updateViewportScale = function() {
        const lw = currentState.logicalWidth || 1860;
        const lh = currentState.logicalHeight || 2480;
        screenEl.style.width = lw + 'px';
        screenEl.style.height = lh + 'px';

        const mode = zoomSelect.value;
        let scale = 0.35;
        if (mode === 'fit') {
            const availW = Math.max(280, stageEl.clientWidth - 96);
            const availH = Math.max(320, stageEl.clientHeight - 110);
            scale = Math.min(availW / lw, availH / lh);
        } else {
            scale = parseFloat(mode) || 0.35;
        }
        screenEl.style.transform = `scale(${scale})`;
        scalerEl.style.width = Math.round(lw * scale) + 'px';
        scalerEl.style.height = Math.round(lh * scale) + 'px';
    };

    window.addEventListener('resize', window.updateViewportScale);

    function playFullFlash() {
        flashEl.classList.remove('flashing');
        void flashEl.offsetWidth;
        flashEl.classList.add('flashing');
    }

    function captureScrollPositions() {
        const scrollers = rootEl.querySelectorAll('.k-scroll-view');
        scrollers.forEach(el => {
            const id = el.getAttribute('data-scroll-id');
            if (id) {
                savedScrollPositions[id] = { top: el.scrollTop, left: el.scrollLeft };
            }
        });
    }

    function restoreScrollPositions() {
        const scrollers = rootEl.querySelectorAll('.k-scroll-view');
        scrollers.forEach(el => {
            const id = el.getAttribute('data-scroll-id');
            if (id && savedScrollPositions[id]) {
                el.scrollTop = savedScrollPositions[id].top;
                el.scrollLeft = savedScrollPositions[id].left;
            }
            el.addEventListener('scroll', () => {
                savedScrollPositions[id] = { top: el.scrollTop, left: el.scrollLeft };
            }, { passive: true });
        });
    }

    function bindGestureAndCanvasEvents() {
        const gestureNodes = rootEl.querySelectorAll('[data-tap-id], [data-lp-id], [data-swipe-left-id], [data-swipe-right-id]');
        gestureNodes.forEach(node => {
            let startX = 0, startY = 0, lpTimer = null, didLongPress = false, isDown = false;
            const tapID = node.getAttribute('data-tap-id');
            const lpID = node.getAttribute('data-lp-id');
            const slID = node.getAttribute('data-swipe-left-id');
            const srID = node.getAttribute('data-swipe-right-id');

            node.addEventListener('pointerdown', (e) => {
                if (e.target.closest('button, input, textarea, select, a')) return;
                isDown = true;
                didLongPress = false;
                startX = e.clientX;
                startY = e.clientY;
                if (lpID) {
                    lpTimer = setTimeout(() => {
                        didLongPress = true;
                        postAction({ type: 'longPress', id: lpID });
                    }, 500);
                }
            });

            node.addEventListener('pointerup', (e) => {
                if (!isDown) return;
                isDown = false;
                if (lpTimer) { clearTimeout(lpTimer); lpTimer = null; }
                if (didLongPress) return;

                const dx = e.clientX - startX;
                const dy = e.clientY - startY;
                if (Math.abs(dx) > 45 && Math.abs(dx) > Math.abs(dy) * 1.3) {
                    if (dx < 0 && slID) {
                        e.stopPropagation();
                        postAction({ type: 'swipeLeft', id: slID });
                        return;
                    }
                    if (dx > 0 && srID) {
                        e.stopPropagation();
                        postAction({ type: 'swipeRight', id: srID });
                        return;
                    }
                }
                if (Math.abs(dx) < 12 && Math.abs(dy) < 12 && tapID) {
                    e.stopPropagation();
                    postAction({ type: 'tap', id: tapID });
                }
            });

            node.addEventListener('pointercancel', () => {
                isDown = false;
                if (lpTimer) { clearTimeout(lpTimer); lpTimer = null; }
            });
        });

        const canvases = rootEl.querySelectorAll('.k-canvas-img[data-interactive="1"]');
        canvases.forEach(img => {
            const canvasID = img.getAttribute('data-canvas-id');
            const bufW = parseInt(img.getAttribute('data-width') || '800', 10);
            const bufH = parseInt(img.getAttribute('data-height') || '600', 10);
            let drawing = false;
            let lastMoveSent = 0;

            function coords(e) {
                const rect = img.getBoundingClientRect();
                const relX = (e.clientX - rect.left) / Math.max(1, rect.width);
                const relY = (e.clientY - rect.top) / Math.max(1, rect.height);
                return {
                    x: Math.max(0, Math.min(bufW - 1, Math.round(relX * bufW))),
                    y: Math.max(0, Math.min(bufH - 1, Math.round(relY * bufH)))
                };
            }

            img.addEventListener('pointerdown', (e) => {
                e.preventDefault();
                drawing = true;
                img.setPointerCapture(e.pointerId);
                const pt = coords(e);
                postAction({ type: 'canvasPointer', id: canvasID, phase: 0, x: pt.x, y: pt.y });
            });

            img.addEventListener('pointermove', (e) => {
                if (!drawing) return;
                const now = performance.now();
                if (now - lastMoveSent < 28) return;
                lastMoveSent = now;
                const pt = coords(e);
                postAction({ type: 'canvasPointer', id: canvasID, phase: 1, x: pt.x, y: pt.y });
            });

            img.addEventListener('pointerup', (e) => {
                if (!drawing) return;
                drawing = false;
                const pt = coords(e);
                postAction({ type: 'canvasPointer', id: canvasID, phase: 2, x: pt.x, y: pt.y });
            });
        });
    }

    window.addEventListener('keydown', (e) => {
        if (!currentState.keyboardVisible) return;
        const activeTag = document.activeElement ? document.activeElement.tagName : '';
        if (activeTag === 'INPUT' || activeTag === 'TEXTAREA' || activeTag === 'SELECT') return;
        if (e.metaKey || e.ctrlKey || e.altKey) return;

        let keyval = 0;
        if (e.key === 'Escape') keyval = 0xff1b;
        else if (e.key === 'Backspace') keyval = 0xff08;
        else if (e.key === 'Enter') keyval = 0xff0d;
        else if (e.key.length === 1) keyval = e.key.charCodeAt(0);

        if (keyval > 0) {
            e.preventDefault();
            postAction({ type: 'hardwareKey', keyval: keyval });
        }
    });

    function applyFrame(frame) {
        if (!frame || !frame.html) return;

        captureScrollPositions();
        if (frame.scrollPosition === 0 && lastScrollPositionReset !== 0) {
            savedScrollPositions = {};
        }
        lastScrollPositionReset = frame.scrollPosition || 0;

        const dimensionChanged = (frame.logicalWidth !== currentState.logicalWidth) || (frame.logicalHeight !== currentState.logicalHeight);
        currentState = frame;

        screenEl.style.backgroundColor = frame.bgHex || '#ffffff';
        rootEl.innerHTML = frame.html;

        if (frame.fullFlash) {
            playFullFlash();
        }

        if (frame.scenes && Array.isArray(frame.scenes)) {
            const currentOpts = Array.from(sceneSelect.options).map(o => o.value).join(',');
            const nextOpts = frame.scenes.map(s => s.id).join(',');
            if (currentOpts !== nextOpts) {
                sceneSelect.innerHTML = frame.scenes.map(s => `<option value="${s.id}">${s.title}</option>`).join('');
            }
            sceneSelect.value = frame.activeSceneID || '__main__';
        }
        if (frame.deviceModel && deviceSelect.value !== frame.deviceModel) {
            deviceSelect.value = frame.deviceModel;
        }
        orientBtn.textContent = frame.isLandscape ? 'Landscape ↔' : 'Portrait ↕';
        schemeBtn.textContent = frame.colorScheme === 'dark' ? '☀ Light' : '☾ Dark';
        schemeBtn.classList.toggle('active', frame.colorScheme === 'dark');

        if (typeof frame.frontlight === 'number') flSlider.value = frame.frontlight;
        if (typeof frame.warmth === 'number') warmthSlider.value = frame.warmth;
        updatePaperLighting(frame.frontlight ?? 12, frame.warmth ?? 6);

        const scaleStr = (frame.uiScale || 0.665).toFixed(3);
        metaEl.textContent = `${frame.physicalWidth}×${frame.physicalHeight} · Scale ${scaleStr} · Refreshes: ${frame.refreshCount || 0}`;
        document.title = `${frame.windowTitle || 'KindleUI'} — KindleUI Live Preview`;

        if (dimensionChanged) {
            window.updateViewportScale();
        }
        restoreScrollPositions();
        bindGestureAndCanvasEvents();
    }

    function connectSSE() {
        const es = new EventSource('/events');
        es.onopen = () => {
            liveDot.classList.remove('offline');
        };
        es.onmessage = (ev) => {
            try {
                const data = JSON.parse(ev.data);
                applyFrame(data);
            } catch (e) {}
        };
        es.onerror = () => {
            liveDot.classList.add('offline');
        };
    }

    window.updateViewportScale();
    connectSSE();
})();
</script>
</body>
</html>
"""#
    }
}
