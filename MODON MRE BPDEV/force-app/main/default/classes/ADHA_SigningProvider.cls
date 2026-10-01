/**********************************************************************************************************************
* Name               : ADHA_SigningProvider
* Description        : What the journey needs from a signing service, and nothing more. Tests never reach Modon's
*                      live DocuSign account, and a demo account later is a setting change rather than a rewrite.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
public interface ADHA_SigningProvider {

    /** Raises the envelope and returns its id. Must not send the signer any email. */
    String send(ADHA_SigningService.SignRequest request);

    /** A short-lived captive URL for this signer to sign in the browser. */
    String signingUrl(String envelopeId, ADHA_SigningService.SignRequest request);

    /** DocuSign's own word for the envelope: sent, delivered, completed, declined, voided. */
    String status(String envelopeId);

    /** Withdraws an envelope. Used to clean up after a test send. */
    Boolean voidEnvelope(String envelopeId, String reason);

    /**
     * The executed PDF with the certificate of completion appended, as base64.
     * Null when DocuSign will not give it up, which must never cost the customer their reservation.
     */
    String downloadSigned(String envelopeId);
}