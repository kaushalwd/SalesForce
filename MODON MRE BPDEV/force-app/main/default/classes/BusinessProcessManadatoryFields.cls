/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class BusinessProcessManadatoryFields {
        
    public static void validateMandatoryFields(List<SObject> newList, Map<Id, SObject> oldMap) {
        System.debug('validateMandatoryFields method called');
        Set<String> stepNames = new Set<String>();
        Set<Id> businessProcessIds = new Set<Id>();
        Set<Id> stepIds = new Set<Id>();
        Set<Id> processFlowStepIds = new Set<Id>();
        
        for (Business_Process_Step__c newStep : (List<Business_Process_Step__c>) newList) {
            Business_Process_Step__c oldStep = (Business_Process_Step__c) oldMap.get(newStep.Id);
            if (oldStep.Status__c != newStep.Status__c && newStep.Status__c == 'Completed' && newStep.Business_Process__c != null) {
                stepNames.add(newStep.name);
                stepIds.add(newStep.Id);
                businessProcessIds.add(newStep.Business_Process__c);
            }
        }
        System.debug('stepNames = '+stepNames);
        System.debug('businessProcessIds = '+businessProcessIds);
        if (stepNames.isEmpty()) return;
        
        Set<Id> bookingIds = new Set<Id>();
        Set<Id> unitIds = new Set<Id>();
        Set<Id> processFlowIds = new Set<Id>();
        Map<Id, Business_Process__c> businessProcessMap = new Map<Id, Business_Process__c>();
        
        for (Business_Process__c bp : [
            SELECT Id, Process_Flow__c/*, Booking__c, Unit__c */
            FROM Business_Process__c 
            WHERE Id IN :businessProcessIds AND Process_Flow__c != null
        ]) {
            businessProcessMap.put(bp.Id, bp);
            processFlowIds.add(bp.Process_Flow__c);
           // if (bp.Booking__c != null) bookingIds.add(bp.Booking__c);
           // if (bp.Unit__c != null) unitIds.add(bp.Unit__c);
        }
        System.debug('bookingIds = '+bookingIds);
        System.debug('unitIds = '+unitIds);
        System.debug('businessProcessMap = '+businessProcessMap);
        System.debug('processFlowIds = '+processFlowIds);
        if (processFlowIds.isEmpty()) return;
        
        //Set<Id> processFlowStepIds = new Set<Id>();
        Map<String, Process_Flow_Step__c> pfsKeyToPfsMap = new Map<String, Process_Flow_Step__c>();
        for (Process_Flow_Step__c pfs : [
            SELECT Id, Step_Name__c, Process_Flow__c 
            FROM Process_Flow_Step__c 
            WHERE Process_Flow__c IN :processFlowIds AND Step_Name__c IN :stepNames
        ]) {
            String key = pfs.Process_Flow__c + '__' + pfs.Step_Name__c;
            pfsKeyToPfsMap.put(key, pfs);
            processFlowStepIds.add(pfs.Id);
        }
        
        System.debug('processFlowStepIds = '+processFlowStepIds);
        List<Mandatory_Field__c> mandatoryFields = [
            SELECT Id, Field_API_Name__c, Field_Value__c, Object_Api_Name__c, Process_Flow_Step__c 
            FROM Mandatory_Field__c 
            WHERE Process_Flow_Step__c IN :processFlowStepIds
        ];
        System.debug('mandatoryFields = '+mandatoryFields);
        if (mandatoryFields.isEmpty()) return;
        
        Map<Id, List<Mandatory_Field__c>> pfsIdToMandatoriesMap = new Map<Id, List<Mandatory_Field__c>>();
        Set<String> bookingFieldApiNames = new Set<String>();
        Set<String> unitFieldApiNames = new Set<String>();
        Set<String> businessProcessFieldApiNames = new Set<String>();
        Set<String> businessProcessStepFieldApiNames = new Set<String>();
        
        for (Mandatory_Field__c mf : mandatoryFields) {
            if (!pfsIdToMandatoriesMap.containsKey(mf.Process_Flow_Step__c))
                pfsIdToMandatoriesMap.put(mf.Process_Flow_Step__c, new List<Mandatory_Field__c>());
            pfsIdToMandatoriesMap.get(mf.Process_Flow_Step__c).add(mf);
            
           // if (mf.Object_Api_Name__c == 'Booking__c') bookingFieldApiNames.add(mf.Field_API_Name__c);
           // else if (mf.Object_Api_Name__c == 'Unit__c') unitFieldApiNames.add(mf.Field_API_Name__c);
            if (mf.Object_Api_Name__c == 'Business_Process__c') businessProcessFieldApiNames.add(mf.Field_API_Name__c);
            else if (mf.Object_Api_Name__c == 'Business_Process_Step__c') businessProcessStepFieldApiNames.add(mf.Field_API_Name__c);
        }
        System.debug('pfsIdToMandatoriesMap = '+pfsIdToMandatoriesMap);
        
         /*
        // Query related Booking__c records
        Map<Id, Booking__c> bookingMap = new Map<Id, Booking__c>();
        if (!bookingIds.isEmpty() && !bookingFieldApiNames.isEmpty()) {
            String bookingFields = 'Id';
            for (String f : bookingFieldApiNames) bookingFields += ', ' + f;
          //  List<Booking__c> bookingList = (List<Booking__c>) Database.query('SELECT ' + bookingFields + ' FROM Booking__c WHERE Id IN :bookingIds');
          //  bookingMap = new Map<Id, Booking__c>(bookingList);
        }
        System.debug('bookingMap = '+bookingMap);
       
        // Query related Unit__c records
        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>();
        if (!unitIds.isEmpty() && !unitFieldApiNames.isEmpty()) {
            String unitFields = 'Id';
            for (String f : unitFieldApiNames) unitFields += ', ' + f;
            
            List<Unit__c> unitList = (List<Unit__c>) Database.query('SELECT ' + unitFields + ' FROM Unit__c WHERE Id IN :unitIds');
            unitMap = new Map<Id, Unit__c>(unitList);
        }
         System.debug('unitMap = '+unitMap);
      */
        
        // Query related Business_Process__c records for needed fields
        Map<Id, Business_Process__c> bpFieldMap = new Map<Id, Business_Process__c>();
        if (!businessProcessFieldApiNames.isEmpty()) {
            String bpFields = 'Id';
            for (String f : businessProcessFieldApiNames) bpFields += ', ' + f;
            
            List<Business_Process__c> businessProcessList = (List<Business_Process__c>) Database.query('SELECT ' + bpFields + ' FROM Business_Process__c WHERE Id IN :businessProcessIds');
            bpFieldMap = new Map<Id, Business_Process__c>(businessProcessList);
        }
         System.debug('bpFieldMap = '+bpFieldMap);
        
        // Query the Business_Process_Step__c records with needed fields for validation
        Set<String> allBpsFields = new Set<String>(businessProcessStepFieldApiNames);
        allBpsFields.add('Id');
        allBpsFields.add('Business_Process__c');
        allBpsFields.add('Name');
        String bpsFieldQuery = 'SELECT ' + String.join(new List<String>(allBpsFields), ', ') + ' FROM Business_Process_Step__c WHERE Id IN :stepIds';
        List<Business_Process_Step__c> bpsList = Database.query(bpsFieldQuery);
        Map<Id, Business_Process_Step__c> bpsMap = new Map<Id, Business_Process_Step__c>();
        for (Business_Process_Step__c bps : bpsList) {
            bpsMap.put(bps.Id, bps);
        }
        
        // Validate mandatory fields for each Business Process Step changing status to 'Completed'
        for (Business_Process_Step__c newStep : (List<Business_Process_Step__c>) newList) {
            
            if(stepIds.contains(newStep.Id)){
                
                String key = businessProcessMap.get(newStep.Business_Process__c).Process_Flow__c + '__' + newStep.Name;
                if (!pfsKeyToPfsMap.containsKey(key)) continue;
                
                Process_Flow_Step__c pfs = pfsKeyToPfsMap.get(key);
                List<Mandatory_Field__c> mandatories = pfsIdToMandatoriesMap.get(pfs.Id);
                 System.debug('mandatories = '+mandatories);
                if (mandatories == null || mandatories.isEmpty()) continue;
                
                Business_Process__c bp = businessProcessMap.get(newStep.Business_Process__c);
                System.debug('bp = '+bp);
                Business_Process_Step__c bpsRecord = bpsMap.get(newStep.Id);
                
                for (Mandatory_Field__c mf : mandatories) {
                    String objApi = mf.Object_Api_Name__c;
                    String fieldApi = mf.Field_API_Name__c;
                    String expectedVal = mf.Field_Value__c != null ? mf.Field_Value__c.trim() : '';
                    String actualVal;
                    
                     System.debug('objApi = '+objApi);
                    /*
                    if (objApi == 'Booking__c') {
                        Booking__c booking = bp != null ? bookingMap.get(bp.Booking__c) : null;
                        actualVal = (booking != null && booking.get(fieldApi) != null) ? String.valueOf(booking.get(fieldApi)).trim() : '';
                    } else if (objApi == 'Unit__c') {
                        Unit__c unitRec = bp != null ? unitMap.get(bp.Unit__c) : null;
                        actualVal = (unitRec != null && unitRec.get(fieldApi) != null) ? String.valueOf(unitRec.get(fieldApi)).trim() : '';
                    } else */if (objApi == 'Business_Process__c') {
                        Business_Process__c bpRec = bp != null ? bpFieldMap.get(bp.Id) : null;
                        actualVal = (bpRec != null && bpRec.get(fieldApi) != null) ? String.valueOf(bpRec.get(fieldApi)).trim() : '';
                    } else if (objApi == 'Business_Process_Step__c') {
                        actualVal = (bpsRecord != null && bpsRecord.get(fieldApi) != null) ? String.valueOf(bpsRecord.get(fieldApi)).trim() : '';
                    }  else {
                        continue; 
                    }
                    
                    System.debug('actualVal = '+actualVal);
                    System.debug('expectedVal = '+expectedVal);
                    if ( actualVal != expectedVal &&  !String.isBlank(expectedVal)) {
                        System.debug('actualVal != expectedVal');
                        System.debug('fieldApi = '+fieldApi);
                        System.debug('objApi = '+objApi);
                        System.debug('Mandatory field "' + fieldApi + '" on ' + objApi + ' incorrect. Expected: "' + expectedVal + '"');
                        newStep.addError('Mandatory field "' + fieldApi + '" on ' + objApi + ' incorrect. Expected: "' + expectedVal + '"');
                    } else if(String.isBlank(actualVal) && String.isBlank(expectedVal) ){
                        System.debug('missing value');
                        newStep.addError('Mandatory field "' + fieldApi + '" on ' + objApi + ' is missing. Please enter the values before proceed:' );
                    }
                }
            }
        }
    }
    
    
    
}