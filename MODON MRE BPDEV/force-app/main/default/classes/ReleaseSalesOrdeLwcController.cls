/**********************************************************************************************************************
* Name               : ReleaseSalesOrdeLwcController                                                        
* Description        : This class is used as controller for LWC (Release sales order action button on account)
* Usage              : release sales order LWC                                                          
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         09 Feb 2024      Initial Draft    
* 1.1           Manoj.vallapuneni@modon.com      24 Dec 2024     Update the Change as par of new status
* 1.2           MODON IT                         28-Oct-2025      Remove the "payments cancel dependency" for MODON-UAE
* 1.3           MODON CRM TEAM                   22 Dec 2025     Added cancellation reason & comments
* 1.4           MODON CRM TEAM                   11 Jun 2026     Mapped Sub Status
******************************************************************************************************************/
public without sharing class ReleaseSalesOrdeLwcController {
    public static Boolean bypassTrigger = false;
    @AuraEnabled
    public static String releaseSalesOrder(Id recordId, String cancellationReason, String comments){
        List<SalesOrder__c> soLst = [SELECT Id, Status__c, Unit__c, Unit__r.Source_Entity__c, Unit__r.OldStatus__c, Unit__r.Status_Change_Time__c, VirtualAccount__c,CancellationReason__c,Comments__c,Sub_Status__c FROM SalesOrder__c WHERE Id = : recordId];
        if(!soLst.isEmpty()){
            SalesOrder__c soObj = soLst[0];
            String sourceEntity = soLst[0].Unit__r.Source_Entity__c;
            if(soObj.Status__c.contains('Cancel')){
                return 'Sales order is already cancelled';
            }else{
                soObj.Status__c = 'Cancelled';
                //1.3
                //Start
                soObj.CancellationReason__c = cancellationReason;
                soObj.Comments__c = comments;
                //END
                //1.4
                //Start
                soObj.Sub_Status__c = '';
                //END
                Unit__c unitObj = new Unit__c();
                unitObj.Id = soObj.Unit__c;
                if(sourceEntity == 'Modon - egypt'){
                    unitObj.Status__c = 'Available'; // Default or other logic
                    unitObj.Sub_Status__c = 'Un-Assigned';
                    List<Receipt__c> recLst = [SELECT Id, Name FROM Receipt__c WHERE SalesOrder__c = :soObj.Id AND Status__c NOT IN ('Reversed','Cancelled','Rejected')];
                    if(!recLst.isEmpty() && recLst.size() > 0){
                        return 'Payment already exist for this sales order.';
                    }
                }else{
                    unitObj.Status__c = ''; // Default or other logic
                    unitObj.Sub_Status__c = '';
                }
                //unitObj.Status__c = ''; //Add Update the Change as par of new status
                unitObj.ApprovalStatus__c='Draft'; //Add Update the Change as par of new status
                //unitObj.Status__c = 'Available';
                //unitObj.Sub_Status__c='';
                unitObj.BlockedFor__c = null;
                unitObj.BlockedBy__c = null;
                unitObj.Opportunity__c = null;
                unitObj.BlockUntil__c = null;
                unitObj.Blocked_Time__c = null;
                //unitObj.Status_Change_Time__c = DATETIME.NOW();
                VirtualAccount__c vaObj = new VirtualAccount__c();
                vaObj.Id = soObj.VirtualAccount__c;
                vaObj.Status__c = 'Available';
                
                Savepoint sp = Database.setSavepoint();
                try{
                    if(String.isNotBlank(vaObj.Id)){
                        UPDATE vaObj;
                    }
                    
                    UPDATE soObj;
                    UPDATE unitObj;
                }catch(Exception ex){
                    Database.rollback(sp);
                    return 'There is some issue in releasing the unit. Please contact your system administrator.';
                }
                
            }
        }
        return 'Success';
    }
}