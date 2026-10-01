public with sharing class SendEnvelopeFlowAction {
    public class Request {
        @InvocableVariable(required=true)
        public Id serviceRequestId;
    }
    public class Response {
        @InvocableVariable public String docuSignId;
        @InvocableVariable public String status;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Send DocuSign Envelope for Service Request')
    public static List<Response> sendEnvelope(List<Request> requests) {
        List<Response> outs = new List<Response>();
        for (Request r : requests) {
            Response res = new Response();
            try {
                res.docuSignId = DocusignSRSendEnvelopStatus.sendFromServiceRequest(r.serviceRequestId);
                res.status = 'Success';
            } catch (Exception e) {
                res.status = 'Error';
                res.errorMessage = e.getMessage();
            }
            outs.add(res);
        }
        return outs;
    }
}