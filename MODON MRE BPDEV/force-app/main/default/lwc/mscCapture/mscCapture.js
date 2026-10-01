/**
 * Guided image capture with graceful degradation.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  06 Aug 2026  Initial.
 * 1.1      Aurelix IT  19 Aug 2026  A REFUSED CAMERA IS NOT A MISSING CAMERA. One "Block"
 *                                   on the browser's permission prompt used to hide the
 *                                   capture button for good (the refusal set
 *                                   _cameraUnavailable, which canUseCamera reads), so a rep
 *                                   who then re-allowed the camera in the address bar had
 *                                   no way to try again. Now the button stays; a refusal
 *                                   (NotAllowedError / SecurityError), a busy camera
 *                                   (NotReadableError) or any other start failure explains
 *                                   itself in the banner and still opens the file picker as
 *                                   the fallback. Only "no camera on this device"
 *                                   (NotFoundError / OverconstrainedError) hides the button,
 *                                   because that is the one case a retry cannot fix.
 * 1.2      Aurelix Dev 21 Aug 2026  MSC-105. `autostart` - THE HOST HAS ALREADY ASKED FOR
 *                                   THE CAMERA, SO DO NOT ASK AGAIN.
 *
 *                                   The idle screen (Capture proof · Upload a file) is this
 *                                   widget's entry state, and it is right where the widget
 *                                   IS the surface - the cheque sheet, the cheque capture.
 *                                   In c/mscPaymentBlock it is mounted UNDER a strip that
 *                                   already carries Attach proof and Use camera, so one
 *                                   press on Use camera answered with the same two questions
 *                                   again, plus a file dialog the catch below opened by
 *                                   itself. Three responses to one press, none of them a
 *                                   camera.
 *
 *                                   Under `autostart` the widget opens LIVE, never draws the
 *                                   idle screen, never opens the picker on its own, and says
 *                                   what went wrong instead - the messages 1.1 already
 *                                   wrote, ending in `fallbackHint` so they name the control
 *                                   the host actually has on screen. Cancel raises `cancel`
 *                                   rather than falling back to an idle screen that is not
 *                                   drawn.
 *
 *                                   Off by default: every existing host keeps 1.1 exactly,
 *                                   message text included.
 */

import { LightningElement, api, track } from "lwc";

/**
 * Guided image capture, degrading gracefully: getUserMedia with a framing guide and
 * retake, then <input capture="environment"> for the OS camera, then a plain picker.
 *
 * No component in this org has used navigator.mediaDevices before, so mode 1 is
 * treated as unproven - any failure falls through rather than leaving a dead button.
 *
 * getUserMedia earns its place mainly for size: a 12MP photo is ~8MB and base64 adds
 * a third, past the Apex async heap. The canvas step resamples before encoding, which
 * the capture attribute gives no control over. Framing and retake are the bonus.
 */
const MAX_EDGE = 1600;
const JPEG_QUALITY = 0.82;
/** Backstop only; mscCapture normally lands far under this. */
const MAX_BYTES = 4 * 1024 * 1024;

export default class MscCapture extends LightningElement {
  /** Aspect ratio of the framing guide. 2.4 suits a cheque. */
  @api aspect = 2.4;
  @api label = "Capture";
  @api hint = "Fit the whole document inside the frame";
  @api accept = ".jpg,.jpeg,.png,.pdf";
  @api disabled = false;

  /**
   * 1.2 - OPEN LIVE. Set by a host whose own surface is the idle screen: the press
   * that mounted this widget WAS the "use the camera" press, so asking again is the
   * bug. It also hands the two fallbacks back to the host - the idle screen is not
   * drawn and the file picker is never opened from in here.
   *
   * A property rather than a bare attribute at the call site: LWC passes a bare
   * boolean attribute as "", which is falsy.
   */
  @api autostart = false;

  /**
   * 1.2 - what to do instead, in the host's own words, mid-sentence and lowercase
   * ("use Attach proof above"). The failure messages end in it, so they name a
   * control the rep can actually see. Defaults to this widget's own idle button, so
   * every message reads exactly as it did in 1.1 where nothing sets it.
   */
  @api fallbackHint;

  @track mode = "idle"; // idle | live | preview
  @track cameraError;
  @track busy = false;

  _stream;
  _dataUrl;
  _fileName;
  /**
   * 1.1 - set only when the device has NO camera to offer (NotFoundError and
   * friends). A refusal is not recorded here: the rep can re-allow the camera in
   * the browser and press the button again.
   */
  _cameraUnavailable = false;

  // ---- lifecycle ---------------------------------------------------------

  /**
   * 1.2 - the host mounts this widget in response to a press, so connecting IS the
   * press. Once per mount: @api properties are set before connectedCallback, and the
   * hosts that use this unmount the widget rather than leaving it idle.
   */
  connectedCallback() {
    if (this.autostart === true) {
      this.startCamera();
    }
  }

