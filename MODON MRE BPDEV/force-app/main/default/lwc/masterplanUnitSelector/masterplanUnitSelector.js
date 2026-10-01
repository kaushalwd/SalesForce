import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
// MODON's plan as a tile pyramid: the 28 MB sheet beats the 5 MB static resource cap, one
// resource per shard (see tileManifest.js). WestBaniyasLandUse is only backdrop and fallback now.
import MASTERPLAN_REAL from '@salesforce/resourceUrl/WestBaniyasLandUse';
import PLAN_TILES_0 from '@salesforce/resourceUrl/WestBaniyasPlanTiles0';
import PLAN_TILES_1 from '@salesforce/resourceUrl/WestBaniyasPlanTiles1';
import PLAN_TILES_2 from '@salesforce/resourceUrl/WestBaniyasPlanTiles2';
import PLAN_TILES_3 from '@salesforce/resourceUrl/WestBaniyasPlanTiles3';
import PLAN_TILES_4 from '@salesforce/resourceUrl/WestBaniyasPlanTiles4';
import PLAN_TILES_5 from '@salesforce/resourceUrl/WestBaniyasPlanTiles5';
import PLAN_TILES_6 from '@salesforce/resourceUrl/WestBaniyasPlanTiles6';
import PLAN_TILES_7 from '@salesforce/resourceUrl/WestBaniyasPlanTiles7';
import PLAN_TILES_8 from '@salesforce/resourceUrl/WestBaniyasPlanTiles8';
import PLAN_TILES_9 from '@salesforce/resourceUrl/WestBaniyasPlanTiles9';
import PLAN_TILES_10 from '@salesforce/resourceUrl/WestBaniyasPlanTiles10';
import PLAN_TILES_11 from '@salesforce/resourceUrl/WestBaniyasPlanTiles11';
import PLAN_TILES_12 from '@salesforce/resourceUrl/WestBaniyasPlanTiles12';
// The same villa at source resolution, drawn per parcel at zoom. See syncVillaArt.
import VILLA_ART from '@salesforce/resourceUrl/WestBaniyasVillaArt';
// window.WB_VILLA_BEARINGS: which way each villa's entrance faces. See entryRect.
import VILLA_BEARINGS from '@salesforce/resourceUrl/WestBaniyasVillaBearings';
import MASTERPLAN_DATA from '@salesforce/resourceUrl/WestBaniyasMasterplanData';
import getMasterplanFor from '@salesforce/apex/ADHA_MasterplanController.getMasterplanFor';
import getAvailability from '@salesforce/apex/ADHA_MasterplanController.getAvailability';
import opsSearchApplicants from '@salesforce/apex/ADHA_PinController.searchApplicants';
import opsPinBoard from '@salesforce/apex/ADHA_PinController.board';
import opsPinUnit from '@salesforce/apex/ADHA_PinController.pin';
import opsUnpinUnit from '@salesforce/apex/ADHA_PinController.unpin';
import opsHolderOf from '@salesforce/apex/ADHA_PinController.holder';
import opsAssignableStock from '@salesforce/apex/ADHA_PinController.assignableStock';
import markExploring from '@salesforce/apex/ADHA_JourneyController.markExploring';
import markUnitExplored from '@salesforce/apex/ADHA_JourneyController.markUnitExplored';
import quoteUnit from '@salesforce/apex/ADHA_ReservationController.quote';
import AMENITY_DATA from '@salesforce/resourceUrl/WestBaniyasAmenities';
// MODON's 20 Aug pack: 57 renders, one resource per category (no longer fits one 5 MB zip).
// villaMedia.js maps which file is which - nothing can be derived from the unit's fields.
import VILLA_A from '@salesforce/resourceUrl/WestBaniyasVillaA';
import VILLA_B from '@salesforce/resourceUrl/WestBaniyasVillaB';
import VILLA_C from '@salesforce/resourceUrl/WestBaniyasVillaC';
import { IMG_W, IMG_H, CANVAS, OVERLAY_STYLES, FACETS, AMENITIES, PIN_RANK, productOf } from './masterplanData';
import { TILES } from './tileManifest';
import { VILLA_MEDIA } from './villaMedia';

/* Keyed by Category_Type__c, which is a restricted A/B/C picklist, so these three are the whole
   set. Indexed rather than concatenated: a resourceUrl is a real import and cannot be built. */
const VILLA_BASE = { A: VILLA_A, B: VILLA_B, C: VILLA_C };
import { drawVilla } from './villaArt';
import { t, pick, dirOf, toLatinDigits, num, DEFAULT_LANG , allLabels } from 'c/adhaLabels';

const SVG_NS = 'http://www.w3.org/2000/svg';

/* Order is load-bearing: index = shard number in tileManifest.js. Hand-maintained because
   resourceUrl imports must be static, so extend this list whenever a re-bake adds shards. */
const TILE_SHARDS = [
    PLAN_TILES_0, PLAN_TILES_1, PLAN_TILES_2, PLAN_TILES_3,
    PLAN_TILES_4, PLAN_TILES_5, PLAN_TILES_6, PLAN_TILES_7,
    PLAN_TILES_8, PLAN_TILES_9, PLAN_TILES_10, PLAN_TILES_11,
    PLAN_TILES_12
];

if (TILE_SHARDS.length !== TILES.shards.length) {
    // eslint-disable-next-line no-console
    console.error(
        `masterplanUnitSelector: tileManifest has ${TILES.shards.length} shards but only ` +
        `${TILE_SHARDS.length} are imported. Tiles in the missing shards will 404. ` +
        'Add the imports for the remaining WestBaniyasPlanTiles resources.'
    );
}

/* The finest level worth loading while the map is in its overview tier. Individual plots are not
   even clickable there, so full detail buys nothing and would make first paint 38 tiles. */
const OVERVIEW_TILE_LEVEL = 2;

/* Geometry is normalised to IMG_W x IMG_H but the camera measures from CANVAS, whose origin sits
   outside that frame - absolute coordinates must cross the gap; differences must NOT. */
const geoToCanvasX = (x) => x - CANVAS.x;
const geoToCanvasY = (y) => y - CANVAS.y;
const canvasToGeoX = (x) => x + CANVAS.x;
const canvasToGeoY = (y) => y + CANVAS.y;

/* Half a source pixel of overlap between neighbours. Tiles are placed in percentages, which round
   independently, and without the bleed the seams show as hairlines at some magnifications. */
const TILE_BLEED = 0.5;

const ZOOM_MIN = 1;
const ZOOM_MAX = 20;
// Multiplicative, matching pinch, so every press feels the same. 1.35 crosses the range in ten
// presses; 1.2 keeps the wheel at a fraction of a press.
const ZOOM_FACTOR = 1.35;
const WHEEL_FACTOR = 1.2;
// Villa clicks zoom to the per-device ceiling: focusAndOpenUnit reads zoomCeiling, since a fixed
// FOCUS_ZOOM pulled phones BACK from their higher ceiling.

/* Phone ceiling, set by plot-number legibility: a phone's fitted scale is ~4x smaller, and plate
   overlap only clears near counter-scale 1.1. THE BASEMAP IS SOFT past 1:1 pixels - accepted. */
const TOUCH_ZOOM_MAX = 45;
/* Three tiers: plan (no chrome, blocks clickable) up to OVERVIEW_ZOOM, blocks captioned with
   their plot range up to PLATE_ZOOM, individual plot numbers from there. */
const OVERVIEW_ZOOM = 2.1;

/* Backstop on how far the camera may open to fill the viewport; the deepest real device needs
   3.19x, so it only bites on absurdly narrow viewports. */
const OPENING_ZOOM_MAX = 3.4;
// Not a label threshold any more - only the .far stroke weight, and the villa art below. Both are
// about what is legible at a given scale, which has not changed just because the numbers moved.
const LABEL_ZOOM = 4.5;
// Individual plot numbers. Near the ceiling on purpose: below this a villa is too small for its own
// number to be worth reading, and the range on its block is the label that actually helps.
const PLATE_ZOOM = 18;
// OFF while MODON's land-use plan is the base: it draws every villa itself, so our art doubled
// each house. Restore by setting back to 4.5; high zoom is softer with this off - accepted.
const VILLA_ART_ZOOM = Infinity;
// Ceiling on the lazily grown node pool: worst case is ~723 parcels on a portrait frame, so any
// fixed pool either wasted nodes or silently stopped drawing villas.
const VILLA_ART_MAX = 900;
const CAMERA_MS = 580;
const SEARCH_FLASH_MS = 1500;
const DRAG_THRESHOLD = 3;
/* A finger never lands still: at the mouse threshold nearly every tap read as a drag and was
   discarded. Big enough to absorb wobble, small enough that a real drag starts at once. */
const TOUCH_DRAG_THRESHOLD = 9;

// The card opens once the camera has mostly settled; shorter than the 520ms transition because
// the pan and zoom are already final, so it can be placed where the unit will land.
const DETAIL_OPEN_MS = 220;

// Card placement inside the frame.
const CARD_GAP = 14;
const CARD_MARGIN = 10;

// Number-plate geometry, viewBox units: width is a bound clamped to the parcel, height comes off
// the font so every plate holds the same shape.
/* One walkthrough per villa type; MODON's ver4 cut, verified live. MIND THE CAPITAL T: the host
   is case sensitive, so 'ver4typeA' 404s silently. Still 223-273MB master exports. */
const WALKTHROUGH_FILE = {
    A: 'ver4TypeA.mp4',
    B: 'ver4TypeB.mp4',
    C: 'ver4TypeC.mp4'
};

const BUBBLE_MIN_W = 34;
const BUBBLE_CHAR_W = 5.9;
const BUBBLE_PAD_W = 15;
// Plate height scales with its own type; a flat height made small plots read as dark blocks.
const BUBBLE_H_RATIO = 2.15;
// Only used when a unit arrives without geometry, which none of the 1,659 currently do.
const BUBBLE_H = 17;

// Amenity pins: designed at ICON_UNITS in viewBox space, then counter-scaled by the camera so
// they always occupy ICON_PX on screen.
/* Touch-only counter-scale for plot plates: PLATE_FONT_PX is the on-screen target, and the cap
   stops a plate outgrowing its parcel and reading as its neighbour's. */
/* On touch, plates show only at the ceiling (plateZoom); lower bands made them collide. The
   cluster floor has its own constant so cluster taps do not go to maximum zoom. */
const TOUCH_FIT_FLOOR = 12;
const PLATE_FONT_PX = 11;
const PLATE_SCALE_MAX = 2.6;
/* Box used to thin plates that would overlap, in screen px. Wider than tall: the numbers are long
   and it is horizontal collision that makes them unreadable. */
/* Breathing room between two plates, screen px. The footprint itself is measured per plate, so
   this is the gap and not the plate. */
const PLATE_GUTTER = 3;

const ICON_UNITS = 28;
// 17 puts the glyph at ~14.6 screen px, matching the 14px icon on the amenity tiles.
const ICON_PX = 17;

// Screen box a pin claims, CSS px, for declutterPins. Two sizes because a selected pin carries
// its name: PIN_BOX_NAMED is a width only - the height stays PIN_BOX.
const PIN_BOX = 26;
const PIN_BOX_NAMED = 128;

// Pin-local units, counter-scaled by scaleAmenityIcons; the name plate is measured from the same
// 28 units as the glyph so both halves scale together.
const PIN_NAME_DX = 20;
const PIN_NAME_FONT = 15;
const PIN_NAME_H = 26;

// One sun for the whole map, from the upper left. Every shadow the overlay draws has to agree
// with this, and so does anything baked into the base image, or the light reads as two suns.
const SHADOW_DX = 6;
const SHADOW_DY = 4;
// Amenity classes that are buildings rather than ground, so only these cast a shadow.
const BUILT_CLASSES = new Set(['mosque', 'school', 'clinic', 'retail', 'community']);

// Cluster captions, counter-scaled; TAG_PX is on-screen width and every type size scales from it.
// 96 carries a 14-character plot range, and the title is fitted so a long range shrinks.
const TAG_UNITS = 132;
const TAG_PX = 96;

/* The "Cluster N" plate, counter-scaled off the same 132-unit reference; smaller and lighter
   than the plot-range caption because 19 of these are on screen at once. */
const NUM_UNITS = 132;
const NUM_PX = 80;
const NUM_FONT = 19;
const NUM_BOX_H = 32;

/* The WestBaniyasTile0..3 quadrant tiles were withdrawn twice for layout faults the pyramid
   avoids by construction. Those resources are deleted; do not reintroduce them. */


export default class MasterplanUnitSelector extends LightningElement {
    // Supplied by Visualforce so the resource paths resolve on the host domain.
    // "data*" is a reserved attribute prefix in LWC, hence mappingUrl rather than dataUrl.
    @api mappingUrl;
    /* Walkthrough film folder from the journey. Its host must be a CSP Trusted Site with mediaSrc
       set - imgSrc alone does not cover video. Blank hides the tab. */
    @api walkthroughBaseUrl;
    // Session token issued after OTP verification. Blank runs in preview mode, where every unit
    // is eligible. An invalid token is rejected by Apex rather than downgraded to preview.
    @api sessionToken;

    /* ---------- Pinning ---------- */
    // Ops session: unit taps open the villa card with assign controls in place of Explore.
    @api opsMode = false;
    // The villa set aside for this customer; focused once on load.
    @api pinnedPlotUid;
    opsTerm = '';
    opsResults = [];
    opsSelected;
    opsTarget;
    opsBoard = [];
    opsPinsByPlot = new Map();
    opsMessage = '';
    opsConfirmingUnpin = false;
    pinnedFocusDone = false;
    /* Assign-from-card, board table, map tint. */
    opsPinning = false;
    opsUnpinning = false;
    opsBoardOpen = false;
    opsSortKey = 'age';
    opsSortAsc = true;
    opsPinsPainted = new Set();
    opsConfirmingUnpinPlot = '';
    pendingOpsBoardFocus = false;
    pendingOpsEnlargeFocus = false;

    /** The plot UID this customer holds. The server flips a held unit to Reserved, so on a later
     *  load their own villa would paint as somebody else's reservation. */
    @api
    get heldPlotUid() {
        return this.heldValue;
    }
    set heldPlotUid(value) {
        const next = value || null;
        if (next === this.heldValue) {
            return;
        }
        this.heldValue = next;
        this.heldFocused = false;
        this.markHeld();
        // canBook() exempts the held villa, so counts and wash must be redone; the setter can
        // fire either side of the first render, so this cannot be left to renderData.
        if (this.overlayReady) {
            this.applyFilters();
        }
    }
    heldValue = null;
    heldFocused = false;
    heldIndex = -1;
    // What markHeld last painted, so it can early-return on an unchanged render.
    paintedHeld = null;
    // Owned by the journey shell. A setter because the hand-built SVG overlay is never
    // re-rendered, so text already drawn into it is repainted by hand.
    @api
    get lang() {
        return this.langValue;
    }
    set lang(value) {
        const next = value || DEFAULT_LANG;
        const changed = this.langValue && this.langValue !== next;
        this.langValue = next;
        if (changed) {
            this.relabelOverlay();
            // The facet and chip labels are resolved strings held in this.facets, not getters, and
            // only this rebuilds them. Without it the filter rail stayed in the old language.
            this.refreshFacetOptions();
        }
    }
    langValue = DEFAULT_LANG;

    /** True while a journey card sits over the map: it shares the leading edge with the search
     *  HUD and filter rail, and a committing customer is not searching. */
    @api muted = false;

    /* The confirmed reservation, as a header on this component's own panel - the map owns the
       corner, so it owns the collision. Display strings because the journey formats them. */
    @api heldReference;
    @api heldDaysLabel;
    @api heldUrgent = false;

    /** Whether the held villa is committed rather than soft-held: a soft hold still needs
     *  Continue, a confirmed reservation has nothing left to continue to. */
    @api heldCommitted = false;

    /** Soft launch, stated as the closed case because an absent boolean @api is false. Mirrors
     *  ADHA_JourneyController.reservationsOpen inverted. */
    @api reservationsClosed = false;
    /** The server's refusal code, empty when reserving is possible. reservationsClosed gates only
     *  what can be TAKEN; this withholds the CTA and the additional amount. */
    @api reserveRefusal = '';

    /** From the masterplan payload, which has carried the applicant block all along. */
    get applicantName() {
        if (!this.applicant) {
            return '';
        }
        return [this.applicant.customerName, this.applicant.applicationNumber]
            .filter(Boolean)
            .join(' · ');
    }

    /** Stands down behind a journey card, like every other panel on this map. Without that it
     *  floated on top of the confirmation screen, which already names the same reservation. */
    get showHeldHeader() {
        return !!this.heldValue && !!this.heldReference && !this.muted;
    }

    get heldTitle() {
        return t(this.langValue, 'reservedShort', this.heldValue);
    }

    /** Joined here so a missing half never leaves a stray separator on screen. */
    get heldMeta() {
        return [this.heldReference, this.heldDaysLabel].filter(Boolean).join(' · ');
    }

    get heldMetaClass() {
        return this.heldUrgent ? 'held-meta urgent' : 'held-meta';
    }

    /** The reservation card belongs to the journey; this only asks for it. */
    handleHeldDetails = () => {
        this.dispatchEvent(new CustomEvent('showdetails', { bubbles: true, composed: true }));
    };

    // Read by the template, so assigning these re-renders the (small) chrome. The overlay is
    // built manually and is never touched by a re-render.
    selected;
    /* Search feedback, shown inside the panel that produced it. */
    searchMessage = '';
    toastMessage = '';
    reserving = false;
    /* The villa a committed customer has asked to swap to, held here while the journey asks them
       to confirm. Not reactive: nothing renders from it, it only survives the round trip. */
    pendingSwapUnit = null;
    zoom = 1;
    unitCount = 0;
    imageReady = false;
    overlayReady = false;
    loadError = '';
    // Rebuilt whenever a chip is clicked, so the template re-renders the chips and counts.
    facets = [];
    filtersOpen = false;
    /* Which summoned panel is on screen: '', 'search', 'amenities' or 'legend'. The filter rail
       keeps its own flag; handleTool and handleToggleFilters each close the other. */
    mapPanel = '';
    matchCount = 0;
    // Eligible AND bookable, so it excludes what someone else already has. eligibleCount comes
    // from the server and counts entitlement only, which is not what "available to you" means.
    bookableCount = 0;
    // Amenity chips are rendered by the template; the polygons they control are not.
    amenityChips = [];
    activeAmenities = [];

    // Not read by the template, so these stay off the render path entirely.
    panX = 0;
    panY = 0;
    units = [];
    unitNodes = [];
    labelNodes = [];
    /* The plate under the pointer in the band where villas are clickable but unnumbered. Held as
       the node so the paint pass can spare it. Desktop only: touch has no hover. */
    hoverPlate = null;
    /* Whether that plate was dimmed before the pointer reached it, so the search and held-villa
       dimming survives the hover rather than being silently cleared by it. */
    hoverPlateWasDim = false;
    // Which villa has its card open, so the overlay is cleared off it. Reset in renderData.
    selectedLabelIndex = -1;
    clusterNodes = [];
    unitCenters = [];
    clusterMeta = [];
    // Initialised here, not only in renderData: the lang setter can fire before the overlay is
    // built, and relabelOverlay walks these.
    clusterTags = [];
    clusterNumbers = [];
    clusterMembers = new Map();
    amenityNodes = {};
    amenityIcons = {};
    // Which pin layout is on screen, as scale plus selection. declutterPins compares against this
    // and returns early, so a drag costs nothing. Null forces the next pass to run.
    pinLayoutKey = null;
    clusterHiddenCount = 0;
    selectedClusterId = null;
    overlay;
    stageEl;
    frameEl;
    // Villa-art layer. Declared here so a camera move before the first render finds empty arrays
    // rather than undefined.
    villaGroup = null;
    villaPool = [];
    villaShown = false;
    unitRects = [];
    unitBoxes = [];
    unitPoints = [];
    dataReady = false;
    built = false;
    dragging = false;
    dragMoved = false;
    dragStartX = 0;
    dragStartY = 0;
    panStartX = 0;
    panStartY = 0;
    lastOverview = null;
    lastShowLabels = null;
    lastShowPlates = null;
    lastShowClusters = null;
    // Live touch points, keyed by pointerId. Two of them means a pinch is in progress.
    pointers = new Map();
    pinchDistance = 0;
    pinchZoom = 1;
    lastTapAt = 0;
    lastTapX = 0;
    lastTapY = 0;
    // facet key -> Set of chosen values. An absent or empty entry means "no constraint".
    selections = {};
    facetDefs = [];
    // Plot UIDs the server has refused since load. The payload is a frozen read-only
    // proxy, so the correction lives here rather than on the unit.
    taken = new Set();
    masterplan;
    eligibleCount = 0;
    /** Applicant block from getMasterplan; approvedLoanAmount lets the card show the extra cost
     *  before the customer chooses rather than after. */
    applicant;
    exploring = false;
    // The villa opens on its photography, not its plan.
    activeTab = 'exterior';
    // The walkthrough src playWalkthrough() has already started. Plain field, not @track:
    // it guards a side effect in renderedCallback and must not cause a re-render itself.
    autoplayedSrc = '';
    // The tab still waiting to be scrolled into view. Plain field for the same reason as above.
    pendingTabScroll = '';
    activeFloor = 'GF';
    areaUnit = 'sqm';
    exploreZoom = 1;
    /* How much of the opening magnification is carried by the stage's LAYOUT rather than by
       the transform. 1 on desktop, so nothing there changes at all. See fitStage. */
    layoutBoost = 1;
    /* CSS px per viewBox unit at zoom 1, WITHOUT the layout boost - reading the stage's measured
       size would fold the boost in and silently multiply the answer. */
    fitScale = 0;
    /* How far out this device may zoom. The whole plan on a phone is a 98px strip in a 664px
       frame, so the opening view is also the way out. 1 on desktop, which is unchanged. */
    zoomFloor = ZOOM_MIN;
    /* Keyed on the URL, not the tab, so changing tab or unit re-arms the spinner and a slow
       image cannot clear the new tab's loading state. */
    mediaLoaded;
    mediaFailed;
    /* Gallery position, reset when the tab or villa changes - the counts differ per type, so a
       carried index would land out of range. */
    galleryIndex = 0;
    stageFitted = false;
    resizeHandler;
    keyHandler;
    // pendingCardIndex is a one-shot "place it on the next render"; cardIndex is which unit the
    // open card belongs to, so zooming keeps it glued to that unit.
    pendingCardIndex = -1;
    cardIndex = -1;
    cameraTimer;
    searchTimer;
    toastTimer;
    detailOpenTimer;

