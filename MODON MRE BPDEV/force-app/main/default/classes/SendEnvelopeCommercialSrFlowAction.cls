/**
* @description  : Flow Action to Send DocuSign Envelope
*                  Supports:
*                  1. Deed / Novation Agreement
*                  2. NOC Documents
*
* @author       : Sireesha
*/
public class SendEnvelopeCommercialSrFlowAction {
 @TestVisible
    private static Boolean isTestMode = false;
    public class Request {

        @InvocableVariable(required=true)
        public Id serviceRequestId;

        @InvocableVariable(required=true)
        public String documentType;
        /*
            Values:
            'DEED'
            'NOC'
        */
    }

    public class Response {

        @InvocableVariable
        public String docuSignId;

        @InvocableVariable
        public String status;

        @InvocableVariable
        public String errorMessage;
    }

    @InvocableMethod(label='Send DocuSign Envelope for TitleDeed SR')
    public static List<Response> sendEnvelope(List<Request> requests) {

        List<Response> outs = new List<Response>();

        for (Request r : requests) {

            Response res = new Response();

            try {

                if (r.documentType == 'DEED') {

                    if (Test.isRunningTest() && isTestMode) {
                        res.docuSignId = 'TEST_DEED_ENVELOPE_ID';
                    } else {
                        res.docuSignId =
                            DocusignSendEnvelopeBySRDeed.sendFromServiceRequest(
                                r.serviceRequestId
                            );
                    }

                } else if (r.documentType == 'NOC') {

                     if (Test.isRunningTest() && isTestMode) {
                        res.docuSignId = 'TEST_NOC_ENVELOPE_ID';
                    } else {
                        res.docuSignId =
                            DocusignSendEnvelopeByRecordAndDocName.sendFromServiceRequest(
                                r.serviceRequestId
                            );
                    }

                } else {

                    throw new AuraHandledException(
                        'Invalid document type. Use DEED or NOC.'
                    );
                }

                res.status = 'Success';

            } catch (Exception e) {

                res.status = 'Error';

                res.errorMessage =
                    e.getMessage()
                    + ' | Line: '
                    + e.getLineNumber()
                    + ' | Stack: '
                    + e.getStackTraceString();
            }

            outs.add(res);
        }

        return outs;
    }
}