  renderedCallback() {
    // The LWC template compiler refuses `capture` as a static attribute on
    // <input> (LWC1057) despite it being valid HTML, so it is applied here.
    // Without it, mode 2 degrades to an ordinary file picker on a phone -
    // still usable, just an extra tap through the photo library.
    const input = this.template.querySelector("input[type='file']");
    if (!input) return;
    const want = this.fileInputCapture;
    if (want) {
      if (input.getAttribute("capture") !== want) input.setAttribute("capture", want);
    } else if (input.hasAttribute("capture")) {
      input.removeAttribute("capture");
    }
  }

  disconnectedCallback() {
    // A live camera left running after the component is torn down keeps the
    // device indicator lit, which reads as spyware.
    this.stopStream();
  }

  // ---- capability --------------------------------------------------------

  get canUseCamera() {
    return (
      !this._cameraUnavailable &&
      typeof navigator !== "undefined" &&
      !!navigator.mediaDevices &&
      typeof navigator.mediaDevices.getUserMedia === "function"
    );
  }

  /**
   * Mode 2 only makes sense where an OS camera exists. On a desktop the
   * attribute is ignored and the control is an ordinary file picker, so the
   * button is labelled for what it will actually do.
   */
  get fileInputCapture() {
    return this.canUseCamera || this.isLikelyMobile ? "environment" : undefined;
  }

  get isLikelyMobile() {
    return (
      typeof window !== "undefined" &&
      typeof window.matchMedia === "function" &&
      window.matchMedia("(pointer: coarse)").matches
    );
  }

  get showCameraButton() {
    return this.mode === "idle" && (this.canUseCamera || this.isLikelyMobile);
  }

  /**
   * 1.2 - the tail every failure message ends with. Lowercase, because it is always
   * mid-sentence; `fallbackLead` is the same words where a sentence starts with them.
   */
  get fallbackTail() {
    return this.fallbackHint || "upload a file";
  }
  get fallbackLead() {
    const t = this.fallbackTail;
    return t.charAt(0).toUpperCase() + t.slice(1);
  }

  // ---- view state --------------------------------------------------------

  /* 1.2 - never under autostart. The host's own surface is the idle screen, and
     drawing a second one is the whole defect. A failure therefore renders the banner
     alone, which is the intent: one message, and the way out is where the rep just
     pressed. */
  get isIdle() {
    return this.mode === "idle" && this.autostart !== true;
  }
  get isLive() {
    return this.mode === "live";
  }
  get isPreview() {
    return this.mode === "preview";
  }
  get previewSrc() {
    return this._dataUrl;
  }
  get actionsDisabled() {
    return this.disabled || this.busy;
  }
  get guideStyle() {
    // Padding-top percentage is the only reliable way to hold an aspect ratio
    // across the browsers this has to run on.
    return `padding-top:${(1 / Number(this.aspect || 2.4)) * 100}%`;
  }

  // ---- mode 1: live camera ----------------------------------------------