    // All geometry comes from ADHA_Unit__c. The static resource is still loaded because the
    // cluster names are read from it, and the overlay cannot be built until both have arrived.
    connectedCallback() {
        this.loadMasterplan();
        // A customer who leaves the tab open over lunch comes back to a map from before lunch.
        this.visibilityHandler = () => {
            if (document.hidden) {
                this.stopAvailabilityPoll();
            } else {
                this.refreshAvailability();
                this.startAvailabilityPoll();
            }
        };
        document.addEventListener('visibilitychange', this.visibilityHandler);
        // Started here, not from the first response: that refresh bails before the overlay
        // exists, so the poll never ran.
        this.startAvailabilityPoll();
    }

    /** Retry after a failed load. The veil is opaque and blocking, so this is the only way off it. */
    handleRetryLoad() {
        this.loadError = '';
        this.loadMasterplan();
    }

    loadMasterplan() {
        Promise.all([
            loadScript(this, this.mappingUrl || MASTERPLAN_DATA),
            // Amenities are decoration on top of a working map, so a failure to load them must
            // not take the map down with it.
            loadScript(this, AMENITY_DATA).catch(() => undefined),
            // Same treatment: without bearings the villas fall back to the minimum-area rectangle
            // and face an arbitrary way, which is worse than today but still a working map.
            loadScript(this, VILLA_BEARINGS).catch(() => undefined),
            // build: bumped whenever the payload gains fields OR the ops paint changes, so no
            // browser can serve a cached response from before they existed. A stale ops payload
            // carries reserveStock:false on every unit, which paints the whole map fill:none -
            // indistinguishable from a broken map, so the key must move with the paint too.
            getMasterplanFor({ sessionToken: this.sessionToken, build: 'cr012' })
        ])
            .then(([, , , data]) => {
                this.masterplan = data;
                this.dataReady = true;
                this.buildIfReady();
                // Journey stage 4. getMasterplan is cacheable and cannot write, so the stage is
                // stamped separately - without it ADHA's daily "Exploring units" count is unproducible.
                if (this.sessionToken) {
                    markExploring({ token: this.sessionToken }).catch(() => {
                        // Reporting only. A failure here must never block the map.
                    });
                }
                // getMasterplan is cached, so what just painted may be hours old. Correct it before
                // the customer has had time to choose anything from it.
                this.refreshAvailability();
            })
            .catch((error) => {
                // messageOf resolves an Apex MSG_* code; anything else is already prose.
                this.loadError = this.messageOf(error) || t(this.langValue, 'MSG_GENERIC');
            });
    }

    renderedCallback() {
        this.buildIfReady();
        this.fitStage();

        this.paintVilla();
        this.markHeld();
        this.revealActiveTab();

        if (!this.resizeHandler) {
            this.resizeHandler = () => {
                this.fitStage(true);
                this.paintVilla(true);
            };
            window.addEventListener('resize', this.resizeHandler);
        }

        // Escape leaves explore. Bound on window rather than the section because focus is
        // usually on the map or nothing at all when the customer reaches for it.
        if (!this.keyHandler) {
            this.keyHandler = (event) => {
                if (event.key !== 'Escape') {
                    return;
                }
                // Innermost first: the ops board sheet, a panel over the map, then the map.
                if (this.opsBoardOpen) {
                    this.closeOpsBoard(true);
                } else if (this.mapPanel) {
                    this.mapPanel = '';
                } else if (this.filtersOpen) {
                    this.filtersOpen = false;
                } else if (this.exploring) {
                    this.handleBackToCommunity();
                }
            };
            window.addEventListener('keydown', this.keyHandler);
        }

        // The tile layer is a manual host, so it can only be populated once it has rendered.
        this.initTiles();

        this.playWalkthrough();

        // The card is rendered by lwc:if, so it exists only from this point on.
        if (this.pendingCardIndex >= 0) {
            const index = this.pendingCardIndex;
            this.pendingCardIndex = -1;
            this.positionCard(index);
        }

        // One-shot focus moves for the ops board sheet - the nodes exist only after render.
        if (this.pendingOpsBoardFocus) {
            this.pendingOpsBoardFocus = false;
            const close = this.template.querySelector('.ops-sheet-close');
            if (close) {
                close.focus();
            }
        }
        if (this.pendingOpsEnlargeFocus) {
            this.pendingOpsEnlargeFocus = false;
            const enlarge = this.template.querySelector('.ops-enlarge');
            if (enlarge) {
                enlarge.focus();
            }
        }
    }

    disconnectedCallback() {
        this.stopAvailabilityPoll();
        if (this.visibilityHandler) {
            document.removeEventListener('visibilitychange', this.visibilityHandler);
        }
        if (this.viewFrame) {
            cancelAnimationFrame(this.viewFrame);
            this.viewFrame = 0;
        }
        clearTimeout(this.cameraTimer);
        clearTimeout(this.searchTimer);
        clearTimeout(this.toastTimer);
        clearTimeout(this.detailOpenTimer);
        clearTimeout(this.boostTimer);
        if (this.resizeHandler) {
            window.removeEventListener('resize', this.resizeHandler);
        }
        if (this.keyHandler) {
            window.removeEventListener('keydown', this.keyHandler);
        }
        this.hoverPlate = null;
    }

    /** Sizes the stage to the render's aspect fitted in the viewport, and centres it with pan -
     *  the stage sits at the frame origin, so centring is pan, not CSS offset. */
    fitStage(force) {
        const frame = this.frame;
        const stage = this.stage;
        if (!frame || !stage || !frame.clientWidth) {
            return;
        }
        if (this.stageFitted && !force) {
            return;
        }
        const fit = Math.min(frame.clientWidth / CANVAS.w, frame.clientHeight / CANVAS.h);

        /* The opening magnification goes into the stage's SIZE, not the transform: magnifying the
           transform stretched a tiny raster and the map was soft on phones. Desktop boost is 1. */
        this.fitScale = fit;
        this.zoomFloor = this.openingZoom(frame, fit) || ZOOM_MIN;
        this.layoutBoost = Math.min(this.zoomFloor, this.maxLayoutBoost(fit));
        stage.style.width = `${CANVAS.w * fit * this.layoutBoost}px`;
        stage.style.height = `${CANVAS.h * fit * this.layoutBoost}px`;

        // Recentre only on the first fit or a resize; a resize mid-journey should not yank the
        // camera away from whatever the customer was looking at.
        if (!this.stageFitted) {
            this.zoom = this.zoomFloor;
            this.panX = (frame.clientWidth - CANVAS.w * fit * this.zoom) / 2;
            this.panY = (frame.clientHeight - CANVAS.h * fit * this.zoom) / 2;
        }
        this.stageFitted = true;
        this.applyView();
    }

    /** Where the camera starts: filled on every device - fitting left half a laptop screen black.
     *  Covering crops the ends on narrow screens, weighed and accepted; zoomFloor rebases the rest. */
    openingZoom(frame, fitScale) {
        const cover = Math.max(frame.clientWidth / CANVAS.w, frame.clientHeight / CANVAS.h);
        return Math.max(ZOOM_MIN, Math.min(cover / fitScale, OPENING_ZOOM_MAX));
    }

    /** Keeps the map covering the viewport: pan is bounded so no edge can be dragged inside the
     *  frame, and a smaller axis is locked centred. */
    /** How much magnification moves from the transform into the layout: a tile laid out small
     *  keeps its rasterised resolution. Capped at one image pixel per device pixel. */
    maxLayoutBoost(fit) {
        const dpr = window.devicePixelRatio || 1;
        return Math.max(1, TILES.image.w / dpr / (CANVAS.w * fit));
    }

    /** Where plot numbers start. On touch that is the ceiling and nowhere below it: anywhere
     *  shallower, the counter-scale inflates each plate past its own parcel and they collide. */
    get plateZoom() {
        return this.touchDevice ? TOUCH_ZOOM_MAX : PLATE_ZOOM;
    }

    get showPlates() {
        return this.zoom >= this.plateZoom;
    }

    /** The cluster tier, expressed against zoomFloor rather than a flat OVERVIEW_ZOOM - the
     *  camera opens filled, so a flat threshold could sit below what phones can reach. */
    get showClusters() {
        return this.zoom <= Math.max(OVERVIEW_ZOOM, this.zoomFloor * 1.08);
    }

    get zoomCeiling() {
        return this.touchDevice ? TOUCH_ZOOM_MAX : ZOOM_MAX;
    }

    get touchDevice() {
        return !!(window.matchMedia && window.matchMedia('(pointer: coarse)').matches);
    }

    /** Re-lays the stage out at the reached zoom. Visually a no-op (size times boost, transform
     *  divides it back), so it costs a reflow and hands the raster its full resolution. */
    commitLayoutBoost = () => {
        const stage = this.stage;
        if (!stage || !this.fitScale) {
            return;
        }
        // Mid-flight the transform is being transitioned; re-laying out under it would jump.
        if (stage.classList.contains('camera-animating') || stage.classList.contains('search-animating')) {
            this.scheduleLayoutBoost();
            return;
        }
        // No cap: the tile cap is right for the basemap and wrong for the vector plot numbers,
        // which were GPU-stretched soft above it. See the will-change note in the stylesheet.
        const target = Math.max(1, this.zoom);
        if (Math.abs(target - this.layoutBoost) < 0.05) {
            return;
        }
        this.layoutBoost = target;
        stage.style.width = `${CANVAS.w * this.fitScale * target}px`;
        stage.style.height = `${CANVAS.h * this.fitScale * target}px`;
        this.applyView();
    };

