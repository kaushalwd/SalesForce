/**
 * The ownership module, wired to one booking, for a host that is not the journey (My Bookings).
 *
 * Version  Author      Date         Detail
 * 2.5      Aurelix Dev 22 Sep 2026  handlePersonFound: the drawer created a person without adding
 *                                   them (they do KYC first), so show them as found.
 * 2.4      Aurelix Dev 30 Aug 2026  MSC-181. handleAssignSignatory / handleCreateSignatory for the POA pane.
 * 2.3      Aurelix Dev 30 Aug 2026  MSC-180. Corporate bookings open; buyerIsCompany read off the DTO.
 * 2.2      Aurelix Dev 26 Aug 2026  MSC-174. The next-step bar gets its button; the company workspace opens here.
 * 2.1      Aurelix Dev 25 Aug 2026  MSC-173. The Verification tab reports a company (read-only tracks).
 * 2.0      Aurelix IT  20 Aug 2026  MSC-088. Two tabs, owners and verify, over one state.
 * 1.0      Aurelix IT  20 Aug 2026  Initial. MSC-084.
 *
 * c/mscBookingPage's handlers are welded to the journey, so this is a second host for the same
 * dumb children. No rule is duplicated: every gate runs on the server. The panel covers the
 * booking, not the row (salesOrderId is a focus). Drawers are mounted at this component's root:
 * no ancestor here carries backdrop-filter, transform or filter.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";
import { reduceError } from "c/modonSalesFormat";

/* the server side, unchanged */
import getOwners from "@salesforce/apex/SalesConsoleJointOwnerService.getOwners";
import findPerson from "@salesforce/apex/SalesConsoleJointOwnerService.findPerson";
import addOwner from "@salesforce/apex/SalesConsoleJointOwnerService.addOwner";
import updateOwner from "@salesforce/apex/SalesConsoleJointOwnerService.updateOwner";
import sendOwnerVerification from "@salesforce/apex/SalesConsoleJointOwnerService.sendVerification";
import sendKycLink from "@salesforce/apex/SalesConsoleController.sendKycLink";
import getComplianceState from "@salesforce/apex/SalesConsoleController.getComplianceState";
import getOrgDetails from "@salesforce/apex/SalesConsoleOrgController.getOrgDetails";
import saveOrgDetails from "@salesforce/apex/SalesConsoleOrgController.saveOrgDetails";
import assignOrgSignatory from "@salesforce/apex/SalesConsoleOrgController.assignSignatory";
import createOrgSignatoryContact from "@salesforce/apex/SalesConsoleOrgController.createSignatoryContact";
import uploadCompanyLicence from "@salesforce/apex/SalesConsoleOrgController.uploadCompanyLicence";
import submitOrganisationCompliance from "@salesforce/apex/SalesConsoleOrgController.submitOrganisationCompliance";
import getChecklist from "@salesforce/apex/SalesConsoleComplianceService.getChecklist";
import saveChecklistDetails from "@salesforce/apex/SalesConsoleComplianceService.saveDetails";
import submitToCompliance from "@salesforce/apex/SalesConsoleComplianceService.submit";
import ensurePartyDocSlots from "@salesforce/apex/SalesConsoleComplianceService.ensureDocSlots";

/* the journey's cadence, deliberately the same numbers (see startVerificationPoll) */
const POLL_MS = 20000;
const POLL_FIRST_MS = 5000;
const POLL_CEILING_MS = 20 * 60 * 1000;

export default class MscOwnersPane extends LightningElement {
  labels = LABELS;

  // in
  /** The booking, as SalesConsoleBookingListController described it. */
  @api summary;
  /** Whether the host offers Resume on this booking; decided by the header, not here. */
  @api canResume = false;

  /** Which tab this pane is drawing: "owners" or "verify". Two screens over one state. */
  @api view = "owners";

  _active = false;
  _needsLoad = false;

  /** The Owners tab is showing. Flagged here, loaded in renderedCallback (@api assignment order). */
  @api
  get active() {
    return this._active;
  }
  set active(value) {
    const next = !!value;
    /* once, not on every visit; `!this.owners` so a failed read is retried */
    if (next && !this._active && !this.owners) {
      this._needsLoad = true;
    }
    this._active = next;
  }

