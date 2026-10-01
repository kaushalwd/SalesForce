/**
 * The console's one loader.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  12 Aug 2026  Initial. Screens read as frozen while Apex was in
 *                                   flight: eighteen components tracked a wait and almost
 *                                   none of them showed it, mscBookingPage.busyPage - set
 *                                   for the whole of bootstrap() - among them.
 * 1.1      Aurelix IT  12 Aug 2026  The Modon O, which is the browser-tab icon
 *                                   (staticresources/modonFavicon.png). 1.0 used
 *                                   Microsite_Logo/favicon.svg - the microsite's mark, not
 *                                   this console's.
 */

import { LightningElement, api } from "lwc";

/**
 * A blocking overlay carrying the Modon O - the same mark as the browser-tab icon,
 * taken as vector from the wordmark in c/mscLogo rather than as the raster favicon,
 * so it scales cleanly and follows the theme colour.
 *
 * Blocking is the point as much as the mark is: it covers the viewport, so a rep cannot
 * press Confirm or Take payment a second time while the first request is still running.
 *
 * Render it conditionally on whatever flag the host already keeps - this component owns
 * no state and starts no timers, so mounting and unmounting it is the whole API.
 */
export default class MscLoader extends LightningElement {
  /**
   * Optional. A long wait should say what it is doing; a short one is better with
   * nothing, since a label that flashes for 200ms is noise.
   */
  @api label;

  /**
   * 1.1 - fills its nearest positioned ancestor instead of the viewport.
   *
   * The default is a blocking, blurred, whole-screen overlay, which is right for
   * a call the agent must wait out. It is wrong for one box that is still filling
   * in - the offer drawer's document frame, which flashed white while the PDF
   * loaded. Contained, it is opaque and covers only that box, so the rest of the
   * drawer stays readable and usable.
   *
   * The host must be position: relative, or this fills whatever above it is.
   */
  @api contained = false;

  get loaderClass() {
    return this.contained ? "loader loader--contained" : "loader";
  }
}