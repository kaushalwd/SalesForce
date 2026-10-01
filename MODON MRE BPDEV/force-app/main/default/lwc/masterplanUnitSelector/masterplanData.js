/**
 * Constants for masterplanUnitSelector.
 *
 * Unit geometry comes from ADHA_Unit__c via ADHA_MasterplanController. Cluster geometry does not:
 * the blocks are the plan's own CLUSTER DISTRIBUTION LIMITS boundaries, read from window.WB_CLUSTERS
 * in the WestBaniyasMasterplanData static resource along with each cluster's name and centre. That
 * boundary covers the whole cluster, roads and parks included, which is what lets a filled block
 * read as a marked area rather than as tinted houses. It was checked against the unit data before
 * being trusted: all 1,659 centroids fall inside their own cluster, no two clusters overlap, and
 * every villaCount matches. Member parcels remain the fallback if the resource does not load.
 *
 * Dimensions are the community crop of the CAD masterplan sheet inside
 * West_Baniyas_Road_Facing_Villas_Full_Masterplan.pdf. All polygon coordinates are normalised to
 * this frame, so changing the crop means re-normalising them.
 */
export const IMG_W = 7798;
export const IMG_H = 1951;

/**
 * The basemap's extent, in the same units, so the map can show the surrounding area without a
 * single record moving.
 *
 * IMG_W x IMG_H stays the GEOMETRY frame: every polygon, centroid and amenity is normalised
 * against it and still multiplies by it. CANVAS is only what the picture covers, and it is what
 * the SVG viewBox and the stage are sized from. The development therefore sits at 0,0 to
 * IMG_W,IMG_H inside a larger box that also carries the neighbouring districts and the arterials.
 *
 * NO LONGER FROM bake.py. The basemap is MODON's land use plan (WestBaniyasLandUse), so these
 * numbers come from fitting that sheet onto our parcel centroids, not from a bake. bake.py still
 * runs for WestBaniyasVillaBearings.js; its own basemap output is now unused.
 *
 * Fit: 1,622 of 1,659 plots matched, pure scale and translate at 1.220960 image px per frame unit,
 * median residual 0.52 px or about 0.011 of a plot width. Constrained to isotropic on purpose - an
 * unconstrained affine wanted 0.1% anisotropy, which would squash the picture.
 *
 * 16:9 SINCE 21 AUG 2026. The basemap was 9752x3078, aspect 3.1683, and no screen is that wide -
 * fitting it left 445 px of 900 black on a MacBook, half the display. MODON re-rendered the same
 * plan at 9752x5486 with desert and neighbouring blocks added above and below, and the map now
 * fills the viewport instead of letterboxing.
 *
 * NOTHING MOVED. Registration was measured, not assumed: template-matching the old sheet inside
 * the new one at full resolution gives dx=0, dy=+1204 at three widely separated patches, and
 * 5486-3078 is exactly 2x1204, so the addition is symmetric and the scale is unchanged. Only the
 * numbers below changed, and they are derived from that offset at 1.220954 px per frame unit:
 * y = -362.5 - 1204/1.220954, h = 5486/1.220954. x and w could not move, because dx is zero.
 *
 * Every polygon, centroid, cluster boundary and amenity pin is untouched - they are normalised
 * against IMG_W x IMG_H, which is the geometry frame and did not change.
 *
 * 24 AUG 2026 SHEET, AND STILL NOTHING MOVED. Same 9752x5486 frame, and 99.76% of it byte
 * identical to the 21 Aug render: the only difference is one 682x390 block at rows 1623-2012,
 * cols 1956-2637, north of WB2_01. Registration did not need measuring this time - rasterising
 * all 1,659 parcels and intersecting them with the diff gives zero changed pixels under any of
 * them, so no villa's artwork moved by even one pixel. The numbers below stand unchanged.
 */
export const CANVAS = { x: -31.8, y: -1348.6, w: 7987.2, h: 4493.2 };

