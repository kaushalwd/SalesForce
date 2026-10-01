trigger CommissionLine on Commission_Line__c (after insert,after update) {
    if(Trigger.isInsert){
       CommissionLineReviewController.handleCommissionStsChange(Trigger.new, null);
    }
    if(Trigger.isUpdate){
     //   MBP_CommissionLineHelper.generateAndAttachPDF(Trigger.oldMap, Trigger.newMap);
     //   MBP_CommissionLineHelper.handleAfterUpdate(Trigger.oldMap, Trigger.newMap);
        CommissionLineReviewController.handleCommissionStsChange(Trigger.new,Trigger.oldMap);
    }
}