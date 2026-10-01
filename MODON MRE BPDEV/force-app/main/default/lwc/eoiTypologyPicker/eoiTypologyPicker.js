/**
 * eoiTypologyPicker — residence selection with per-typology quantities,
 * mirroring the HGE journey's residence step. Amounts are display-only;
 * the server re-reads them at submit.
 * @author Aurelix
 */
import { LightningElement, api, track } from 'lwc';
import getTypologies from '@salesforce/apex/EOIWadeemSiteController.getTypologies';
import basePath from '@salesforce/community/basePath';

/* MEOI-TILES (13 Sep 2026): bump when a tile picture is replaced under the same file name, so the
   public cache and browsers fetch the new file (4/5/6-bedrooms.jpg = MODON's villa renders). */
const TILE_ASSET_VERSION = '2';

export default class EoiTypologyPicker extends LightningElement {
    @api projectId;
    @api imageBase = '';
    @api initialCart; // rangeId -> quantity; re-seeds the cart when the customer comes back
    /* MEOI-A10 (corrected 9 Sep). Every available typology is ALWAYS offered, bought
       before or not. Choosing one again is a new, distinct EOI - the per-unit payment key
       gives it the next index after anything already paid. What "not shown again" meant
       was the Confirm & pay screen: settled lines do not reappear there. */

    @track tiles = [];
    @track cart = {};
    @track errorMessage = '';
    @track isLoading = true;

