// File: DocusignDynamicSendFlowAction.cls
public with sharing class DocusignDynamicSendFlowAction {

    public class Inputs {
        @InvocableVariable(required=true)
        public Id recordId; // ServiceRequest__c Id
    }

    public class Outputs {
        @InvocableVariable
        public String envelopeId;

        @InvocableVariable
        public String message;

        @InvocableVariable
        public Boolean success;
    }

    @InvocableMethod(label='Send DocuSign Envelope for Service Request'
                     description='Sends a DocuSign envelope for the given ServiceRequest__c Id and returns the envelope Id.')
    public static List<Outputs> send(List<Inputs> batch) {
        List<Outputs> results = new List<Outputs>();
        if (batch == null || batch.isEmpty()) return results;

        // Optional: bypass user lookup in tests only
        Boolean resetBypass = false;
       
        try {
            for (Inputs inRec : batch) {
                Outputs out = new Outputs();
                try {
                    String envId = DocusignDynamicSendHelper.sendEnvelope(inRec.recordId);
                    out.envelopeId = envId;
                    out.message = 'Envelope sent successfully.';
                    out.success = true;
                } catch (Exception e) {
                    out.envelopeId = null;
                    out.message = 'Failed: ' + e.getMessage();
                    out.success = false;
                }
                results.add(out);
            }
        } finally {
            
        }
        return results;
    }
}