    scheduleLayoutBoost() {
        clearTimeout(this.boostTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.boostTimer = setTimeout(this.commitLayoutBoost, 260);
    }

    /** The scale the transform applies. this.zoom stays in fitted-scale units for the thresholds;
     *  everything else works from fitScale, so the boost never leaks into camera maths. */
    get renderScale() {
        return this.zoom / (this.layoutBoost || 1);
    }

    clampPan() {
        const frame = this.frame;
        const stage = this.stage;
        if (!frame || !stage || !stage.clientWidth) {
            return;
        }
        const w = CANVAS.w * this.fitScale * this.zoom;
        const h = CANVAS.h * this.fitScale * this.zoom;
        const fw = frame.clientWidth;
        const fh = frame.clientHeight;

        this.panX = w <= fw ? (fw - w) / 2 : Math.min(0, Math.max(fw - w, this.panX));
        this.panY = h <= fh ? (fh - h) / 2 : Math.min(0, Math.max(fh - h, this.panY));
    }

    // Where the camera sits when fully zoomed out.
    get homeView() {
        const frame = this.frame;
        // At the floor, not the fitted extent: the floor is the opening view and the extent is
        // not reachable.
        const k = this.fitScale * this.zoomFloor;
        return {
            panX: (frame.clientWidth - CANVAS.w * k) / 2,
            panY: (frame.clientHeight - CANVAS.h * k) / 2
        };
    }

    /* ---------- template bindings ---------- */

    // Not the map any more - that is the tile pyramid. This is the same sheet downscaled, used as
    // the explore-panel backdrop and as the fallback if the tiles cannot load.
    get imageUrl() {
        return MASTERPLAN_REAL;
    }

    // No darkening. The cad-base scrim existed to lift overlay colours off pale CAD paper; MODON's
    // plan is already saturated and graded, and the wash only made it muddy.
    get scrimClass() {
        return 'stage-scrim';
    }

    get unitCountLabel() {
        return num(this.unitCount);
    }

    /** Against zoomFloor, not ZOOM_MIN: the camera can never reach 1, so a ZOOM_MIN test kept the
     *  button on screen doing nothing. */
    get zoomedIn() {
        return this.zoom > this.zoomFloor * 1.01;
    }

    // The map is usable only once the image has painted and the overlay is built. The veil stays
    // in the DOM and fades, rather than being removed, so the transition can run.
    get notReady() {
        return !this.imageReady || !this.overlayReady;
    }

    get veilClass() {
        return this.notReady || this.loadError ? 'veil' : 'veil done';
    }

    get dir() {
        return dirOf(this.langValue);
    }

    // Everything the template reads as static text. One object rather than a getter per string.
    get labels() {
        return allLabels(this.langValue);
    }

    // The arrow has to point back the way the language reads, or "back" points forward.
    get backLabel() {
        const arrow = this.dir === 'rtl' ? '→' : '←';
        return `${arrow} ${t(this.langValue, 'backToCommunity')}`;
    }

    get loadingMessage() {
        if (!this.dataReady) {
            return t(this.langValue, 'loadingUnits');
        }
        if (!this.overlayReady) {
            return t(this.langValue, 'loadingMapped');
        }
        return t(this.langValue, 'loadingImage');
    }

    get selectedUnit() {
        return this.selected;
    }

    get hasSelection() {
        return Boolean(this.selected);
    }

    get badgeClass() {
        if (this.opsMode && this.selected) {
            if (this.opsCardPin) {
                return 'badge pinned';
            }
            if (this.opsCardAssignable) {
                return 'badge reserve';
            }
            // Live from status, not the frozen statusKey, so a villa taken mid-assign re-badges.
            return `badge ${this.statusClass(this.selected.status)}`;
        }
        return `badge ${this.selected ? this.selected.statusKey : ''}`;
    }

    /** The plan distinguishes available from taken again, so the card has to agree with it. */
    get showStatusBadge() {
        return Boolean(this.selected);
    }

    // detailRows was here and was dead - the template has bound cardRows since the two-stage card
    // landed. Deleted rather than translated: nine strings that nothing renders.

    get showProvisionalNote() {
        return Boolean(this.selected && this.selected.provisional);
    }

    /** Same figure and conditions as cardRows, soft-launch withholding included - two screens
     *  must not disagree about what a customer owes. */
    get showExploreExtra() {
        const unit = this.selected;
        return Boolean(
            !this.reservationsClosed && unit && unit.additional != null && unit.additional > 0
        );
    }

    get exploreExtraValue() {
        return this.selected ? this.formatAed(this.selected.additional) : '';
    }

    /* ---------- two-stage selection ---------- */

    // Stage 1: the anchored card. Stage 2 covers the map, so only one shows at a time.
    get showCard() {
        return Boolean(this.selected) && !this.exploring;
    }

    // The card stays deliberately short - enough to decide whether to explore.
    /** Bookable, or the customer's own villa - which the server has already flipped to Reserved. */
    get selectDisabled() {
        // Before everything else: during soft launch no villa is bookable, held or not.
        if (this.reservationsClosed) {
            return true;
        }
        if (this.reserveRefusal) {
            return true;
        }
        const unit = this.selected;
        const isHeld = !!this.heldValue && unit && unit.plotUid === this.heldValue;
        if (unit && this.taken.has(unit.plotUid) && !isHeld) {
            return true;
        }
        // Already theirs and already committed. Exploring it is still welcome; taking it again is
        // not an action that exists.
        if (isHeld && this.heldCommitted) {
            return true;
        }
        return !unit || (!unit.selectable && !isHeld) || this.reserving;
    }

    /** The lapsed window and spent attempts, where the map looks normal but nothing is takeable;
     *  soft launch keeps its own wording, so it is excluded. */
    get reserveRefused() {
        return !!this.reserveRefusal && !this.reservationsClosed;
    }

    get reserveRefusalMessage() {
        return this.reserveRefused ? t(this.langValue, this.reserveRefusal) : '';
    }

    /** Hidden rather than disabled-with-a-label. "Unavailable" would blame the villa for something
     *  that applies to every villa on the map, and the reason is stated in the note instead. */
    get showSelectCta() {
        return !this.reserveRefused;
    }

    get selectLabel() {
        // Ahead of the taken check: "Unavailable" would blame the villa for a gate that applies
        // to every villa on the map.
        if (this.reservationsClosed) {
            return t(this.langValue, 'reservationsClosedCta');
        }
        // Ahead of unitUnavailable, which would tell a customer their own villa is not available.
        const unit = this.selected;
        if (this.heldCommitted && unit && unit.plotUid === this.heldValue) {
            return t(this.langValue, 'unitAlreadyYours');
        }
        return t(this.langValue, this.selectDisabled && !this.reserving ? 'unitUnavailable' : 'continueWithUnit');
    }

    /** Cost on top of the approval; mirrors ADHA_ReservationService.additionalFor exactly so the
     *  two screens agree. Null when the approval is unknown, so the row is omitted. */
    additionalFor(price) {
        const approved = this.applicant && this.applicant.approvedLoanAmount;
        if (price == null || approved == null) {
            return null;
        }
        return price > approved ? price - approved : 0;
    }

    get cardRows() {
        const unit = this.selected;
        const l = this.langValue;
        // Price first - it was missing entirely. The tier code and planNo are dropped: internal,
        // explained nowhere, and they had the place price should have had.
        const rows = [
            { label: t(l, 'totalPrice'), value: unit.price, cls: 'detail-row' }
        ];
        // Under the price, only when there is something to pay. Withheld during soft launch: a
        // personal figure about a purchase that cannot happen yet.
        if (!this.reservationsClosed && unit.additional != null && unit.additional > 0) {
            rows.push({
                label: t(l, 'extraToPay'),
                value: this.formatAed(unit.additional),
                cls: 'detail-row extra'
            });
        }
        // Marked secondary because the phone sheet drops them: all three are shown in full on the
        // Explore view, and on a phone the card has to leave the plot visible behind it.
        rows.push(
            { label: t(l, 'type'), value: pick(l, unit.type), cls: 'detail-row secondary' },
            { label: t(l, 'bedrooms'), value: unit.bedrooms, cls: 'detail-row secondary' },
            { label: t(l, 'gsa'), value: this.formatArea(unit.bua), cls: 'detail-row secondary' }
        );
        return rows;
    }

    // Media is supplied by villa type rather than per unit, so these resolve against
    // ADHA_Villa_Type__mdt once ADHA delivers the assets.
    get tabDefs() {
        const l = this.langValue;
        // Stills, then the plan, then the film. Exterior stays the opening tab.
        const tabs = [
            { key: 'exterior', label: t(l, 'exterior') },
            { key: 'interior', label: t(l, 'interior') },
            { key: 'floorplan', label: t(l, 'floorPlan') }
        ];
        // Last, and only when there is actually a film for this villa's type: a tab that opens on
        // nothing is worse than no tab.
        if (this.walkthroughSrc) {
            tabs.push({ key: 'walkthrough', label: t(l, 'walkthrough') });
        }
        return tabs;
    }

    get mediaTabs() {
        return this.tabDefs.map((t) => ({
            ...t,
            cls: t.key === this.activeTab ? 'tab active' : 'tab',
            barCls: t.key === this.activeTab ? 'bar-btn active' : 'bar-btn'
        }));
    }

    /* ---------- explore media ---------- */

    /** The villa's media set, or null. typeOf() falls back to 'Villa' when unmapped, and that
     *  must not become a path - it would 404 and flash the spinner first. */
    get mediaSet() {
        const unit = this.selected;
        const cat = unit && unit.category;
        const type = unit && unit.type;
        if (!cat || !type || type === 'Villa') {
            return null;
        }
        const set = VILLA_MEDIA[String(cat).toUpperCase()];
        return set ? { ...set, base: VILLA_BASE[String(cat).toUpperCase()], type } : null;
    }

    /** Pictures per tab, in gallery order. Exteriors filter to the villa's own style, interiors
     *  are shared per category, and floor plans are not a gallery so that tab returns empty. */
    tabImages(tab) {
        const set = this.mediaSet;
        if (!set) {
            return [];
        }
        if (tab === 'exterior') {
            const style = String(set.type).toLowerCase();
            return set.exterior.filter((name) => name.startsWith(style + '-'))
                .map((name) => ({ src: `${set.base}/exterior/${name}.webp` }));
        }
        if (tab === 'interior') {
            return set.interior.map((entry) => ({
                src: `${set.base}/interior/${entry.f}.webp`,
                room: entry.room,
                n: entry.n
            }));
        }
        return [];
    }

    /** Where the current tab's picture lives, or undefined if there is none. */
    mediaUrl(tab) {
        const set = this.mediaSet;
        if (!set) {
            return undefined;
        }
        if (tab === 'walkthrough') {
            return this.walkthroughSrc;
        }
        if (tab === 'floorplan') {
            // Only the drawn fallback has a roof, so anything that is not the first floor is ground.
            return `${set.base}/plan/${this.activeFloor === '1F' ? 'first' : 'ground'}.jpg`;
        }
        const images = this.tabImages(tab);
        if (!images.length) {
            return undefined;
        }
        return images[Math.min(this.galleryIndex, images.length - 1)].src;
    }

    /* One film per villa TYPE, not per plot - the same as the renders, which are also supplied per
       type. Category is the A/B/C key the rest of the media already resolves on. */
    get walkthroughSrc() {
        const cat = this.selected && this.selected.category;
        const file = cat ? WALKTHROUGH_FILE[String(cat).toUpperCase()] : null;
        if (!file || !this.walkthroughBaseUrl) {
            return undefined;
        }
        return `${String(this.walkthroughBaseUrl).replace(/\/+$/, '')}/${file}`;
    }

    get mediaSrc() {
        return this.mediaUrl(this.activeTab);
    }

    get isWalkthroughTab() {
        return this.activeTab === 'walkthrough';
    }

    /** Starts the film with sound on; browsers often refuse unmuted autoplay (Safari near enough
     *  always), so a refusal falls back to a muted play with controls on. Keyed on src. */
    playWalkthrough() {
        const video = this.template.querySelector('.walkthrough-video');
        if (!video) {
            this.autoplayedSrc = '';
            return;
        }
        if (this.autoplayedSrc === video.src) {
            return;
        }
        this.autoplayedSrc = video.src;
        video.muted = false;
        const withSound = video.play();
        if (!withSound || !withSound.catch) {
            return;
        }
        withSound.catch(() => {
            video.muted = true;
            const silent = video.play();
            if (silent && silent.catch) {
                // Nothing left to try. The poster and the controls are both still there.
                silent.catch(() => {});
            }
        });
    }

    /* Not autoplayed or preloaded: they press play or nothing is fetched. The poster is the
       villa's own elevation, so the plate is never empty. */
    get walkthroughPoster() {
        const shots = this.tabImages('exterior');
        return shots.length ? shots[0].src : undefined;
    }

    /** The drawn villa is the fallback, so it shows only when there is no asset or it failed. */
    get showDrawnVilla() {
        const src = this.mediaSrc;
        return !src || this.mediaFailed === src;
    }

    get showMediaImage() {
        return !this.showDrawnVilla && !this.isWalkthroughTab;
    }

    /* Shares showDrawnVilla with the images, so a missing or broken film falls back to the drawn
       villa exactly as a missing render does, rather than leaving a black rectangle. */
    get showWalkthroughVideo() {
        return this.isWalkthroughTab && !this.showDrawnVilla;
    }

    /** Spinner until this exact URL reports back. A different URL means pending again. */
    get mediaPending() {
        const src = this.mediaSrc;
        return Boolean(src) && this.mediaLoaded !== src && this.mediaFailed !== src;
    }

    get mediaImgClass() {
        return this.mediaLoaded === this.mediaSrc ? 'media-img ready' : 'media-img';
    }

    get mediaAlt() {
        return t(this.langValue, `alt${this.activeTab}`, pick(this.langValue, this.selected.type));
    }

    /* ---------- the gallery ---------- */

    /** The current tab's pictures. Floor plans are not one of them - see tabImages. */
    get galleryImages() {
        return this.tabImages(this.activeTab);
    }

    /** Clamped, because the tabs have different lengths and so do the three villa types. */
    get galleryAt() {
        const images = this.galleryImages;
        return images.length ? Math.min(this.galleryIndex, images.length - 1) : 0;
    }

    /* Any tab with more than one picture earns the control - two exterior views, or twelve to
       nineteen interiors depending on the type. It used to be interiors only, and hardcoded at two. */
    get showGallery() {
        return this.galleryImages.length > 1 && this.showMediaImage;
    }

    get galleryCount() {
        return t(this.langValue, 'imageCount', num(this.galleryAt + 1), num(this.galleryImages.length));
    }

    /** Only interiors name a room. The number is appended rather than baked into the string to
     *  sidestep Arabic's six plural forms, matching the rest of this file. */
    get galleryRoom() {
        const image = this.galleryImages[this.galleryAt];
        if (!image || !image.room) {
            return '';
        }
        const key = 'room' + image.room.charAt(0).toUpperCase() + image.room.slice(1);
        const label = t(this.langValue, key);
        return image.n ? t(this.langValue, 'roomNumbered', label, num(image.n)) : label;
    }

    get hasGalleryRoom() {
        return !!this.galleryRoom;
    }

    /* getAttribute, not .src: the property resolves absolute while mediaSrc is relative, so
       comparing .src never matched and the spinner sat there for ever. */
    handleMediaLoad = (event) => {
        this.mediaLoaded = event.target.getAttribute('src');
    };

    handleMediaError = (event) => {
        // Falls through to the drawn villa rather than leaving a broken image behind.
        this.mediaFailed = event.target.getAttribute('src');
    };

    /* Both wrap. With nineteen interiors on a type C villa, running off the end and stopping would
       leave the customer pressing a dead button with no way back but the other arrow. */
    handleGalleryNext = () => {
        const n = this.galleryImages.length;
        this.galleryIndex = n ? (this.galleryAt + 1) % n : 0;
    };

    handleGalleryPrev = () => {
        const n = this.galleryImages.length;
        this.galleryIndex = n ? (this.galleryAt - 1 + n) % n : 0;
    };

    /* ---------- explore view ---------- */

    // Every villa is two storeys, so the plan set is ground, first and roof.
    /* ---------- drawn villa imagery ---------- */

    // renderedCallback fires on every reactive change, and a redraw is a full canvas repaint,
    // so the signature gates it down to the four things the drawing actually depends on.
    paintVilla(force) {
        if (!this.exploring || !this.showDrawnVilla) {
            this.villaSig = null;
            return;
        }
        const canvas = this.template.querySelector('.villa-art');
        if (!canvas) {
            return;
        }
        const box = canvas.getBoundingClientRect();
        if (!box.width || !box.height) {
            return;
        }
        const sig = [
            this.activeTab,
            this.activeFloor,
            this.langValue,
            Math.round(box.width),
            Math.round(box.height)
        ].join('|');
        if (!force && sig === this.villaSig) {
            return;
        }
        this.villaSig = sig;
        drawVilla(canvas, this.activeTab, this.activeFloor, this.langValue, t);
    }

    get floors() {
        // ADHA supplied ground and first only. The roof exists on the drawn fallback alone, so it
        // is offered only when that is what is on screen.
        const keys = this.showDrawnVilla ? ['RF', '1F', 'GF'] : ['1F', 'GF'];
        return keys.map((key) => ({
            key,
            cls: key === this.activeFloor ? 'floor-btn active' : 'floor-btn'
        }));
    }

    get showFloors() {
        return this.activeTab === 'floorplan';
    }

    // Named on the drawing itself: the areas and the bedroom count are ADHA's, the internal
    // arrangement is not, and the customer must not read it as the approved layout.
    get indicativeLabel() {
        const type = pick(this.langValue, this.selected.type);
        // Split by tab since 22 Aug: Comms' plan caption is wrong over a photograph, and the
        // photo tabs say the render is of the villa TYPE, not the plot being booked.
        if (!this.showDrawnVilla) {
            return this.activeTab === 'floorplan'
                ? t(this.langValue, 'suppliedPlan')
                : t(this.langValue, 'suppliedAsset', type);
        }
        return this.activeTab === 'floorplan'
            ? t(this.langValue, 'indicativePlan', type)
            : t(this.langValue, 'awaitingAsset', type);
    }

    get plotTitle() {
        // The number alone. "Plot WB4_03-405" said the same thing twice, and the prefix pushed
        // the part that identifies the villa off the edge on a narrow screen.
        return this.selected.unitId;
    }

    get selectedStatusLabel() {
        if (this.opsMode && this.selected) {
            if (this.opsCardPin) {
                return t(this.langValue, 'opsPinnedBadge');
            }
            // The working pool reads as reserve stock, not as somebody's reservation.
            if (this.opsCardAssignable) {
                return t(this.langValue, 'opsReserveStock');
            }
            // Available on paper but not assignable: the badge is the only explanation ops gets.
            if (this.statusClass(this.selected.status) === 'available') {
                return t(this.langValue, 'opsNotAssignable');
            }
        }
        return pick(this.langValue, this.selected.status);
    }

    get selectedTypeLabel() {
        return pick(this.langValue, this.selected.type);
    }

    // The community map, blurred, stands in for the render backdrop until ADHA supplies one.
    get exploreBgStyle() {
        return `background-image:url(${this.imageUrl})`;
    }

    get exploreMediaStyle() {
        // A custom property, not a transform on the plate: scaling the plate carried the caption
        // and floor switch off with the picture.
        return `--ez:${this.exploreZoom}`;
    }

    get sqmClass() {
        return this.areaUnit === 'sqm' ? 'u on' : 'u';
    }

    get sqftClass() {
        return this.areaUnit === 'sqft' ? 'u on' : 'u';
    }

    get gsaValue() {
        return this.formatArea(this.selected && this.selected.bua);
    }

    get areaUnitLabel() {
        return t(this.langValue, this.areaUnit);
    }

    get plotAreaValue() {
        return this.formatArea(this.selected && this.selected.plotArea);
    }

    // Stored in square metres; sqft is derived so only one number is ever authoritative.
    formatArea(sqm) {
        if (sqm == null) {
            return 'TBC';
        }
        const value = this.areaUnit === 'sqft' ? Number(sqm) * 10.7639 : Number(sqm);
        // Latin digits regardless of UI language - see the digit note in c/adhaLabels.
        return num(value, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }

    handleAreaUnit = (event) => {
        event.stopPropagation();
        this.areaUnit = event.currentTarget.dataset.unit;
    };

    handleFloor = (event) => {
        event.stopPropagation();
        this.activeFloor = event.currentTarget.dataset.floor;
    };

    handleExploreZoomIn = () => {
        this.exploreZoom = Math.min(3, this.exploreZoom + 0.25);
    };

    handleExploreZoomOut = () => {
        this.exploreZoom = Math.max(1, this.exploreZoom - 0.25);
    };

    handleTab(event) {
        event.stopPropagation();
        this.activeTab = event.currentTarget.dataset.tab;
        // A tab tapped while half out of view has to finish arriving, or the customer is left
        // reading a label that is still cut by the edge they tapped at.
        this.pendingTabScroll = this.activeTab;
        // Each tab is its own gallery of its own length; carrying position between them would open
        // the exterior at picture 9 of 2.
        this.galleryIndex = 0;
    }

    handleExplore(event) {
        event.stopPropagation();
        // Reset per open, so a customer who left the last villa on the plan still opens the next
        // one on its photography.
        this.activeTab = 'exterior';
        this.pendingTabScroll = 'exterior';
        this.activeFloor = 'GF';
        this.galleryIndex = 0;
        this.exploring = true;
        this.warmMedia();
        this.recordExplored();
    }

    /** Scrolls the active tab fully into view. Rect maths and scrollBy, not scrollLeft: RTL
     *  scrollLeft has three sign conventions across engines, and scrollIntoView can move the page. */
    revealActiveTab() {
        const key = this.pendingTabScroll;
        if (!key) {
            return;
        }
        const bar = this.template.querySelector('.explore-bar');
        const pill = bar && bar.querySelector(`.bar-btn[data-tab="${key}"]`);
        if (!pill) {
            return;
        }
        this.pendingTabScroll = '';
        // Desktop: the bar is centred and absolutely positioned, and never scrolls.
        if (bar.scrollWidth <= bar.clientWidth) {
            return;
        }
        const barBox = bar.getBoundingClientRect();
        const pillBox = pill.getBoundingClientRect();
        const pad = 12;
        let delta = 0;
        if (pillBox.left < barBox.left + pad) {
            delta = pillBox.left - barBox.left - pad;
        } else if (pillBox.right > barBox.right - pad) {
            delta = pillBox.right - barBox.right + pad;
        }
        // Only when it is actually clipped, and only by as much as it is clipped: centring the
        // first tab would drag it off the leading edge and open a gap where nothing is.
        if (delta) {
            bar.scrollBy({ left: delta });
        }
    }

    /** One row per explore press, for ADHA's reporting. Fire and forget and silent - a browsing
     *  customer must never see it fail. */
    recordExplored() {
        const plotUid = this.selected && this.selected.plotUid;
        if (!plotUid || !this.sessionToken) {
            return;
        }
        markUnitExplored({ token: this.sessionToken, plotUid }).catch(() => {
            // Reporting only. Never surfaces.
        });
    }

    /** Prefetches the unopened tabs so switching is usually instant. Not awaited and silent; a
     *  failed warm just means the spinner shows. */
    warmMedia() {
        ['exterior', 'interior'].forEach((tab) => {
            const src = this.mediaUrl(tab);
            if (src) {
                const img = new Image();
                img.src = src;
            }
        });
    }

    // The map is only covered, never unmounted, so zoom and pan survive the round trip.
    handleBackToCommunity(event) {
        if (event) {
            event.stopPropagation();
        }
        this.exploring = false;
        // Re-anchor the card to its unit on the next render.
        this.pendingCardIndex = this.cardIndex;
    }

    get frame() {
        if (!this.frameEl) {
            this.frameEl = this.template.querySelector('.frame');
        }
        return this.frameEl;
    }

    get stage() {
        if (!this.stageEl) {
            this.stageEl = this.template.querySelector('.stage');
        }
        return this.stageEl;
    }

    get showSearchHud() {
        return !this.muted && this.mapPanel === 'search';
    }

    get showAmenityBar() {
        return !this.muted && this.mapPanel === 'amenities' && this.amenityChips.length > 0;
    }

    /* Hidden while a reservation is being confirmed or a unit card is open - on a phone the card
       is a bottom sheet in exactly this space. */
    get showTools() {
        return !this.muted && !this.showCard;
    }

    /** Identity and reservation share one card; the shell renders when either half has something
     *  to say, the hairline only when both do. */
    get showIdCard() {
        return this.showTools || this.showHeldHeader;
    }

    get showIdDivide() {
        return this.showTools && this.showHeldHeader;
    }

    /** Muted means the journey has a panel over the map, and Zoom out does not belong on top of
     *  a reservation screen. */
    get showZoomOut() {
        return this.zoomedIn && !this.muted;
    }

    /** Both zoom pills, hidden while muted. Not on the walkthrough: they zoom a still and only
     *  sat on the video's corner. */
    get showZoomControls() {
        return !this.muted && !this.isWalkthroughTab;
    }

    toolClass(panel) {
        return `tool${this.mapPanel === panel ? ' on' : ''}`;
    }

    get searchToolClass() {
        return this.toolClass('search');
    }

    get amenitiesToolClass() {
        return this.toolClass('amenities');
    }

    /* Filters lives in the rail, not in mapPanel, so its active state reads the rail's flag. */
    get filtersToolClass() {
        return `tool${this.filtersOpen ? ' on' : ''}${this.anyFilter ? ' has-filters' : ''}`;
    }

    /* Tapping the open tool closes it, which is what a customer expects of a toggle. */
    handleTool = (event) => {
        const panel = event.currentTarget.dataset.panel;
        if (panel === 'filters') {
            this.mapPanel = '';
            this.filtersOpen = !this.filtersOpen;
            return;
        }
        this.filtersOpen = false;
        this.mapPanel = this.mapPanel === panel ? '' : panel;
    };

    handleClosePanel = () => {
        this.mapPanel = '';
    };

    get showFilterRail() {
        return this.filtersOpen && !this.muted;
    }

    get clusterCount() {
        // Clusters actually drawn, not all 21, and no WB_CLUSTERS fallback - either would
        // contradict what is on screen.
        return this.clusterMeta.length;
    }

    /* ---------- keeping the inventory current ---------- */

    availabilityTimer = 0;
    availabilityInFlight = false;
    availabilityLoaded = false;
    /** Overwritten by the first response. Defaulted so a focus event before that still polls. */
    availabilitySeconds = 60;

    /** Re-reads which villas are free and repaints the difference - availability was frozen into
     *  the cached masterplan payload. Silent by design. */
    refreshAvailability() {
        if (!this.sessionToken || this.availabilityInFlight || !this.units || !this.units.length) {
            return;
        }
        this.availabilityInFlight = true;
        getAvailability({ sessionToken: this.sessionToken })
            .then((result) => {
                if (!result) {
                    return;
                }
                this.applyAvailability(result.taken || []);
                this.availabilityLoaded = true;
                // The server owns the cadence, so changing the setting takes effect on the next
                // poll rather than the next page load.
                this.availabilitySeconds = result.pollSeconds;
                this.startAvailabilityPoll();
            })
            .catch(() => {
                // Left as it was. A stale map is worse than a fresh one and better than a broken one.
            })
            .finally(() => {
                this.availabilityInFlight = false;
            });
    }

    /** Applies the server's list through the existing paint methods, so there is one
     *  implementation of what taken and available look like. */
    applyAvailability(taken) {
        const now = new Set(taken);
        const index = this.unitIndexByPlot || new Map();
        // Their own villa is unavailable to everyone else by definition, and greying it here would
        // black out the one plot they actually hold.
        if (this.heldValue) {
            now.delete(this.heldValue);
        }
        for (const plotUid of now) {
            if (this.taken.has(plotUid)) {
                continue;
            }
            const unit = this.units[index.get(plotUid)];
            if (!unit) {
                continue;
            }
            // Already grey from load: without this skip the first refresh repainted ~300 villas
            // through markTaken/applyFilters and froze the map.
            if (unit.selectable === false) {
                this.taken.add(plotUid);
                continue;
            }
            this.markTaken(plotUid);
        }
        for (const plotUid of Array.from(this.taken)) {
            if (now.has(plotUid)) {
                continue;
            }
            // Eligibility too: markAvailable sets selectable outright, and a freed villa this
            // customer may not book must not be offered.
            const unit = this.units[index.get(plotUid)];
            if (unit && unit.eligible) {
                this.markAvailable(plotUid);
            } else {
                this.taken.delete(plotUid);
            }
        }
        // A villa lost while its card is open: a Set mutated in place is not reactive, so
        // reassigning selected is what makes Continue catch up.
        const open = this.selected;
        if (open && open.plotUid !== this.heldValue && now.has(open.plotUid)) {
            this.selected = Object.assign({}, open, { selectable: false, status: 'Reserved' });
            this.showNotice(t(this.langValue, 'MSG_UNIT_TAKEN'));
        }
    }

    startAvailabilityPoll() {
        this.stopAvailabilityPoll();
        const seconds = this.availabilitySeconds;
        // Zero is the switch to pull if the org is struggling: the load, focus and card-open
        // refreshes carry on without a timer behind them.
        if (!seconds || seconds <= 0 || document.hidden) {
            return;
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.availabilityTimer = setInterval(() => this.refreshAvailability(), seconds * 1000);
    }

    stopAvailabilityPoll() {
        if (this.availabilityTimer) {
            clearInterval(this.availabilityTimer);
            this.availabilityTimer = 0;
        }
    }

    /** Repaints one parcel as taken without refetching - the cacheable masterplan would keep it
     *  green until reload. */
    markTaken(plotUid) {
        const index = this.units.findIndex((u) => u && u.plotUid === plotUid);
        if (index < 0) {
            return;
        }
        this.taken.add(plotUid);
        // The cached payload as well as the paint. Safe because renderData copies the response out
        // of the Lightning Data Service cache; writing straight to the cached object throws.
        this.units[index].selectable = false;
        const node = this.overlay && this.overlay.querySelector(`.unit[data-index="${index}"]`);
        if (node) {
            node.classList.remove('available', ...this.groupClasses(this.units[index]).split(' '));
            node.classList.add('reserved');
        }
        const label = this.labelNodes[index];
        if (label) {
            label.classList.add('dim');
        }
        this.applyFilters();
    }

    /** Counterpart to markTaken, for when the customer gives a villa back; a payload loaded while
     *  it was theirs still reads Held. */
    @api
    markAvailable(plotUid) {
        const index = this.units.findIndex((u) => u && u.plotUid === plotUid);
        if (index < 0) {
            return;
        }
        this.taken.delete(plotUid);
        const unit = this.units[index];
        // Repainting it green was never enough on its own: selectable stayed false from the load
        // when it was theirs, so handleUnitClick went on refusing the villa they had just released.
        unit.selectable = true;
        const node = this.overlay && this.overlay.querySelector(`.unit[data-index="${index}"]`);
        if (node) {
            node.classList.remove('reserved', 'held');
            node.classList.add('available', ...this.groupClasses(unit).split(' '));
        }
        const label = this.labelNodes[index];
        if (label) {
            label.classList.remove('dim');
        }
        this.applyFilters();
    }

    /** Nothing to book. Distinct from "still loading" and from "filtered everything out". */
    get hasNothingEligible() {
        return this.overlayReady && !this.loadError && this.eligibleCount === 0;
    }

    /* ---------- data shape helpers ---------- */

    // The plate shows the full plot UID (WB4_03-405) - the only identifier unique across the
    // project. buildMarker stacks it over two lines so it fits the parcel.
    idOf(unit, index) {
        return String(unit.plotUid ?? unit.plotNo ?? unit.num ?? index + 1);
    }

    statusOf(unit) {
        return unit.status ?? 'Available';
    }

    /** Colour recipe for a bookable parcel: hue from style, shade from bedrooms, straight off
     *  PRODUCTS so the filter swatches match by construction. One place, four call sites. */
    groupClasses(unit) {
        const product = productOf(unit);
        return product ? product.cls : 'style-x bed-x';
    }

    statusClass(status) {
        const value = String(status || '').toLowerCase();
        if (['available', 'open', 'avail'].includes(value)) {
            return 'available';
        }
        if (['reserved', 'held', 'hold'].includes(value)) {
            return 'reserved';
        }
        if (['sold', 'booked'].includes(value)) {
            return 'sold';
        }
        return 'blocked';
    }

    // Map_Polygon__c is a JSON string of normalised pairs. Nothing cached on the unit: Apex
    // results are read-only proxies, and assigning to them throws.
    pointsOf(unit) {
        let raw;
        try {
            raw = JSON.parse(unit.polygon || '[]');
        } catch (e) {
            return [];
        }
        return raw.map((p) => [Number(p[0]) * IMG_W, Number(p[1]) * IMG_H]);
    }

    typeOf(unit) {
        return unit.villaType ?? 'Villa';
    }

    /** The box a villa is drawn into. With a bearing the entrance edge faces its street; the
     *  fallback rectangle is only defined modulo 90 degrees, so it faces one of four ways. */
    entryRect(points, bearing) {
        if (bearing == null || !Number.isFinite(bearing)) {
            return this.orientedRect(points);
        }
        const r = (bearing * Math.PI) / 180;
        const ca = Math.cos(r);
        const sa = Math.sin(r);
        let minU = Infinity;
        let maxU = -Infinity;
        let minV = Infinity;
        let maxV = -Infinity;
        for (const p of points) {
            const u = p[0] * ca + p[1] * sa;
            const v = -p[0] * sa + p[1] * ca;
            if (u < minU) { minU = u; }
            if (u > maxU) { maxU = u; }
            if (v < minV) { minV = v; }
            if (v > maxV) { maxV = v; }
        }
        const u0 = (minU + maxU) / 2;
        const v0 = (minV + maxV) / 2;
        return {
            angle: bearing,
            w: maxU - minU,
            h: maxV - minV,
            cx: u0 * ca - v0 * sa,
            cy: u0 * sa + v0 * ca
        };
    }

    /** Smallest enclosing rectangle - deliberately not the drop's plot_mapping.csv estimator,
     *  which is about 40 degrees out on irregular corner plots. */
    orientedRect(points) {
        let best = null;
        for (let i = 0; i < 180; i++) {
            const a = (i * 0.5 * Math.PI) / 180;
            const ca = Math.cos(a);
            const sa = Math.sin(a);
            let minU = Infinity;
            let maxU = -Infinity;
            let minV = Infinity;
            let maxV = -Infinity;
            for (const p of points) {
                const u = p[0] * ca + p[1] * sa;
                const v = -p[0] * sa + p[1] * ca;
                if (u < minU) { minU = u; }
                if (u > maxU) { maxU = u; }
                if (v < minV) { minV = v; }
                if (v > maxV) { maxV = v; }
            }
            const w = maxU - minU;
            const h = maxV - minV;
            if (best === null || w * h < best.area) {
                const u0 = (minU + maxU) / 2;
                const v0 = (minV + maxV) / 2;
                best = {
                    area: w * h,
                    angle: (i * 0.5),
                    w,
                    h,
                    cx: u0 * ca - v0 * sa,
                    cy: u0 * sa + v0 * ca
                };
            }
        }
        return best;
    }

    /** Villas drawn from the source render, which stays sharp where the basemap runs out at ~2x.
     *  Only on-screen parcels get a node, from a recycled pool. */
    syncVillaArt() {
        const group = this.villaGroup;
        const stage = this.stage;
        const frame = this.frame;
        if (!group || !stage || !frame || !this.units.length) {
            return;
        }

        if (this.zoom < VILLA_ART_ZOOM) {
            if (this.villaShown !== false) {
                group.style.display = 'none';
                this.villaShown = false;
            }
            return;
        }
        group.style.display = '';
        this.villaShown = true;

        // Screen to viewBox. Same mapping the camera uses, inverted.
        const k = this.fitScale * this.zoom;
        if (!k) {
            return;
        }
        const pad = 40;
        const x0 = canvasToGeoX((0 - this.panX) / k) - pad;
        const y0 = canvasToGeoY((0 - this.panY) / k) - pad;
        const x1 = canvasToGeoX((frame.clientWidth - this.panX) / k) + pad;
        const y1 = canvasToGeoY((frame.clientHeight - this.panY) / k) + pad;

        let slot = 0;
        for (let i = 0; i < this.units.length; i++) {
            const box = this.unitBoxes[i];
            if (!box || box.maxX < x0 || box.minX > x1 || box.maxY < y0 || box.minY > y1) {
                continue;
            }
            const rect = this.unitRects[i];
            if (!rect) {
                continue;
            }
            const node = this.villaSlot(slot);
            if (!node) {
                // Ceiling reached. Said once rather than silently drawing a partial screen.
                if (!this.villaCapped) {
                    this.villaCapped = true;
                    console.warn(`masterplanUnitSelector: villa art capped at ${VILLA_ART_MAX} parcels`);
                }
                break;
            }
            if (node.index !== i) {
                node.clip.setAttribute('points', this.unitPoints[i]);
                node.image.setAttribute('x', String(rect.cx - rect.w / 2));
                node.image.setAttribute('y', String(rect.cy - rect.h / 2));
                node.image.setAttribute('width', String(rect.w));
                node.image.setAttribute('height', String(rect.h));
                node.image.setAttribute(
                    'transform',
                    `rotate(${rect.angle} ${rect.cx} ${rect.cy})`
                );
                node.index = i;
            }
            if (!node.visible) {
                node.image.style.display = '';
                node.visible = true;
            }
            slot++;
        }
        for (let j = slot; j < this.villaPool.length; j++) {
            const node = this.villaPool[j];
            if (node.visible) {
                node.image.style.display = 'none';
                node.visible = false;
            }
        }
    }

    /** Empty layer. Slots are cut on demand by villaSlot, so nothing is allocated until a zoom. */
    buildVillaArt(fragment) {
        const defs = document.createElementNS(SVG_NS, 'defs');
        const group = document.createElementNS(SVG_NS, 'g');
        group.setAttribute('class', 'villa-art');
        group.style.display = 'none';
        this.villaPool = [];
        this.villaShown = false;
        this.villaCapped = false;
        this.villaDefs = defs;

        fragment.appendChild(defs);
        fragment.appendChild(group);
        this.villaGroup = group;
    }

    /** One slot: a clipPath and the image it clips. Created once, then recycled by index. */
    villaSlot(n) {
        if (n < this.villaPool.length) {
            return this.villaPool[n];
        }
        if (n >= VILLA_ART_MAX || !this.villaDefs || !this.villaGroup) {
            return null;
        }
        const id = `wb-villa-clip-${n}`;
        const clipPath = document.createElementNS(SVG_NS, 'clipPath');
        clipPath.setAttribute('id', id);
        clipPath.setAttribute('clipPathUnits', 'userSpaceOnUse');
        const clip = document.createElementNS(SVG_NS, 'polygon');
        clip.setAttribute('points', '0,0 1,0 1,1');
        clipPath.appendChild(clip);
        this.villaDefs.appendChild(clipPath);

        const image = document.createElementNS(SVG_NS, 'image');
        image.setAttribute('href', VILLA_ART);
        // Older SVG renderers only honour the xlink form.
        image.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', VILLA_ART);
        image.setAttribute('preserveAspectRatio', 'xMidYMid slice');
        image.setAttribute('clip-path', `url(#${id})`);
        image.style.display = 'none';
        this.villaGroup.appendChild(image);

        const slot = { clip, image, index: -1, visible: false };
        this.villaPool.push(slot);
        return slot;
    }

    formatAed(value) {
        // Intl places the currency correctly for the locale instead of hard-coding a prefix
        // ahead of the digits, which reads wrong on an RTL line.
        return value == null
            ? 'TBC'
            : Number(value).toLocaleString('en-US', {
                  style: 'currency',
                  currency: 'AED',
                  maximumFractionDigits: 0
              });
    }

    /* ---------- overlay build ---------- */

    buildIfReady() {
        const host = this.template.querySelector('.overlay-host');
        if (this.built || !this.dataReady || !host) {
            return;
        }
        this.built = true;

        const svg = document.createElementNS(SVG_NS, 'svg');
        svg.setAttribute('class', this.opsMode ? 'wb-overlay ops' : 'wb-overlay');
        // CANVAS, not IMG_W/IMG_H: the picture now carries the surrounding area, and the origin
        // is offset so geometry still lands at 0,0 to IMG_W,IMG_H without any record moving.
        svg.setAttribute('viewBox', `${CANVAS.x} ${CANVAS.y} ${CANVAS.w} ${CANVAS.h}`);
        svg.setAttribute('preserveAspectRatio', 'none');

        // Component CSS cannot reach manual nodes; a <style> in the SVG can, but is unscoped
        // under synthetic shadow, so every OVERLAY_STYLES rule is prefixed svg.wb-overlay.
        const style = document.createElementNS(SVG_NS, 'style');
        style.textContent = OVERLAY_STYLES;
        svg.appendChild(style);

        svg.addEventListener('click', this.handleOverlayClick);
        // Delegated like the click: 1,659 parcels, one listener. mouseover because only the
        // bubbling pair delegates; mouseleave catches the pointer leaving the map.
        svg.addEventListener('mouseover', this.handleOverlayHover);
        svg.addEventListener('mouseleave', this.handleOverlayLeave);
        host.appendChild(svg);
        this.overlay = svg;

        this.renderData(this.masterplan);
        this.overlayReady = true;
        // The first moment this.units is populated, which is what refreshAvailability needs and
        // what the call in loadMasterplan is too early for.
        this.refreshAvailability();
    }

    renderData(data) {
        const svg = this.overlay;
        if (!svg) {
            return;
        }

        // Keep the injected <style> (first child), drop everything else.
        while (svg.childNodes.length > 1) {
            svg.removeChild(svg.lastChild);
        }
        this.closeCard();
        this.unitNodes = [];
        this.labelNodes = [];
        this.selectedLabelIndex = -1;
        this.clusterNodes = [];
        this.unitCenters = [];
        this.clusterMeta = [];
        this.clusterMembers = new Map();
        this.amenityNodes = {};
        this.amenityIcons = {};
        this.activeAmenities = [];
        this.pinLayoutKey = null;
        this.clusterTags = [];
        this.clusterNumbers = [];
        this.lastOverview = null;
        this.lastShowLabels = null;
        this.lastShowPlates = null;
        this.lastShowClusters = null;

        // Copied, not referenced: the cacheable response is a read-only proxy, so writing
        // selectable on it throws. A shallow copy per unit; polygons stay shared by reference.
        this.units = (data?.units ?? []).map((u) => Object.assign({}, u));
        // A payload from before the reserve-stock model carries no reserve flag. Say so once, and every ops rule
        // below stands down rather than quieting a map nobody can then work.
        this.opsFlagsPresent = this.units.some((u) => u.reserveStock !== undefined);
        // Plot id to index, so the availability refresh does not scan 1,659 units per villa.
        this.unitIndexByPlot = new Map();
        this.units.forEach((u, i) => {
            if (u && u.plotUid) {
                this.unitIndexByPlot.set(u.plotUid, i);
            }
        });
        this.eligibleCount = data?.eligibleUnits ?? 0;
        this.applicant = data?.applicant;
        // Ops loads its board; a pinned customer jumps to their villa once.
        if (this.opsMode) {
            this.loadPinBoard();
        } else if (this.pinnedPlotUid && !this.pinnedFocusDone) {
            const pinnedIndex = this.unitIndexByPlot.get(this.pinnedPlotUid);
            if (pinnedIndex !== undefined) {
                this.pinnedFocusDone = true;
                // Next tick - the stage is not laid out yet.
                setTimeout(() => this.focusAndOpenUnit(pinnedIndex), 0);
            }
        }
        this.unitRects = [];
        this.unitBoxes = [];
        this.unitPoints = [];
        // Read once rather than per parcel. Empty if the resource failed to load, which entryRect
        // handles by falling back.
        const bearings = window.WB_VILLA_BEARINGS || {};
        const fragment = document.createDocumentFragment();
        const markers = [];

        // Before the amenities, so land use still paints over a villa where the two overlap.
        this.buildVillaArt(fragment);

        // First into the fragment, so land use paints under every parcel rather than over it.
        this.renderAmenities(fragment);

        for (let i = 0; i < this.units.length; i++) {
            const unit = this.units[i];
            const points = this.pointsOf(unit);
            if (points.length < 3) {
                continue;
            }

            const polygon = document.createElementNS(SVG_NS, 'polygon');
            const pointsAttr = points.map((p) => p.join(',')).join(' ');
            polygon.setAttribute('points', pointsAttr);
            // Ineligible parcels stay drawn but dimmed and inert; eligible ones carry status
            // plus product classes so available parcels colour by style and size.
            // Ops takes the painted branch whatever the payload says about eligibility: the
            // ineligible class draws nothing, and their own classes decide what they can see.
            polygon.setAttribute(
                'class',
                unit.eligible || this.opsMode
                    ? `unit ${this.statusClass(unit.status)} ${this.groupClasses(unit)}${this.opsClasses(unit)}`
                    : 'unit ineligible'
            );
            polygon.dataset.index = String(i);

            const center =
                unit.cx != null && unit.cy != null
                    ? [Number(unit.cx) * IMG_W, Number(unit.cy) * IMG_H]
                    : points.reduce((acc, p) => [acc[0] + p[0] / points.length, acc[1] + p[1] / points.length], [0, 0]);
            this.unitCenters[i] = { x: center[0], y: center[1] };

            fragment.appendChild(polygon);
            this.unitNodes.push(polygon);

            // Cached for the villa-art layer: what it clips with, what it culls on, and the
            // oriented box it draws the villa into. All three are fixed for the life of the map.
            this.unitPoints[i] = pointsAttr;
            this.unitBoxes[i] = {
                minX: Math.min(...points.map((q) => q[0])),
                maxX: Math.max(...points.map((q) => q[0])),
                minY: Math.min(...points.map((q) => q[1])),
                maxY: Math.max(...points.map((q) => q[1]))
            };
            this.unitRects[i] = this.entryRect(points, bearings[unit.plotUid]);

            // Centred on the parcel's own box, not the vertex-average centroid, which can hang
            // the plate over one edge.
            const xsAll = points.map((q) => q[0]);
            const ysAll = points.map((q) => q[1]);
            const bx0 = Math.min(...xsAll);
            const bx1 = Math.max(...xsAll);
            const by0 = Math.min(...ysAll);
            const by1 = Math.max(...ysAll);
            // Only the customer's own plots get a plate - numbering the rest buries them.
            // labelNodes stays index-aligned, so ineligible entries hold null.
            if (unit.eligible) {
                const marker = this.buildMarker(this.idOf(unit, i), [(bx0 + bx1) / 2, (by0 + by1) / 2], {
                    w: bx1 - bx0,
                    h: by1 - by0
                });
                markers.push(marker);
                this.labelNodes.push(marker);
            } else {
                this.labelNodes.push(null);
            }

            // The cluster layer is built from these parcels rather than from a separate boundary
            // polygon, so it cannot drift away from them when the unit geometry is reloaded.
            if (unit.cluster != null) {
                const key = String(unit.cluster);
                let bucket = this.clusterMembers.get(key);
                if (!bucket) {
                    bucket = [];
                    this.clusterMembers.set(key, bucket);
                }
                bucket.push({
                    points,
                    bx0,
                    bx1,
                    by0,
                    by1,
                    selectable: unit.selectable,
                    // Carried so the cluster tier can follow the parcels while reservations are
                    // closed, where eligibility decides and availability means nothing.
                    eligible: unit.eligible,
                    category: unit.category,
                    // Carried so renderClusters can caption the block with its plot range.
                    uid: this.idOf(unit, i)
                });
            }
        }

        this.renderClusters(fragment);

        // Markers go in last so the unit numbers always paint above every parcel outline and
        // cluster shape. Interleaving them with the polygons puts numbers under later lines.
        for (const marker of markers) {
            fragment.appendChild(marker);
        }

        // Pins last of all: an amenity is a landmark, so it stays legible over both the parcel
        // fills and the unit plates.
        for (const key of Object.keys(this.amenityIcons)) {
            for (const pin of this.amenityIcons[key]) {
                fragment.appendChild(pin);
            }
        }
        svg.appendChild(fragment);

        this.unitCount = this.unitNodes.length;
        this.selections = {};
        this.buildFacets();
        this.applyFilters();
        this.applyView();
    }

    /* ---------- filters (journey stage 4) ---------- */

    // Facets derive from what this customer can book, so a value with no bookable villas never
    // becomes a dead chip; closed, canExplore widens this to everything eligible.
    buildFacets() {
        const offered = this.units.filter((u) => u.eligible && this.canExplore(u));
        this.facetDefs = FACETS.map((facet) => {
            const values = new Set();
            for (const unit of offered) {
                const value = facet.of(unit);
                if (value != null && value !== '') {
                    values.add(String(value));
                }
            }
            return { ...facet, values: [...values].sort() };
        }).filter((facet) => facet.values.length > 1);
    }

    /** Single source of truth for availability, read by counting and painting alike so they
     *  cannot drift. Their own hold is exempt: changing away from it must stay possible. */
    canBook(unit) {
        return (
            unit.plotUid === this.heldValue ||
            (unit.selectable && !this.taken.has(unit.plotUid))
        );
    }

    /** What the customer may open - the same set as what they may book, since 27 Aug 2026. */
    canExplore(unit) {
        return this.canBook(unit);
    }

    // A unit passes when it satisfies every facet that has a selection. Facets with nothing
    // selected are skipped, which is what makes "no filters" mean "everything".
    matches(unit, skipKey) {
        if (!unit.eligible) {
            return false;
        }
        // Availability is a rule, not a facet, so it cannot be switched off; while reservations
        // are closed it means reachable instead.
        if (!this.canExplore(unit)) {
            return false;
        }
        for (const facet of this.facetDefs || []) {
            if (facet.key === skipKey) {
                continue;
            }
            const chosen = this.selections[facet.key];
            if (chosen && chosen.size && !chosen.has(String(facet.of(unit) ?? ''))) {
                return false;
            }
        }
        return true;
    }

    applyFilters() {
        let matched = 0;
        let bookable = 0;
        for (let i = 0; i < this.units.length; i++) {
            const node = this.unitNodes[i];
            if (!node) {
                continue;
            }
            const unit = this.units[i];
            const hit = this.matches(unit);
            if (hit) {
                matched++;
            }
            // Ineligible parcels are already dimmed and inert; leave them alone.
            if (!unit.eligible) {
                continue;
            }
            const reachable = this.canExplore(unit);
            if (reachable) {
                bookable++;
            }
            // The number plate recedes for anything outside the current view, taken or filtered.
            const label = this.labelNodes[i];
            if (label) {
                label.classList.toggle('dim', !hit);
            }
            // The wash means "outside what you asked to see", so only reachable villas carry it;
            // taken ones keep their status colour. Closed, taken villas take the wash too.
            if (reachable) {
                node.classList.toggle('filtered-out', !hit);
            } else {
                node.classList.remove('filtered-out');
            }
        }
        this.matchCount = matched;
        this.bookableCount = bookable;
        this.refreshFacetOptions();
    }

    /* No status line: the only count worth reading lives on the filter rows themselves. */

    // Each option's count ignores its own facet, so the numbers show what selecting it would
    // add rather than collapsing to zero as soon as a sibling in the same facet is chosen.
    refreshFacetOptions() {
        this.facets = (this.facetDefs || []).map((facet) => {
            const chosen = this.selections[facet.key];
            const counts = new Map();
            for (const unit of this.units) {
                if (!this.matches(unit, facet.key)) {
                    continue;
                }
                const value = String(facet.of(unit) ?? '');
                counts.set(value, (counts.get(value) || 0) + 1);
            }
            const l = this.langValue;
            return {
                key: facet.key,
                label: t(l, facet.labelKey),
                options: facet.values.map((value) => {
                    const on = !!(chosen && chosen.has(value));
                    const count = counts.get(value) || 0;
                    return {
                        id: `${facet.key}:${value}`,
                        // value is the stable selection key; label is what the customer reads.
                        value,
                        on,
                        label: facet.display ? facet.display(value, l, t, pick) : pick(l, value),
                        count,
                        disabled: !on && count === 0,
                        // The exact hue the map paints this product, inline off PRODUCTS, so the
                        // row and the plan cannot drift - the panel is the key.
                        hasSwatch: !!facet.swatch,
                        swatchStyle: facet.swatch ? `background:${facet.swatch(value)}` : '',
                        cls: `chip${on ? ' on' : ''}${!on && count === 0 ? ' empty' : ''}`
                    };
                })
            };
        });
    }

    get hasFacets() {
        return this.facets.length > 0;
    }

    get anyFilter() {
        return Object.values(this.selections).some((set) => set && set.size);
    }

    get filterToggleLabel() {
        const active = Object.values(this.selections).reduce((n, set) => n + (set ? set.size : 0), 0);
        return active
            ? t(this.langValue, 'filtersCount', num(active))
            : t(this.langValue, 'filters');
    }

    // The rail owns the leading edge; panel-open lets the phone layout stand the map controls
    // down while a summoned panel is docked over their strip.
    /** Inert while the JOURNEY has a card over the map - keyed on muted, not on selected, so
     *  browsing stays free. Dismissal stays unlocked, or touch would be trapped on the card. */
    get mapLocked() {
        return this.muted;
    }

    get frameClass() {
        return (
            `frame${this.filtersOpen ? ' filters-open' : ''}` +
            `${this.showCard ? ' card-open' : ''}` +
            `${this.mapPanel ? ' panel-open' : ''}`
        );
    }

    handleToggleFilters = () => {
        this.mapPanel = '';
        this.filtersOpen = !this.filtersOpen;
    };

    handleFacetToggle = (event) => {
        const { facet, value } = event.currentTarget.dataset;
        const chosen = this.selections[facet] || new Set();
        if (chosen.has(value)) {
            chosen.delete(value);
        } else {
            chosen.add(value);
        }
        this.selections = { ...this.selections, [facet]: chosen };
        this.applyFilters();
    };

    /* ---------- overlay: plates, clusters, land use ---------- */

    /** Number plate, centred on the parcel and clamped to it, so a long number shrinks instead
     *  of spilling over its neighbours. */
    buildMarker(label, center, extent) {
        const parcelW = extent && extent.w ? extent.w : BUBBLE_MIN_W;
        const parcelH = extent && extent.h ? extent.h : BUBBLE_H;

        const wanted = label.length * BUBBLE_CHAR_W + BUBBLE_PAD_W;
        const bubbleW = Math.min(parcelW * 0.9, Math.max(BUBBLE_MIN_W * 0.6, wanted));
        // Width binds on every real parcel, so the font comes off the width and the height
        // follows the font.
        const fontSize = Math.max(4.2, Math.min(6.8, (bubbleW - 6) / (label.length * 0.7)));
        const bubbleH = Math.min(parcelH * 0.5, fontSize * BUBBLE_H_RATIO);

        // High on the plot with a tail pointing into it - a centred plate reads as painted on
        // the roof. Both stay inside the parcel.
        const tailH = bubbleH * 0.34;
        const tailW = bubbleH * 0.52;
        const bubbleY = center[1] - parcelH / 2 + parcelH * 0.14;
        const bubbleBottom = bubbleY + bubbleH;

        const marker = document.createElementNS(SVG_NS, 'g');
        marker.setAttribute('class', 'unit-label-group');

        const bubble = document.createElementNS(SVG_NS, 'rect');
        bubble.setAttribute('x', center[0] - bubbleW / 2);
        bubble.setAttribute('y', bubbleY);
        bubble.setAttribute('width', bubbleW);
        bubble.setAttribute('height', bubbleH);
        bubble.setAttribute('rx', Math.min(5, bubbleH / 2));
        bubble.setAttribute('class', 'unit-label-bg');

        // Drawn before the bubble so the rounded corners paint over where the two meet.
        const tail = document.createElementNS(SVG_NS, 'polygon');
        tail.setAttribute(
            'points',
            `${center[0] - tailW / 2},${bubbleBottom - 1} ${center[0] + tailW / 2},${bubbleBottom - 1} ${center[0]},${bubbleBottom + tailH}`
        );
        tail.setAttribute('class', 'unit-label-tail');

        const text = document.createElementNS(SVG_NS, 'text');
        text.setAttribute('x', center[0]);
        text.setAttribute('y', bubbleY + bubbleH / 2);
        text.setAttribute('font-size', fontSize.toFixed(2));
        text.setAttribute('class', 'unit-label-text');
        text.textContent = label;

        // Records the anchor and design font so the counter-scale pass can scale about the
        // anchor without touching the children's coordinates.
        marker.dataset.cx = center[0];
        marker.dataset.cy = bubbleY + bubbleH / 2;
        marker.dataset.fs = fontSize;
        // Recorded so the declutter pass can collide plates on the size they actually paint at.
        marker.dataset.bw = bubbleW;
        marker.dataset.bh = bubbleH + tailH;

        marker.append(tail, bubble, text);
        return marker;
    }

    /** Ops sees the pool they allocate from, not the customer's map. Reserve stock and
     *  pins carry colour; everything else goes quiet but stays tappable for status and holder. */
    get clusterCountKey() {
        return this.opsMode ? 'clusterAssignable' : 'clusterAvailable';
    }

    /** Free to assign wins, then reserve stock that is spoken for, then everything else. The
     *  free list is the authority: it is fetched fresh every time, while the map payload is
     *  cacheable and a browser can hand back one captured before the pool existed. */
    opsBaseClass(unit) {
        if (this.opsAssignablePlots.has(unit.plotUid)) {
            return ' ops-reserve';
        }
        return unit.reserveStock === true ? ' ops-held' : ' ops-quiet';
    }

    /** Ops opens their own stock, free or already spoken for, and nothing else. */
    opsTouchable(unit) {
        return this.opsAssignablePlots.has(unit.plotUid) || unit.reserveStock === true;
    }

    /** Nothing known about the pool yet: paint as before rather than quiet a map ops cannot
     *  then work. The rules apply the moment either source answers. */
    get opsPoolKnown() {
        return this.opsAssignablePlots.size > 0 || this.opsFlagsPresent;
    }

    /** The free list lands after the map has drawn, so reconcile the nodes already on screen -
     *  the same idempotent sweep paintOpsPins does for the violet. */
    repaintOpsStock() {
        if (!this.opsMode || !this.overlay) {
            return;
        }
        let painted = 0;
        for (let i = 0; i < this.units.length; i++) {
            const unit = this.units[i];
            // By the index the node carries, never by array position: a unit whose polygon was
            // unusable is skipped when the nodes are built, which shifts every later slot.
            const node = this.overlay.querySelector(`.unit[data-index="${i}"]`);
            if (!node || !unit) {
                continue;
            }
            const base = this.opsBaseClass(unit).trim();
            node.classList.remove('ops-reserve', 'ops-held', 'ops-quiet', 'ineligible');
            node.classList.add(base);
            if (base === 'ops-reserve') {
                painted++;
            }
        }
        this.opsPaintedCount = painted;
        this.paintClusterStock();
        // Pins sit on top and belong to the board, so re-assert them after the sweep.
        this.paintOpsPins();
    }

    /** A cluster holding free stock carries a tint at the zoom ops actually lands on, so they
     *  know where to go before any villa is big enough to read. */
    paintClusterStock() {
        if (!this.opsMode || !this.clusterNodes) {
            return;
        }
        for (const node of this.clusterNodes) {
            const key = node.dataset.cluster;
            const meta = key === undefined ? null : this.clusterMeta[Number(key)];
            const members = meta ? this.clusterMembers.get(meta.clusterId) || [] : [];
            const free = members.some((m) => this.opsAssignablePlots.has(m.uid));
            node.dataset.free = free ? '1' : '0';
        }
    }

    opsClasses(unit) {
        if (!this.opsMode || !this.opsPoolKnown) {
            return '';
        }
        const base = this.opsBaseClass(unit);
        // Reserve stock only, on the pin too: ops-pinned carries fill and pointer-events and would
        // otherwise beat ops-quiet on source order, surfacing a public villa ops must not see or
        // touch. A pin that landed outside the pool is invisible here and absent from board().
        return this.opsTouchable(unit) && unit.pinned ? `${base} ops-pinned` : base;
    }

    /** Cluster records from the static resource, keyed by id. Tolerates a failed load: an empty
     *  map sends every cluster down the member-parcel fallback. */
    clusterIndex() {
        const index = new Map();
        for (const cluster of window.WB_CLUSTERS || []) {
            index.set(String(cluster.clusterId), cluster);
        }
        return index;
    }

    /** One block per cluster from the plan's own boundary; member parcels stay the fallback. A
     *  cluster with nothing bookable (nothing eligible, while closed) is not drawn at all. */
    renderClusters(fragment) {
        const index = this.clusterIndex();
        this.clusterHiddenCount = 0;

        for (const [key, members] of this.clusterMembers) {
            // Selectable, not eligible: the cluster tier has to agree with the parcels
            // underneath it.
            const shown = members.filter((m) => m.selectable);
            // Ops navigates the whole plan, so an empty cluster still draws - its count simply
            // reads zero. A customer is never shown a cluster with nothing to book.
            if (!shown.length && !this.opsMode) {
                this.clusterHiddenCount++;
                continue;
            }

            const supplied = index.get(key);
            const boundary = supplied && supplied.polygon && supplied.polygon.length
                ? supplied.polygon
                : null;
            // Normalised against the same IMG_W x IMG_H frame as every unit polygon, so this is
            // the same conversion pointsOf does.
            const d = boundary
                ? 'M' + boundary.map((p) => `${p[0] * IMG_W} ${p[1] * IMG_H}`).join('L') + 'Z'
                : members.map((m) => 'M' + m.points.map((p) => p.join(' ')).join('L') + 'Z').join(' ');

            const minX = Math.min(...members.map((m) => m.bx0));
            const minY = Math.min(...members.map((m) => m.by0));
            const maxX = Math.max(...members.map((m) => m.bx1));
            const maxY = Math.max(...members.map((m) => m.by1));

            // The supplied centre, because the bounding-box centre of an L-shaped or split cluster
            // lands outside the block and would hang its label over a neighbour.
            const centre = supplied && supplied.center
                ? [supplied.center[0] * IMG_W, supplied.center[1] * IMG_H]
                : [(minX + maxX) / 2, (minY + maxY) / 2];

            const metaIndex = this.clusterMeta.length;
            this.clusterMeta.push({
                name: (supplied && supplied.name) || t(this.langValue, 'cluster', key),
                range: this.plotRange(members),
                clusterId: key,
                available: shown.length,
                cx: centre[0],
                cy: centre[1],
                minX,
                minY,
                maxX,
                maxY
            });

            const shape = document.createElementNS(SVG_NS, 'path');
            shape.setAttribute('d', d);
            shape.setAttribute('class', 'cluster-block');
            // Fallback only: the wide round join bridges roads so disjoint villas read as one
            // block, and it overrides the white border - a traced outline would be noise.
            if (!boundary) {
                shape.setAttribute(
                    'style',
                    'stroke:#080b12;stroke-opacity:.3;stroke-width:18;stroke-linejoin:round;vector-effect:none'
                );
            }
            shape.dataset.cluster = String(metaIndex);
            fragment.appendChild(shape);
            this.clusterNodes.push(shape);

            const number = this.buildClusterNumber(this.clusterMeta[metaIndex]);
            fragment.appendChild(number);
            this.clusterNumbers.push({ node: number, meta: this.clusterMeta[metaIndex] });

            const tag = this.buildClusterTag(this.clusterMeta[metaIndex]);
            fragment.appendChild(tag);
            this.clusterTags.push({ node: tag, meta: this.clusterMeta[metaIndex] });
        }
    }

    /** The span of plot numbers as read off a plate. Exact for 19 of 21 clusters; 1 and 2
     *  interleave and read a little wide, fine for "your plot is in here". */
    plotRange(members) {
        const parts = [];
        for (const m of members) {
            const at = m.uid ? m.uid.lastIndexOf('-') : -1;
            if (at > 0) {
                parts.push([m.uid.slice(0, at), Number(m.uid.slice(at + 1))]);
            }
        }
        if (!parts.length) {
            return '';
        }
        const numbers = parts.map((p) => p[1]).filter((n) => !isNaN(n));
        if (!numbers.length) {
            return parts[0][0];
        }
        const lo = Math.min(...numbers);
        const hi = Math.max(...numbers);
        // Hyphens throughout, matching how a plot ID already reads on the search box and the card.
        return lo === hi ? `${parts[0][0]}-${lo}` : `${parts[0][0]}-${lo}-${hi}`;
    }

    /** Caption plate for one block: the plot range it covers over how many villas are left in it. */
    buildClusterTag(meta) {
        const cx = (meta.minX + meta.maxX) / 2;
        const cy = (meta.minY + meta.maxY) / 2;

        const tag = document.createElementNS(SVG_NS, 'g');
        tag.setAttribute('class', 'cluster-tag');

        const oneLine = false;

        const bg = document.createElementNS(SVG_NS, 'rect');
        bg.setAttribute('x', -TAG_UNITS / 2);
        bg.setAttribute('y', oneLine ? -14 : -21);
        bg.setAttribute('width', TAG_UNITS);
        bg.setAttribute('height', oneLine ? 28 : 42);
        bg.setAttribute('rx', 8);
        bg.setAttribute('class', 'cluster-tag-bg');

        // A range is far longer than the cluster name it replaces, so the type is fitted to the
        // plate rather than fixed at 19 - a long one shrinks instead of spilling over the edge.
        const label = meta.range || meta.name;
        const titleSize = Math.min(19, (TAG_UNITS - 16) / (label.length * 0.58));

        const title = document.createElementNS(SVG_NS, 'text');
        title.setAttribute('class', 'cluster-tag-text');
        title.setAttribute('y', oneLine ? 0 : -5);
        title.setAttribute('font-size', titleSize.toFixed(2));
        title.textContent = label;

        tag.append(bg, title);

        // relabelOverlay guards on finding this node, so leaving it out is safe for the
        // language switch.
        if (!oneLine) {
            const sub = document.createElementNS(SVG_NS, 'text');
            sub.setAttribute('class', 'cluster-tag-text cluster-tag-sub');
            sub.setAttribute('y', 13);
            sub.setAttribute('font-size', '15');
            sub.textContent = t(this.langValue, this.clusterCountKey, num(meta.available));
            tag.append(sub);
        }
        // Position and counter-scale are both applied in scaleAmenityIcons, which runs on
        // every camera change; this only records where the plate belongs.
        tag.dataset.cx = String(cx);
        tag.dataset.cy = String(cy);
        return tag;
    }

    /** "Cluster 9" on a dark plate for the plan tier - the only treatment that reads over both
     *  pale ground and asphalt. Inert, so the click falls through to the block. */
    buildClusterNumber(meta) {
        const group = document.createElementNS(SVG_NS, 'g');
        group.setAttribute('class', 'cluster-num');

        const bg = document.createElementNS(SVG_NS, 'rect');
        bg.setAttribute('class', 'cluster-num-bg');
        bg.setAttribute('y', -NUM_BOX_H / 2);
        bg.setAttribute('height', NUM_BOX_H);
        bg.setAttribute('rx', 8);

        const text = document.createElementNS(SVG_NS, 'text');
        text.setAttribute('class', 'cluster-num-text');

        group.append(bg, text);
        this.paintClusterNumber(group, meta);

        // Same contract as the caption: this records where it belongs, scaleAmenityIcons places it.
        group.dataset.cx = String(meta.cx);
        group.dataset.cy = String(meta.cy);
        return group;
    }

    /** The text and the plate that must fit it, shared with relabelOverlay. Width estimated from
     *  character count: getBBox is unreliable inside a DocumentFragment. */
    paintClusterNumber(group, meta) {
        const label = this.clusterLabel(meta);
        group.querySelector('.cluster-num-text').textContent = label;

        const width = Math.round(label.length * NUM_FONT * 0.6) + 22;
        const bg = group.querySelector('.cluster-num-bg');
        bg.setAttribute('x', -width / 2);
        bg.setAttribute('width', width);
    }

    /** Localised. The digits stay Latin, as every other figure on the site does - see num(). */
    clusterLabel(meta) {
        return t(this.langValue, 'cluster', num(Number(meta.clusterId)));
    }

    /** Land use from the plan's own layers, drawn first and inert throughout - context for a
     *  decision, not something to book. */
    renderAmenities(fragment) {
        const data = window.WB_AMENITIES || [];
        if (!data.length) {
            return;
        }
        this.amenityNodes = {};
        this.amenityIcons = {};
        this.pinLayoutKey = null;

        const shadows = [];
        const shapes = [];

        for (const entry of data) {
            const cls = entry.cls;
            // A class with no AMENITIES entry is skipped entirely, keeping Landscaping's 95
            // polygons out of the DOM.
            if (!AMENITIES.some((a) => a.key === cls)) {
                continue;
            }
            const d = (entry.polygons || [])
                .map(
                    (ring) =>
                        'M' +
                        ring.map((p) => `${Number(p[0]) * IMG_W} ${Number(p[1]) * IMG_H}`).join('L') +
                        'Z'
                )
                .join(' ');
            if (!d) {
                continue;
            }

            // Buildings sit above the ground they stand on, so only they cast a shadow, and every
            // one uses the same sun vector as the base image.
            if (BUILT_CLASSES.has(cls)) {
                const shadow = document.createElementNS(SVG_NS, 'path');
                shadow.setAttribute('d', d);
                shadow.setAttribute('class', 'built-shadow');
                shadow.setAttribute('transform', `translate(${SHADOW_DX} ${SHADOW_DY})`);
                shadows.push(shadow);
            }

            const shape = document.createElementNS(SVG_NS, 'path');
            shape.setAttribute('d', d);
            shape.setAttribute('class', `amenity ${cls}`);
            shapes.push(shape);
            (this.amenityNodes[cls] = this.amenityNodes[cls] || []).push(shape);

            if (entry.cx != null && entry.cy != null) {
                const pin = this.buildAmenityPin(cls, Number(entry.cx) * IMG_W, Number(entry.cy) * IMG_H);
                if (pin) {
                    (this.amenityIcons[cls] = this.amenityIcons[cls] || []).push(pin);
                }
            }
        }

        // Shadows under every footprint rather than under their own building only, so a block of
        // adjacent buildings does not print one shadow over its neighbour.
        for (const node of shadows) {
            fragment.appendChild(node);
        }
        for (const node of shapes) {
            fragment.appendChild(node);
        }
        this.refreshAmenityChips();
    }

    /** One landmark pin: the glyph, and nothing else. The chip row is what names the class. */
    buildAmenityPin(cls, x, y) {
        const def = AMENITIES.find((a) => a.key === cls);
        if (!def) {
            return null;
        }
        const pin = document.createElementNS(SVG_NS, 'g');
        pin.setAttribute('class', `amenity-icon-pin ${cls}`);
        const glyph = document.createElementNS(SVG_NS, 'text');
        glyph.setAttribute('class', 'amenity-icon-glyph');
        glyph.setAttribute('font-size', String(ICON_UNITS * 0.62));
        glyph.textContent = def.icon;
        pin.appendChild(glyph);

        // The name, hidden by CSS until selected. Built always: toggling opacity is cheaper
        // than rebuilding on every chip press.
        const name = document.createElementNS(SVG_NS, 'g');
        name.setAttribute('class', 'amenity-pin-name');
        const bg = document.createElementNS(SVG_NS, 'rect');
        bg.setAttribute('class', 'amenity-pin-bg');
        bg.setAttribute('y', String(-PIN_NAME_H / 2));
        bg.setAttribute('height', String(PIN_NAME_H));
        bg.setAttribute('rx', '7');
        const text = document.createElementNS(SVG_NS, 'text');
        text.setAttribute('class', 'amenity-pin-text');
        text.setAttribute('font-size', String(PIN_NAME_FONT));
        name.append(bg, text);
        pin.appendChild(name);

        // The glyph keeps 0,0 because that is the amenity's real centroid.
        pin.dataset.cls = cls;
        pin.dataset.cx = String(x);
        pin.dataset.cy = String(y);

        // After the dataset, which paintAmenityPinName reads to find the class.
        this.paintAmenityPinName(pin);
        return pin;
    }

    /** The pin's name and its plate, split out so relabelOverlay can repaint on language change.
     *  Width from character count (getBBox is unreliable in a fragment); signed offset for RTL. */
    paintAmenityPinName(pin) {
        const def = AMENITIES.find((a) => a.key === pin.dataset.cls);
        const group = pin.querySelector('.amenity-pin-name');
        if (!def || !group) {
            return;
        }
        const label = t(this.langValue, def.pinKey);
        const width = Math.round(label.length * PIN_NAME_FONT * 0.6) + 18;
        const dir = this.dir === 'rtl' ? -1 : 1;
        const cx = dir * (PIN_NAME_DX + width / 2);

        group.querySelector('.amenity-pin-text').textContent = label;
        group.querySelector('.amenity-pin-text').setAttribute('x', String(cx));
        const bg = group.querySelector('.amenity-pin-bg');
        bg.setAttribute('x', String(cx - width / 2));
        bg.setAttribute('width', String(width));
    }

    /** Counter-scales pins and captions to a constant on-screen size. Runs on every camera
     *  change, so it touches transforms only. */
    scaleAmenityIcons() {
        const stage = this.stage;
        if (!stage) {
            return;
        }
        const sx = this.fitScale * this.zoom;
        if (!sx) {
            return;
        }
        const iconScale = ICON_PX / (ICON_UNITS * sx);
        for (const key of Object.keys(this.amenityIcons)) {
            for (const pin of this.amenityIcons[key]) {
                pin.setAttribute(
                    'transform',
                    `translate(${pin.dataset.cx} ${pin.dataset.cy}) scale(${iconScale})`
                );
            }
        }

        const tagScale = TAG_PX / (TAG_UNITS * sx);
        for (const tag of this.clusterTags) {
            tag.node.setAttribute(
                'transform',
                `translate(${tag.node.dataset.cx} ${tag.node.dataset.cy}) scale(${tagScale})`
            );
        }

        const numScale = NUM_PX / (NUM_UNITS * sx);
        for (const label of this.clusterNumbers) {
            label.node.setAttribute(
                'transform',
                `translate(${label.node.dataset.cx} ${label.node.dataset.cy}) scale(${numScale})`
            );
        }

        this.declutterPins(sx);
        this.scalePlates(sx);
    }

    /** Plot plates counter-scaled and thinned, touch only. translate/scale/translate scales
     *  about the anchor so the children keep their tuned geometry. */
    scalePlates(sx) {
        if (!this.touchDevice || !this.showPlates || !sx) {
            return;
        }
        const key = `${Math.round(sx * 1e5)}`;
        if (key === this.plateLayoutKey) {
            return;
        }
        this.plateLayoutKey = key;

        const kept = [];
        const clashes = (b) => kept.some((k) => b[0] < k[1] && b[1] > k[0] && b[2] < k[3] && b[3] > k[2]);

        for (const marker of this.labelNodes) {
            if (!marker) {
                continue;
            }
            const cx = Number(marker.dataset.cx);
            const cy = Number(marker.dataset.cy);
            const fs = Number(marker.dataset.fs) || 1;
            // Never below 1: a plate is never shrunk under the size it was designed at.
            const scale = Math.min(PLATE_SCALE_MAX, Math.max(1, PLATE_FONT_PX / (fs * sx)));
            marker.setAttribute('transform', `translate(${cx} ${cy}) scale(${scale}) translate(${-cx} ${-cy})`);

            // Same greedy box pass as the pins but measured per plate - a constant box
            // suppressed numbers that had room.
            const x = cx * sx;
            const y = cy * sx;
            const halfW = (Number(marker.dataset.bw) || 0) * scale * sx / 2 + PLATE_GUTTER;
            const halfH = (Number(marker.dataset.bh) || 0) * scale * sx / 2 + PLATE_GUTTER;
            const box = [x - halfW, x + halfW, y - halfH, y + halfH];
            // Touch shows every number. Desktop still thins them: it reaches the plate tier at a
            // much wider view, where the plates genuinely do compete.
            const crowded = !this.touchDevice && clashes(box);
            marker.classList.toggle('crowded', crowded);
            if (!crowded) {
                kept.push(box);
            }
        }
    }

    /** Walks pins in priority order, gives each its screen box and hides any that will not fit.
     *  A pure function of sx and the selection, so it is keyed on those and a drag re-runs nothing. */
    declutterPins(sx) {
        const key = `${Math.round(sx * 1e5)}|${[...this.activeAmenities].sort().join(',')}`;
        if (key === this.pinLayoutKey) {
            return;
        }
        this.pinLayoutKey = key;

        const kept = [];
        const clashes = (b) => kept.some((k) => b[0] < k[1] && b[1] > k[0] && b[2] < k[3] && b[3] > k[2]);

        for (const pin of this.pinsByPriority()) {
            const x = Number(pin.dataset.cx) * sx;
            const y = Number(pin.dataset.cy) * sx;
            // Selected pins carry their name, so they are wide rather than square. The name sits
            // on the trailing side, so the box grows that way only.
            const named = this.activeAmenities.indexOf(pin.dataset.cls) >= 0;
            const w = named ? PIN_BOX_NAMED : PIN_BOX;
            const lead = this.dir === 'rtl' ? w - PIN_BOX / 2 : PIN_BOX / 2;
            const box = [x - lead, x - lead + w, y - PIN_BOX / 2, y + PIN_BOX / 2];

            const crowded = clashes(box);
            pin.classList.toggle('crowded', crowded);
            if (!crowded) {
                kept.push(box);
            }
        }
    }

    /** Asks the journey to sign out; the session belongs to the component that issued it. */
    handleSignOut = () => {
        this.dispatchEvent(new CustomEvent('signout', { bubbles: true, composed: true }));
    };

    /** Every pin, selected classes first and then PIN_RANK, which is the order they compete in. */
    pinsByPriority() {
        const rank = (cls) => {
            const at = PIN_RANK.indexOf(cls);
            return at < 0 ? PIN_RANK.length : at;
        };
        const pins = [];
        for (const cls of Object.keys(this.amenityIcons)) {
            pins.push(...this.amenityIcons[cls]);
        }
        return pins.sort((a, b) => {
            const active =
                (this.activeAmenities.includes(a.dataset.cls) ? 0 : 1) -
                (this.activeAmenities.includes(b.dataset.cls) ? 0 : 1);
            return active || rank(a.dataset.cls) - rank(b.dataset.cls);
        });
    }

    /** The chips over the map, rebuilt whenever the language or the selection changes. */
    refreshAmenityChips() {
        const l = this.langValue;
        const present = AMENITIES.filter((a) => (this.amenityNodes[a.key] || []).length);
        this.amenityChips = present.map((a) => {
            const on = this.activeAmenities.indexOf(a.key) >= 0;
            const label = t(l, a.labelKey);
            return {
                key: a.key,
                icon: a.icon,
                label,
                title: label,
                pressed: on,
                cls: on ? 'amenity-chip active' : 'amenity-chip'
            };
        });
    }

    handleAmenityToggle = (event) => {
        event.stopPropagation();
        const key = event.currentTarget.dataset.key;
        const at = this.activeAmenities.indexOf(key);
        const on = at < 0;
        this.activeAmenities = on
            ? [...this.activeAmenities, key]
            : this.activeAmenities.filter((k) => k !== key);

        for (const node of this.amenityNodes[key] || []) {
            node.classList.toggle('on', on);
        }
        for (const pin of this.amenityIcons[key] || []) {
            pin.classList.toggle('on', on);
        }
        // The selection is half the layout key: a pressed chip reorders and widens its pins, so
        // the pass has to run again.
        this.pinLayoutKey = null;
        this.scaleAmenityIcons();
        this.refreshAmenityChips();
    };

    /* ---------- legend ---------- */

    /* No Key panel: the filter rows ARE the key - each carries the exact PRODUCTS hue the map
       paints those villas. */

    /** A control, not a key: it goes to the villa this customer holds. Fired by the held pill's
        own title, which replaced the legend row that used to carry it. */
    handleGoToHeld = (event) => {
        if (event) {
            event.stopPropagation();
        }
        if (this.heldIndex >= 0) {
            this.focusAndOpenUnit(this.heldIndex);
        }
    };

    /** Paints the held villa and restores its clickability - the server flips it to Reserved,
     *  right for everyone else and wrong for its holder. Early-returns on unchanged renders. */
    markHeld() {
        if (!this.overlayReady || !this.units.length) {
            return;
        }
        const wanted = this.heldValue || null;
        if (wanted === this.paintedHeld) {
            return;
        }
        this.paintedHeld = wanted;

        if (this.heldIndex >= 0 && this.unitNodes[this.heldIndex]) {
            this.unitNodes[this.heldIndex].classList.remove('held');
        }
        this.heldIndex = wanted ? this.units.findIndex((u) => u && u.plotUid === wanted) : -1;
        if (this.heldIndex < 0) {
            return;
        }
        const node = this.overlay && this.overlay.querySelector(`.unit[data-index="${this.heldIndex}"]`);
        if (node) {
            node.classList.add('held');
        }
    }

    /** Repaints text already drawn into the hand-built SVG after a language switch; only text
     *  changes, nothing rebuilds geometry. */
    relabelOverlay() {
        for (const tag of this.clusterTags) {
            const sub = tag.node.querySelector('.cluster-tag-sub');
            if (sub) {
                sub.textContent = t(this.langValue, this.clusterCountKey, num(tag.meta.available));
            }
        }
        // The captions carry the word for cluster, so they change with the language and the
        // plate resizes with the Arabic.
        for (const label of this.clusterNumbers) {
            this.paintClusterNumber(label.node, label.meta);
        }
        // The pins carry a name since 22 Aug, so they do have to be repainted - and the plate has
        // to be re-measured with it, because the Arabic is a different length.
        for (const cls of Object.keys(this.amenityIcons)) {
            for (const pin of this.amenityIcons[cls]) {
                this.paintAmenityPinName(pin);
            }
        }
        this.refreshAmenityChips();
    }

    /* ---------- basemap tiles ---------- */

    /** Builds the tile host and pins z0 (two tiles, 130 KB) down for good: finer levels stack
     *  above it, so an undecoded tile shows the overview through. Also clears the veil. */
    initTiles() {
        if (this.tileHost) {
            return;
        }
        const host = this.template.querySelector('.tile-layer');
        if (!host) {
            return;
        }
        this.tileHost = host;
        this.mountedTiles = new Map();
        // One layer per level, z-index rising with detail, so finer simply covers coarser.
        this.levelHosts = TILES.levels.map((level) => {
            const div = document.createElement('div');
            div.className = 'lvl';
            div.style.zIndex = String(level.z);
            host.appendChild(div);
            return div;
        });

        const base = TILES.levels[0];
        let pending = 0;
        const settle = () => {
            pending -= 1;
            if (pending <= 0) {
                this.imageReady = true;
            }
        };
        for (let y = 0; y < base.rows; y += 1) {
            for (let x = 0; x < base.cols; x += 1) {
                const img = this.mountTile(0, x, y);
                if (!img) {
                    continue;
                }
                pending += 1;
                img.addEventListener('load', settle);
                img.addEventListener('error', () => {
                    this.loadError = t(this.langValue, 'imageFailed');
                    settle();
                });
            }
        }
        if (pending === 0) {
            this.imageReady = true;
        }
        this.syncTiles();
    }

    /** One tile, placed in percentages of its own level, so the grid occupies exactly the box
     *  the single <img> did and the SVG overlay stays registered for free. */
    mountTile(z, x, y) {
        const key = `${z}/${x}/${y}`;
        const existing = this.mountedTiles.get(key);
        if (existing) {
            return existing;
        }
        const shard = TILES.tiles[key];
        // Absent means the tile was all background and never emitted. Skip it rather than 404.
        if (shard === undefined) {
            return null;
        }
        const level = TILES.levels[z];
        const size = TILES.tileSize;
        const left = x * size;
        const top = y * size;
        const right = Math.min(left + size + TILE_BLEED, level.w);
        const bottom = Math.min(top + size + TILE_BLEED, level.h);

        const img = document.createElement('img');
        img.src = `${TILE_SHARDS[shard]}/${key}.webp`;
        img.alt = '';
        img.draggable = false;
        img.decoding = 'async';
        img.style.left = `${(left / level.w) * 100}%`;
        img.style.top = `${(top / level.h) * 100}%`;
        img.style.width = `${((right - left) / level.w) * 100}%`;
        img.style.height = `${((bottom - top) / level.h) * 100}%`;
        this.levelHosts[z].appendChild(img);
        this.mountedTiles.set(key, img);
        return img;
    }

    /** The pyramid level whose pixels match the screen's at the current magnification, in
     *  device pixels. */
    targetLevel() {
        const needed = CANVAS.w * this.fitScale * this.zoom * (window.devicePixelRatio || 1);
        let z = TILES.levels.findIndex((level) => level.w >= needed);
        if (z < 0) {
            z = TILES.levels.length - 1;
        }
        return this.zoom <= OVERVIEW_ZOOM ? Math.min(z, OVERVIEW_TILE_LEVEL) : z;
    }

    /** The tile range covering the viewport at one level, with a tile of margin for a flick. */
    tileRange(z, fx0, fx1, fy0, fy1) {
        const level = TILES.levels[z];
        const size = TILES.tileSize;
        return {
            x0: Math.max(0, Math.floor((fx0 * level.w) / size) - 1),
            x1: Math.min(level.cols - 1, Math.floor((fx1 * level.w) / size) + 1),
            y0: Math.max(0, Math.floor((fy0 * level.h) / size) - 1),
            y1: Math.min(level.rows - 1, Math.floor((fy1 * level.h) / size) + 1)
        };
    }

    /** Mounts what the camera sees and drops the rest, retaining three levels - z0, the underlay
     *  below the target, the target - bounding the DOM without leaving gaps. */
    syncTiles() {
        const frame = this.frame;
        if (!this.tileHost || !this.fitScale || !frame || !frame.clientWidth) {
            return;
        }
        const w = CANVAS.w * this.fitScale * this.zoom;
        const h = CANVAS.h * this.fitScale * this.zoom;
        const clamp = (v) => Math.max(0, Math.min(1, v));
        const fx0 = clamp(-this.panX / w);
        const fx1 = clamp((frame.clientWidth - this.panX) / w);
        const fy0 = clamp(-this.panY / h);
        const fy1 = clamp((frame.clientHeight - this.panY) / h);

        const z = this.targetLevel();
        const range = this.tileRange(z, fx0, fx1, fy0, fy1);
        // A pan inside the same tiles changes nothing, and this runs on every frame of a drag.
        const key = `${z}:${range.x0}:${range.x1}:${range.y0}:${range.y1}`;
        if (key === this.tileKey) {
            return;
        }
        this.tileKey = key;

        const keep = new Set();
        const take = (level, r) => {
            for (let y = r.y0; y <= r.y1; y += 1) {
                for (let x = r.x0; x <= r.x1; x += 1) {
                    const k = `${level}/${x}/${y}`;
                    if (TILES.tiles[k] === undefined) {
                        continue;
                    }
                    keep.add(k);
                    this.mountTile(level, x, y);
                }
            }
        };
        const base = TILES.levels[0];
        take(0, { x0: 0, x1: base.cols - 1, y0: 0, y1: base.rows - 1 });
        if (z > 1) {
            take(z - 1, this.tileRange(z - 1, fx0, fx1, fy0, fy1));
        }
        take(z, range);

        this.mountedTiles.forEach((img, k) => {
            if (keep.has(k)) {
                return;
            }
            img.remove();
            this.mountedTiles.delete(k);
        });
    }

    /** One transform write per frame, for the drag path only; applyView stays synchronous
     *  elsewhere so callers can measure layout straight after. */
    scheduleView() {
        if (this.viewFrame) {
            return;
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.viewFrame = requestAnimationFrame(() => {
            this.viewFrame = 0;
            this.applyView();
        });
    }

    /* ---------- camera ---------- */

    applyView() {
        const stage = this.stage;
        // Bounded before every paint, so no path - drag, wheel, search, cluster focus - can
        // leave the map showing background.
        this.clampPan();
        if (stage) {
            stage.style.transform = `translate3d(${this.panX}px, ${this.panY}px, 0) scale(${this.renderScale})`;
        }
        this.scaleAmenityIcons();
        // Both before the threshold early-return below: panning changes what is on screen without
        // crossing any zoom threshold, and both layers are culled to the viewport.
        this.syncTiles();
        this.syncVillaArt();

        // Zoom moves the unit under the card, so follow it. Skipped while a placement is
        // already queued for the next render, which would otherwise measure a stale card.
        if (this.cardIndex >= 0 && this.pendingCardIndex < 0 && !this.exploring) {
            this.positionCard(this.cardIndex);
        }

        // Zooming back out to overview automatically re-enables the cluster layer.
        if (this.zoom <= OVERVIEW_ZOOM && this.selectedClusterId !== null) {
            this.selectedClusterId = null;
            this.closeCard();
        }

        const overview = this.zoom <= OVERVIEW_ZOOM;
        const showLabels = this.zoom >= LABEL_ZOOM;
        const showPlates = this.showPlates;
        const showClusters = this.showClusters;
        // Toggling ~3,400 nodes is only worth doing when a threshold is actually crossed.
        if (
            overview === this.lastOverview &&
            showLabels === this.lastShowLabels &&
            showPlates === this.lastShowPlates &&
            showClusters === this.lastShowClusters
        ) {
            return;
        }
        this.lastOverview = overview;
        this.lastShowLabels = showLabels;
        this.lastShowPlates = showPlates;
        this.lastShowClusters = showClusters;

        // Below LABEL_ZOOM the parcels are a few pixels across. One class on the root, and the
        // stylesheet drops the per-parcel glow and thickens the stroke; no per-node work.
        if (this.overlay) {
            this.overlay.classList.toggle('far', !showLabels);
        }

        // Hit-testing follows the wash: a drawn block is what you tap, then villas take over.
        // Keyed on showClusters, not `overview`, which a phone can never reach.
        for (const node of this.clusterNodes) {
            node.style.display = showClusters ? '' : 'none';
            node.style.pointerEvents = showClusters ? 'all' : 'none';
        }
        for (const label of this.clusterNumbers) {
            label.node.style.display = showClusters ? '' : 'none';
        }
        // Plot ranges take over where the cluster labels stop, never alongside them, and give way
        // again at the villa tier where each plot carries its own number.
        for (const tag of this.clusterTags) {
            tag.node.style.display = !showClusters && !showPlates ? '' : 'none';
        }

        // Drawn at every zoom, clickable only above the plan tier - an 8-pixel villa is not a
        // tap target, the cluster blocks are.
        for (const node of this.unitNodes) {
            node.style.pointerEvents = overview ? 'none' : 'all';
        }

        for (const node of this.labelNodes) {
            if (!node) {
                continue;
            }
            // Spared: a hovered plate is shown outside the plate tier by definition, so keying it
            // on showPlates alone would clear it on the next repaint, mid-hover.
            const on = showPlates || node === this.hoverPlate;
            node.style.display = on ? '' : 'none';
            node.classList.toggle('visible', on);
        }
    }

    // Restart the CSS transition rather than letting the previous one run on. The class is set
    // directly because LWC never re-applies an unchanged static class attribute on re-render.
    animateCamera(mode) {
        const stage = this.stage;
        if (!stage) {
            return;
        }
        stage.classList.remove('camera-animating', 'search-animating');
        void stage.offsetWidth;
        stage.classList.add(`${mode}-animating`);
        this.applyView();

        clearTimeout(this.cameraTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.cameraTimer = setTimeout(
            () => stage.classList.remove('camera-animating', 'search-animating'),
            mode === 'search' ? SEARCH_FLASH_MS : CAMERA_MS
        );
    }

    centreOn(x, y, zoom) {
        const frame = this.frame;
        const k = this.fitScale * zoom;
        this.zoom = zoom;
        this.panX = frame.clientWidth / 2 - geoToCanvasX(x) * k;
        this.panY = frame.clientHeight / 2 - geoToCanvasY(y) * k;
        this.scheduleLayoutBoost();
    }

    zoomAt(clientX, clientY, nextZoom) {
        const zoom = Math.max(this.zoomFloor, Math.min(this.zoomCeiling, nextZoom));
        const rect = this.frame.getBoundingClientRect();
        const pointerX = clientX - rect.left;
        const pointerY = clientY - rect.top;
        // Hold the point under the cursor steady while the scale changes.
        this.panX = pointerX - ((pointerX - this.panX) / this.zoom) * zoom;
        this.panY = pointerY - ((pointerY - this.panY) / this.zoom) * zoom;
        this.zoom = zoom;
        this.applyView();
        this.scheduleLayoutBoost();
    }


    /** Puts a rectangle of plan coordinates on screen, clamped so the camera stays between
     *  "recognisably the community" and "close enough to read a plate". */
    fitBounds(minX, minY, maxX, maxY) {
        const frame = this.frame;
        const width = Math.max(1, (maxX - minX) * this.fitScale);
        const height = Math.max(1, (maxY - minY) * this.fitScale);

        const fitted = Math.min(frame.clientWidth / width, frame.clientHeight / height) * 0.76;
        // Touch only, and deliberately NOT plateZoom - that would send every cluster tap to
        // maximum zoom. This floor means "villas distinguishable".
        const floor = this.touchDevice ? Math.min(TOUCH_FIT_FLOOR, this.zoomCeiling) : 2.4;
        const ceiling = this.touchDevice ? this.zoomCeiling : 5.6;
        this.centreOn((minX + maxX) / 2, (minY + maxY) / 2, Math.max(floor, Math.min(ceiling, fitted)));
    }

    focusCluster(meta) {
        this.selectedClusterId = String(meta.clusterId);
        this.fitBounds(meta.minX, meta.minY, meta.maxX, meta.maxY);

        this.closeCard();
        this.animateCamera('camera');
    }

    /* ---------- selection ---------- */

    // Close first, move the camera, then open the card once the map has settled. Without the
    // delay the card is placed against coordinates the map is still animating towards.
    focusAndOpenUnit(index) {
        clearTimeout(this.detailOpenTimer);
        this.selected = undefined;
        if (this.opsMode) {
            // However the card opens - tap, map search, board jump - assign needs the raw unit.
            this.opsTarget = this.units[index];
            this.opsConfirmingUnpin = false;
            this.opsMessage = '';
        }

        const centre = this.unitCenters[index];
        this.centreOn(centre.x, centre.y, this.zoomCeiling);
        this.animateCamera('camera');

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.detailOpenTimer = setTimeout(() => this.showDetails(index), DETAIL_OPEN_MS);
    }

    // Every path that dismisses the card must also kill a pending open, or a card the user
    // just closed reappears a fifth of a second later.
    closeCard() {
        clearTimeout(this.detailOpenTimer);
        this.selected = undefined;
        this.exploring = false;
        this.pendingCardIndex = -1;
        this.cardIndex = -1;
        this.markSelected(-1);
        // Ops card state goes with the card; the chosen applicant survives for the next villa.
        this.opsTarget = undefined;
        this.opsConfirmingUnpin = false;
        this.opsMessage = '';
        this.opsResults = [];
        this.opsTerm = '';
        this.opsHolder = undefined;
    }

    /** Clears the tint and plate off the villa whose card is open; the previous selection is
     *  restored before the new one is set. Pass -1 to clear. */
    markSelected(index) {
        if (index === this.selectedLabelIndex) {
            return;
        }
        for (const nodes of [this.unitNodes, this.labelNodes]) {
            const previous = nodes[this.selectedLabelIndex];
            if (previous) {
                previous.classList.remove('selected');
            }
            const next = index >= 0 ? nodes[index] : null;
            if (next) {
                next.classList.add('selected');
            }
        }
        this.selectedLabelIndex = index;
    }

    /** Sits the card beside its unit, flipping and clamping so it never hangs outside the map. */
    positionCard(index) {
        const card = this.template.querySelector('.floating-details');
        const centre = this.unitCenters[index];
        if (!card || !centre) {
            return;
        }
        // On a phone the card is a bottom sheet; stale inline left/top from a desktop layout
        // must be cleared or they keep winning over the sheet rules.
        if (this.touchDevice) {
            card.style.left = '';
            card.style.top = '';
            return;
        }

        const frame = this.frame;
        const k = this.fitScale * this.zoom;

        const x = geoToCanvasX(centre.x) * k + this.panX;
        const y = geoToCanvasY(centre.y) * k + this.panY;
        const cardW = card.offsetWidth;
        const cardH = card.offsetHeight;

        /* Opens on the reading-natural side and flips at the edge, both inverted under RTL.
           `left` stays physical: x, panX and centre.x all measure from the physical left edge. */
        const rtl = this.dir === 'rtl';
        const maxLeft = frame.clientWidth - cardW - CARD_MARGIN;
        let left = rtl ? x - cardW - CARD_GAP : x + CARD_GAP;
        let top = y - cardH / 2;
        if (rtl ? left < CARD_MARGIN : left > maxLeft) {
            left = rtl ? x + CARD_GAP : x - cardW - CARD_GAP;
        }
        // Clamped against both edges. The original only clamped the left, so a flipped card next
        // to the right-hand edge could still hang outside the frame.
        left = Math.min(Math.max(CARD_MARGIN, left), Math.max(CARD_MARGIN, maxLeft));
        top = Math.max(CARD_MARGIN, Math.min(top, frame.clientHeight - cardH - CARD_MARGIN));

        card.style.left = `${left}px`;
        card.style.top = `${top}px`;
    }

    showDetails(index) {
        // Opening a villa is where a customer starts to commit, so it is worth being current.
        this.refreshAvailability();
        const unit = this.units[index];
        // A different villa is a different gallery - type C has nineteen interiors where type A has
        // twelve - so the position never carries across.
        this.galleryIndex = 0;
        // The server flips a held unit to Reserved; without this the holder read the same badge
        // a stranger's villa gets.
        const isHeld = !!this.heldValue && unit.plotUid === this.heldValue;
        const status = isHeld ? 'Yours' : String(this.statusOf(unit) || 'Available');

        this.selected = {
            isHeld,
            unitId: this.idOf(unit, index),
            plotUid: unit.plotUid,
            status: isHeld ? t(this.langValue, 'yourVilla') : status,
            statusKey: isHeld ? 'held' : this.statusClass(status),
            type: this.typeOf(unit),
            category: unit.category,
            bedrooms: unit.bedrooms,
            bua: unit.bua,
            plotArea: unit.plotArea,
            price: this.formatAed(unit.price),
            additional: this.additionalFor(unit.price),
            provisional: unit.provisional,
            selectable: unit.selectable
        };
        this.pendingCardIndex = index;
        this.cardIndex = index;
        this.markSelected(index);
    }

    handleOverlayClick = (event) => {
        const target = event.target;
        if (this.mapLocked || this.dragMoved || !target.classList) {
            return;
        }
        if (target.classList.contains('cluster-block')) {
            event.stopPropagation();
            this.focusCluster(this.clusterMeta[Number(target.dataset.cluster)]);
            return;
        }
        if (target.classList.contains('unit')) {
            event.stopPropagation();
            // In pin mode a tap assigns, it never opens the customer card.
            if (this.opsMode) {
                // The reserve pool is the whole ops surface. The paint says so too,
                // but a class is not a permission - refuse the tap here as well.
                const tapped = this.units[Number(target.dataset.index)];
                if (this.opsPoolKnown && (!tapped || !this.opsTouchable(tapped))) {
                    return;
                }
                this.handleOpsUnitTap(Number(target.dataset.index));
                return;
            }
            this.focusAndOpenUnit(Number(target.dataset.index));
        }
    };

    /** The plot number under the pointer, in the band between the cluster tier and the plate
     *  tier where a villa is clickable but unlabelled. */
    handleOverlayHover = (event) => {
        // Touch first. mouseover still fires after a tap on several Android browsers, and without
        // this a tap would leave a number stuck on until the next repaint.
        if (this.touchDevice || this.mapLocked || this.showPlates || this.showClusters) {
            this.clearHoverPlate();
            return;
        }
        const target = event.target;
        if (!target.classList || !target.classList.contains('unit')) {
            this.clearHoverPlate();
            return;
        }
        // No hover number over stock ops cannot touch.
        if (this.opsMode && this.opsPoolKnown) {
            const hovered = this.units[Number(target.dataset.index)];
            if (!hovered || !this.opsTouchable(hovered)) {
                this.clearHoverPlate();
                return;
            }
        }
        this.showHoverPlate(Number(target.dataset.index));
    };

    handleOverlayLeave = () => {
        this.clearHoverPlate();
    };

    /** Ineligible parcels hold null in labelNodes and are skipped, matching the overlay's own
     *  hover rule. */
    showHoverPlate(index) {
        const marker = this.labelNodes[index];
        if (!marker || marker === this.hoverPlate) {
            return;
        }
        this.clearHoverPlate();

        /* Same arithmetic as scalePlates but uncapped - only one plate is drawn here.
           translate/scale/translate keeps the plate on its parcel. */
        const sx = this.fitScale * this.zoom;
        if (sx) {
            const fs = Number(marker.dataset.fs) || 1;
            const cx = Number(marker.dataset.cx);
            const cy = Number(marker.dataset.cy);
            const scale = Math.max(1, PLATE_FONT_PX / (fs * sx));
            marker.setAttribute('transform', `translate(${cx} ${cy}) scale(${scale}) translate(${-cx} ${-cy})`);
        }

        // dim comes off the pointed-at plate and goes back on the way out, because nothing else
        // would restore it.
        this.hoverPlateWasDim = marker.classList.contains('dim');
        marker.classList.remove('dim');
        marker.style.display = '';
        marker.classList.add('visible');
        this.hoverPlate = marker;
    }

    clearHoverPlate() {
        const marker = this.hoverPlate;
        if (!marker) {
            return;
        }
        this.hoverPlate = null;
        marker.removeAttribute('transform');
        // Back to whatever the tier says, rather than blindly hidden: clearing can happen at any
        // zoom, including after the camera has crossed into the plate tier mid-hover.
        const on = this.showPlates;
        marker.style.display = on ? '' : 'none';
        marker.classList.toggle('visible', on);
        if (this.hoverPlateWasDim) {
            marker.classList.add('dim');
        }
        this.hoverPlateWasDim = false;
    }

    // Card controls that remove themselves on click (result row, Change chip, Unpin ask) are
    // detached before the bubble reaches the frame, so onChrome's closest() misses and the
    // frame closed the card. The card stops its own clicks instead.
    handleCardClick(event) {
        event.stopPropagation();
    }

    // A click that lands on neither a unit nor the card itself dismisses the card.
    handleFrameClick(event) {
        if (!this.selected || this.dragMoved) {
            return;
        }
        const target = event.target;
        const onUnit = target.classList && target.classList.contains('unit');
        // onChrome, not just the card - without it zooming or filtering closed the open card.
        if (!onUnit && !this.onChrome(target)) {
            this.closeCard();
        }
    }

    handleSelect(event) {
        event.stopPropagation();
        const unit = this.selected;
        // selectable as well as present: taken plots reached this handler. reserving guards the
        // double-click - a second in-flight call would race its own response.
        const isHeld = !!this.heldValue && unit && unit.plotUid === this.heldValue;
        if (!unit || (!unit.selectable && !isHeld) || this.reserving) {
            return;
        }

        /* ASK BEFORE THE WRITE: takeUnit releases a committed reservation and spends a change,
           so the confirm must come first - Cancel used to restore nothing. Unsigned holds swap freely. */
        if (this.heldCommitted && this.heldValue && unit.plotUid !== this.heldValue) {
            this.pendingSwapUnit = unit;
            this.dispatchEvent(
                new CustomEvent('swaprequest', {
                    bubbles: true,
                    composed: true,
                    detail: { plotUid: unit.plotUid }
                })
            );
            return;
        }
        this.takeUnit(unit);
    }

    /** The journey confirmed the swap. Nothing was written until now, which is the whole point. */
    @api
    confirmSwap() {
        const unit = this.pendingSwapUnit;
        this.pendingSwapUnit = null;
        if (unit && !this.reserving) {
            this.takeUnit(unit);
        }
    }

    /** The journey cancelled. There is nothing to undo, which is also the point. */
    @api
    cancelSwap() {
        this.pendingSwapUnit = null;
    }

    /** The write, lifted out of handleSelect unchanged so both routes reach the server identically. */
    takeUnit(unit) {
        this.reserving = true;
        clearTimeout(this.toastTimer);
        this.toastMessage = t(this.langValue, 'checkingVilla');

        // This WRITES: quote() takes a soft hold (v1.1, 17 Aug 2026), pulling the villa off other
        // customers' maps. Anything that must not consume stock has to stop short of this call.
        quoteUnit({ token: this.sessionToken, plotUid: unit.plotUid })
            .then((quote) => {
                this.showNotice(t(this.langValue, 'continuingToReservation', unit.plotUid));
                // The reservation card renders over the MAP, so explore must close or "Change
                // villa" appears to do nothing.
                this.exploring = false;
                this.closeCard();
                this.dispatchEvent(
                    new CustomEvent('unitselected', {
                        bubbles: true,
                        composed: true,
                        detail: { plotUid: unit.plotUid, unitId: unit.unitId, quote }
                    })
                );
            })
            .catch((error) => {
                this.toastMessage = this.messageOf(error);
                // Somebody was faster: grey the parcel and send them back to the community
                // rather than leaving them on a villa they cannot have.
                this.markTaken(unit.plotUid);
                this.exploring = false;
                this.closeCard();
                clearTimeout(this.toastTimer);
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                this.toastTimer = setTimeout(() => {
                    this.toastMessage = '';
                }, 8000);
            })
            .finally(() => {
                this.reserving = false;
            });
        // A toast with no timer of its own stayed on screen forever if the call never settled,
        // with the CTA dead behind it and no way back short of a reload.
        clearTimeout(this.toastTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.toastTimer = setTimeout(() => {
            this.toastMessage = '';
        }, 15000);
    }

    /** Public so the journey can surface a message on a stage where its own error box does not
     *  render. Also used for the map's own success and failure notices. */
    @api
    showNotice(message) {
        clearTimeout(this.toastTimer);
        this.toastMessage = message || '';
        if (!message) {
            return;
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.toastTimer = setTimeout(() => {
            this.toastMessage = '';
        }, 6000);
    }

    /** Apex sends MSG_* codes rather than prose so the text can be Arabic or English. */
    messageOf(error) {
        const raw =
            (error && error.body && error.body.message) || (error && error.message) || 'MSG_GENERIC';
        return raw.indexOf('MSG_') === 0 ? t(this.langValue, raw) : raw;
    }

    handleCloseDetails(event) {
        event.stopPropagation();
        this.closeCard();
    }

    /* ---------- search ---------- */

    normalizeUnitSearch(value) {
        // Arabic-Indic digits first: JS \d is ASCII-only and Number('٤٠٥') is NaN, so an Arabic
        // keyboard's digits fell straight through to "not found".
        return toLatinDigits(String(value ?? ''))
            .trim()
            .replace(/^unit\s*/i, '')
            .replace(/^#/, '')
            .trim();
    }

    /** The lookup, over whichever set the caller cares about; a predicate keeps the bookable
     *  and taken passes on identical matching rules. */
    findUnitIndexBy(raw, allowed) {
        const query = this.normalizeUnitSearch(raw);
        if (!query) {
            return -1;
        }

        const lower = query.toLowerCase();
        const mine = (unit) => !!unit && allowed(unit);

        // The plot UID goes first: it is the only unambiguous key. A bare plot number matches up
        // to four villas, so it is only tried once the UID has failed.
        let index = this.units.findIndex(
            (unit) => mine(unit) && String(unit.plotUid || '').toLowerCase() === lower
        );
        if (index >= 0) {
            return index;
        }

        // Numeric fallback, so "405" or "00405" still finds a plot. Plot number first, since that
        // is the half of the UID a customer would type; then the plan's own 1-1659 numbering.
        if (/^\d+$/.test(query)) {
            const target = Number(query);
            index = this.units.findIndex((unit) => mine(unit) && Number(unit.plotNo) === target);
            if (index < 0) {
                index = this.units.findIndex((unit) => mine(unit) && Number(unit.num) === target);
            }
        }
        return index;
    }

    // Eligible and matches(): search opens the card directly, so pointer-events cannot stop it
    // reaching round eligibility or the filters.
    findUnitIndexBySearch(raw) {
        return this.findUnitIndexBy(raw, (unit) => unit.eligible && this.matches(unit));
    }

    handleSearchInput() {
        this.searchMessage = '';
    }

    handleSearchKeydown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleSearch();
        }
    }

    handleSearch() {
        const input = this.template.querySelector('.search-input');
        const index = this.findUnitIndexBySearch(input.value);
        this.searchMessage = '';

        // One answer for every miss, and never "not found": the villa is usually real and just
        // taken, out of category or filtered out. Nothing to open, so the line is the whole reply.
        if (index < 0) {
            this.searchMessage = t(this.langValue, 'searchUnavailable', input.value.trim());
            input.focus();
            return;
        }

        const polygon = this.overlay && this.overlay.querySelector(`.unit[data-index="${index}"]`);
        if (!polygon) {
            this.searchMessage = t(this.langValue, 'searchNotRendered');
            return;
        }

        // Search is navigation only; it does not filter any other units.
        this.selectedClusterId = null;
        this.focusAndOpenUnit(index);

        for (const node of this.unitNodes) {
            node.classList.remove('search-hit');
        }
        polygon.classList.add('search-hit');
        clearTimeout(this.searchTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchTimer = setTimeout(() => polygon.classList.remove('search-hit'), SEARCH_FLASH_MS);
    }

    /* ---------- toolbar and pointer ---------- */

    /** Pull back to the whole community; public because "Change villa" has to land the customer
     *  somewhere they can actually choose from. */
    @api
    showCommunity() {
        // Also leaves the explore view, which otherwise stays on top of the map it returned to.
        this.exploring = false;
        this.handleReset();
    }

    handleReset() {
        this.selectedClusterId = null;
        this.closeCard();
        this.zoom = this.zoomFloor;
        const home = this.homeView;
        this.panX = home.panX;
        this.panY = home.panY;
        this.animateCamera('camera');
    }

    handleZoomIn() {
        const rect = this.frame.getBoundingClientRect();
        this.zoomAt(rect.left + rect.width / 2, rect.top + rect.height / 2, this.zoom * ZOOM_FACTOR);
    }

    handleZoomOut() {
        const rect = this.frame.getBoundingClientRect();
        this.zoomAt(rect.left + rect.width / 2, rect.top + rect.height / 2, this.zoom / ZOOM_FACTOR);
        // Fully zoomed out means centred; against zoomFloor because an equality test with
        // ZOOM_MIN never fired.
        if (this.zoom <= this.zoomFloor * 1.01) {
            const home = this.homeView;
            this.panX = home.panX;
            this.panY = home.panY;
            this.applyView();
        }
    }

    // Anything over the chrome belongs to the chrome: the filter panel scrolls natively and
    // the map stays put.
    onChrome(target) {
        return !!(
            target &&
            target.closest &&
            target.closest(
                '.hud, .filter-rail, .image-controls, .legend, .floating-details, .amenity-bar,' +
                    // The toolbar and the top bar are new; .zoom-out-bar was always missing from
                    // this list, so a wheel over "Zoom out" zoomed the map underneath it.
                    // So was .ops-board-overlay - a wheel over the enlarged board zoomed the map.
                    '.map-tools, .id-card, .zoom-out-bar, .ops-board-overlay'
            )
        );
    }

    handleWheel(event) {
        if (this.mapLocked || this.onChrome(event.target)) {
            return;
        }
        event.preventDefault();
        this.zoomAt(event.clientX, event.clientY, this.zoom * (event.deltaY < 0 ? WHEEL_FACTOR : 1 / WHEEL_FACTOR));
    }

    handlePointerDown(event) {
        // Cleared before the early returns: a click on a unit must not inherit dragMoved from
        // the drag that came before it, or the click is swallowed.
        this.dragMoved = false;

        const target = event.target;
        if (this.mapLocked || this.onChrome(target)) {
            return;
        }

        // Tracked even when the press lands on a unit, so a pinch that starts with a finger on
        // a parcel still registers as a pinch rather than a tap on that parcel.
        if (event.pointerType !== 'mouse') {
            this.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
            if (this.pointers.size === 2) {
                this.dragging = false;
                this.pinchDistance = this.pointerSpread();
                this.pinchZoom = this.zoom;
                return;
            }
            if (this.handleDoubleTap(event)) {
                return;
            }
        }

        // A press on a villa or block still arms the pan; DRAG_THRESHOLD decides tap vs drag.
        // Returning here left nowhere to grab at cluster zoom.
        if (event.pointerType === 'mouse' && event.button !== 0) {
            return;
        }
        this.dragging = true;
        this.dragStartX = event.clientX;
        this.dragStartY = event.clientY;
        this.panStartX = this.panX;
        this.panStartY = this.panY;
    }

    // Distance between the two live touch points, in CSS pixels.
    pointerSpread() {
        const [a, b] = [...this.pointers.values()];
        return Math.hypot(a.x - b.x, a.y - b.y);
    }

    pointerMidpoint() {
        const [a, b] = [...this.pointers.values()];
        return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
    }

    // Double tap zooms in, the standard map gesture. Returns true when it fired, so the caller
    // skips starting a drag.
    handleDoubleTap(event) {
        const now = Date.now();
        const quick = now - this.lastTapAt < 300;
        const near = Math.abs(event.clientX - this.lastTapX) < 30 && Math.abs(event.clientY - this.lastTapY) < 30;
        this.lastTapAt = now;
        this.lastTapX = event.clientX;
        this.lastTapY = event.clientY;
        if (quick && near) {
            this.lastTapAt = 0;
            this.zoomAt(event.clientX, event.clientY, this.zoom * ZOOM_FACTOR * ZOOM_FACTOR);
            return true;
        }
        return false;
    }

    handlePointerMove(event) {
        if (this.pointers.has(event.pointerId)) {
            this.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
        }

        // Pinch takes precedence: scale by how far the fingers have spread, anchored on the
        // midpoint between them so the map grows out of the gesture rather than the centre.
        if (this.pointers.size === 2) {
            const spread = this.pointerSpread();
            if (this.pinchDistance > 0) {
                const mid = this.pointerMidpoint();
                this.zoomAt(mid.x, mid.y, this.pinchZoom * (spread / this.pinchDistance));
            }
            this.dragMoved = true;
            return;
        }

        if (!this.dragging) {
            return;
        }
        const deltaX = event.clientX - this.dragStartX;
        const deltaY = event.clientY - this.dragStartY;

        if (!this.dragMoved) {
            const threshold = event.pointerType === 'mouse' ? DRAG_THRESHOLD : TOUCH_DRAG_THRESHOLD;
            if (Math.abs(deltaX) <= threshold && Math.abs(deltaY) <= threshold) {
                return;
            }
            this.dragMoved = true;
            // Capture only once a real drag begins. Capturing on pointerdown retargets the
            // following click to the frame, which stops the buttons and units responding.
            this.frame.setPointerCapture(event.pointerId);
            // The card is anchored to its unit, so panning would drag it out of place.
            this.closeCard();
        }

        this.panX = this.panStartX + deltaX;
        this.panY = this.panStartY + deltaY;
        this.scheduleView();
    }

    handlePointerUp(event) {
        this.pointers.delete(event.pointerId);
        // Lifting one finger of a pinch must not hand the remaining finger a drag mid-gesture.
        if (this.pointers.size < 2) {
            this.pinchDistance = 0;
        }
        if (!this.dragging) {
            return;
        }
        this.dragging = false;
        if (this.frame.hasPointerCapture(event.pointerId)) {
            this.frame.releasePointerCapture(event.pointerId);
        }
    }

    /* ---------- Pin mode (ops only; server re-checks the double gate on every call) ---------- */

    loadPinBoard() {
        opsPinBoard({ sessionToken: this.sessionToken })
            .then((rows) => {
                this.opsBoard = rows || [];
                this.opsPinsByPlot = new Map(this.opsBoard.map((p) => [p.plotUid, p]));
                this.paintOpsPins();
            })
            .catch(() => {
                this.opsBoard = [];
            });
        // Alongside the board, so assigning a villa takes it off the free list at once. This
        // call is not cacheable, which is why the paint keys off it rather than the masterplan.
        opsAssignableStock({ sessionToken: this.sessionToken })
            .then((rows) => {
                this.opsStock = rows || [];
                this.opsStockLoaded = true;
                this.opsAssignablePlots = new Set(this.opsStock.map((u) => u.plotUid));
                this.repaintOpsStock();
            })
            .catch(() => {
                this.opsStock = [];
                this.opsStockLoaded = true;
                this.opsAssignablePlots = new Set();
            });
    }

    get opsStockCount() {
        return num(this.opsStock.length);
    }

    get opsFreeLabel() {
        return t(this.langValue, 'opsFreeCount', this.opsStockCount);
    }

    get hasOpsStock() {
        return this.opsStock.length > 0;
    }

    get opsStockRows() {
        return this.opsStock.map((u) => ({
            plotUid: u.plotUid,
            cluster: u.cluster ? t(this.langValue, 'cluster', num(u.cluster)) : '',
            villaType: pick(this.langValue, u.villaType),
            bedrooms: u.bedrooms == null ? '' : num(u.bedrooms),
            price: this.formatAed(u.price)
        }));
    }

    get opsAssignedTabClass() {
        return this.opsBoardTab === 'assigned' ? 'ops-tab on' : 'ops-tab';
    }

    get opsAvailableTabClass() {
        return this.opsBoardTab === 'available' ? 'ops-tab on' : 'ops-tab';
    }

    get showOpsAssigned() {
        return this.opsBoardTab === 'assigned';
    }

    get showOpsAvailable() {
        return this.opsBoardTab === 'available';
    }

    handleOpsTab = (event) => {
        this.opsBoardTab = event.currentTarget.dataset.tab;
    };

    /** Reconciles the violet tint with the board - runs after every board load, so every pin and
     *  unpin repaints without a rebuild. */
    paintOpsPins() {
        if (!this.opsMode || !this.overlay) {
            return;
        }
        const want = new Set(this.opsPinsByPlot.keys());
        const toggle = (uid, on) => {
            const i = this.unitIndexByPlot.get(uid);
            // Same reason as repaintOpsStock: the node knows its own index, the array may not.
            const node = i === undefined ? null : this.overlay.querySelector(`.unit[data-index="${i}"]`);
            if (node) {
                node.classList.toggle('ops-pinned', on);
            }
        };
        for (const uid of this.opsPinsPainted) {
            if (!want.has(uid)) {
                toggle(uid, false);
            }
        }
        for (const uid of want) {
            toggle(uid, true);
        }
        this.opsPinsPainted = want;
    }

    handleOpsTerm = (event) => {
        this.opsTerm = event.target.value || '';
        window.clearTimeout(this.opsSearchTimer);
        const term = this.opsTerm;
        this.opsSearchTimer = window.setTimeout(() => {
            if (term.trim().length < 2) {
                this.opsResults = [];
                return;
            }
            opsSearchApplicants({ sessionToken: this.sessionToken, term })
                .then((rows) => {
                    // A slow older response must not overwrite a newer term's results.
                    if (term === this.opsTerm.trim()) {
                        this.opsResults = rows || [];
                    }
                })
                .catch(() => {
                    this.opsResults = [];
                });
        }, 300);
    };

    // Who holds the taken villa whose card is open. Ops only, read-only.
    opsHolder;

    /** Executive stock still free to assign, and which half of the board is showing. */
    opsStock = [];

    /** Plot ids of that stock. The map paints from this, never from the cacheable masterplan
     *  payload, which a browser can serve back from before the pool existed. */
    opsAssignablePlots = new Set();

    opsStockLoaded = false;

    /** How many villas the last sweep actually painted as free stock. Support readout only. */
    opsPaintedCount = 0;

    opsBoardTab = 'assigned';

    /** Whether the loaded payload knows about reserve stock at all. False means an older cached
     *  response, and every reserve-stock rule stands down so ops keeps a working map. */
    opsFlagsPresent = false;

    handleOpsPick = (event) => {
        const appNo = event.currentTarget.dataset.app;
        const row = this.opsResults.find((r) => r.applicationNumber === appNo);
        if (!row || row.pinnedPlotUid || row.hasActiveReservation || row.expired) {
            return; // tagged rows are not assignable - the server would refuse anyway
        }
        this.opsSelected = row;
        this.opsMessage = '';
        this.opsResults = [];
        this.opsTerm = '';
    };

    handleOpsClearApplicant = () => {
        this.opsSelected = undefined;
        this.opsMessage = '';
    };

    handleOpsUnitTap(index) {
        const unit = this.units[index];
        if (!unit) {
            return;
        }
        // focusAndOpenUnit sets the ops target; here only the search state resets.
        this.opsResults = [];
        this.opsTerm = '';
        this.focusAndOpenUnit(index);
        this.loadOpsHolder(unit.plotUid);
    }

    /** A taken villa tells ops who has it. Silent on failure - the card still works. */
    loadOpsHolder(plotUid) {
        this.opsHolder = undefined;
        if (!this.opsMode || !plotUid) {
            return;
        }
        opsHolderOf({ sessionToken: this.sessionToken, plotUid })
            .then((h) => {
                // Only if the same card is still open - taps can outrun responses.
                if (h && this.selected && this.selected.plotUid === plotUid) {
                    this.opsHolder = h;
                }
            })
            .catch(() => {
                this.opsHolder = undefined;
            });
    }

    get opsHolderLine() {
        const h = this.opsHolder;
        if (!h) {
            return '';
        }
        const who = `${h.applicationNumber} ${h.customerName}`;
        return `${t(this.langValue, 'opsReservedBy')} ${who} (${this.opsStatusLabel(h.status)})`;
    }

    get opsTargetPin() {
        return this.opsTarget ? this.opsPinsByPlot.get(this.opsTarget.plotUid) : undefined;
    }

    get cardClass() {
        return this.opsMode ? 'floating-details ops' : 'floating-details';
    }

    /** The pin on the card's villa. The board row wins (it has the name); the DTO flag covers
     *  the moments before the board has answered. */
    get opsCardPin() {
        if (!this.selected) {
            return undefined;
        }
        const fromBoard = this.opsPinsByPlot.get(this.selected.plotUid);
        if (fromBoard) {
            return fromBoard;
        }
        const i = this.cardIndex;
        const raw = i >= 0 ? this.units[i] : undefined;
        return raw && raw.pinned ? { applicationNumber: '', customerName: '' } : undefined;
    }

    get opsCardPinLabel() {
        const pinRow = this.opsCardPin;
        const who = pinRow
            ? [pinRow.applicationNumber, pinRow.customerName].filter(Boolean).join(' ')
            : '';
        return who
            ? t(this.langValue, 'opsPinnedToName', who)
            : t(this.langValue, 'opsPinnedBadge');
    }

    get opsCardAssignable() {
        const u = this.selected;
        return !!(u && u.selectable && !this.taken.has(u.plotUid) && !this.opsCardPin);
    }

    get opsSelectedLabel() {
        const a = this.opsSelected;
        return a ? `${a.applicationNumber} ${a.customerName}` : '';
    }

    get opsAssignLabel() {
        return t(this.langValue, this.opsPinning ? 'opsAssigning' : 'opsAssign');
    }

    get opsBusy() {
        return this.opsPinning || this.opsUnpinning;
    }

    get opsResultRows() {
        return this.opsResults.map((r) => {
            const blocked = !!(r.hasActiveReservation || r.pinnedPlotUid || r.expired);
            return {
                ...r,
                blocked,
                tag: r.pinnedPlotUid
                    ? t(this.langValue, 'opsPinnedToName', r.pinnedPlotUid)
                    : r.hasActiveReservation
                        ? t(this.langValue, 'opsTagReserved')
                        : r.expired
                            ? t(this.langValue, 'opsTagExpired')
                            : '',
                cls: blocked ? 'ops-result blocked' : 'ops-result'
            };
        });
    }

    // Informative only - the pin overrides eligibility, so warn, never block.
    get opsWarnings() {
        const out = [];
        const a = this.opsSelected;
        const u = this.opsTarget;
        if (!a || !u) {
            return out;
        }
        const cats = (a.categories || '').split(';');
        if (u.category && !cats.includes(u.category)) {
            out.push(t(this.langValue, 'opsWarnCategory'));
        }
        const aliased = a.serviceType === 'House Purchase Deferred Loan'
            ? 'House Purchase Loan' : a.serviceType;
        if (u.service && aliased !== u.service) {
            out.push(t(this.langValue, 'opsWarnService'));
        }
        if (u.price != null && a.approvedLoanAmount != null && u.price > a.approvedLoanAmount) {
            out.push(t(this.langValue, 'opsWarnPrice'));
        }
        return out;
    }

    get hasOpsWarnings() {
        return this.opsWarnings.length > 0;
    }

    get hasOpsResults() {
        return this.opsResults.length > 0;
    }

    get opsCanPin() {
        return !!(this.opsSelected && this.opsTarget && this.opsCardAssignable && !this.opsPinning);
    }

    get opsPinDisabled() {
        return !this.opsCanPin;
    }

    opsStatusLabel(status) {
        // Tolerates null: a hand-written pin can reach the board with no derived status.
        const k = String(status || 'waiting');
        return t(this.langValue, 'opsStatus' + k.charAt(0).toUpperCase() + k.slice(1));
    }

    get hasOpsBoard() {
        return this.opsBoard.length > 0;
    }

    opsCount(status) {
        return num(this.opsBoard.filter((p) => p.pinStatus === status).length);
    }

    get opsCountPinned() {
        return num(this.opsBoard.length);
    }

    get opsCountWaiting() {
        return this.opsCount('waiting');
    }

    get opsCountBooked() {
        return this.opsCount('booked');
    }

    get opsCountSigned() {
        return this.opsCount('signed');
    }

    /** Rows for the enlarged table: age computed here, per open - board data is refetched on
     *  every pin action, so a server-side day count would only go stale. */
    get opsTableRows() {
        const now = Date.now();
        const rows = this.opsBoard.map((p) => {
            const ts = p.pinnedOn ? new Date(p.pinnedOn).getTime() : 0;
            return {
                ...p,
                ts,
                pinnedOnLabel: ts
                    ? new Date(ts).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })
                    : '-',
                daysWaiting: ts ? num(Math.floor((now - ts) / 86400000)) : '-',
                confirming: p.plotUid === this.opsConfirmingUnpinPlot,
                statusLabel: this.opsStatusLabel(p.pinStatus)
            };
        });
        const dir = this.opsSortAsc ? 1 : -1;
        rows.sort((a, b) => {
            if (this.opsSortKey === 'status') {
                return String(a.pinStatus).localeCompare(String(b.pinStatus)) * dir;
            }
            // Oldest first by default; unstamped pins (ts 0) sort to the end either way.
            const at = a.ts || Number.MAX_SAFE_INTEGER;
            const bt = b.ts || Number.MAX_SAFE_INTEGER;
            return (at - bt) * dir;
        });
        return rows;
    }

    get opsPanelEmpty() {
        return this.opsBoard.length === 0;
    }

    /** The reserve pool is what ops allocates from, so a payload without one leaves an inert,
     *  colourless map. That is indistinguishable from a broken map, so say so rather than let ops
     *  hunt a plan that can never answer. Flags present but nothing flagged = a stale cached build. */
    /** Invisible unless the URL carries opsdebug, so it costs ops nothing and gives support a
     *  straight answer about where a paint problem sits. */
    get showOpsDebug() {
        return this.opsMode && String(window.location.search || '').includes('opsdebug');
    }

    get opsDebugLine() {
        const flagged = this.units.filter((u) => u.reserveStock === true).length;
        const nodes = this.overlay ? this.overlay.querySelectorAll('.unit').length : 0;
        const isOps = this.applicant ? this.applicant.isOps : 'n/a';
        return `units ${this.units.length} | flagged ${flagged} | stock ${this.opsStock.length}`
            + ` | nodes ${nodes} | teal ${this.opsPaintedCount} | payload isOps ${isOps}`;
    }

    get opsReserveMissing() {
        // Only when the free list itself came back empty. Payload flags disagreeing with it is
        // a cache artefact, not something ops can act on.
        return this.opsMode && this.opsStockLoaded && this.opsStock.length === 0;
    }

    handleOpsBoardOpen = () => {
        this.opsBoardOpen = true;
        this.opsConfirmingUnpinPlot = '';
        this.pendingOpsBoardFocus = true;
        this.loadPinBoard();
    };

    handleOpsBoardClose = () => {
        this.closeOpsBoard(true);
    };

    handleOpsBoardScrim = (event) => {
        if (event.target === event.currentTarget) {
            this.closeOpsBoard(true);
        }
    };

    closeOpsBoard(restoreFocus) {
        this.opsBoardOpen = false;
        this.opsConfirmingUnpinPlot = '';
        if (restoreFocus) {
            this.pendingOpsEnlargeFocus = true;
        }
    }

    handleOpsSort = (event) => {
        const key = event.currentTarget.dataset.sort;
        if (key === this.opsSortKey) {
            this.opsSortAsc = !this.opsSortAsc;
        } else {
            this.opsSortKey = key;
            this.opsSortAsc = true;
        }
    };

    handleOpsTableUnpin = (event) => {
        const plot = event.currentTarget.dataset.plot;
        if (this.opsUnpinning) {
            return;
        }
        // Two taps, per row: the first only arms the confirm.
        if (this.opsConfirmingUnpinPlot !== plot) {
            this.opsConfirmingUnpinPlot = plot;
            return;
        }
        this.opsUnpinning = true;
        opsUnpinUnit({ sessionToken: this.sessionToken, plotUid: plot })
            .then(() => {
                this.opsConfirmingUnpinPlot = '';
                this.showNotice(t(this.langValue, 'opsUnpinned', plot));
                this.loadPinBoard();
            })
            .catch((error) => {
                this.opsMessage = this.messageOf(error);
            })
            .finally(() => {
                this.opsUnpinning = false;
            });
    };

    handleOpsPin = () => {
        if (!this.opsCanPin) {
            return;
        }
        this.opsPinning = true;
        const plotUid = this.opsTarget.plotUid;
        const who = this.opsSelected;
        opsPinUnit({
            sessionToken: this.sessionToken,
            plotUid,
            applicationNumber: who.applicationNumber
        })
            .then(() => {
                this.opsMessage = '';
                this.showNotice(t(this.langValue, 'opsAssigned', plotUid, who.customerName));
                // Consumed: one pin per applicant. The board reload flips this card to pinned.
                this.opsSelected = undefined;
                this.loadPinBoard();
            })
            .catch((error) => {
                this.opsMessage = this.messageOf(error);
                // Somebody may have taken or pinned it meanwhile - reconcile both views.
                this.loadPinBoard();
                this.refreshAvailability();
            })
            .finally(() => {
                this.opsPinning = false;
            });
    };

    handleOpsUnpinAsk = () => {
        this.opsConfirmingUnpin = true;
    };

    handleOpsUnpin = () => {
        const plotUid = this.opsTarget ? this.opsTarget.plotUid : undefined;
        if (!plotUid || this.opsUnpinning) {
            return;
        }
        this.opsUnpinning = true;
        opsUnpinUnit({ sessionToken: this.sessionToken, plotUid })
            .then(() => {
                this.opsConfirmingUnpin = false;
                this.showNotice(t(this.langValue, 'opsUnpinned', plotUid));
                // The card stays open and flips to its assignable state on the board reload.
                this.loadPinBoard();
            })
            .catch((error) => {
                this.opsMessage = this.messageOf(error);
            })
            .finally(() => {
                this.opsUnpinning = false;
            });
    };

    handleOpsBoardJump = (event) => {
        const plot = event.currentTarget.dataset.plot;
        const index = this.unitIndexByPlot.get(plot);
        if (index === undefined) {
            return;
        }
        // From the table the jump lands on the map with the card open in its pinned state.
        if (this.opsBoardOpen) {
            this.closeOpsBoard(false);
        }
        this.handleOpsUnitTap(index);
    };

}