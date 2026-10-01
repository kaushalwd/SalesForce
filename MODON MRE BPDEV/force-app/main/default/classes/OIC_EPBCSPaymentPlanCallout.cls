/**
 * @description       : OIC_EPBCSPaymentPlanCallout
 *                      - Sends the mapped EPBCS Payment Plan payload to the OIC flow and logs the callout.
 *
 * @author            : Karunakar Pulkam
 * @Created           : 15-08-2026
 * --------------------------------------------------------------------------------------------------------------------
 * Version   Author              Date          Comment
 * 1.0       Karunakar Pulkam    15-08-2026    Initial Draft
 ********************************************************************************************************************/
public class OIC_EPBCSPaymentPlanCallout {

    private static final String CREDENTIAL_TYPE = 'EPBCSPaymentPlanData';

    /**
     * Description : Serializes the payload, sends it to the EPBCS Payment Plan OIC flow,
     *               and logs the callout (success or error).
     */
    public static void sendPaymentPlanData(List<OIC_EPBSCPaymentPlanVO.PaymentPlanRecord> payload) {
        try {
            HttpRequest req = OIC_CredentialsController.getCredentials(CREDENTIAL_TYPE);
            req.setMethod('POST');
            req.setTimeout(120000);

            OIC_EPBSCPaymentPlanVO.PaymentPlanRecordWrapperList wrapperList =
                new OIC_EPBSCPaymentPlanVO.PaymentPlanRecordWrapperList();
            wrapperList.RequestArray = payload;

            String reqBody = JSON.serialize(wrapperList);
            System.debug('JSON.serialize(wrapperList)==> ' + reqBody);

            Blob   binaryData   = Blob.valueOf(reqBody);
            String base64String = EncodingUtil.base64Encode(binaryData);

            OIC_RequestWrapperController.Base64Wrapper wrapper =
                new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;

            req.setBody(JSON.serialize(wrapper));
            System.debug('PaymentPlan Data JSON.serialize(wrapper)==> ' + JSON.serialize(wrapper));

            Http         http = new Http();
            HttpResponse res  = http.send(req);

            /*LoggerService.save(
                LoggerService.createAPILog(
                    'EPBCS Payment Plan API',
                    'OIC_EPBCSPaymentPlanCallout',
                    'sendPaymentPlanData',
                    reqBody,
                    res.getBody(),
                    'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(),
                    'Callout Log'
                )
            );*/
        } catch (Exception ex) { LoggerService.save(LoggerService.createApexLog(ex, 'EPBCS Payment Plan API', 'OIC_EPBCSPaymentPlanCallout','sendPaymentPlanData')); }
    }
}