/**********************************************************************************************************************
* Name               : ADHA_StubSigningProvider
* Description        : A signing provider that never leaves the org, and the default: only a deliberate assignment
*                      can put an envelope into Modon's live DocuSign account. Every test runs against this.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
public without sharing class ADHA_StubSigningProvider implements ADHA_SigningProvider {

    /** Set by tests to walk the journey through to a signed envelope. */
    @TestVisible private static String nextStatus = 'sent';
    @TestVisible private static List<ADHA_SigningService.SignRequest> sent =
        new List<ADHA_SigningService.SignRequest>();
    @TestVisible private static List<String> voided = new List<String>();

    public String send(ADHA_SigningService.SignRequest request) {
        sent.add(request);
        return 'STUB-' + String.valueOf(sent.size()).leftPad(4, '0');
    }

    public String signingUrl(String envelopeId, ADHA_SigningService.SignRequest request) {
        // Shaped like the real thing, including the return URL, so the journey can be built against it.
        return request.returnUrl + '?event=signing_complete&stub=' + envelopeId;
    }

    public String status(String envelopeId) {
        return nextStatus;
    }

    /** Cleared by a test to prove a DocuSign refusal still lets the villa go. */
    @TestVisible private static Boolean voidSucceeds = true;

    public Boolean voidEnvelope(String envelopeId, String reason) {
        if (voidSucceeds != true) {
            return false;
        }
        voided.add(envelopeId);
        return true;
    }

    /** Set to null by a test to prove a failed download still completes the reservation. */
    @TestVisible private static String signedCopy = '%PDF-1.4 stub signed copy';

    public String downloadSigned(String envelopeId) {
        return signedCopy == null ? null : EncodingUtil.base64Encode(Blob.valueOf(signedCopy));
    }
}