  // state
  owners;
  busyOwners = false;
  busyOwnersSave = false;
  /* a re-read the rep asked for, and when it landed; separate from busyOwners */
  refreshingOwners = false;
  checkedAt;
  /** The drawer's own refusal. */
  ownersError;
  /** The pane's own error, kept apart from ownersError. */
  paneError;
  loadFailed = false;

  drawerOpen = false;
  drawerMode = "add";
  editAccountId;
  preselected;
  person;
  searchStatus = "idle";

  /* one attempt per booking; see maybeLoadCompliance */
  _complianceTried = false;

  /* MSC-174: the company's details workspace, same names the journey uses */
  orgDetailsOpen = false;
  orgDetails;
  orgDetailsError;
  busyOrgDetails = false;
  busyOrgSave = false;
  busyOrgSubmit = false;
  busyOrgUpload = false;
  busyOrgSendLink = false;

  gateOpen = false;
  gateAnswered = false;
  /** The leaving question is armed by an add, not by arriving. */
  addedThisVisit = false;

  checkOpen = false;
  partyAccountId;
  check;
  busyCheck = false;
  busyCheckSave = false;
  busyCheckSubmit = false;
  checkError;

  sendingAccountId;

  /* MSC-173: the company's own verification picture; null on every individual booking */
  compliance;

  _poll;
  _pollStartedAt = 0;
  _visibility;

  renderedCallback() {
    if (this._needsLoad) {
      this._needsLoad = false;
      this.loadOwners();
    }
    this.maybeLoadCompliance();
  }

  disconnectedCallback() {
    /* leaving the detail must not leave a timer behind */
    this.stopPoll();
  }

  // the booking
  get s() {
    return this.summary || {};
  }
  get opportunityId() {
    return this.s.opportunityId || null;
  }
  /** The unit the detail is about. A focus for the server, never a filter. */
  get salesOrderId() {
    return this.s.id || null;
  }

  // reading
  /** Who owns this booking. Read once on first open and after every write. */
  async loadOwners(quiet) {
    if (!this.opportunityId) {
      this.loadFailed = true;
      return;
    }
    if (!quiet) {
      this.busyOwners = true;
      this.loadFailed = false;
    }
    try {
      this.owners = await getOwners({
        opportunityId: this.opportunityId,
        salesOrderId: this.salesOrderId
      });
      /* stamped from the answer landing */
      this.checkedAt = new Date().toISOString();
      this.reportCount();
    } catch (e) {
      /* a quiet reload keeps whatever we already had */
      if (!quiet) {
        this.owners = undefined;
        this.loadFailed = true;
      }
    } finally {
      this.busyOwners = false;
    }
  }

  /** The tab's badge, refreshed after a write (the same partyStats figure). */
  reportCount() {
    const dto = this.owners || {};
    const parties = dto.parties || [];
    /* three figures, for two tabs */
    this.dispatchEvent(
      new CustomEvent("ownerscount", {
        detail: {
          count: parties.length,
          verified: dto.verifiedCount || 0,
          verifiable: dto.verifiableCount || 0
        }
      })
    );
  }

  /** Which of the two screens this pane is drawing. */
  get isOwnersView() {
    return this.view !== "verify";
  }

  /* MSC-173: a company's verification on this screen. Read once, on the verify tab only, and
   * never for an individual booking. */
  async maybeLoadCompliance() {
    if (
      this.isOwnersView ||
      !this._active ||
      this.compliance ||
      this._complianceTried ||
      !this.opportunityId ||
      !this.owners ||
      /* MSC-180: buyerIsCompany is the signal now, not `available !== true` */
      (this.owners.available === true && this.owners.buyerIsCompany !== true)
    ) {
      return;
    }
    this._complianceTried = true;
    try {
      this.compliance = await getComplianceState({
        opportunityId: this.opportunityId
      });
    } catch (e) {
      /* silent, like the poll */
      this.compliance = undefined;
    }
  }

  /** What c/mscVerifyList draws its org rows from. Passed only for a company. */
  get verifyBuyerDetail() {
    const d = this.compliance;
    return d && d.isPersonAccount === false ? d : undefined;
  }

