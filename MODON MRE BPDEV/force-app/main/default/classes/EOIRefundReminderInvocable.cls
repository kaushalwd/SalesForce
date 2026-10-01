public with sharing class EOIRefundReminderInvocable {

    public class Request {

        @InvocableVariable(required=true)
        public Id caseId;

        @InvocableVariable(required=true)
        public String messageType;

        @InvocableVariable(required=true)
        public String templateName;
    }

    @InvocableMethod(label='Send EOI Refund WhatsApp Reminder')
    public static void sendReminder(List<Request> requests) {

        if(requests == null || requests.isEmpty()){
            return;
        }

        Set<Id> caseIds = new Set<Id>();

        Map<Id, Request> requestMap = new Map<Id, Request>();

        for(Request req : requests){
            if(req.caseId != null){
                caseIds.add(req.caseId);
                requestMap.put(req.caseId, req);
            }
        }

        if(caseIds.isEmpty()){
            return;
        }

        List<Case> caseList = [
            SELECT Id,
                   AccountId,
                   Account.PersonMobilePhone
            FROM Case
            WHERE Id IN :caseIds
        ];

        Map<Id,List<Id>> caseToEOIIdsMap = new Map<Id,List<Id>>();

        for(Expressionofinterest__c eoi : [
            SELECT Id, Case__c FROM Expressionofinterest__c WHERE Case__c IN :caseIds
        ]){
            if(!caseToEOIIdsMap.containsKey(eoi.Case__c)){caseToEOIIdsMap.put(eoi.Case__c,new List<Id>());
            }

            caseToEOIIdsMap.get(eoi.Case__c).add(eoi.Id);
        }

        for(Case cs : caseList){

            if(cs.Account == null
               || String.isBlank(cs.Account.PersonMobilePhone)
               || !caseToEOIIdsMap.containsKey(cs.Id)){
                continue;
            }

            Request req = requestMap.get(cs.Id);
            if(!Test.isRunningTest()) 
            System.enqueueJob(
                new EOIRefundWhatsAppQueueable(cs.Id,cs.Account.PersonMobilePhone,caseToEOIIdsMap.get(cs.Id),req.messageType,req.templateName
                ));
        }
    }
}