  async startCamera() {
    this.cameraError = undefined;
    if (!this.canUseCamera) {
      /* 1.2 - no getUserMedia at all (an old browser, or an insecure context). Under
         autostart the picker is the host's, so say so rather than opening one. */
      if (this.autostart === true) {
        this.cameraError = `No camera is available in this browser. ${this.fallbackLead} instead.`;
        return;
      }
      this.openFilePicker();
      return;
    }
    try {
      this._stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: { ideal: "environment" },
          width: { ideal: 1920 },
          height: { ideal: 1080 }
        },
        audio: false
      });
      this.mode = "live";
      // Wait for the template to swap before reaching for the video element.
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      window.requestAnimationFrame(() => this.attachStream());
    } catch (e) {
      /* 1.1 - say why, keep the button, and still offer the picker. Only a device
         with no camera at all loses the button; a refusal is recoverable from the
         browser's address bar, and a busy camera frees up. */
      const name = (e && e.name) || "";
      /* 1.2 - the same four messages 1.1 wrote, ending in fallbackTail so they name
         the host's control instead of an idle button that may not be drawn. With
         nothing set, every one of them reads exactly as it did. */
      if (name === "NotFoundError" || name === "DevicesNotFoundError" || name === "OverconstrainedError") {
        this._cameraUnavailable = true;
        this.cameraError = `No camera was found on this device. ${this.fallbackLead} instead.`;
      } else if (name === "NotAllowedError" || name === "PermissionDeniedError" || name === "SecurityError") {
        this.cameraError =
          "Camera access is blocked for this site. Allow the camera in your browser's site settings " +
          "(the camera icon in the address bar), then press " + this.label + " again - or " +
          this.fallbackTail + ".";
      } else if (name === "NotReadableError" || name === "TrackStartError" || name === "AbortError") {
        this.cameraError =
          "The camera could not be started - another app may be using it. Close that app and try again, or " +
          this.fallbackTail + ".";
      } else {
        this.cameraError = "The camera could not be started. Try again, or " + this.fallbackTail + ".";
      }
      this.stopStream();
      this.mode = "idle";
      /* 1.2 - and the picker does NOT open itself under autostart. A file dialog
         appearing on top of a permission refusal is startling, and it buries the
         message that is the only thing able to fix the refusal. */
      if (this.autostart !== true) {
        this.openFilePicker();
      }
    }
  }

  attachStream() {
    const video = this.template.querySelector("video");
    if (!video || !this._stream) return;
    video.srcObject = this._stream;
    // iOS Safari forces fullscreen playback without playsinline, which loses
    // the framing guide entirely.
    video.setAttribute("playsinline", "true");
    video.setAttribute("muted", "true");
    const p = video.play();
    if (p && typeof p.catch === "function") {
      p.catch(() => {
        // 1.1 - playback refused (autoplay policy, tab backgrounded): back to idle
        // with the button still there, not a permanent loss of the camera.
        this.cameraError =
          "The camera preview could not start. Try again, or " + this.fallbackTail + ".";
        this.stopStream();
        this.mode = "idle";
      });
    }
  }

  stopStream() {
    if (this._stream) {
      this._stream.getTracks().forEach((t) => t.stop());
      this._stream = undefined;
    }
    const video = this.template.querySelector("video");
    if (video) video.srcObject = null;
  }

  /**
   * Freezes the frame and resamples it.
   *
   * The downscale is the whole point: it is what keeps the base64 payload
   * inside the Apex heap, and 1600px on the long edge is still comfortably
   * more resolution than a cheque needs to be read.
   */
  handleShutter() {
    const video = this.template.querySelector("video");
    if (!video || !video.videoWidth) return;

    const sw = video.videoWidth;
    const sh = video.videoHeight;
    const scale = Math.min(1, MAX_EDGE / Math.max(sw, sh));
    const w = Math.round(sw * scale);
    const h = Math.round(sh * scale);

    const canvas = document.createElement("canvas");
    canvas.width = w;
    canvas.height = h;
    canvas.getContext("2d").drawImage(video, 0, 0, w, h);

    this._dataUrl = canvas.toDataURL("image/jpeg", JPEG_QUALITY);
    this._fileName = `cheque-${new Date().getTime()}.jpg`;
    this.stopStream();
    this.mode = "preview";
  }

  handleRetake() {
    this._dataUrl = undefined;
    this._fileName = undefined;
    this.mode = "idle";
    this.startCamera();
  }

  handleCancel() {
    this.stopStream();
    this._dataUrl = undefined;
    this._fileName = undefined;
    this.mode = "idle";
    /* 1.2 - under autostart idle draws nothing, so Cancel has to mean "close me" and
       the host is the only thing that can. The stream is stopped above first, so a
       host that ignores the event still leaks no camera. */
    if (this.autostart === true) {
      this.dispatchEvent(new CustomEvent("cancel"));
    }
  }

  handleAccept() {
    if (!this._dataUrl) return;
    this.emit(this._dataUrl, this._fileName);
  }

  // ---- modes 2 and 3: the file input ------------------------------------

  openFilePicker() {
    const input = this.template.querySelector("input[type='file']");
    if (input) input.click();
  }

  handleFilePick(event) {
    const file = event.target.files && event.target.files[0];
    // Reset immediately so picking the same file twice still fires a change.
    event.target.value = null;
    if (!file) return;

    if (file.size > MAX_BYTES) {
      this.cameraError =
        "That file is too large to process. Take a photo with the camera instead, or use a smaller file.";
      return;
    }
    this.cameraError = undefined;

    const reader = new FileReader();
    reader.onload = () => {
      this._dataUrl = reader.result;
      this._fileName = file.name;
      // A PDF has no useful preview here, and re-encoding it through a canvas
      // would destroy it. Send it straight on.
      if (file.type === "application/pdf") {
        this.emit(reader.result, file.name);
      } else {
        this.mode = "preview";
      }
    };
    reader.onerror = () => {
      this.cameraError = "That file could not be read. Please try another.";
    };
    reader.readAsDataURL(file);
  }

  // ---- output ------------------------------------------------------------

  /**
   * Emits base64 without the data-URI prefix - the shape
   * CustomerKYCHandler.handlePOAFile and tradeLicenseuploadFile already expect,
   * and the same `reader.result.split(",")[1]` idiom used by
   * powerofattorneyfileuploadcmp and tradeLicensefileUploadLWC.
   */
  emit(dataUrl, fileName) {
    const base64 = String(dataUrl).split(",")[1];
    this.dispatchEvent(
      new CustomEvent("capture", {
        detail: { base64, fileName, dataUrl }
      })
    );
    this._dataUrl = undefined;
    this._fileName = undefined;
    this.mode = "idle";
  }
}