/**
 * RelixApiException - one Relix (Dalil) API call that did not succeed.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. Carries what a caller may act on: the HTTP status,
 *                                    Relix's stable error code (callers switch on the code, never on
 *                                    the message), the errorRef to quote to Dalil support, the failed
 *                                    field names on a 400, retry-after on a 429, and whether the fault
 *                                    is on our side (key, host, principal access) rather than in the
 *                                    request.
 *
 * OWNERSHIP. Owner: MODON. Thrown by RelixClient only.
 */
public class RelixApiException extends Exception {
    public Integer httpStatus;
    public String code;
    public String errorRef;
    public List<String> fields = new List<String>();
    public Integer retryAfterSeconds;
    public Integer rateRemaining;
    public Boolean isConfigFault = false;
    public Boolean isTimeout = false;

    /** An answer came back and it was not a success. */
    public static RelixApiException of(Integer httpStatus, String code, String errorRef, String message) {
        RelixApiException e = new RelixApiException(
            String.isBlank(message) ? 'Relix call failed.' : message);
        e.httpStatus = httpStatus;
        e.code = String.isBlank(code) ? (httpStatus == null ? 'unknown' : 'http_' + httpStatus) : code;
        e.errorRef = errorRef;
        // 401 and 403 mean the key or the principal is wrong: nothing the buyer or the rep can fix.
        e.isConfigFault = httpStatus == 401 || httpStatus == 403;
        return e;
    }

    /** No answer at all: no principal access, missing key, unknown host, or a timeout. */
    public static RelixApiException transport(Exception cause, String what) {
        String msg = cause == null ? '' : String.valueOf(cause.getMessage());
        RelixApiException e = new RelixApiException(
            'Relix call failed before an answer (' + what + '): ' + msg);
        e.code = 'callout_failed';
        e.isTimeout = msg != null && msg.toLowerCase().contains('timed out');
        e.isConfigFault = !e.isTimeout;
        return e;
    }

    public Boolean isServerError() { return httpStatus != null && httpStatus >= 500; }
    public Boolean isRateLimited() { return httpStatus == 429; }
    public Boolean isNotFound() { return httpStatus == 404; }
    /** True when Relix may have created the case although we never saw the answer. */
    public Boolean isUncertain() { return isTimeout || isServerError(); }
}