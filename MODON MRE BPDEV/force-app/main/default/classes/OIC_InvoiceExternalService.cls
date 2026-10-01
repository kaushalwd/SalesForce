/**********************************************************************************************************************
* Name               : OIC_InvoiceExternalService
* Description        : Handles the outbound HTTP callout for the Invoice / Installment integration with Oracle Fusion.
*                      Encapsulates credential retrieval, Base64 request wrapping and sending the callout,
*                      keeping the callout mechanics separate from the payload-building and response-handling
*                      logic in OIC_ManageSalesforceDataController.
* Usage              : Called from OIC_ManageSalesforceDataController.createInstallment.
* Created By         : Karunakar
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Karunakar                   26 Aug 2026     Initial Draft - extracted createInstallment callout
* 1.1           Karunakar                   26 Aug 2026     Added Advance Tax cancellation callout
* 1.2           Karunakar                   28 Aug 2026     Added Advance Tax creation callout (no Base64 envelope)
* 1.3           Karunakar                   28 Aug 2026     Advance Tax cancellation now shares the same plain-JSON,
*                                                            no-Base64 callout and credential as creation
***********************************************************************************************************************/
public without sharing class OIC_InvoiceExternalService {

    private static final String INSTALLMENT_API_CREDENTIAL = 'ModonFusionInstallmentAPI2';
    private static final String ADVANCE_TAX_CREATE_CREDENTIAL = 'CreateAdvanceTaxInvoiceAPI';
    private static final Integer CALLOUT_TIMEOUT_MS = 120000;

    /**
     * Description : Sends the serialized installment request payload to Oracle Fusion. The payload is
     *               Base64-encoded and wrapped before being sent via the configured named credential.
     * @param installmentWrapString The serialized InstallmentWrapperLst JSON request payload.
     * @return HttpResponse returned by the Oracle Fusion installment API callout.
     */
    public static HttpResponse sendInstallment(String installmentWrapString) {

        //original base64 pattern
        HttpRequest req = OIC_CredentialsController.getCredentials(INSTALLMENT_API_CREDENTIAL);
        req.setTimeout(CALLOUT_TIMEOUT_MS);
        System.debug('JSON.serialize(installmentWrapString)==>' + installmentWrapString);
        Blob binaryData = Blob.valueOf(installmentWrapString);
        String base64String = EncodingUtil.base64Encode(binaryData);
        System.debug('base64String JSON request :' + base64String);

        OIC_RequestWrapperController.Base64Wrapper wrapper = new OIC_RequestWrapperController.Base64Wrapper();
        wrapper.Base64RequestPayload = base64String;
        req.setBody(JSON.serialize(wrapper));
        req.setHeader('Accept', 'application/json');
        System.debug('JSON.serialize(wrapper)==>' + JSON.serialize(wrapper));

        Http http = new Http();
        HttpResponse res = http.send(req);
        return res;
    }

    /**
     * Description : Sends the serialized Advance Tax cancellation payload to Oracle Fusion. Uses the same
     *               named credential as the Advance Tax creation callout - the cancellation is the same
     *               ADV_TAX Oracle service, just carrying the cancellation flags - and, like creation, does
     *               not use the Base64 request/response envelope; the JSON payload is sent and received as
     *               plain JSON.
     * @param advanceTaxCancelString The serialized AdvanceTaxInvoiceWrapper.RequestWrapperList JSON payload.
     * @return HttpResponse returned by the Oracle Fusion callout.
     */
    public static HttpResponse sendAdvanceTaxCancellation(String advanceTaxCancelString) {
        return sendAdvanceTaxPayload(advanceTaxCancelString);
    }

    /**
     * Description : Sends the serialized Advance Tax Invoice creation payload to Oracle Fusion. Unlike the
     *               installment callout, the Advance Tax creation API does not use the Base64
     *               request/response envelope - the JSON payload is sent and received as plain JSON.
     * @param advanceTaxRequestString The serialized AdvanceTaxInvoiceWrapper.RequestWrapperList JSON payload.
     * @return HttpResponse returned by the Oracle Fusion callout.
     */
    public static HttpResponse sendAdvanceTaxInvoice(String advanceTaxRequestString) {
        return sendAdvanceTaxPayload(advanceTaxRequestString);
    }

    /**
     * Description : Shared plain-JSON callout used by both Advance Tax creation and cancellation - they are
     *               the same Oracle ADV_TAX service and named credential, differing only in the payload's
     *               cancellation flags.
     */
    private static HttpResponse sendAdvanceTaxPayload(String payload) {
        HttpRequest req = OIC_CredentialsController.getCredentials(ADVANCE_TAX_CREATE_CREDENTIAL);
        req.setTimeout(CALLOUT_TIMEOUT_MS);
        req.setBody(payload);
        req.setHeader('Accept', 'application/json');

        Http http = new Http();
        return http.send(req);
    }
}