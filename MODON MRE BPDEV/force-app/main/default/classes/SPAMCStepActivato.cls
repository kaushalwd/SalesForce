public class SPAMCStepActivato {

    @AuraEnabled
    public static Map<String, Object> getChecklistItems(String recordId) {
    Map<String, Object> result = new Map<String, Object>();
    
    Process_Checklist__c processCheckList = [SELECT Id,/* Business_Process__r.Booking__c, Business_Process__r.Booking__r.Name, 
                                           Business_Process__r.Unit__c, Business_Process__r.Unit__r.Name, */
                                           Checklist_Metadata__r.Checklist_Name_in_short__c 
                                           FROM Process_Checklist__c 
                                           WHERE Business_Process__c = :recordId 
                                           ORDER BY CreatedDate DESC LIMIT 1];
    
    List<Process_Checklist_Items__c> items = [
        SELECT Id, Checklist_Name__c, Name, Maker_Action__c, Checker_Action__c,
               Maker_Comments__c, Checker_Comments__c,
               Process_Checklist__r.Is_Maker_Review_Completed__c,
               Process_Checklist__r.Is_Checker_Review_Completed__c,
               Checker_Rejection_Reasons__c, Maker_Rejection_Reasons__c, Process_Checklist__c
        FROM Process_Checklist_Items__c
        WHERE Process_Checklist__c = :processCheckList.Id ORDER BY Sequence__c
    ];
    
    result.put('checklistItems', items);
    result.put('checkListName', processCheckList.Checklist_Metadata__r.Checklist_Name_in_short__c  != null ?  processCheckList.Checklist_Metadata__r.Checklist_Name_in_short__c : '');
    // result.put('bookingId', processCheckList.Business_Process__r.Booking__c);
    //result.put('bookingName', processCheckList.Business_Process__r.Booking__c != null ? processCheckList.Business_Process__r.Booking__r.Name : '');
    // result.put('unitId', processCheckList.Business_Process__r.Unit__c);
   // result.put('unitName', processCheckList.Business_Process__r.Unit__c != null ?  processCheckList.Business_Process__r.Unit__r.Name: '');
    
    return result;
}

    /*@AuraEnabled
    public static List<Process_Checklist_Items__c> getChecklistItems(String recordId) {

       Process_Checklist__c  processCheckList= [select Id from Process_Checklist__c where Business_Process__c =:recordId order by CreatedDate DESC limit 1];
        return [
            SELECT Id, Checklist_Name__c, Name, Maker_Action__c, Checker_Action__c,
                   Maker_Comments__c, Checker_Comments__c,
                   Process_Checklist__r.Is_Maker_Review_Completed__c,
                   Process_Checklist__r.Is_Checker_Review_Completed__c,
                   Checker_Rejection_Reasons__c, Process_Checklist__c,Sequence__c
            FROM Process_Checklist_Items__c
            WHERE Process_Checklist__c =: processCheckList.ID ORDER BY Sequence__c
        ];
    }*/
    

    @AuraEnabled
    public static void updateChecklistItems(List<Process_Checklist_Items__c> items) {
        update items;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValuesForChecklist() {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        result.put('makerStatusOptions', getPicklist('Process_Checklist_Items__c', 'Maker_Action__c'));
        result.put('checkerStatusOptions', getPicklist('Process_Checklist_Items__c', 'Checker_Action__c'));
        result.put('rejectionReasonOptions', getPicklist('Process_Checklist_Items__c', 'Checker_Rejection_Reasons__c'));
        return result;
    }

    private static List<Map<String, String>> getPicklist(String sObjectName, String fieldName) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(sObjectName);
        Schema.DescribeFieldResult fieldResult = objType.getDescribe().fields.getMap().get(fieldName).getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            options.add(new Map<String, String>{
                'label' => entry.getLabel(),
                'value' => entry.getValue()
            });
        }
        return options;
    }
 

}