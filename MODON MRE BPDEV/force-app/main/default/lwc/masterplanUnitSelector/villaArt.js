/**
 * Drawn villa imagery for the explore view.
 *
 * WHY THIS IS DRAWN RATHER THAN PHOTOGRAPHED. ADHA has not supplied renders or floor plans for
 * any of the 12 villa types (A1M...C2T), and West Baniyas is not built, so no photography of it
 * exists anywhere. The explore view previously showed an emoji over the words "awaiting ADHA
 * assets", which tells the customer nothing about the house they are about to commit to for a
 * decade. An architectural drawing is honest about being indicative in a way a stock photograph
 * of somebody else's villa would not be, and it matches the surveyed-sheet language the rest of
 * the product is built in.
 *
 * These are generated rather than hand-authored path data or SVG assets: three floors x three
 * views is nine drawings, and the geometry below is a few hundred bytes against what nine
 * exported SVGs would cost in the bundle.
 *
 * WHAT IS AND IS NOT REAL. The plot is 1,000 sqm and the house 450 sqm BUA over two floors with
 * 5 bedrooms - those come from ADHA_Unit__c and are correct. The internal arrangement is a
 * plausible Emirati villa program (majlis at the front, family living behind, prep kitchen off
 * the main one) and is NOT ADHA's layout. The caption says so, in both languages. When the real
 * plans arrive they replace drawVilla and nothing else changes.
 *
 * The palette is fixed rather than themed: a plan is printed on paper and reads the same
 * whichever theme the page is in, and it sits on the blurred backdrop exactly as a drawing on a
 * table would.
 */

const PL = {
    paper: '#EDE8DE',
    wall: '#FCFAF6',
    live: '#E2DACB',
    serv: '#D6CDBB',
    circ: '#E8E2D6',
    lawn: '#BFCBA2',
    pave: '#DCD5C6',
    ink: '#4A443A',
    furn: '#B6A88F',
    furn2: '#9C8E76',
    glass: '#7E8B90',
    line: 'rgba(74, 68, 58, 0.45)'
};

// The plot is 1,000 sqm, portrait, drawn on a 100 x 150 grid. The building envelope is
// x 8-92, y 22-120, which leaves a rear garden and a front driveway at roughly the setbacks
// the masterplan shows.
const FLOORS = {
    GF: {
        rooms: [
            [8, 22, 36, 36, 'rMajlis', 'live'],
            [46, 22, 46, 44, 'rFamily', 'live'],
            [8, 60, 30, 26, 'rKitchen', 'serv'],
            [8, 88, 30, 14, 'rPrep', 'serv'],
            [40, 68, 22, 34, 'rHall', 'circ'],
            [64, 68, 28, 34, 'rBed', 'live'],
            [8, 104, 42, 16, 'rGarage', 'serv'],
            [52, 104, 40, 16, null, 'circ']
        ],
        // Only the first of a repeated name is labelled, or the plan turns into a wall of pills.
        once: ['rPrep'],
        cars: [[12, 107], [31, 107]],
        stair: [42, 72, 18, 22]
    },
    '1F': {
        rooms: [
            [46, 22, 46, 40, 'rMaster', 'live'],
            [8, 22, 36, 26, 'rBed', 'live'],
            [8, 50, 36, 26, 'rBed', 'live'],
            [8, 78, 30, 24, 'rBed', 'live'],
            [40, 68, 22, 34, 'rHall', 'circ'],
            [64, 68, 28, 34, 'rBed', 'live'],
            [8, 104, 20, 16, 'rLaundry', 'serv'],
            [30, 104, 62, 16, null, 'out']
        ],
        once: ['rBed'],
        beds: [[52, 26, 26, 18], [14, 26, 20, 14], [14, 54, 20, 14], [12, 82, 18, 13], [70, 72, 18, 13]],
        stair: [42, 72, 18, 22]
    },
    RF: {
        rooms: [
            [8, 22, 84, 98, null, 'out'],
            [40, 68, 22, 20, 'rStair', 'serv'],
            [64, 88, 20, 14, 'rPlant', 'serv'],
            [10, 90, 24, 12, 'rTanks', 'serv']
        ],
        once: [],
        roof: true
    }
};