  /** The next-step bar. The headline is the server's; the button is dropped for acts this host cannot carry out. */
  get verifyNextStep() {
    const step = this.verifyBuyerDetail && this.verifyBuyerDetail.nextStep;
    if (!step) {
      return undefined;
    }
    /* MSC-174: the button is kept for opendetails, sendlink and submit, dropped for 'check' */
    const canAct =
      step.action === "opendetails" ||
      step.action === "sendlink" ||
      step.action === "submit";
    return {
      key: step.key,
      label: step.label,
      headline: step.headline,
      tone: step.tone,
      buttonLabel: canAct ? step.buttonLabel : null,
      action: canAct ? step.action : null
    };
  }

  /** Every write the bar can start. */
  get verifyNextBusy() {
    return !!(
      this.busyOrgSubmit ||
      this.busyOrgSendLink ||
      this.busyOrgDetails ||
      this.refreshingOwners
    );
  }

  /* MSC-174: the company's details workspace on this screen; same Apex as the journey, and every
   * act re-reads this pane's two pictures. Unreachable on an individual booking. */
  handleVerifyNextAction(event) {
    const action = (event.detail || {}).action;
    if (action === "opendetails") {
      return this.handleOpenOrgDetails();
    }
    if (action === "sendlink") {
      return this.handleSendLinkFromWorkspace();
    }
    if (action === "submit") {
      return this.handleSubmitOrgCompliance();
    }
    return undefined;
  }

  handleOpenOrgDetails() {
    /* one overlay at a time */
    this.checkOpen = false;
    this.orgDetailsOpen = true;
    this.orgDetailsError = undefined;
    return this.loadOrgDetails();
  }

  async loadOrgDetails() {
    if (!this.opportunityId) {
      return;
    }
    this.busyOrgDetails = true;
    this.orgDetailsError = undefined;
    try {
      this.orgDetails = await getOrgDetails({ opportunityId: this.opportunityId });
    } catch (e) {
      this.orgDetailsError = reduceError(e);
      this.orgDetails = undefined;
    } finally {
      this.busyOrgDetails = false;
    }
  }

  /** The reply is the recomputed picture. */
  async handleSaveOrgDetails(event) {
    const fields = (event.detail && event.detail.fields) || {};
    if (!Object.keys(fields).length) {
      return;
    }
    this.busyOrgSave = true;
    this.orgDetailsError = undefined;
    try {
      this.orgDetails = await saveOrgDetails({
        opportunityId: this.opportunityId,
        fieldsJson: JSON.stringify(fields)
      });
      await this.refreshVerification();
    } catch (e) {
      this.orgDetailsError = reduceError(e);
    } finally {
      this.busyOrgSave = false;
    }
  }

  /** Assigns the company's Power of Attorney. Both pictures are re-read. */
  async handleAssignSignatory(event) {
    this.busyOrgSave = true;
    this.orgDetailsError = undefined;
    try {
      this.orgDetails = await assignOrgSignatory({
        opportunityId: this.opportunityId,
        contactId: (event.detail && event.detail.contactId) || null
      });
      await this.refreshVerification();
    } catch (e) {
      this.orgDetailsError = reduceError(e);
    } finally {
      this.busyOrgSave = false;
    }
  }

  /** MSC-181: the lookup's New Contact, created and assigned in one transaction. Both pictures re-read. */
  async handleCreateSignatory(event) {
    const d = event.detail || {};
    this.busyOrgSave = true;
    this.orgDetailsError = undefined;
    try {
      this.orgDetails = await createOrgSignatoryContact({
        opportunityId: this.opportunityId,
        fullName: d.name,
        nationality: d.nationality,
        residency: d.residency,
        email: d.email,
        mobile: d.mobile
      });
      await this.refreshVerification();
    } catch (e) {
      this.orgDetailsError = reduceError(e);
    } finally {
      this.busyOrgSave = false;
    }
  }


  /** The licence upload; the workspace is read again after the queued extraction. */
  async handleUploadLicence(event) {
    const detail = event.detail || {};
    if (!detail.base64 || !detail.fileName) {
      return;
    }
    this.busyOrgUpload = true;
    this.orgDetailsError = undefined;
    try {
      this.orgDetails = await uploadCompanyLicence({
        opportunityId: this.opportunityId,
        base64: detail.base64,
        fileName: detail.fileName
      });
    } catch (e) {
      this.orgDetailsError = reduceError(e);
    } finally {
      this.busyOrgUpload = false;
    }
  }

  /** A file the browser could not read never reaches the server. */
  handleLicenceUnreadable(event) {
    this.orgDetailsError =
      (event.detail && event.detail.message) || LABELS.ORG_LICENCE_UNREADABLE;
  }