/**
 * Provenance of the geometry, and what is and is not established about it.
 *
 * ESTABLISHED. The polygons are real parcel outlines lifted from the plan's vector layer
 * (the prototype recorded mappingSource: PDF_VECTOR_PARCEL_OUTLINE), normalised 0-1 against its
 * base render. Fitting deployed coordinates against those originals gives an exact linear
 * relation - max residual 6e-08 over 24 control points - so the load applied:
 *
 *     x_here = 1.025957 * x_prototype - 0.004719
 *     y_here = 1.372119 * y_prototype - 0.302552
 *
 * i.e. the prototype frame was cropped to x 0.00460-0.97930, y 0.22050-0.94930 and rescaled.
 * That transform is reproducible and is the one to invert if the geometry is ever re-derived.
 *
 * NOT ESTABLISHED. How that frame relates to a page box of the source PDF. An earlier note here
 * claimed "full sheet width, page y 0.2179-0.6916, correlation 0.978"; it is in a different
 * reference frame from the numbers above, the two cannot both describe the crop, and it should
 * not be relied on.
 *
 * NOW ESTABLISHED (15 Aug). The base image is the CAD sheet from
 * West_Baniyas_Road_Facing_Villas_Full_Masterplan.pdf - a 7680x5425 raster on the same 2384x1684
 * page - cropped at 97,1742 size 7368x1837 and scaled to 7798x1951. Our polygons land on the drawn
 * parcels at dx=0, dy=+3px, and both halves of the plan agree on that independently. CAD parcels
 * have crisp outlines, which is why the boundary-darkness metric works here and did not on the
 * render.
 *
 * WHY NOT THE PHOTOREALISTIC RENDER. It correlates only 0.80 against the plan (a faithful crop
 * scores 0.978), so it re-imagines geometry rather than reproducing it; buildings do not sit on
 * their CAD footprints. The separate Firefly/Gemini render is additionally only 1769x592 - 3.6 m
 * per pixel, about 7px per villa plot, against 0.81 m and ~33px for this image.
 *
 * SUPERSEDED NOTE. Whether the polygons were registered to the previous render.
 * Image-based fitting was attempted and abandoned as unsound: an unconstrained affine fit wanted
 * -126px at the right edge (about three parcel widths, consistent with locking onto neighbouring
 * parcels rather than the right ones), and two different objectives disagreed in sign - edge
 * darkness preferred dx=-18 on both halves of the plan while interior-vs-edge contrast preferred
 * dx=+52 on the left and +12 on the right, several hitting the search bound. The parcels are
 * colour-filled and carry printed text, so neither objective is specific enough on this raster.
 * Any correction derived that way would be a guess. Establish the transform analytically from the
 * PDF vector layer instead.
 *
 * RELOADING AFTER A NEW MASTERPLAN. A data reload, not a migration: Plot_UID__c is the identity
 * and geometry is only attached to it, so reservations, applicants and eligibility do not move.
 * Re-derive the outlines, restate Map_Polygon__c, Centroid_X__c, Centroid_Y__c, Cluster__c,
 * Zone__c, Phase__c and Masterplan_Number__c in one bulk upsert on Plot_UID__c, refresh
 * WB_CLUSTERS in the WestBaniyasMasterplanData static resource, and update IMG_W / IMG_H.
 *
 * Keep MASTER PLAN NEW Color.pdf as the source of truth: it is the layered original, and both
 * _Edited_ exports are flattened with zero optional-content groups.
 */
export const GEOMETRY_PROVENANCE = {
    source: 'MASTER PLAN NEW Color_Edited_03.pdf',
    fromPrototypeFrame: { sx: 1.025957, tx: -0.004719, sy: 1.372119, ty: -0.302552 },
    prototypeCrop: { x0: 0.00460, x1: 0.97930, y0: 0.22050, y1: 0.94930 },
    maxResidual: 6e-8,
    registeredToRaster: true
};
/**
 * The four products, and the one place their colours are written down.
 *
 * The filter rows and the map fills are the same thing now - a row is a product is a colour, the way
 * MODON's own viewer does it - so both are generated from here. The map rule is built into
 * OVERLAY_STYLES below and the row's swatch is set inline from `swatch`, which means there is no
 * second copy of these values anywhere and the panel cannot drift out of step with the plan.
 *
 * `key` is what FACETS stores as the selection and what groupClasses turns into a class pair. It is
 * built from the raw field values, never from a label, because the selection has to survive a
 * language switch.
 *
 * Four distinct hues, PAIRED by style rather than four shades of two. Two shades of one hue read as
 * near-duplicates in a list of rows, which is what these used to be.
 *
 * The pairing is what keeps the map legible. Style is the axis that is spatially coherent - of each
 * villa's six nearest neighbours 99.1% share its style, against 61.6% for bedrooms and 32.8% for
 * category, which is indistinguishable from random and painted confetti when it was tried. So the
 * two 5-bedroom hues carry the large contiguous fields and the two 6-bedroom hues, being only 332
 * villas, land as accents inside their own style's band rather than as scatter across the plan.
 * Checked by rendering all four over the basemap before choosing them.
 *
 * Orange is spendable again: the exclusion note further down reserved it for sold, and sold draws
 * nothing at all now. Green is still excluded and more firmly than before - the basemap is MODON's
 * photoreal render and the gardens are real grass.
 *
 * Pink is excluded too, since 24 Aug. Modern|6 was orchid #C765D9, and measuring it against the
 * other three settled what taste had already suggested: it was the WORST separated of the four,
 * not the best. Composited over the plan it sat at dE 24 from the Modern 5-bedroom blue - close to
 * the ~23 where two colours start being confusable at small size, and that blue is the one colour a
 * customer compares it against, being the row directly above it in the filter list. Burgundy is at
 * 35. Measure the COMPOSITED colour if these are ever revisited: the fills are translucent over a
 * photoreal render, so the opaque hex is not what anyone sees, and by that measure the pink looked
 * fine (dE 36) right up until it was composited.
 *
 * Two conventions the rows follow, so a fifth product does not have to rediscover them:
 *   - stroke is the same hue as its swatch at 0.46 of its lightness. All four sit at 0.45-0.47.
 *   - alpha is .40 for the 5-bedroom fields and .52 for the 6-bedroom accents. Modern|6 is the one
 *     exception at .60, because burgundy is darker and far less saturated than the orchid it
 *     replaced and stood off the sand too weakly at .52. Raising it further reads as a flat block
 *     and stops the render's roofs and gardens showing through, which is what the low alphas are for.
 */
export const PRODUCTS = [
    { key: 'Heritage|5', style: 'Heritage', bedrooms: 5, cls: 'style-heritage bed-5', swatch: '#2FBFC9', fill: 'rgba(47,191,201,.40)', stroke: '#0E5C63' },
    { key: 'Heritage|6', style: 'Heritage', bedrooms: 6, cls: 'style-heritage bed-6', swatch: '#F2913D', fill: 'rgba(242,145,61,.52)', stroke: '#7A4110' },
    { key: 'Modern|5', style: 'Modern', bedrooms: 5, cls: 'style-modern bed-5', swatch: '#5B76E8', fill: 'rgba(91,118,232,.40)', stroke: '#1D2A73' },
    { key: 'Modern|6', style: 'Modern', bedrooms: 6, cls: 'style-modern bed-6', swatch: '#9C3D52', fill: 'rgba(156,61,82,.60)', stroke: '#471C25' }
];