// Backing store sized to the device, drawing coordinates left in CSS pixels.
function surface(canvas) {
    const ratio = window.devicePixelRatio || 1;
    const box = canvas.getBoundingClientRect();
    const w = box.width || 480;
    const h = box.height || 640;
    canvas.width = Math.round(w * ratio);
    canvas.height = Math.round(h * ratio);
    const g = canvas.getContext('2d');
    g.scale(ratio, ratio);
    return { g, w, h };
}

function roundRect(g, x, y, w, h, r) {
    const rad = Math.min(r, w / 2, h / 2);
    g.beginPath();
    g.moveTo(x + rad, y);
    g.arcTo(x + w, y, x + w, y + h, rad);
    g.arcTo(x + w, y + h, x, y + h, rad);
    g.arcTo(x, y + h, x, y, rad);
    g.arcTo(x, y, x + w, y, rad);
    g.closePath();
}

function fontFamily(lang) {
    return lang === 'ar'
        ? '"Noto Kufi Arabic","SuisseIntl",sans-serif'
        : '"SuisseIntl",system-ui,sans-serif';
}

// Room names as dark pills, the way an architectural viewer labels a plan - readable over any
// room fill without needing a halo.
function pill(g, x, y, text, size, lang) {
    g.font = `400 ${size}px ${fontFamily(lang)}`;
    const w = g.measureText(text).width;
    const padX = size * 0.7;
    const h = size * 1.9;
    g.fillStyle = 'rgba(28, 30, 34, 0.86)';
    roundRect(g, x - w / 2 - padX, y - h / 2, w + padX * 2, h, h / 2);
    g.fill();
    g.fillStyle = '#F4F2EC';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.fillText(text, x, y + size * 0.06);
}

function drawFloor(canvas, floorKey, lang, t) {
    const { g, w: W, h: H } = surface(canvas);
    const s = Math.min(W / 100, H / 150);
    const ox = (W - 100 * s) / 2;
    const oy = (H - 150 * s) / 2;
    const X = (v) => ox + v * s;
    const Y = (v) => oy + v * s;
    const F = FLOORS[floorKey] || FLOORS.GF;

    g.fillStyle = PL.paper;
    g.fillRect(0, 0, W, H);
    g.fillStyle = PL.lawn;
    g.fillRect(X(0), Y(0), 100 * s, 150 * s);
    g.fillStyle = PL.pave;
    g.fillRect(X(50), Y(118), 44 * s, 32 * s);

    const trees = [[14, 8], [30, 12], [86, 10], [90, 40], [16, 132], [44, 146], [74, 144]];
    g.fillStyle = 'rgba(84, 110, 58, 0.55)';
    trees.forEach((tr, i) => {
        g.beginPath();
        g.arc(X(tr[0]), Y(tr[1]), (3.4 + (i % 3)) * s, 0, Math.PI * 2);
        g.fill();
    });

    // Envelope painted in the wall colour, rooms inset on top: the gaps between rooms then
    // read as the walls, which is cheaper and truer than stroking every partition.
    g.fillStyle = PL.wall;
    g.fillRect(X(8), Y(22), 84 * s, 98 * s);
    g.strokeStyle = PL.line;
    g.lineWidth = 1;
    g.strokeRect(X(8), Y(22), 84 * s, 98 * s);

    if (F.roof) {
        g.fillStyle = '#E4DCCC';
        g.fillRect(X(10), Y(24), 80 * s, 94 * s);
        g.strokeStyle = 'rgba(74, 68, 58, 0.25)';
        for (let r = 0; r < 9; r += 1) {
            g.beginPath();
            g.moveTo(X(10), Y(24 + r * 10.5));
            g.lineTo(X(90), Y(24 + r * 10.5));
            g.stroke();
        }
    }

    F.rooms.forEach((rm) => {
        if (rm[5] === 'out') {
            return;
        }
        g.fillStyle = rm[5] === 'live' ? PL.live : rm[5] === 'serv' ? PL.serv : PL.circ;
        g.fillRect(X(rm[0]), Y(rm[1]), rm[2] * s, rm[3] * s);
        g.strokeStyle = 'rgba(74, 68, 58, 0.18)';
        g.strokeRect(X(rm[0]), Y(rm[1]), rm[2] * s, rm[3] * s);
    });

    const block = (x, y, bw, bh, dark) => {
        g.fillStyle = dark ? PL.furn2 : PL.furn;
        roundRect(g, X(x), Y(y), bw * s, bh * s, 1.6 * s);
        g.fill();
    };

    if (floorKey === 'GF') {
        block(11, 25, 5, 28);
        block(38, 25, 4, 28);
        block(16, 54, 24, 3);
        block(50, 26, 22, 10);
        block(76, 26, 12, 16, true);
        block(50, 42, 30, 3);
        block(10, 62, 4, 20);
        block(16, 62, 18, 4);
        block(68, 72, 16, 11, true);
        block(86, 70, 4, 12);
        (F.cars || []).forEach((c) => {
            g.fillStyle = '#6E6659';
            roundRect(g, X(c[0]), Y(c[1]), 8 * s, 12 * s, 1.8 * s);
            g.fill();
            g.fillStyle = 'rgba(255, 255, 255, 0.22)';
            roundRect(g, X(c[0] + 1.4), Y(c[1] + 3), 5.2 * s, 4.6 * s, 1 * s);
            g.fill();
        });
    }

    if (floorKey === '1F') {
        (F.beds || []).forEach((b) => {
            block(b[0], b[1], b[2], b[3], true);
            g.fillStyle = PL.paper;
            roundRect(g, X(b[0] + 1), Y(b[1] + 1), (b[2] - 2) * s, 3 * s, 1 * s);
            g.fill();
        });
        block(10, 106, 16, 5);
    }

    if (F.stair) {
        const st = F.stair;
        g.strokeStyle = 'rgba(74, 68, 58, 0.5)';
        for (let i = 0; i < 8; i += 1) {
            const sy = Y(st[1] + i * (st[3] / 8));
            g.beginPath();
            g.moveTo(X(st[0]), sy);
            g.lineTo(X(st[0] + st[2]), sy);
            g.stroke();
        }
    }

    // Below this the pills collide with each other and with the furniture.
    if (W < 300) {
        return;
    }
    const size = Math.max(9, W * 0.028);
    const seen = {};
    F.rooms.forEach((rm) => {
        if (!rm[4]) {
            return;
        }
        if (F.once.indexOf(rm[4]) >= 0) {
            if (seen[rm[4]]) {
                return;
            }
            seen[rm[4]] = true;
        }
        pill(g, X(rm[0] + rm[2] / 2), Y(rm[1] + rm[3] / 2), t(lang, rm[4]), size, lang);
    });
}