  /** The verification link, the same Apex call the journey makes; a refusal lands on the panel or the pane. */
  async handleSendLinkFromWorkspace() {
    this.busyOrgSendLink = true;
    this.orgDetailsError = undefined;
    try {
      const problem = await sendKycLink({ opportunityId: this.opportunityId });
      if (problem) {
        this.reportOrgProblem(problem);
      }
      if (this.orgDetailsOpen) {
        await this.loadOrgDetails();
      }
      await this.refreshVerification();
    } catch (e) {
      this.reportOrgProblem(reduceError(e));
    } finally {
      this.busyOrgSendLink = false;
    }
  }

  /** Sends the company to compliance; the picture is re-read either way. */
  async handleSubmitOrgCompliance() {
    this.busyOrgSubmit = true;
    this.orgDetailsError = undefined;
    try {
      const problem = await submitOrganisationCompliance({
        opportunityId: this.opportunityId,
        salesOrderId: this.salesOrderId
      });
      if (problem) {
        this.reportOrgProblem(problem);
        if (this.orgDetailsOpen) {
          await this.loadOrgDetails();
          this.orgDetailsError = problem;
        }
        return;
      }
      this.orgDetailsOpen = false;
      this.orgDetails = undefined;
      await this.refreshVerification();
    } catch (e) {
      const message = reduceError(e);
      if (this.orgDetailsOpen) {
        await this.loadOrgDetails();
        this.orgDetailsError = message;
      } else {
        this.reportOrgProblem(message);
      }
    } finally {
      this.busyOrgSubmit = false;
    }
  }

  /** The panel asks to open the signatory's compliance check; this host has no org path, so it says where the act lives. */
  handleCheckSignatory() {
    this.orgDetailsError = LABELS.OP_CHECK_ON_JOURNEY;
  }

  reportOrgProblem(message) {
    if (this.orgDetailsOpen) {
      this.orgDetailsError = message;
    } else {
      this.paneError = message;
    }
  }

  handleOrgDetailsClose() {
    // mid-write the answer is still coming
    if (
      this.busyOrgSave ||
      this.busyOrgSubmit ||
      this.busyOrgUpload ||
      this.busyOrgSendLink
    ) {
      return;
    }
    this.orgDetailsOpen = false;
    this.orgDetails = undefined;
    this.orgDetailsError = undefined;
  }

  /** The company, off the compliance answer. */
  get orgDetailsCompanyName() {
    const co = (this.verifyBuyerDetail || {}).company;
    return (co && co.name) || null;
  }

  /** The Sales Order this detail is about. */
  get orgDetailsBookingRef() {
    return this.s.bookingRef || null;
  }

  /** Both pictures, after a write that moved either. */
  async refreshVerification() {
    await this.loadOwners(true);
    this._complianceTried = false;
    const held = this.compliance;
    this.compliance = undefined;
    await this.maybeLoadCompliance();
    if (!this.compliance) {
      this.compliance = held;
    }
  }

  /** The rep asked for the latest status; quiet, so the list stays on screen. */
  async handleRefreshOwners() {
    if (this.refreshingOwners || this.busyOwners) {
      return;
    }
    this.refreshingOwners = true;
    try {
      /* MSC-173: owners and the company's picture, through the one place that knows how */
      await this.refreshVerification();
    } finally {
      this.refreshingOwners = false;
    }
  }

  // what the panel is given
  get showLoader() {
    return this.busyOwners && !this.owners;
  }
  get showFailure() {
    return this.loadFailed && !this.owners;
  }
  get ownersBusy() {
    return this.busyOwners || this.busyOwnersSave;
  }

  /**
   * The rep opened a unit the booking can no longer show while others are live: a comparison of
   * two server answers (focusedSalesOrderId vs the request), not a rule.
   */
  get showOtherUnitNote() {
    const dto = this.owners;
    if (!dto || dto.available !== true || !this.salesOrderId) {
      return false;
    }
    return dto.focusedSalesOrderId !== this.salesOrderId;
  }

  get uncovered() {
    return (this.owners && this.owners.unitsWithNoJointOwner) || [];
  }
  get primaryName() {
    const parties = (this.owners && this.owners.parties) || [];
    const primary = parties.find((p) => p.isPrimary);
    return primary ? primary.name : "";
  }