    connectedCallback() {
        if (this.initialCart) {
            const seed = {};
            Object.keys(this.initialCart).forEach((rangeId) => {
                const qty = parseInt(this.initialCart[rangeId], 10);
                if (qty > 0) {
                    seed[rangeId] = Math.min(10, qty);
                }
            });
            this.cart = seed;
        }
        getTypologies({ projectId: this.projectId })
            .then((tiles) => {
                /* MEOI-TILE-DEDUPE (10 Sep, Prateek/Mridul). Tiles are titled by bedrooms only,
                   so two typologies with the same bedroom count would look identical. Keep the
                   first range per bedroom count (server order) and drop the rest; production data
                   is expected to be clean, this is the guard. */
                const seen = new Set();
                this.imageAttempts = {};
                this.tiles = (tiles || []).filter((t) => {
                    const bn = parseInt(t.bedrooms, 10);
                    const key = isNaN(bn) ? String(t.bedrooms || t.rangeId) : String(bn);
                    if (seen.has(key)) {
                        return false;
                    }
                    seen.add(key);
                    return true;
                });
            })
            .catch((e) => {
                this.errorMessage = (e.body && e.body.message) || 'Could not load the collection.';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleAdd(event) {
        const id = event.currentTarget.dataset.rangeId;
        // server caps at 10 units per residence; keep the UI inside that
        const qty = Math.min(10, (this.cart[id] || 0) + 1);
        this.cart = { ...this.cart, [id]: qty };
        this.emitLineChange(id, 'added', qty);
    }

    handleRemove(event) {
        const id = event.currentTarget.dataset.rangeId;
        const qty = Math.max(0, (this.cart[id] || 0) - 1);
        const next = { ...this.cart };
        if (qty === 0) {
            delete next[id];
        } else {
            next[id] = qty;
        }
        this.cart = next;
        this.emitLineChange(id, 'removed', qty);
    }

    /* MEOI-ACT. Tells the parent about every + / - so the activity diary can record it;
       the parent decides whether the diary is on. */
    emitLineChange(rangeId, action, qty) {
        const tile = (this.tiles || []).find((t) => t.rangeId === rangeId);
        this.dispatchEvent(new CustomEvent('linechange', {
            detail: { rangeId, action, qty, bedrooms: (tile && tile.bedrooms) || '' }
        }));
    }

    handleContinue() {
        if (!this.selectionCount) {
            this.errorMessage = 'Select at least one villa.';
            return;
        }
        this.dispatchEvent(new CustomEvent('continue', {
            detail: { selections: this.selections, lines: this.lines, total: this.selectionTotal }
        }));
    }

    get hasTiles() {
        return !this.isLoading && this.tiles.length > 0;
    }
    get showEmpty() {
        return !this.isLoading && this.tiles.length === 0;
    }
    get tileViewModels() {
        return this.tiles.map((t) => {
            const qty = this.cart[t.rangeId] || 0;
            return {
                ...t,
                quantity: qty,
                hasQty: qty > 0,
                rowClass: qty > 0 ? 'm-lrow is-picked' : 'm-lrow',
                metaBr: t.bedrooms || t.unitTypology || '',
                metaLoc: t.phaseName || '',
                imageUrl: this.imageUrl(t.unitTypology, t.bedrooms, t.unitType),
                formattedAmount: this.formatAmount(t.amount),
                removeDisabled: qty <= 0
            };
        });
    }
    get collectionCap() {
        const n = this.tiles.length;
        return `The collection \u00B7 ${n} ${n === 1 ? 'typology' : 'typologies'}`;
    }
    get selections() {
        return Object.keys(this.cart).map((rangeId) => ({ rangeId, quantity: this.cart[rangeId] }));
    }
    get lines() {
        return this.tileViewModels
            .filter((t) => t.quantity > 0)
            .map((t) => ({
                rangeId: t.rangeId,
                unitTypology: t.unitTypology,
                bedrooms: t.bedrooms,
                phaseName: t.phaseName,
                quantity: t.quantity,
                lineTotal: (t.amount || 0) * t.quantity,
                formattedLineTotal: this.formatAmount((t.amount || 0) * t.quantity)
            }));
    }
    get selectionCount() {
        return Object.values(this.cart).reduce((a, b) => a + b, 0);
    }
    get selectionTotal() {
        return this.tiles.reduce((sum, t) => sum + (t.amount || 0) * (this.cart[t.rangeId] || 0), 0);
    }
    get formattedSelectionTotal() {
        return this.formatAmount(this.selectionTotal);
    }
    get selectionLine() {
        const n = this.selectionCount;
        return `${n} ${n === 1 ? 'villa' : 'villas'} selected`;
    }

    /* MEOI-IMG3 (11 Sep 2026). A tile's picture must survive whatever happens to the data
       or the files later: MODON cleared Unit Typology on the ranges on 11 Sep and every tile
       went blank because the file name was derived from that one field. The picture is now
       resolved at runtime through a chain of keys, each one tried only if the previous file
       does not exist (the <img> error handler moves to the next):
         1. the typology name      select-villas.jpg
         2. the bedroom count      4-bedrooms.jpg
         3. the unit type          villa.jpg
         4. the generic fallback   default.jpg
       Renaming a typology, clearing it, adding a 3-bedroom range or deleting a file can at
       worst land on default.jpg; only when even that is missing does the tile show the plain
       panel (MEOI-13a). Files live in Wadeem_Assets/typologies/. */
    imageCandidates(tile) {
        if (!this.imageBase) {
            return [];
        }
        const slugOf = (v) => (v || '').toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
        const bn = parseInt(tile.bedrooms, 10);
        const keys = [
            slugOf(tile.unitTypology),
            isNaN(bn) ? slugOf(tile.bedrooms) : `${bn}-bedrooms`,
            slugOf(tile.unitType),
            'default'
        ];
        const out = [];
        keys.forEach((k) => {
            if (k && !out.includes(k)) {
                out.push(k);
            }
        });
        return out.map((k) => `${this.siteImageBase}/${k}.jpg?v=${TILE_ASSET_VERSION}`);
    }
    imageUrl(unitTypology, bedrooms, unitType) {
        const c = this.imageCandidates({ unitTypology, bedrooms, unitType });
        return c.length ? c[0] : '';
    }
    /* which candidate each tile is currently showing (rangeId -> index); reset on load */
    imageAttempts = {};

    /* MEOI-IMG (11 Sep 2026). The page hands us a site-less resource path
       (/sfsites/c/resource/...). The platform answers such a path with a redirect to the
       domain's DEFAULT site (the broker portal on this domain) - fragile, different in every
       org, and seen failing in a customer browser (blank tiles). This site's own path serves
       the same files directly, so the base is prefixed with the community base path
       (/eoi here, /adibeoi on the ADIB site). Absolute and already-prefixed bases pass through. */
    get siteImageBase() {
        const base = this.imageBase || '';
        const site = (basePath || '').replace(/\/$/, '');
        if (site && base.startsWith('/sfsites/')) {
            return site + base;
        }
        return base;
    }

    /* MEOI-13a. Hiding the image is now safe: .m-lrow__media holds the 4:3 box and the
       sand background, so what remains is a deliberate placeholder rather than a
       collapsed card. Clearing the handler stops a broken src re-firing this on every
       re-render. Tile images are resolved by filename convention from the typology
       name, so a newly added typology with no matching file lands here - see the
       Typology_Image_URL__c proposal in the changelog. */
    handleImageError(event) {
        const img = event.target;
        // MEOI-IMG3: try the next key before giving up
        const id = img.dataset.rangeId;
        const tile = (this.tiles || []).find((t) => t.rangeId === id);
        if (tile) {
            const candidates = this.imageCandidates(tile);
            const next = (this.imageAttempts[id] || 0) + 1;
            this.imageAttempts[id] = next;
            if (next < candidates.length) {
                img.src = candidates[next];
                return;
            }
        }
        img.onerror = null;
        img.style.display = 'none';
    }

    formatAmount(amount) {
        try {
            return new Intl.NumberFormat('en-AE').format(amount || 0);
        } catch (e) {
            return String(amount || 0);
        }
    }
}