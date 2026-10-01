public class BusinessProcesssMandatoryFieldUpdate {
    
    public static void populateMandatoryFields(List<SObject> newList, Map<Id, SObject> oldMap) {
        System.debug('populateMandatoryFields method calleddddd');
        
        Set<String> status = new Set<String>{'Approved', 'Rejected', 'Completed', 'Required Info'};
            Set<String> stepNames = new Set<String>();
        Set<Id> businessProcessIds = new Set<Id>();
        Set<Id> stepIds = new Set<Id>();
        
        for (Business_Process_Step__c newStep : (List<Business_Process_Step__c>) newList) {
            Business_Process_Step__c oldStep = (Business_Process_Step__c) oldMap.get(newStep.Id);
            system.debug('oldStep.Status__c:'+oldStep.Status__c);
            system.debug('oldStep.Status__c:'+oldStep.Status__c);
            system.debug('oldStep.Status__c:'+oldStep.Status__c);
            if (oldStep.Status__c != newStep.Status__c && status.contains(newStep.Status__c) && newStep.Business_Process__c != null) { //  'Completed'
                stepNames.add(newStep.Name);
                stepIds.add(newStep.Id);
                businessProcessIds.add(newStep.Business_Process__c);
            }
        }
        
        System.debug('stepNames = '+stepNames);
        System.debug('businessProcessIds = '+businessProcessIds);
        if (stepNames.isEmpty()) return;
        
        //Set<Id> bookingIds = new Set<Id>();
       // Set<Id> unitIds = new Set<Id>();
        Set<Id> processFlowIds = new Set<Id>();
        Map<Id, Business_Process__c> businessProcessMap = new Map<Id, Business_Process__c>();
        
        for (Business_Process__c bp : [ SELECT Id, Process_Flow__c/*, Booking__c, Unit__c*/ FROM Business_Process__c WHERE Id IN :businessProcessIds AND Process_Flow__c != null ]) {
            businessProcessMap.put(bp.Id, bp);
            processFlowIds.add(bp.Process_Flow__c);
           // if (bp.Booking__c != null) bookingIds.add(bp.Booking__c);
           // if (bp.Unit__c != null) unitIds.add(bp.Unit__c);
        }
      //  System.debug('bookingIds = '+bookingIds);
       // System.debug('unitIds = '+unitIds);
        System.debug('businessProcessMap = '+businessProcessMap);
        System.debug('processFlowIds = '+processFlowIds);
        if (processFlowIds.isEmpty()) return;
        
        
        Set<Id> processFlowStepIds = new Set<Id>();
        Map<String, Process_Flow_Step__c> pfsKeyToPfsMap = new Map<String, Process_Flow_Step__c>();
        for (Process_Flow_Step__c pfs : [ SELECT Id, Step_Name__c, Process_Flow__c FROM Process_Flow_Step__c  WHERE Process_Flow__c IN :processFlowIds AND Step_Name__c IN :stepNames ]) {
            String key = pfs.Process_Flow__c + '__' + pfs.Step_Name__c;
            pfsKeyToPfsMap.put(key, pfs);
            processFlowStepIds.add(pfs.Id);
        }
        if (processFlowStepIds.isEmpty()) return;
        
        
        List<Automation_Update__c> mandatoryFields = [ SELECT Id, Field_API_Name__c, Field_Value__c, Object_Api_Name__c, Process_Flow_Step__c,Status_Field_Value__c FROM Automation_Update__c WHERE Process_Flow_Step__c IN :processFlowStepIds AND Status_Field_Value__c IN: status ];
        if (mandatoryFields.isEmpty()) return;
        
        
        Map<Id, List<Automation_Update__c>> pfsIdToMandatoriesMap = new Map<Id, List<Automation_Update__c>>();        
        for (Automation_Update__c mf : mandatoryFields) {
            System.debug('mf = '+mf);
            if (!pfsIdToMandatoriesMap.containsKey(mf.Process_Flow_Step__c))
                pfsIdToMandatoriesMap.put(mf.Process_Flow_Step__c, new List<Automation_Update__c>());
            pfsIdToMandatoriesMap.get(mf.Process_Flow_Step__c).add(mf);
        }
        
        
       // Map<Id, Booking__c> bookingsToUpdate = new Map<Id, Booking__c>();
       // Map<Id, Unit__c> unitsToUpdate = new Map<Id, Unit__c>();
        Map<Id, Business_Process__c> businessProcessesToUpdate = new Map<Id, Business_Process__c>();
        Map<Id, Business_Process_Step__c> stepsToUpdate = new Map<Id, Business_Process_Step__c>();
        
        
        for (Business_Process_Step__c newStep : (List<Business_Process_Step__c>) newList) {
            
            if(stepIds.contains(newStep.Id)){
                System.debug('contains');
                String key = businessProcessMap.get(newStep.Business_Process__c).Process_Flow__c + '__' + newStep.Name;
                System.debug('key = '+key);
                if (!pfsKeyToPfsMap.containsKey(key)) continue;
                
                Process_Flow_Step__c pfs = pfsKeyToPfsMap.get(key);
                List<Automation_Update__c> mandatories = pfsIdToMandatoriesMap.get(pfs.Id);
                System.debug('mandatories = '+mandatories);
                if (mandatories == null || mandatories.isEmpty()) continue;
                
                Business_Process__c bp = businessProcessMap.get(newStep.Business_Process__c);
                
                for (Automation_Update__c mf : mandatories) {
                    String objApi = mf.Object_Api_Name__c;
                    String fieldApi = mf.Field_API_Name__c;
                    String stepStatus = mf.Status_Field_Value__c;
                    Object fieldValue = mf.Field_Value__c;
                    System.debug(' objApi = '+objApi +' ---- fieldApi = '+fieldApi + ' --- fieldValue = '+fieldValue);
                    
                    // Skip if no value to populate - check for null instead of String.isBlank
                    if (fieldValue == null) continue;
                    
                    try {
                        // Convert fieldValue to appropriate type based on the field's schema
                        Schema.DescribeFieldResult fieldDescribe = getFieldDescribe(objApi, fieldApi);
                        Object typedValue = convertToAppropriateType(fieldValue, fieldDescribe);
                        
                        if (typedValue == null) continue; // Skip if conversion failed
                        /*
                        if (objApi == 'Booking__c' && bp.Booking__c != null) {
                            if (!bookingsToUpdate.containsKey(bp.Booking__c)) {
                                bookingsToUpdate.put(bp.Booking__c, new Booking__c(Id = bp.Booking__c));
                            }
                            if(newStep.status__c == stepStatus )
                            bookingsToUpdate.get(bp.Booking__c).put(fieldApi, typedValue);
                            System.debug('bookingsToUpdate = '+bookingsToUpdate);
                        } else if (objApi == 'Unit__c' && bp.Unit__c != null) {
                            if (!unitsToUpdate.containsKey(bp.Unit__c)) {
                                unitsToUpdate.put(bp.Unit__c, new Unit__c(Id = bp.Unit__c));
                            }
                            if(newStep.status__c == stepStatus )
                            unitsToUpdate.get(bp.Unit__c).put(fieldApi, typedValue);
                            
                        } else */ if (objApi == 'Business_Process__c') {
                            if (!businessProcessesToUpdate.containsKey(bp.Id)) {
                                businessProcessesToUpdate.put(bp.Id, new Business_Process__c(Id = bp.Id));
                            }
                            if(newStep.status__c == stepStatus )
                            businessProcessesToUpdate.get(bp.Id).put(fieldApi, typedValue);
                            System.debug('businessProcessesToUpdate = '+businessProcessesToUpdate);
                        } else if (objApi == 'Business_Process_Step__c') {
                            if (!stepsToUpdate.containsKey(newStep.Id)) {
                                stepsToUpdate.put(newStep.Id, newStep);
                            }
                            if(newStep.status__c == stepStatus )
                            stepsToUpdate.get(newStep.Id).put(fieldApi, typedValue);
                        }//End
                        System.debug('tttt');
                    } catch (Exception e) {
                        System.debug('Error populating field ' + fieldApi + ' on ' + objApi + ': ' + e.getMessage());
                    }
                }
            }
        }
        
        List<SObject> allUpdates = new List<SObject>();
        
       // System.debug('bookingsToUpdate = '+bookingsToUpdate);
       // System.debug('unitsToUpdate = '+unitsToUpdate);
       // System.debug('businessProcessesToUpdate = '+businessProcessesToUpdate);
       /// if (!bookingsToUpdate.isEmpty()) allUpdates.addAll(bookingsToUpdate.values());
       // if (!unitsToUpdate.isEmpty()) allUpdates.addAll(unitsToUpdate.values());
        if (!businessProcessesToUpdate.isEmpty()) allUpdates.addAll(businessProcessesToUpdate.values());
        
        System.debug('allUpdates = '+allUpdates);
        if (!allUpdates.isEmpty()) {
            update allUpdates;
        }
    }
    
    
    
    
    
    private static Schema.DescribeFieldResult getFieldDescribe(String objectApiName, String fieldApiName) {
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            if (objType != null) {
                Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
                Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
                if (fieldMap.containsKey(fieldApiName)) {
                    return fieldMap.get(fieldApiName).getDescribe();
                }
            }
        } catch (Exception e) {
            System.debug('Error getting field describe for ' + objectApiName + '.' + fieldApiName + ': ' + e.getMessage());
        }
        return null;
    }
    
    // method to convert field value to appropriate type
    private static Object convertToAppropriateType(Object fieldValue, Schema.DescribeFieldResult fieldDescribe) {
        if (fieldDescribe == null || fieldValue == null) {
            return fieldValue;
        }
        
        Schema.DisplayType fieldType = fieldDescribe.getType();
        String stringValue = String.valueOf(fieldValue);
        
        try {
            switch on fieldType {
                when BOOLEAN {
                    if (fieldValue instanceof Boolean) {
                        return fieldValue;
                    }
                    return Boolean.valueOf(fieldValue);
                }
                when INTEGER {
                    if (fieldValue instanceof Integer) {
                        return fieldValue;
                    }
                    return Integer.valueOf(fieldValue);
                }
                when DOUBLE, CURRENCY, PERCENT {
                    if (fieldValue instanceof Decimal) {
                        return fieldValue;
                    }
                    if (fieldValue instanceof Double) {
                        return Decimal.valueOf((Double)fieldValue);
                    }
                    return Decimal.valueOf(stringValue);
                }
                when DATE {
                    if (fieldValue instanceof Date) {
                        return fieldValue;
                    }
                    return Date.valueOf(stringValue);
                }
                when DATETIME {
                    if (fieldValue instanceof Datetime) {
                        return fieldValue;
                    }
                    return Datetime.valueOf(stringValue);
                }
                when STRING, TEXTAREA, PICKLIST, PHONE, EMAIL, URL, ID {
                    return String.valueOf(fieldValue);
                }
                when else {
                    return String.valueOf(fieldValue);
                }
            }
        } catch (Exception e) {
            System.debug('Error converting value ' + fieldValue + ' to type ' + fieldType + ': ' + e.getMessage());
            return null;
        }
    }
    
}