  // adding and editing
  openDrawer(mode, opts) {
    this.drawerMode = mode;
    this.editAccountId = (opts && opts.accountId) || undefined;
    this.preselected = (opts && opts.orderIds) || undefined;
    this.person = undefined;
    this.searchStatus = "idle";
    this.ownersError = undefined;
    this.paneError = undefined;
    this.drawerOpen = true;
  }

  handleAddOwner() {
    this.openDrawer("add");
  }

  handleEditOwner(event) {
    this.openDrawer("edit", { accountId: event.detail.accountId });
  }

  /** The coverage line's one-press correction. */
  handleAddToUncovered() {
    const empty = ((this.owners && this.owners.units) || [])
      .filter((u) => u.open && !u.ownerCount)
      .map((u) => u.salesOrderId);
    this.openDrawer("add", { orderIds: empty });
  }

  dismissPaneError() {
    this.paneError = undefined;
  }

  handleCloseDrawer() {
    // mid-save the answer is still coming
    if (this.busyOwnersSave) {
      return;
    }
    this.drawerOpen = false;
    this.person = undefined;
    this.searchStatus = "idle";
    this.ownersError = undefined;
  }

  handleResetSearch() {
    this.person = undefined;
    this.searchStatus = "idle";
    this.ownersError = undefined;
  }

  /** Identity first; the console has one identity matcher. */
  async handleFindPerson(event) {
    const idNumber = ((event.detail && event.detail.idNumber) || "").trim();
    if (!idNumber) {
      return;
    }
    this.searchStatus = "searching";
    this.ownersError = undefined;
    try {
      const found = await findPerson({
        opportunityId: this.opportunityId,
        idNumber
      });
      if (found && found.length) {
        this.person = found[0];
        this.searchStatus = "found";
      } else {
        this.person = undefined;
        this.searchStatus = "notfound";
      }
    } catch (e) {
      this.ownersError = reduceError(e);
      this.searchStatus = "idle";
    }
  }

  /* 2.5: the drawer created a person without adding them; show them as found */
  handlePersonFound(event) {
    this.person = (event.detail || {}).person;
    this.searchStatus = this.person ? "found" : "idle";
    this.ownersError = undefined;
  }

  /** The one write; a refusal is reported on the drawer. */
  async handleSaveOwner(event) {
    const d = event.detail || {};
    this.busyOwnersSave = true;
    this.ownersError = undefined;
    try {
      const input = {
        opportunityId: this.opportunityId,
        salesOrderId: this.salesOrderId,
        targetOrderIds: d.targetOrderIds,
        accountId: d.accountId,
        share: d.share,
        relationshipType: d.relationshipType,
        relationshipSubType: d.relationshipSubType
      };
      if (d.mode === "edit") {
        /* blank fields only */
        this.owners = await updateOwner({
          input: {
            ...input,
            email: d.email,
            mobile: d.mobile,
            nationality: d.nationality,
            residentStatus: d.residentStatus
          }
        });
      } else {
        this.owners = await addOwner({
          input: {
            ...input,
            firstName: d.firstName,
            lastName: d.lastName,
            email: d.email,
            mobile: d.mobile,
            nationality: d.nationality,
            residentStatus: d.residentStatus,
            eidNumber: d.eidNumber,
            passportNumber: d.passportNumber,
            /* MSC-180: the company path's three; the flag only picks which create runs */
            isCompany: d.isCompany === true,
            companyName: d.companyName,
            tradeLicence: d.tradeLicence
          }
        });
        /* the leaving question is armed here and nowhere else */
        this.addedThisVisit = true;
      }
      this.drawerOpen = false;
      this.person = undefined;
      this.searchStatus = "idle";
      this.reportCount();
    } catch (e) {
      this.ownersError = reduceError(e);
    } finally {
      this.busyOwnersSave = false;
    }
  }

  // identity verification, per person
  /**
   * One button per row, two routes: a joint owner through sendVerification (which stamps the
   * unit), the primary owner through sendKycLink (MODON's lookup finds their order).
   */
  async handleSendVerification(event) {
    const accountId = (event.detail || {}).accountId;
    if (!accountId || this.sendingAccountId) {
      return;
    }
    this.sendingAccountId = accountId;
    this.paneError = undefined;
    try {
      if (this.isPrimaryAccount(accountId)) {
        const problem = await sendKycLink({ opportunityId: this.opportunityId });
        if (problem) {
          this.paneError = problem;
        }
        /* no poll on this route: sendKYCForm is a direct call and the read carries the new state */
        await this.loadOwners(true);
      } else {
        this.owners = await sendOwnerVerification({
          opportunityId: this.opportunityId,
          salesOrderId: this.salesOrderId,
          accountId
        });
        /* this one is a queueable, so the row says "Sending" and the poll watches */
        this.startPoll();
      }
    } catch (e) {
      /* the server's own sentence */
      this.paneError = reduceError(e);
    } finally {
      this.sendingAccountId = undefined;
    }
  }