function drawExterior(canvas) {
    const { g, w: W, h: H } = surface(canvas);
    g.fillStyle = PL.paper;
    g.fillRect(0, 0, W, H);

    const s = W / 600;
    const ground = H * 0.78;
    const shift = (W - 600 * s) / 2;
    const rect = (x, y, w, h, fill) => {
        g.beginPath();
        g.rect(x * s + shift, ground - (y + h) * s, w * s, h * s);
        g.fillStyle = fill;
        g.fill();
        g.strokeStyle = PL.line;
        g.lineWidth = 1;
        g.stroke();
    };

    g.fillStyle = PL.lawn;
    g.fillRect(0, ground, W, H - ground);

    rect(40, 0, 520, 24, '#E0D9C9');
    rect(120, 0, 250, 190, '#F7F3EB');
    rect(360, 0, 150, 120, '#E6DFD1');
    rect(150, 190, 190, 14, '#DCD4C3');
    rect(370, 120, 130, 12, '#DCD4C3');
    for (let i = 0; i < 4; i += 1) {
        rect(146 + i * 54, 110, 34, 56, PL.glass);
    }
    rect(146, 20, 96, 74, PL.glass);
    rect(262, 20, 42, 74, '#5D6A70');
    for (let j = 0; j < 3; j += 1) {
        rect(384 + j * 40, 20, 26, 62, PL.glass);
    }
    // Shading fins over the upper glazing: the one detail that makes a flat white box read as
    // a house built for this climate rather than any house anywhere.
    for (let k = 0; k < 4; k += 1) {
        rect(142 + k * 54, 168, 42, 4, '#CFC6B2');
    }

    g.strokeStyle = PL.ink;
    g.lineWidth = 1.4;
    g.beginPath();
    g.moveTo(0, ground);
    g.lineTo(W, ground);
    g.stroke();

    const tree = (x, r) => {
        const cx = x * s + shift;
        g.strokeStyle = 'rgba(74, 68, 58, 0.55)';
        g.lineWidth = 1;
        g.beginPath();
        g.moveTo(cx, ground);
        g.lineTo(cx, ground - r * 1.15 * s);
        g.stroke();
        g.fillStyle = 'rgba(120, 146, 84, 0.55)';
        for (let a = 0; a < 3; a += 1) {
            g.beginPath();
            g.arc(cx, ground - (r * 1.4 + a * 4) * s, (r - a * 5) * s, 0, Math.PI * 2);
            g.fill();
        }
    };
    tree(78, 26);
    tree(540, 20);
}