/** The product a unit belongs to, or null. One place, so the class, the swatch and the filter agree. */
export function productOf(unit) {
    if (!unit || !unit.villaType || unit.bedrooms == null) {
        return null;
    }
    return PRODUCTS.find((p) => p.style === unit.villaType && p.bedrooms === Number(unit.bedrooms)) || null;
}

/* Emitted into OVERLAY_STYLES. Colour only - see the warning about stroke-width below. */
const PRODUCT_FILLS = PRODUCTS.map(
    (p) => 'svg.wb-overlay .unit.available.' + p.cls.split(' ').join('.') +
           '{fill:' + p.fill + ';stroke:' + p.stroke + '}'
).join('\n');

/**
 * Styles for the manually built SVG overlay, injected as a <style> element inside the SVG.
 * Every selector is prefixed with svg.wb-overlay: an inline SVG <style> is not scoped, and
 * LWC's synthetic shadow does not scope it either, so unprefixed rules would hit the page.
 */
export const OVERLAY_STYLES = `
svg.wb-overlay{
  /* The stage already carries dir="ltr", but direction is inherited and this SVG is built
     by hand outside the template - pinning it here means no future wrapper can flip the map.
     Every text node uses text-anchor:middle, which is direction-immune; start/end would not be. */
  /* Dragging to pan must not highlight the plot numbers. Set here rather than in the component
     stylesheet because that cannot reach nodes built by hand; user-select inherits, so this one
     declaration covers the number plates, the cluster captions and the amenity glyphs. */
  user-select:none;-webkit-user-select:none;
  direction:ltr;position:absolute;inset:0;width:100%;height:100%;display:block;overflow:visible}

/* Sharp villas at zoom, under every parcel so the translucent status fills still read over them.
   Never a click target: the parcel polygon above it owns hit testing. */
svg.wb-overlay .villa-art{ pointer-events:none; }
svg.wb-overlay .villa-art image{ pointer-events:none; }

/* Deliberately sub-pixel, and there is a known cost to it. vector-effect below means stroke-width
   is in SCREEN pixels at every zoom, so 0.32 is a third of a pixel and whether it renders depends
   on where the edge lands on the grid.
   That is why one side of most plots does not draw. Villas back onto each other: measured across
   all 1,659 parcels, not one has all four edges shared, 752 have three shared and one open, and
   57% of all edges are stroked twice, once by each parcel meeting there. Two thirds-of-a-pixel
   stacked on the same line render; the single open edge facing the road does not.
   Raising these to 1.0 fixes that and was tried - it read too heavy, so the thin weight stands and
   the missing road edge is accepted. Raise all five together if that is ever revisited. */
svg.wb-overlay .unit{
  stroke-width:0.32;
  vector-effect:non-scaling-stroke;
  cursor:pointer;
  pointer-events:all;
  stroke-linejoin:round;
  stroke-linecap:round;
  transition:none;
}
/* Palette lifted from Modon's Hudayriyat viewer: a flat translucent fill per product tier with
   a crisp white outline. It reads there because the ground is a dark aerial - on our pale CAD
   sheet the same colours go chalky, which is why the earlier teal looked washed out. The scrim
   under the overlay (.stage-scrim) is what buys the contrast back. */
/* Available villas are the only thing the overlay marks: ineligible parcels draw nothing, so the
   fill alone carries the signal and the border only has to describe the plot edge.

   No drop-shadow. It used to carry availability back when the border was whisper-thin, but a
   filter blur is in user units, so the camera scales it: at FOCUS_ZOOM a 3px halo became a fat
   blue band that read as the border rather than as a glow. Losing it also loses 1,205
   per-element filters, which was the standing frame-rate risk. */
/* Colour says two things about a bookable parcel: hue is which part of the community it sits in,
   shade is whether it has five bedrooms or six. A coloured parcel is one this customer can book,
   which is why the legend carries no "Available" row. Geometry is shared; the rules below carry
   nothing but colour.

   Hue is the STYLE and not the category, which is the whole point. Of each villa's six nearest
   neighbours 99.1% share its style but only 32.8% share its category, and random mixing of three
   categories would be about 33% - so category is indistinguishable from noise and colouring by it
   painted confetti. Style paints the two clean bands the plan actually has. Shade within the hue is
   the bedroom count, so a swatch still teaches lighter-is-five, darker-is-six.

   This replaced hue-by-zone. Zone was 100% coherent but it is a planning boundary, not something a
   customer can choose, so no filter row could ever name it and the panel could not double as the
   key. Style x bedrooms measures 60.9% against zone x bedrooms' 61.6% - the same patchiness, on an
   axis that means something.

   Not green, in any of them. The villas sit in green gardens and the amenity blocks are green too:
   sampling 14,931 points inside real parcels gives 87.1% neutral with the garden green the only
   busy band, at 5.2%. That exclusion binds harder now the basemap is MODON's photoreal render and
   the lawns are real. Amber is spoken for by sold, grey by reserved, charcoal by blocked, and red
   reads as an error. */
svg.wb-overlay .unit.available{
  fill:rgba(81,179,214,.34);
  stroke:#145871;
  stroke-width:0.35;
}
/* The fill above is the fallback for a bookable villa that arrives without a style or a bedroom
   count - none do today, but renderData can emit a class pair that matches no product, and an
   invisible parcel would be worse than a wrongly coloured one.

   Colour only below, never stroke-width. The .far .unit.available rule ties these on specificity,
   so a width here would be settled by source order and the zoomed-out weight would quietly stop
   applying - the same trap that once made the held villa unclickable.

   Generated from PRODUCTS at the top of this file, which is also what paints the filter rows'
   swatches. Do not hand-write a rule here; add the product there and both follow.

   No backticks in here, ever: this whole block is a template literal, so one would close the
   string and turn the CSS that follows into JavaScript. That is exactly how the component was
   taken down once already. */
${PRODUCT_FILLS}
/* Reserved, sold and blocked draw nothing at all, exactly as ineligible does.
   The overlay marks a villa if and only if this customer can book it, in every state including
   exploration since 27 Aug 2026. Four different ways of
   saying no - grey, amber, charcoal, and nothing - told the customer the same thing four times
   and buried the plan doing it. The base image already draws every house, so a plot with no
   overlay still looks like a villa; it just is not on offer.
   Careful: .unit.held is the customer's OWN hold, and the server has flipped it to Reserved. It
   sits after this block and carries !important on fill and stroke, which is the only reason their
   villa does not vanish here. Do not move either rule. */
svg.wb-overlay .unit.reserved,
svg.wb-overlay .unit.sold,
svg.wb-overlay .unit.blocked{
  fill:none;
  stroke:none;
  pointer-events:none!important;
  cursor:default;
}

/* Ops sessions only (the svg root carries .ops there and nowhere else). Violet is the
   one unclaimed band: azure=bookable, amber=sold, grey=reserved, charcoal=blocked, ink=held. */
/* Ops with a payload from before the reserve-stock model carries none of the classes below, and
   reserved stock is inert for customers - without this they could not open a villa at all.
   .ops-quiet follows and wins,
   so once the reserve pool IS known this only covers what ops is still allowed to open. */
svg.wb-overlay.ops .unit.reserved,
svg.wb-overlay.ops .unit.sold,
svg.wb-overlay.ops .unit.blocked{
  pointer-events:all!important;
  cursor:pointer!important;
}

/* Everything outside the reserve pool. !important because the product fills carry five
   classes and would otherwise win; inert because ops allocates their own stock and nothing else. */
svg.wb-overlay.ops .unit.ops-quiet{
  fill:none!important;
  stroke:rgba(22,24,29,.16)!important;
  stroke-width:.25!important;
  stroke-dasharray:none!important;
  pointer-events:none!important;
}

/* The reserve pool ops allocates from. Teal, distinct from the violet pins over it.
   The alpha carries the whole map for ops - 300 parcels in a field of 1659 inert ones - so it is
   deliberately heavier than a customer product fill. */
svg.wb-overlay.ops .unit.ops-reserve{
  fill:rgba(23,118,130,.45)!important;
  stroke:#10606a!important;
  stroke-width:.5!important;
  pointer-events:all!important;
  cursor:pointer!important;
}

/* Reserve stock already booked out of the pool: still ops's own, so still readable - the dashes
   say it is spoken for and the card names the holder. */
svg.wb-overlay.ops .unit.ops-held{
  fill:rgba(23,118,130,.12)!important;
  stroke:#10606a!important;
  stroke-width:.4!important;
  stroke-dasharray:1.6 1.2;
  pointer-events:all!important;
  cursor:pointer!important;
}

svg.wb-overlay.ops .unit.ops-pinned{
  fill:rgba(124,88,211,.55)!important;
  stroke:#4c3390!important;
  stroke-width:0.6!important;
  stroke-dasharray:2 1.2;
  pointer-events:all!important;
  cursor:pointer!important;
}
/* Card open on a pinned villa: keep a whisper of the tint under the selection edge. */
svg.wb-overlay.ops .unit.ops-pinned.selected{
  fill:rgba(124,88,211,.14)!important;
  stroke:#1A4EA0!important;
  stroke-dasharray:none;
}

/* Zoomed out a parcel is a few pixels across and the widths above, being screen pixels
   (non-scaling-stroke), leave the pool as a hairline - which is what made the map read as
   colourless at the landing view. The .far tier restates them heavier; !important because the
   rules being overridden carry it, so the warning further up (colour only, never stroke-width)
   is honoured by pairing every ops width with its .far partner rather than by dropping either. */
svg.wb-overlay.ops.far .unit.ops-reserve{ stroke-width:.9!important; }
svg.wb-overlay.ops.far .unit.ops-held{ stroke-width:.7!important; }
svg.wb-overlay.ops.far .unit.ops-pinned{ stroke-width:1!important; }

/* The cluster blocks are painted after the units and wash them 30% toward black, which is right
   for customers reading the plan but drowns the ops pool at exactly the zoom ops lands on.
   Ops only: keep the block hit target and its hover, drop the tint to a hint. */
svg.wb-overlay.ops .cluster-block{ fill-opacity:.10; }
svg.wb-overlay.ops .cluster-block:hover{ fill-opacity:.20; }
/* A cluster holding free executive stock, at the zoom where no villa is readable yet. */
svg.wb-overlay.ops .cluster-block[data-free="1"]{ fill:#177682; fill-opacity:.22; }
svg.wb-overlay.ops .cluster-block[data-free="1"]:hover{ fill-opacity:.34; }

/* The .showcase block that used to sit here flattened every status to one neutral fill during
   exploration, on the reasoning that nothing was obtainable yet so availability should not be
   shown. Removed 27 Aug 2026 by ADHA's decision: exploration now paints exactly as booking does,
   so a customer sees their villa types in colour and anything already taken simply is not there.
   The rules above and below are the whole behaviour again, in both states. */

/* Zoomed out, below LABEL_ZOOM. A parcel is a few pixels across and a sub-pixel stroke antialiases
   to a smudge rather than drawing a line, so the border gets real width to keep the plot edges
   readable. Deliberately modest: the fill is what says "available" at this distance. */
svg.wb-overlay.far .unit{stroke-width:0.7}
svg.wb-overlay.far .unit.available{stroke-width:0.8}

/* Ineligible for this customer: kept on the map for context, but neither coloured by status
   nor clickable. pointer-events:none means it is not a target at all, rather than a target
   whose click gets rejected.

   No fill and no stroke: the base image already draws every villa in full, so anything the
   overlay adds here is a second, worse drawing of a plot the customer cannot book. Green is
   then the only thing the overlay contributes, which is exactly what it should mean.

   The node still has to exist. unitNodes is index-aligned with units and is read by position in
   applyFilters, applyView and search - skipping the element would shift every later index. */
svg.wb-overlay .unit.ineligible{
  fill:none;
  stroke:none;
  pointer-events:none!important;
  cursor:default;
}

/* Filtered out by the customer's own filter choices. Eligible in principle, but outside what they
   have just asked to see - so it is inert as well as quiet. Distinct from .ineligible, which they
   could never book at all. */
svg.wb-overlay .unit.filtered-out{
  fill:rgba(120,128,140,.08)!important;
  stroke:rgba(140,148,160,.40)!important;
  /* Filtered out means excluded, not merely dimmed. Without this a customer who filtered to
     5 bedrooms could still open, explore and book a 6-bedroom villa, and the "Filters (2)"
     badge promised a constrained set that did not exist. */
  pointer-events:none!important;
  cursor:default!important;
}

/* The customer's own hold. The server has flipped it to Reserved, which is right for everyone
   else and wrong for its holder - to them it is theirs, and still the thing they can change away
   from. An ink outline over a paper fill, so "mine" reads as drawn rather than as absent.
   Never green, so "mine" and "bookable" stay different signals.

   Last of the status rules on purpose. It ties on specificity with .reserved and .filtered-out and
   carries the same !important, so source order is the only thing deciding it. When .filtered-out
   sat below, a customer whose filters excluded their own villa got it painted grey and
   pointer-events:none, and the one plot they must always be able to reach became unclickable. */
svg.wb-overlay .unit.held{
  fill:rgba(247,246,242,.72) !important;
  stroke:#16181D !important;
  stroke-width:1.6 !important;
  pointer-events:all !important;
  cursor:pointer !important;
  filter:drop-shadow(0 0 3px rgba(255,255,255,.9));
}

/* The villa whose card is open. Nothing is painted over it: the customer asked to see this house,
   so the tint comes off and only an ink edge says which one is selected. The plate is hidden by
   the matching rule in the label block.

   After .held and carrying !important because it has to beat every status rule and .far, whatever
   the customer's villa happens to be. pointer-events is untouched, and pointer-events:all means
   an unfilled shape still takes the click, so the parcel stays selectable. */
/* Nothing painted over the villa - the customer asked to look at this house, so the fill comes off
   and only the outline says which one it is. Azure rather than ink, so the mark is the same colour
   the legend already teaches for a plot you can book. AFTER .held, and !important throughout, so a
   customer's own villa is marked the same way as any other while its card is open. */
/* Same weight as .unit.available above, so the selection does not thicken the outline it replaces
   - what marks it is the fill coming off and the number going, not a heavier line. Mitred rather
   than rounded, which is the one part of the sharpening that costs no weight: .unit rounds every
   join so 1,205 outlines read as one soft field, but a selection is a single shape the customer
   is looking straight at, and rounded corners on a rectangle read as blur. */
svg.wb-overlay .unit.selected{
  fill:none !important;
  filter:none !important;
  stroke:#1A4EA0 !important;
  stroke-width:0.35 !important;
  stroke-linejoin:miter !important;
}

/* Hover clears the parcel fill so the underlying plan shows through. The outline stays, so
   the parcel is still readable as a shape while you are pointing at it. */
svg.wb-overlay .unit:not(.ineligible):hover{fill:transparent!important}

svg.wb-overlay .unit.search-hit{
  stroke:#fff!important;
  stroke-width:0.95px!important;
  filter:drop-shadow(0 0 4px rgba(255,255,255,.95));
}

/* Unit number plates, high on the parcel with a tail pointing down into it, sized to it in viewBox
   units so they scale with the map. The group is appended after every polygon and cluster, which
   keeps numbers on top. */
svg.wb-overlay .unit-label-group{pointer-events:none;opacity:0}
svg.wb-overlay .unit-label-group.visible{opacity:1}
svg.wb-overlay .unit-label-group.visible.dim{opacity:.3}
/* The villa whose card is open. The plate sits on the one house the customer asked to see, and the
   card header already names the plot, so it is redundant there.

   Last of the label rules on purpose. It ties on specificity with .dim, so source order is the
   only thing deciding it - the same trap that made the held villa unclickable when .filtered-out
   was declared after .held. A selected plate must hide whether or not a filter also dimmed it. */
svg.wb-overlay .unit-label-group.visible.selected{opacity:0}
/* Thinned on touch, where a legible plate is about as wide as the villa it names and showing
   every number would be a wall of overlap. Same treatment the amenity pins get. */
svg.wb-overlay .unit-label-group.visible.crowded{opacity:0}
svg.wb-overlay .unit-label-bg{
  fill:rgba(38,38,40,.78);
  stroke:rgba(255,255,255,.08);
  stroke-width:.28;
  vector-effect:non-scaling-stroke;
}
/* No stroke: the plate's own outline would otherwise draw a hairline straight across the join. */
svg.wb-overlay .unit-label-tail{fill:rgba(38,38,40,.78);stroke:none}
svg.wb-overlay .unit-label-text{
  font-family:"SuisseIntl","Noto Kufi Arabic",Inter,system-ui,-apple-system,"Segoe UI",sans-serif;
  /* font-size is set per label so the number fits the parcel it names. */
  font-weight:550;
  text-anchor:middle;
  dominant-baseline:middle;
  text-rendering:geometricPrecision;
  fill:#fff;
  pointer-events:none;
}

/* The overview marking is the member parcels tinted, not a white boundary drawn around them.
   The stroke matches the fill and is deliberately wide, so adjacent villas bleed into one
   another and a cluster reads as a single block rather than a field of separate squares. */
/* Amenities. Drawn beneath the units so a parcel is never obscured by the land use behind it,
   and inert - they are context, not something to book. Each class is toggled by its own chip. */
/* No stroke. WB_AMENITIES is triangle soup - every one of its 924 rings is a triangle - so a
   stroke here does not outline a park, it draws the park's triangulation, at a constant screen
   pixel however far you zoom out. That single declaration was the loudest CAD signal on the map.
   Ground has no outline anyway. */
svg.wb-overlay .amenity{
  pointer-events:none;
  stroke:none;
  opacity:0;
  transition:opacity .18s ease, fill .18s ease;
}
/* Every class stays hidden until its own chip is pressed. Parks and landscape used to be drawn
   from the start as context; the map now opens bare so a chip means one thing throughout. */

/* Ground state - muted, so the map reads as materials rather than as eight highlights. Buildings
   are warm stone with only a hint of their class hue; the saturated colour is reserved for the
   selected state below. */
svg.wb-overlay .amenity.park{fill:rgba(98,138,84,.42)}
svg.wb-overlay .amenity.parking{fill:rgba(92,96,104,.28)}
svg.wb-overlay .amenity.school{fill:rgba(216,208,196,.52)}
svg.wb-overlay .amenity.mosque{fill:rgba(222,206,198,.55)}
svg.wb-overlay .amenity.clinic{fill:rgba(224,206,202,.52)}
svg.wb-overlay .amenity.retail{fill:rgba(226,210,190,.52)}
svg.wb-overlay .amenity.community{fill:rgba(220,208,214,.52)}

/* Selected by its chip: the hue comes back, and only then. */
svg.wb-overlay .amenity.on{opacity:1}
svg.wb-overlay .amenity.on.mosque{fill:rgba(226,86,152,.34)}
svg.wb-overlay .amenity.on.school{fill:rgba(64,124,246,.32)}
svg.wb-overlay .amenity.on.clinic{fill:rgba(240,84,72,.34)}
svg.wb-overlay .amenity.on.retail{fill:rgba(244,152,36,.34)}
svg.wb-overlay .amenity.on.park{fill:rgba(38,176,102,.34)}
svg.wb-overlay .amenity.on.community{fill:rgba(158,96,236,.32)}
svg.wb-overlay .amenity.on.parking{fill:rgba(126,138,152,.30)}

/* Every built amenity's footprint, offset by the sun vector, as one path. */
svg.wb-overlay .built-shadow{fill:rgba(16,20,28,.30);stroke:none;pointer-events:none}

/* Amenity pins. Counter-scaled by the camera in scaleAmenityIcons, so these sizes are in the
   pin's own local space rather than viewBox units.

   A pin rests visible rather than hidden: a customer who never presses a chip should still learn
   that the community has a mosque and a school in it. Pressing the chip is what brings the class
   to full strength and puts its name on. */
svg.wb-overlay .amenity-icon-pin{pointer-events:none;opacity:.55;transition:opacity .18s ease}
svg.wb-overlay .amenity-icon-pin.on{opacity:1}
/* AFTER .on, deliberately: same specificity, so source order is the only thing deciding it, and a
   pin that declutterPins dropped has to stay dropped whether or not its chip is pressed. */
svg.wb-overlay .amenity-icon-pin.crowded{opacity:0}
svg.wb-overlay .amenity-icon-glyph{
  text-anchor:middle;
  dominant-baseline:middle;
  /* Emoji only - no font stack applies, and forcing one loses the colour glyph. The shadow
     replaces the plate that used to sit behind it: without something, a pale glyph such as the
     parking P disappears into the white CAD sheet. */
  filter:drop-shadow(0 1px 1.5px rgba(0,0,0,.5));
}
/* The name, on the selected class only. Unselected pins stay a bare glyph: a name on all 81 at
   once was more type than the plan could carry, which is why this was dropped once before. It
   works now because pressing a chip narrows it to one class, landscaping is gone, and
   declutterPins gives a named pin a much wider box so the survivors do not collide.

   Same dark plate as the cluster pill, for the same reason: the ground underneath runs from pale
   unbuilt sand to dark asphalt and a plate is the only thing that reads over both. */
svg.wb-overlay .amenity-pin-name{opacity:0;transition:opacity .18s ease}
svg.wb-overlay .amenity-icon-pin.on .amenity-pin-name{opacity:1}
svg.wb-overlay .amenity-pin-bg{
  fill:rgba(16,18,24,.9);
  stroke:rgba(255,255,255,.3);
  stroke-width:1;
}
svg.wb-overlay .amenity-pin-text{
  font-family:"SuisseIntl","Noto Kufi Arabic",Inter,system-ui,-apple-system,"Segoe UI",sans-serif;
  font-size:15px;
  font-weight:500;
  text-anchor:middle;
  dominant-baseline:middle;
  fill:#fff;
}

/*
 * The overview layer is one block per cluster - not per-parcel tinting. Marking individual
 * eligible villas at overview cannot work: the whole 7798px plan sits in about a 1400px frame,
 * so a villa is roughly 8 screen pixels. The block is the unit of decision at this zoom; the
 * villas inside it appear once the customer clicks in.
 *
 * One <path> per cluster holding every member parcel as a subpath, stroked wide so neighbouring
 * villas merge into a single shape. Colour is the dominant category among the bookable villas,
 * and the crisp white outline is what makes it read as a selection rather than a stain.
 */
/* White, because the plan underneath already spends every other colour: red project boundary,
   green fence and parks, blue cluster distribution limits, magenta area limits, yellow zone tags,
   orange retail and Phase 2 blocks, purple ponds. White is the one value that cannot be mistaken
   for something printed - and green is now reserved for a single meaning, an eligible unit. */
/* The plan's own cluster boundary, filled, so the customer can see where the 21 clusters are.
   Black rather than a hue because green now means exactly one thing - a villa this customer can
   book - and the plan has already spent every other colour on something printed. Nothing outside
   a cluster is dimmed; the plan keeps its own colours throughout.

   fill-opacity and stroke-opacity separately, NOT one opacity on the element. The border has to be
   sharp, and element opacity would fade the white line to 0.3 along with the wash it sits on. The
   two-alpha edge-darkening this was avoiding does not arise here: the stroke is white and opaque,
   so it paints over the fill rather than compounding with it.

   non-scaling-stroke keeps the border a constant width on screen instead of growing with the map.
   In this tier the layout boost tracks the zoom, so renderScale is ~1 and 1.5 lands at about 1.5
   CSS px - one crisp line at every zoom the blocks are visible at, on desktop and on a phone.

   pointer-events is set per tier in applyView, not here: the block is a click target only in the
   plan tier, and on touch the wash is visible over live units where it must not intercept a tap. */
svg.wb-overlay .cluster-block{
  fill:#080b12;
  fill-opacity:.3;
  stroke:#fff;
  stroke-opacity:.9;
  stroke-width:1.5;
  vector-effect:non-scaling-stroke;
  cursor:pointer;
  transition:fill-opacity .14s ease;
}
svg.wb-overlay .cluster-block:hover{fill-opacity:.46}

/* "Cluster N" on the block, on the same dark plate as the plot-range caption. The block under it
   is a 0.3 wash over everything from pale unbuilt ground to dark asphalt, and a plate is the only
   treatment that reads the same over both. Lighter and smaller than that caption on purpose: 19 of
   these are on screen together where the ranges appear a few at a time, so 650 read as a row of
   headlines. Plate width is set per element in paintClusterNumber - it has to fit the text, and
   the Arabic is a different length. */
svg.wb-overlay .cluster-num{pointer-events:none}
svg.wb-overlay .cluster-num-bg{
  fill:rgba(16,18,24,.9);
  stroke:rgba(255,255,255,.3);
  stroke-width:1;
}
svg.wb-overlay .cluster-num-text{
  font-family:"SuisseIntl","Noto Kufi Arabic",Inter,system-ui,-apple-system,"Segoe UI",sans-serif;
  font-size:19px;
  font-weight:500;
  text-anchor:middle;
  dominant-baseline:middle;
  fill:#fff;
}

/* Cluster caption, in the style of the reference's block labels. Counter-scaled by the camera
   alongside the amenity pins, so it stays a constant size on screen. */
svg.wb-overlay .cluster-tag{pointer-events:none}
svg.wb-overlay .cluster-tag-bg{
  fill:rgba(16,18,24,.9);
  stroke:rgba(255,255,255,.3);
  stroke-width:1;
}
svg.wb-overlay .cluster-tag-text{
  font-family:"SuisseIntl","Noto Kufi Arabic",Inter,system-ui,-apple-system,"Segoe UI",sans-serif;
  font-weight:650;
  text-anchor:middle;
  dominant-baseline:middle;
  fill:#fff;
}
svg.wb-overlay .cluster-tag-sub{font-weight:500;fill:rgba(255,255,255,.72)}
`;

