/**********************************************************************************************************************
* Name               : OIC_ReceiptExternalService
* Description        : Handles the outbound HTTP callout for the Receipt integration with Oracle Fusion.
*                      Encapsulates credential retrieval, Base64 request wrapping and sending the callout,
*                      keeping the callout mechanics separate from the payload-building and response-handling
*                      logic in OIC_ManageSalesforceDataController.
* Usage              : Called from OIC_ManageSalesforceDataController.createReceipt.
* Created By         : MODON IT
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           MODON IT     				26 Jul 2026     Initial Draft - extracted createReceipt callout
***********************************************************************************************************************/
public without sharing class OIC_ReceiptExternalService {

    private static final String RECEIPT_API_CREDENTIAL = 'ModonFusionReceiptAPI2';
    private static final Integer CALLOUT_TIMEOUT_MS = 120000;

    /**
     * Description : Sends the serialized receipt request payload to Oracle Fusion. The payload is
     *               Base64-encoded and wrapped before being sent via the configured named credential.
     * @param receiptWrappString The serialized ReceiptWrapperLst JSON request payload.
     * @return HttpResponse returned by the Oracle Fusion receipt API callout.
     */
    public static HttpResponse sendReceipt(String receiptWrappString) {

        //original base64 pattern
        HttpRequest req = OIC_CredentialsController.getCredentials(RECEIPT_API_CREDENTIAL);
        req.setTimeout(CALLOUT_TIMEOUT_MS);
        System.debug('JSON.serialize(receiptWrappString)==>' + receiptWrappString);
        Blob binaryData = Blob.valueOf(receiptWrappString);
        String base64String = EncodingUtil.base64Encode(binaryData);

        OIC_RequestWrapperController.Base64Wrapper wrapper = new OIC_RequestWrapperController.Base64Wrapper();
        wrapper.Base64RequestPayload = base64String;
        req.setBody(JSON.serialize(wrapper));
        req.setHeader('Accept', 'application/json');
        System.debug('JSON.serialize(wrapper)==>' + JSON.serialize(wrapper));

        Http http = new Http();
        HttpResponse res = http.send(req);        
        return res;
    }
}