function drawInterior(canvas) {
    const { g, w: W, h: H } = surface(canvas);
    g.fillStyle = PL.paper;
    g.fillRect(0, 0, W, H);

    const L = W * 0.08;
    const R = W * 0.92;
    const T = H * 0.08;
    const B = H * 0.92;
    const bl = W * 0.34;
    const br = W * 0.7;
    const bt = H * 0.32;
    const bb = H * 0.72;

    g.fillStyle = '#E7E1D5';
    g.fillRect(L, T, R - L, B - T);
    g.fillStyle = '#F2EDE3';
    g.fillRect(bl, bt, br - bl, bb - bt);
    g.strokeStyle = PL.line;
    g.lineWidth = 1;
    g.strokeRect(bl, bt, br - bl, bb - bt);

    [[L, T, bl, bt], [R, T, br, bt], [L, B, bl, bb], [R, B, br, bb]].forEach((q) => {
        g.beginPath();
        g.moveTo(q[0], q[1]);
        g.lineTo(q[2], q[3]);
        g.stroke();
    });

    // Floor lines converging on the vanishing point, spaced so they foreshorten.
    g.strokeStyle = 'rgba(74, 68, 58, 0.22)';
    for (let i = 1; i < 8; i += 1) {
        const x = L + (R - L) * (i / 8);
        g.beginPath();
        g.moveTo(x, B);
        g.lineTo(bl + (br - bl) * (i / 8), bb);
        g.stroke();
    }
    for (let j = 1; j < 4; j += 1) {
        const f = Math.pow(j / 4, 1.8);
        const y = B + (bb - B) * f;
        g.beginPath();
        g.moveTo(L + (bl - L) * f, y);
        g.lineTo(R + (br - R) * f, y);
        g.stroke();
    }

    const wl = bl + (br - bl) * 0.1;
    const wr = bl + (br - bl) * 0.9;
    const wt = bt + (bb - bt) * 0.12;
    const wb = bt + (bb - bt) * 0.68;
    g.fillStyle = PL.glass;
    g.fillRect(wl, wt, wr - wl, wb - wt);
    g.strokeStyle = PL.ink;
    g.strokeRect(wl, wt, wr - wl, wb - wt);
    g.beginPath();
    g.moveTo((wl + wr) / 2, wt);
    g.lineTo((wl + wr) / 2, wb);
    g.stroke();

    const seat = (x0, x1, yb, h, col) => {
        g.fillStyle = col;
        roundRect(g, x0, yb - h, x1 - x0, h, 6);
        g.fill();
        g.strokeStyle = PL.line;
        g.lineWidth = 1;
        g.stroke();
    };
    seat(W * 0.18, W * 0.44, H * 0.86, H * 0.14, PL.furn);
    seat(W * 0.48, W * 0.66, H * 0.78, H * 0.06, PL.furn2);
    seat(W * 0.72, W * 0.88, H * 0.83, H * 0.12, PL.furn);

    g.strokeStyle = 'rgba(74, 68, 58, 0.25)';
    g.strokeRect(W * 0.3, H * 0.16, W * 0.4, H * 0.05);
}

/**
 * @param {HTMLCanvasElement} canvas target, already laid out
 * @param {string} tab floorplan | exterior | interior
 * @param {string} floor GF | 1F | RF, read only for the floorplan tab
 * @param {string} lang active language, for the room labels
 * @param {Function} t the (lang, key) resolver from c/adhaLabels
 */
export function drawVilla(canvas, tab, floor, lang, t) {
    if (!canvas || !canvas.getContext) {
        return;
    }
    if (tab === 'exterior') {
        drawExterior(canvas);
    } else if (tab === 'interior') {
        drawInterior(canvas);
    } else {
        drawFloor(canvas, floor, lang, t);
    }
}