public class MBP_RegistrationTriggerHandler {
    
    public static void createServiceRequest(List<Registration__c> newList, Map<Id, Registration__c> oldMap) {
        Set<Id> submittedRegIds = new Set<Id>();
        List<ServiceRequest__c> serviceRequestListToUpdate = new List<ServiceRequest__c>();
        String serviceRequestRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Broker Registration').getRecordTypeId();
        
        for (Registration__c reg : newList) {
            Registration__c oldReg = oldMap.get(reg.Id);
            if (reg.Status__c == 'Submitted' && oldReg.Status__c != 'Submitted') {
                submittedRegIds.add(reg.Id);
            }
        }
        
        List<ServiceRequest__c> serviceRequestList = [
            SELECT Id, Registration__c, Name
            FROM ServiceRequest__c 
            WHERE Registration__c IN :submittedRegIds 
            AND RecordTypeId = :serviceRequestRecordTypeId
        ];
        Map<Id, ServiceRequest__c> registrationIdToSR = new Map<Id, ServiceRequest__c>();
        for (ServiceRequest__c sr : serviceRequestList) {
            registrationIdToSR.put(sr.Registration__c, sr);
        }
        
        for (Registration__c reg : newList) {
            Registration__c oldReg = oldMap.get(reg.Id);
            if (reg.Status__c == 'Submitted' && oldReg.Status__c != 'Submitted') {
                if (!registrationIdToSR.containsKey(reg.Id)) {
                    ServiceRequest__c serviceRequest = new ServiceRequest__c();
                    serviceRequest.Registration__c = reg.Id;
                    serviceRequest.Status__c = 'New';
                    serviceRequest.RecordTypeId = serviceRequestRecordTypeId;
                    serviceRequestListToUpdate.add(serviceRequest);
                }
            }
        }
        
        Map<Id, ServiceRequest__c> newSRs = new Map<Id, ServiceRequest__c>();
        if (!serviceRequestListToUpdate.isEmpty()) {
            insert serviceRequestListToUpdate;
            
            Set<Id> newSRIds = new Set<Id>();
            for (ServiceRequest__c sr : serviceRequestListToUpdate) {
                newSRIds.add(sr.Id);
            }
            
            newSRs = new Map<Id, ServiceRequest__c>([
                SELECT Id, Name, Registration__c 
                FROM ServiceRequest__c 
                WHERE Id IN :newSRIds
            ]);
        }
        
        Map<String, String> registration_SRMap = new Map<String, String>();
        
        for (Registration__c reg : newList) {
            Registration__c oldReg = oldMap.get(reg.Id);
            
            if (reg.Status__c == 'Submitted' && oldReg.Status__c != 'Submitted') {
                ServiceRequest__c sr;
                if (registrationIdToSR.containsKey(reg.Id)) {
                    sr = registrationIdToSR.get(reg.Id);
                } else {
                    for (ServiceRequest__c newSR : newSRs.values()) {
                        if (newSR.Registration__c == reg.Id) {
                            sr = newSR;
                            break;
                        }
                    }
                }
                
                if (sr != null) {
                    registration_SRMap.put(reg.Id, sr.Name);
                }
            }
        }
        
        if (!registration_SRMap.isEmpty()) {
            //MBP_RegistrationFormController.sendSRCreationEmail(registration_SRMap);
        }
    }

    
    public static void createDocumentRecords(List<SObject> newList){
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Registration__c');
        if(!lstDocumentsCurrent.isEmpty()){
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(Registration__c registration : (List<Registration__c>)newList){
                for(Documents__c doc: lstDocumentsCurrent){
                    Documents__c tempD = doc.clone();
                    tempD.Registration__c = registration.Id;
                    lstDocumentsToInsert.add(tempD);
                }
            }
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
    }
    
    

}