/**
 * Filter facets for journey stage 4 ("Available search and filter options will be provided to
 * support unit selection"). The journey document mandates filters without naming them, so the
 * criteria are the unit attributes that actually vary once eligibility has been applied.
 *
 * Bedrooms, balconies, BUA and plot area are a pure function of Category_Type__c (A: 5 bed /
 * 3 balconies, B: 5 / 1, C: 6 / 1), so they filter nothing for a single-category customer - but
 * a customer eligible in A, B and C spans both tiers, and there they are real choices. They are
 * listed here and the runtime drop below removes them when they resolve to one value.
 *
 * Bathrooms is left out because it tracks bedrooms exactly (5 bed = 9 bath, 6 bed = 10), so it
 * would only ever duplicate the bedroom chips. GIS_Remarks__c and Expose_To__c are internal
 * stock designations and must not reach a customer.
 */
/**
 * Amenity classes, in the order the chips appear. The geometry is real: every polygon came out
 * of the plan's own land-use layers (_pl_lu_mosque, _pl_lu_school, _PL_PPOCKET-PARKING and so
 * on), so what a chip shows is what the plan draws - with one deliberate exception. The school at
 * the west end of Cluster 8 was removed from the resource on 25 Aug 2026 at the client's request,
 * so the plan draws three schools and the map shows two. The removed row is kept at
 * backup/masterplan-sources/amenity-173-cluster8-school.json.
 *
 * Ordered by how much a buyer is likely to care rather than by area, which is why parking sits
 * at the end.
 *
 * Landscaping was dropped on 22 Aug 2026. It was 95 of the 176 rows the resource held then, all
 * of it ground cover
 * rather than anywhere you would go, and it crowded out the landmarks in declutterPins. An entry
 * removed here is removed everywhere: renderAmenities skips any class it cannot find below, so
 * those 95 polygons are no longer built into the DOM at all.
 *
 * labelKey names the filter and is plural. pinKey names one building and is singular - a pin over
 * a single mosque captioned "Mosques" reads as a mistake.
 */
