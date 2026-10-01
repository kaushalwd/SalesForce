public without sharing class ReAssignToSalesAgent {

    @AuraEnabled(cacheable=true)
    public static String reassignLeadToSA(String leadId){
        System.debug('>>>>>>>>>>>>>>> reassignLeadToSA >>>> '+leadId);
        String result = '';
        Lead leadObj = [SELECT Id, ReAssignRRToSalesAssociate__c FROM Lead WHERE Id =: leadId];
        try{
            if(leadObj != null){
                leadObj.ReAssignRRToSalesAssociate__c = true;
                update leadObj;
                result = 'Success';
            }
        }catch(DMLException e) {
            
            result = 'Failed';
        }
        return result;
    }
    @AuraEnabled(cacheable=true)
    public static String reassignLeadToRecordId(String leadId){
        String leadObjId = leadId;
        System.debug('>>>>>>>>>>>>>>>> Lead Id >>> '+leadId);
        return leadObjId;
    }
}