  /**
   * The way to the missing details: the drawer for a joint owner; for the primary owner, Resume
   * the journey where the Customer card lives, or say so when it cannot be resumed.
   */
  handleFixDetails(event) {
    const accountId = (event.detail || {}).accountId;
    if (!accountId) {
      return;
    }
    if (!this.isPrimaryAccount(accountId)) {
      this.openDrawer("edit", { accountId });
      return;
    }
    if (this.canResume) {
      this.resume();
      return;
    }
    const parties = (this.owners && this.owners.parties) || [];
    const primary = parties.find((p) => p.isPrimary);
    const why = (primary && primary.verificationBlockedReason) || "";
    this.paneError = why
      ? why + " " + LABELS.JO_B_FIX_ON_ACCOUNT
      : LABELS.JO_B_FIX_ON_ACCOUNT;
  }

  /** The host's own handover. */
  resume() {
    const s = this.s;
    this.dispatchEvent(
      new CustomEvent("resumebooking", {
        detail: {
          bookingId: s.id,
          opportunityId: s.opportunityId,
          bookingRef: s.bookingRef,
          unitName: s.unitName,
          customerName: s.customerName
        },
        bubbles: true,
        composed: true
      })
    );
  }

  isPrimaryAccount(accountId) {
    const parties = (this.owners && this.owners.parties) || [];
    const primary = parties.find((p) => p.isPrimary);
    return !!primary && primary.accountId === accountId;
  }

  /** True while any party's link is between enqueued and stamped. */
  get anySending() {
    if (this.sendingAccountId) {
      return true;
    }
    const parties = (this.owners && this.owners.parties) || [];
    return parties.some((p) => p.verificationStatus === "SENDING");
  }