export const AMENITIES = [
    { key: 'park', labelKey: 'amenityPark', pinKey: 'pinPark', icon: '🌳' },
    { key: 'school', labelKey: 'amenitySchool', pinKey: 'pinSchool', icon: '🎓' },
    { key: 'mosque', labelKey: 'amenityMosque', pinKey: 'pinMosque', icon: '🕌' },
    { key: 'retail', labelKey: 'amenityRetail', pinKey: 'pinRetail', icon: '🛍️' },
    { key: 'clinic', labelKey: 'amenityClinic', pinKey: 'pinClinic', icon: '🩺' },
    { key: 'community', labelKey: 'amenityCommunity', pinKey: 'pinCommunity', icon: '👥' },
    { key: 'parking', labelKey: 'amenityParking', pinKey: 'pinParking', icon: '🅿️' }
];

/**
 * Which pin survives when two of them want the same patch of screen.
 *
 * All 80 pins are drawn at every zoom, so at full extent they compete. declutterPins walks this
 * order and keeps whatever still has room, so the plan opens with its landmarks and fills in as
 * the customer zooms. Parking is 26 of the 80 and is the class most likely to be thinned.
 *
 * Separate from AMENITIES above because that is chip order, a layout decision, and this is about
 * what matters on the map. A selected class jumps the queue ahead of all of it, and since 22 Aug
 * a selected pin also carries its name, so it claims a much wider box - see PIN_BOX_NAMED.
 */
