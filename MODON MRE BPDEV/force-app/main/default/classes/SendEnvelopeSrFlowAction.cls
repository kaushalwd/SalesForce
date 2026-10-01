/**
 * @description  : Helper for sending DocuSign envelopes via dfsle toolkit
 *                 Order: SO Customer (PersonAcc or PrimaryContact) -> Joint Owners -> Prospects -> Final custom recipient
 *                 Documents chosen from Files on Documents__c for the SR, Title LIKE '%Transfer Document%'
 * @author       : Krishna Chaitanya
 * @last updated : 2025-12-11
 * 
 * 1.1  KC			15-04-2026		Error Message Update
 */
public class SendEnvelopeSrFlowAction {
    public class Request {
        @InvocableVariable(required=true)
        public Id serviceRequestId;
    }
    public class Response {
        @InvocableVariable public String docuSignId;
        @InvocableVariable public String status;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Send DocuSign Envelope for SR')
    public static List<Response> sendEnvelope(List<Request> requests) {
        List<Response> outs = new List<Response>();
        for (Request r : requests) {
            Response res = new Response();
            try {
                res.docuSignId = DocusignSRSendEnvelopeWithAccount.sendFromServiceRequest(r.serviceRequestId);
                res.status = 'Success';               
            } catch (Exception e) {
                res.status = 'Error';
                res.errorMessage = e.getMessage()+ ' | Line: ' + e.getLineNumber()+ ' | Stack: ' + e.getStackTraceString();//1.1
            }
            outs.add(res);
        }
        return outs;
    }

}