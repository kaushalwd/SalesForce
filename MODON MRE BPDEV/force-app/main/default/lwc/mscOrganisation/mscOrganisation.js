/**
 * Organisation - the trade licence, and what is still outstanding.
 *
 * Version  Author      Date         Detail
 * 1.9      Aurelix IT  22 Aug 2026  MSC-113. THE SHAREHOLDER FORM IS GONE (GAP 10).
 *                                   MODON retired the Passfort shareholder feature on
 *                                   14 Aug 2026 ("Shareholder Details feature no longer
 *                                   required") - the form was spending a rep's time
 *                                   writing Contact rows the compliance submission no
 *                                   longer wants. UI only: the Apex methods stay whole.
 *                                   nationalityOptions leaves with its only consumer.
 * 1.0      Aurelix IT  10 Aug 2026  Initial.
 * 1.1      Aurelix IT  10 Aug 2026  Copy moved to c/mscLabels and put in plain words -
 *                                   "owners" rather than "shareholders", and the vendor
 *                                   is never named to a rep.
 * 1.2      Aurelix IT  12 Aug 2026  Backend waits raise c-msc-loader.
 * 1.3      Aurelix IT  12 Aug 2026  Tidied: a heading and a rule so the company block is
 *                                   its own subject, a themed upload control in place of the
 *                                   native picker, a surface under the outstanding list, and a
 *                                   sub-block empty state instead of the 40px page one.
 * 1.4      Aurelix IT  12 Aug 2026  No "Not uploaded" chip - the Choose a file button
 *                                   already says as much.
 * 1.5      Aurelix IT  12 Aug 2026  Phone rules. Built after the device pass, so it had
 *                                   none - owner rows could not fit at 360px.
 * 1.6      Aurelix IT  12 Aug 2026  Keyboard hints on the owner form.
 * 1.7      Aurelix IT  12 Aug 2026  autocomplete="off" - same reason as mscConsole 2.7.
 * 1.8      Aurelix IT  20 Aug 2026  MSC-087. No stepper on Share owned. Same control and
 *                                   same reason as the joint owner drawer's Ownership %:
 *                                   a share is typed, not nudged.
 */

import { LightningElement, api, track } from "lwc";
import getOrgState from "@salesforce/apex/SalesConsoleOrgController.getOrgState";
import uploadTradeLicence from "@salesforce/apex/SalesConsoleOrgController.uploadTradeLicence";
import { reduceError } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";

export default class MscOrganisation extends LightningElement {
  labels = LABELS;

  @api opportunityId;

  @track state = {};
  busy = false;
  uploading = false;
  errorMsg;

  connectedCallback() {
    this.load();
  }

  async load() {
    if (!this.opportunityId) return;
    this.busy = true;
    try {
      this.state = (await getOrgState({ opportunityId: this.opportunityId })) || {};
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  @api
  refresh() {
    return this.load();
  }

  get isOrganisation() {
    return this.state.isOrganisation === true;
  }

  // ---- trade licence ------------------------------------------------------

  get licenceLabel() {
    return this.state.requiredDocName || LABELS.ORG_LICENCE_DOC;
  }

  get licenceDone() {
    return this.state.tradeLicenceUploaded === true;
  }

  /* Attached but not yet read: the file is safe, the extraction is still running or
     failed. Worth distinguishing - one is waiting, the other needs typing. */
  get licenceAttachedOnly() {
    return this.state.requiredDocPresent === true && !this.licenceDone;
  }

  get licenceStatusText() {
    if (this.licenceDone) return LABELS.ORG_LICENCE_VERIFIED;
    if (this.uploading) return LABELS.ORG_LICENCE_UPLOADING;
    if (this.licenceAttachedOnly) return LABELS.ORG_LICENCE_READING;
    return LABELS.ORG_LICENCE_NONE;
  }

  get licenceChipClass() {
    if (this.licenceDone) return "chip chip--paid";
    if (this.licenceAttachedOnly) return "chip chip--partial";
    return "chip chip--pending";
  }

  /* 1.4 - nothing uploaded says nothing. A "Not uploaded" chip beside a heading whose
     only control is "Choose a file" states what the button already implies. The chip
     appears once there is progress to report. */
  get showLicenceChip() {
    return this.uploading || this.licenceAttachedOnly || this.licenceDone;
  }

  /* 1.3 - the native picker used to display this itself. The input is hidden now, so
     the name is kept and shown beside the styled button. */
  pickedFileName;

  handleFile(event) {
    const file = event.target.files && event.target.files[0];
    if (!file) return;
    this.pickedFileName = file.name;
    const reader = new FileReader();
    reader.onload = () => {
      this.sendFile(file.name, String(reader.result).split(",")[1]);
    };
    reader.onerror = () => {
      this.errorMsg = LABELS.ORG_LICENCE_UNREADABLE;
    };
    reader.readAsDataURL(file);
  }

  async sendFile(fileName, base64) {
    this.uploading = true;
    this.errorMsg = undefined;
    try {
      this.state = await uploadTradeLicence({
        opportunityId: this.opportunityId,
        base64,
        fileName
      });
      /* The read is queued, so the verified flag lands after this returns. */
      this.dispatchEvent(new CustomEvent("licenceuploaded"));
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.uploading = false;
    }
  }

  // ---- what is still missing ---------------------------------------------

  get outstanding() {
    return this.state.outstanding || [];
  }

  get hasOutstanding() {
    return this.outstanding.length > 0;
  }

  /** Licence uploads and the initial load both block. (1.9 - the dead
      `this.loading` read is gone with the shareholder edits that excused it.) */
  get isBusy() {
    return !!(this.busy || this.uploading);
  }
}