export const PIN_RANK = ['mosque', 'school', 'clinic', 'community', 'retail', 'park', 'parking'];

/*
 * `of` returns the SELECTION KEY and must stay language-independent - it is what a chosen filter
 * is stored as, so if it changed with the language every active filter would silently stop
 * matching the moment the customer switched. `display` is the only part that translates.
 *
 * This is also why bedrooms and balconies are bare numbers here rather than "5 bedrooms": the old
 * form hard-coded English plural morphology (balcony/balconies), and Arabic has six plural forms,
 * so no interpolated-count phrasing could be translated correctly. Both now render as
 * label-plus-value, which needs no morphology in either language.
 */
/*
 * One facet, because one row is one product is one colour.
 *
 * Style and bedrooms used to be two independent facets, ANDed together. They are now the single
 * PRODUCTS list, so that a row can carry the exact colour its villas are painted and the panel can
 * be the map key rather than sitting beside one. Ticking two rows is an OR of two whole products,
 * which is how MODON's own viewer reads.
 *
 * Everything else was a form and stays deleted: LOCATION is what the map is for - a masterplan
 * exists so somebody can point at where they want to live, and Wb3_01 is a planning code either
 * way. PLOT POSITION spoke in the planners' own vocabulary ("Double row middle", "Internal single
 * row community") and carried values no buyer acts on, including "Utilities" at six plots.
 * BALCONIES is a spec line on the card, not a way to shortlist - and it is the ONLY thing that
 * separates a category A villa from a category B one, both being 5 bedroom, 450 GSA, 1,000 plot at
 * AED 1,800,000, which is why category is not a row either.
 *
 * The four products split 659 / 165 / 668 / 167. buildFacets drops any facet with one value, so a
 * House Grant applicant - category A only, therefore 5 bedroom only - correctly gets two rows
 * rather than four, and on that axis their map is 99.1% coherent.
 *
 * No availability facet. It is a rule, not a choice: canBook() in the selector enforces it, so an
 * unavailable villa is never offered and never counted. As a facet it had to be pre-selected for
 * the numbers to mean anything, and its only other setting showed a screen of villas the customer
 * cannot have.
 */
export const FACETS = [
    {
        key: 'product',
        labelKey: 'facetProduct',
        of: (u) => {
            const product = productOf(u);
            return product ? product.key : null;
        },
        // Composed from two already-translated pieces rather than a new sentence, because Arabic has
        // six plural forms and no interpolated-count phrasing survives translation.
        display: (v, lang, t, pick) => {
            const product = PRODUCTS.find((p) => p.key === v);
            return product
                ? t(lang, 'productRow', pick(lang, product.style), t(lang, 'countBedrooms', product.bedrooms))
                : v;
        },
        // The exact hue the map paints these villas, straight off PRODUCTS. Inline rather than a
        // class so there is no second copy of the value to fall out of step.
        swatch: (v) => {
            const product = PRODUCTS.find((p) => p.key === v);
            return product ? product.swatch : '';
        }
    }
];