  // the poll
  /** Turns "Sending" into "KYC link sent" once the queueable has run. Nothing else. */
  startPoll() {
    if (this._poll) {
      return;
    }
    this._pollStartedAt = Date.now();
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._poll = setInterval(() => this.pollTick(), POLL_MS);
    /* one early look: the send usually lands within seconds */
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      if (this._poll) {
        this.pollTick();
      }
    }, POLL_FIRST_MS);
    this._visibility = () => {
      if (document.visibilityState === "hidden") {
        this.stopPoll();
      }
    };
    document.addEventListener("visibilitychange", this._visibility);
  }

  stopPoll() {
    if (this._poll) {
      clearInterval(this._poll);
      this._poll = undefined;
    }
    if (this._visibility) {
      document.removeEventListener("visibilitychange", this._visibility);
      this._visibility = undefined;
    }
  }

  async pollTick() {
    if (!this.anySending || !this.opportunityId) {
      this.stopPoll();
      return;
    }
    if (Date.now() - this._pollStartedAt > POLL_CEILING_MS) {
      this.stopPoll();
      return;
    }
    /* quiet */
    await this.loadOwners(true);
    if (!this.anySending) {
      this.stopPoll();
    }
  }

  // compliance, per person
  /** The row is the door (c/mscCompliance is not mounted here). Slots are ensured first and silently. */
  async handleCheckCompliance(event) {
    const accountId = (event.detail && event.detail.accountId) || null;
    if (!accountId) {
      return;
    }
    this.partyAccountId = this.isPrimaryAccount(accountId) ? undefined : accountId;
    this.checkOpen = true;
    this.checkError = undefined;
    /* busy before the first await, and the last person's checklist dropped */
    this.busyCheck = true;
    this.check = undefined;
    await this.ensureSlots();
    await this.loadCheck();
  }

  /** Moving from one person to the next without closing. */
  async handleSwitchParty(event) {
    const accountId = (event.detail && event.detail.accountId) || null;
    if (!accountId || this.busyCheckSave || this.busyCheckSubmit) {
      return;
    }
    this.partyAccountId = this.isPrimaryAccount(accountId) ? undefined : accountId;
    this.checkError = undefined;
    this.busyCheck = true;
    this.check = undefined;
    await this.ensureSlots();
    await this.loadCheck();
  }

  /** Silent by design. */
  async ensureSlots() {
    try {
      await ensurePartyDocSlots({
        opportunityId: this.opportunityId,
        salesOrderId: this.salesOrderId,
        partyAccountId: this.partyAccountId || null
      });
    } catch (e) {
      // deliberately swallowed
    }
  }

  /** Everybody this booking could send, for the party strip. Deduped by account. */
  get checkParties() {
    const parties = (this.owners && this.owners.parties) || [];
    const seen = new Set();
    const out = [];
    parties.forEach((p) => {
      if (!p.accountId || seen.has(p.accountId)) {
        return;
      }
      seen.add(p.accountId);
      out.push(p);
    });
    return out;
  }

  /** null for the buyer. */
  get checkActiveAccountId() {
    if (this.partyAccountId) {
      return this.partyAccountId;
    }
    const primary = this.checkParties.find((p) => p.isPrimary === true);
    return primary ? primary.accountId : undefined;
  }

  async loadCheck() {
    this.busyCheck = true;
    /* on the panel, never on the pane */
    this.checkError = undefined;
    try {
      this.check = await getChecklist({
        opportunityId: this.opportunityId,
        salesOrderId: this.salesOrderId,
        partyAccountId: this.partyAccountId || null
      });
    } catch (e) {
      this.checkError = reduceError(e);
      this.check = undefined;
    } finally {
      this.busyCheck = false;
    }
  }

  handleRefreshCheck() {
    if (this.busyCheckSave || this.busyCheckSubmit) {
      return;
    }
    return this.loadCheck();
  }

  handleCloseCheck() {
    // mid-save or mid-submit the answer is still coming
    if (this.busyCheckSave || this.busyCheckSubmit) {
      return;
    }
    this.checkOpen = false;
    this.partyAccountId = undefined;
    this.check = undefined;
    this.checkError = undefined;
  }

  /** The reply is the recomputed checklist. */
  async handleSaveCheckDetails(event) {
    const fields = (event.detail && event.detail.fields) || {};
    if (!Object.keys(fields).length) {
      return;
    }
    this.busyCheckSave = true;
    this.checkError = undefined;
    try {
      this.check = await saveChecklistDetails({
        opportunityId: this.opportunityId,
        salesOrderId: this.salesOrderId,
        partyAccountId: this.partyAccountId || null,
        fieldsJson: JSON.stringify(fields)
      });
    } catch (e) {
      this.checkError = reduceError(e);
    } finally {
      this.busyCheckSave = false;
    }
  }

  /** Sends one person to compliance; the checklist is re-read either way. */
  async handleSubmitCheck() {
    this.busyCheckSubmit = true;
    this.checkError = undefined;
    try {
      const res = await submitToCompliance({
        opportunityId: this.opportunityId,
        salesOrderId: this.salesOrderId,
        partyAccountId: this.partyAccountId || null
      });
      if (res && res.success === true) {
        this.checkOpen = false;
        this.partyAccountId = undefined;
        this.check = undefined;
        this.busyCheckSubmit = false;
        /* the row above reports this person's own state, so it moves with the submission */
        await this.loadOwners(true);
        return;
      }
      await this.loadCheck();
    } catch (e) {
      const message = reduceError(e);
      await this.loadCheck();
      // loadCheck clears it on the way in
      this.checkError = message;
    } finally {
      this.busyCheckSubmit = false;
    }
  }

  // leaving with a unit nobody co-owns
  /** Whether going back to the list should ask first. Armed by an add, not by arriving. */
  @api
  get holdsLeave() {
    return (
      this.addedThisVisit &&
      !this.gateAnswered &&
      !!this.owners &&
      !this.owners.readOnly &&
      !!this.owners.jointOwnerCount &&
      this.uncovered.length > 0
    );
  }

  @api
  askBeforeLeaving() {
    this.gateOpen = true;
  }

  handleGateAdd() {
    this.gateOpen = false;
    this.handleAddToUncovered();
  }

  handleGateConfirm() {
    this.gateOpen = false;
    this.gateAnswered = true;
    this.dispatchEvent(new CustomEvent("leaveconfirmed"));
  }
}