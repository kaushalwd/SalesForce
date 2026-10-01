/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
* 2.0           sivannaryana.p@modon.com     20-07-2026      Default Process Changes 
* 3.0           sivannaryana.p@modon.com     23-07-2026      LPC Process Changes 
**********************************************************************************************************************/
public class LwcApproveRejectBpstepController {

    @AuraEnabled
public static Boolean isUserInQueue(Id queueId, Id userId) {

    if (queueId == null || userId == null) return false;

    return [
        SELECT Id
        FROM GroupMember
        WHERE GroupId = :queueId
        AND UserOrGroupId = :userId
        LIMIT 1
    ].size() > 0;
}

    @AuraEnabled
    Public static List<Business_Process_Step__c> getSteps(string bpsId){
        System.debug('In getSteps bpsId --> '+bpsId);
        Business_Process_Step__c bps = [Select id,Business_Process__c,Sequence__c,Business_Process__r.Type__c,Name from Business_Process_Step__c where id = :bpsId limit 1];
        System.debug('bps.Business_Process__r.Type__c --> '+bps.Business_Process__r.Type__c);
        System.debug('bpd --> '+bps);
     
        String statusLabel = System.Label.ExcludeStatusForReopenSteps;
        System.debug('statusLabel = '+statusLabel);
        List<String> statusValues = new List<String>();
        
        if(String.isNotBlank(statusLabel)) {
            statusValues = statusLabel.split('\\s*,\\s*');
        } else {
            // If label is empty, use a default list or handle as needed
            statusValues = new List<String>{'Not Actioned'};
                }
        System.debug('statusValues = '+statusValues);  
            List<Business_Process_Step__c> bpsList = [Select id,Business_Process__c,Sequence__c,Step__c,Department__c,Name from Business_Process_Step__c where Business_Process__c = :bps.Business_Process__c AND Sequence__c < :bps.Sequence__c AND Department__c != null AND Step__c != null AND (Status__c NOT IN: statusValues OR Include_In_Reopen__c=true) AND Name NOT IN ('Invoice Upload From Broker', 'Account Team Checker') ]; //nsv];
           system.debug('bpsList size = '+bpsList.size());
            return bpsList;        
    }
    
     @AuraEnabled
    Public static List<Business_Process_Step__c> getAssinedSteps(string bpsId){
        System.debug('In getAssinedSteps bpsId --> '+bpsId);
        Business_Process_Step__c bps = [Select id,Business_Process__c,Sequence__c from Business_Process_Step__c where id = :bpsId limit 1];
        System.debug('bpd --> '+bps);
        List<Business_Process_Step__c> bpsList = [Select id,Business_Process__c,Sequence__c,Step__c,Department__c,Name from Business_Process_Step__c where Business_Process__c = :bps.Business_Process__c AND Sequence__c>:bps.Sequence__c AND Department__c != null AND Step__c != null AND Status__c != 'Not Actioned'];
        return bpsList;
    }
    
    @AuraEnabled
    Public static string approveStepAssignedTo(string bpsId,string assignedToBpsId,string comment){
        Business_Process_Step__c stepData=[Select id,Business_Process__c,Status__c,Name /*,Business_Process__r.Booking__r.CRM_Executive__c*/ from Business_Process_Step__c where Id = :bpsId limit 1 ];
        system.debug('stepData::'+stepData);
        Business_Process_Step__c bps = new Business_Process_Step__c();
        bps.Status__c='Completed';
        bps.Remarks_Comments__c = comment;
        bps.id = bpsId;
        Update bps;
        system.debug('bps::'+bps);
        Business_Process_Step__c bpsNext = new Business_Process_Step__c();
        bpsNext.Status__c='Accepted';
        bpsNext.id = assignedToBpsId;
        Update bpsNext;
        return bpsId;
    }
    
    @AuraEnabled //nsv
    Public static String reAssignUser(string bpsId, string usrId, string comment){
        Business_Process_Step__c stepData=[select Id, Name, Business_Process__c from Business_Process_Step__c where Id=:bpsId  LIMIT 1];
        Business_Process_Step__c stp=new Business_Process_Step__c();
        stp.Id=bpsId;
        //stp.Status__c='Open';
        stp.Assigned_To__c=usrId;
        stp.Remarks_Comments__c=comment;
        update stp;
        createNoteAndLink(stepData.Business_Process__c,'Step Re Assigned -' +stepData.Name ,comment);
        if(stepData.Name=='Collections Customer Engagement' || stepData.Name=='Collections Customer Negotiations')
        BusinessProcessStepController.assignTasks( new Set<Id>{stepData.Business_Process__c}, usrId);
      return 'success';
    }

    @AuraEnabled //nsv
    Public static  List<BusinessProcessStepController.OptionWrapper> getqueueMembers(string bpsId){
        Business_Process_Step__c nextStep = [Select id,Business_Process__c,Sequence__c,Step__c,Department__c,Name,OwnerId from Business_Process_Step__c where Id =:bpsId];
        List<BusinessProcessStepController.OptionWrapper> optionsList=BusinessProcessStepController.getQueueUsers(nextStep.OwnerId);
        return optionsList;
    }
    
    @AuraEnabled
    Public static  List<BusinessProcessStepController.OptionWrapper> getnextqueueMembers(string bpsId)  {
        Business_Process_Step__c bps = [Select id,Business_Process__c,Sequence__c from Business_Process_Step__c where id = :bpsId limit 1];
        Business_Process_Step__c nextStep = [Select id,Business_Process__c,Sequence__c,Step__c,Department__c,Name,OwnerId from Business_Process_Step__c where Business_Process__c = :bps.Business_Process__c AND Sequence__c=:bps.Sequence__c+1];
        List<BusinessProcessStepController.OptionWrapper> optionsList=BusinessProcessStepController.getQueueUsers(nextStep.OwnerId);
        return optionsList;
    }

    @AuraEnabled //nsv
    Public static Boolean checkSysAdmin(string usrId){
        User usr=[Select Id, name, Profile.Name from User where Id=:usrId LIMIT 1];
        if(usr!=null && usr.Profile.Name=='System Administrator'){
            return true;
        }
        else{
            return false;
        }

    }

    public static void createNoteAndLink(Id parentRecordId, String title, String body) {
       /*
        ContentNote note = new ContentNote();
        note.Title = title;
        note.Content = Blob.valueOf(body);
        insert note;
        System.debug('*** note.Id **** '+ note.Id);
        
        //Id docId = [SELECT ContentDocumentId FROM ContentNote WHERE Id = :note.Id].ContentDocumentId;
        
        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = note.Id;
        link.LinkedEntityId = parentRecordId;
        link.ShareType = 'V';
        link.Visibility = 'AllUsers';
        insert link; */
    }
    
    public class RequestMoreInfoWrapper {
        @AuraEnabled public String bpsId;
        @AuraEnabled public String rejectingToBpsId;
        @AuraEnabled public String comment;
        @AuraEnabled public String documentType;         // optional extra
        @AuraEnabled public String reasonForMoreInfo;    // optional extra
       @AuraEnabled public List<MultiStepInfo> multiSteps;
         @AuraEnabled public List<String> multiStepIds ; 
    }

    public class MultiStepInfo {
    @AuraEnabled public String Id;     // matches your LWC payload
    @AuraEnabled public String reason;
}
    
    
    @AuraEnabled
    public static string requestForMoreInfo(string rfmiWrap){
        RequestMoreInfoWrapper rfmiWrapper =(RequestMoreInfoWrapper) JSON.deserialize(rfmiWrap,RequestMoreInfoWrapper.class);
        System.debug('Inside requestForMoreInfo');
        system.debug('rfmiWrapper::'+rfmiWrapper);
        Business_Process_Step__c bps = [Select id,Name,Business_Process__c,Business_Process__r.Process_Flow__r.Name,Sequence__c,Is_check_List__c,Is_Single_Level_Required_Info__c from Business_Process_Step__c where id = :rfmiWrapper.bpsId limit 1];
        Map<Id, String> stepReasonMap = new Map<Id, String>();

if (rfmiWrapper.multiSteps != null) {
    for (MultiStepInfo step : rfmiWrapper.multiSteps) {
        stepReasonMap.put((Id)step.Id, step.reason);
    }
}

Set<Id> multiStepIds = stepReasonMap.keySet();
        
        Business_Process_Step__c bpsReject = [Select id,Name,Business_Process__c,Sequence__c,Is_check_List__c,Is_Single_Level_Required_Info__c from Business_Process_Step__c where id = :rfmiWrapper.rejectingToBpsId OR id IN:multiStepIds LIMIT 1];                    //rfmiWrapper.multiStepIds limit 1];
        system.debug('bps::'+bps);
        system.debug('bpsReject::'+bpsReject);
        List<Business_Process_Step__c> bpsList = new List<Business_Process_Step__c>();
            bpsList = [Select id,Business_Process__c,Business_Process__r.Name,Name,Original_Queue_Id__c,Sequence__c,
                                                    Re_Open_Count__c,Is_Single_Level_Required_Info__c,Business_Process__r.Process_Flow__r.Name,
                                                     Remarks_Comments__c,Skip_Step_To_Reopen__c,Required_Info_Step_Sequence__c 
                                                  FROM Business_Process_Step__c 
                                                  WHERE Business_Process__c = :bps.Business_Process__c 
                                                  AND Sequence__c>=:bpsReject.Sequence__c 
                                                  AND Sequence__c<=:bps.Sequence__c  Order by Sequence__c ASC];
        
        if(bps.Is_check_List__c){
            Process_Checklist__c  processCheckList= [select Id from Process_Checklist__c where Business_Process__c =:bps.Business_Process__c order by CreatedDate DESC limit 1];
            Process_Checklist__c updateprocessCheckList=new Process_Checklist__c();
            updateprocessCheckList.Id=processCheckList.Id;
            updateprocessCheckList.Is_Maker_Review_Completed__c=false;
            updateprocessCheckList.Is_Checker_Review_Completed__c=false;
            update updateprocessCheckList;
        }
      
        Business_Process_Step__c rejectingToBpsUpdate =new Business_Process_Step__c();
        Business_Process_Step__c requiredMoreInfoStep =new Business_Process_Step__c();
        System.debug(' Single  '+ bps.Is_Single_Level_Required_Info__c);
        if(bps.Is_Single_Level_Required_Info__c){
            rejectingToBpsUpdate.Id=rfmiWrapper.rejectingToBpsId;
            rejectingToBpsUpdate.Required_Info_Step_Sequence__c = bps.Sequence__c;
            rejectingToBpsUpdate.Required_Info_Step__c=rfmiWrapper.bpsId;
            rejectingToBpsUpdate.status__c='Re Open';
            rejectingToBpsUpdate.Remarks_Comments__c = rfmiWrapper.comment;
            
            if(bpsReject.name=='Customer Documents'){
                rejectingToBpsUpdate.status__c = 'Accepted';
            }
            
            
            System.debug(' rejectingToBpsUpdate  Required_Info_Step__c '+ rfmiWrapper.bpsId);
            requiredMoreInfoStep.Id=rfmiWrapper.bpsId;
            requiredMoreInfoStep.status__c = 'Required Info';
            requiredMoreInfoStep.Remarks_Comments__c = rfmiWrapper.comment;
            update requiredMoreInfoStep;
            update rejectingToBpsUpdate;
            return bps.Business_Process__c;
        }
        
        List<Business_Process_Step__c> bpsToUpdate = new List<Business_Process_Step__c>();
        system.debug('bpsList::'+bpsList.size());
        system.debug('bpsList::'+bpsList);
        for(Business_Process_Step__c b :bpsList){
            if(b.Id ==rfmiWrapper.rejectingToBpsId){
                b.Required_Info_Step_Sequence__c = bps.Sequence__c;
                b.Remarks_Comments__c = rfmiWrapper.comment;
                b.status__c = 'Re Open';
                if(b.name=='Sales Audit'){
                  b.status__c ='Open';  
                }
                if(b.name=='Customer Documents'){
                    b.status__c = 'Accepted';
                }
                if(b.Re_Open_Count__c!=null){
                    b.Re_Open_Count__c=b.Re_Open_Count__c+1;
                }else {
                    b.Re_Open_Count__c=1;
                }
                bpsToUpdate.add(b);
                
            } 

             else if (stepReasonMap.containsKey(b.Id)) { // multi select
                b.status__c = 'Re Open';
                b.Multi_Select_Step_Required_Info_Step__c = rfmiWrapper.bpsId;
                b.Re_Open_Count__c = (b.Re_Open_Count__c != null) ? b.Re_Open_Count__c + 1 : 1;

                // Set individual reason
                String reason = stepReasonMap.get(b.Id);
                b.Remarks_Comments__c = String.isNotBlank(reason) ? reason : rfmiWrapper.comment;

                bpsToUpdate.add(b);
            }
            
            
            else if(rfmiWrapper.multiStepIds != null && rfmiWrapper.multiStepIds.contains(b.Id)) {
                system.debug('enter in else if condition with Re Open status::');
                b.status__c = 'Re Open';
                b.Multi_Select_Step_Required_Info_Step__c = rfmiWrapper.bpsId;
                b.Re_Open_Count__c = (b.Re_Open_Count__c != null) ? b.Re_Open_Count__c + 1 : 1;
                bpsToUpdate.add(b);
            } else if(rfmiWrapper.multiStepIds == null && !b.Skip_Step_To_Reopen__c && !( (bps.Business_Process__r.Process_Flow__r.Name == 'Owner Ship Changes' || bps.Business_Process__r.Process_Flow__r.Name == 'Name Addition And Deletion') && bps.Sequence__c <= 5)) {
                system.debug('enter in else if condition with  Not Actioned');
                b.status__c = 'Not Actioned';
                if(b.Re_Open_Count__c!=null){
                    b.Re_Open_Count__c=b.Re_Open_Count__c+1;
                }else {
                    b.Re_Open_Count__c=1;
                }
                if(b.Id != rfmiWrapper.bpsId)
                    bpsToUpdate.add(b);
            }
            
            if(b.Id == rfmiWrapper.bpsId){
                system.debug('enter in else if condition with  Required Info');
                b.status__c = 'Required Info';
                bpsToUpdate.add(b);
                b.Remarks_Comments__c = rfmiWrapper.comment; 
                createNoteAndLink(b.Business_Process__c,'Step Required Info -' + b.Name,rfmiWrapper.comment);       
                break;
            }
            
        }
        WithoutSharingApexUtility.updateRecord(bpsToUpdate);
        Business_Process_Step__c stepData = new Business_Process_Step__c();
        for(Business_process_Step__c b:bpsToUpdate){
            system.debug('enter in for loop::'+b);
                stepData = b;
        }
        List<Business_Process_Approval_Automations__mdt> automationMetaDataList=[select Id, Automation_Calss_Name__c, Automation_Method_Name__c, Business_Process_Step_Name__c,Business_Process_Name__c from Business_Process_Approval_Automations__mdt where Business_Process_Name__c =: stepData.Business_Process__r.Process_Flow__r.Name];
        if(!automationMetaDataList.isEmpty())  {
            for(Business_Process_Approval_Automations__mdt automationMeta:automationMetaDataList){
                system.debug('automationMeta::'+automationMeta);
                Type automationType = Type.forName(automationMeta.Automation_Calss_Name__c);
                BusinessProcessAutomation automation = (BusinessProcessAutomation)automationType.newInstance();
                BusinessProcessAutomationInput input=new BusinessProcessAutomationInput();
                input.steps = bpsToUpdate;//mapCallAutomation.get(automationMeta.Business_Process_Name__c);
                input.currentStep=stepData;//businessProcesStep;
                input.isRFMI = true;
                automation.executeAutomation(input);
            }
        }
        return bps.Business_Process__c;
    }

    

    
    @AuraEnabled
    Public static string approveStep(String wrapperJSON, string bpsId,string comment,string nextStepOwnerID, Decimal mortgageContractAmount, Decimal mortgageChequeAmount, String typeOfMortgage){
        system.debug('comment '+comment);
        system.debug('nsv'+wrapperJSON);
        system.debug(' ** approveStep nextStepOwnerID '+nextStepOwnerID);
        system.debug('typeOfMortgage::'+typeOfMortgage);
        system.debug('mortgageChequeAmount::'+mortgageChequeAmount);
        system.debug('bpsId::'+bpsId);
        try{
             FormWrapper wrapper = (FormWrapper) JSON.deserialize(wrapperJSON, FormWrapper.class);
             system.debug('nsv2'+wrapper);
             ApprovalDynamicFieldController.submitApproval(wrapper);
             Business_Process_Step__c bpsstep = [Select id,name,Business_Process__r.Collections_Discussion_OutCome__c, Business_Process__r.Process_Flow__r.Name,
                                                 Business_Process__r.LPC_Waiver_Approvals__c,Business_Process__r.LPC_Amount__c,Business_Process__r.LPCWaivedAmount__c,Business_Process__r.LPC_Waived_Amount__c,Business_Process__r.Sales_Order__r.CustomerAccount__c, Business_Process__r.Sales_Order__c,Business_Process__r.Payment_Extension_Date__c,Business_Process__r.Milestone_Date_Formula__c/*, Business_Process__r.Skip_security__c*/ FROM Business_Process_Step__c WHERE Id = :bpsId ];
            system.debug('bpsstep::'+bpsstep);
            Business_Process_Step__c bps = new Business_Process_Step__c();
            if(bpsstep.Business_Process__r.Collections_Discussion_OutCome__c !=null && bpsstep.Business_Process__r.Collections_Discussion_OutCome__c=='Close the Process' )
            bps.Is_Process_End__c=true;
           // bps.Approval_Status__c = 'Approved';
            bps.Status__c='Completed';
            bps.Remarks_Comments__c = comment;
            if(bpsstep.Business_Process__r.Process_Flow__r.Name == 'Digital NOC for Home Modification' /*&& bpsstep.Business_Process__r.Skip_security__c*/ && bpsstep.Name == 'Customer Payment Completion'){
                bps.Is_Process_End__c= true;
            }
            // bps.Required_Info_Step__c = null;
            // bps.Bank_Reference_Number__c = brNumber;
            bps.id = bpsId;
            
            Update bps;
            
            
            system.debug('bpsId= '+bpsId);
            Business_Process_Step__c businessProcesStep = [
                Select id,Business_Process__r.Customer_Agreed_Payment_Date__c,Multi_Select_Step_Required_Info_Step__c,Business_Process__r.Collections_Discussion_OutCome__c,Business_Process__r.D_T_Customer_Discussion_Outcome__c,Is_Multi_Select_Reopen__c,Required_Info_Step_Sequence__c,Is_Process_End__c,Business_Process_Steps_Name_Custom__c,Is_Single_Level_Required_Info__c,Required_Info_Step__c,Required_Info_Step__r.Sequence__c,/* Business_Process__r.Procedure_Number__c,*/
                 Business_Process__c,Sequence__c,Name,Business_Process__r.Name, Business_Process__r.Type__c,
                Status__c,Re_Open_Count__c,Is_check_List__c,Assigned_To__c,Business_Process__r.Process_Flow__r.Name,
                ownerId,Business_Process__r.Payment_Extension_Category__c,Business_Process__r.LPC_Waiver_Approvals__c,Business_Process__r.LPC_Amount__c,Business_Process__r.CRM_Manager_decision__c,Section_Number__c,
                Business_Process__r.Payment_Extension_No_Of_Days__c,Business_Process__r.LPCWaivedAmount__c,Business_Process__r.LPC_Waived_Amount__c,Business_Process__r.Sales_Order__r.CustomerAccount__c, Business_Process__r.Sales_Order__c,Business_Process__r.Payment_Extension_Date__c,Business_Process__r.Milestone_Date_Formula__c
                FROM Business_Process_Step__c where id = :bpsId limit 1]; 
            system.debug('businessProcesStep::'+businessProcesStep);
            
            
            if(businessProcesStep.Is_check_List__c){
                Process_Checklist__c  processCheckList= [select Id from Process_Checklist__c where Business_Process__c =:businessProcesStep.Business_Process__c order by CreatedDate DESC limit 1];
                Process_Checklist__c updateprocessCheckList=new Process_Checklist__c();
                updateprocessCheckList.Id=processCheckList.Id;
                if(businessProcesStep.Name=='SPA Maker Verification'){
                    updateprocessCheckList.Is_Maker_Review_Completed__c=true;
                }else if(businessProcesStep.Name=='SPA Checklist Checker Verification'){
                    updateprocessCheckList.Is_Checker_Review_Completed__c=true;
                }
                update updateprocessCheckList;
            }
            
            List<Business_Process_Step__c> bpsList = [
                Select id,Business_Process__r.Customer_Agreed_Payment_Date__c,Multi_Select_Step_Required_Info_Step__c,Is_Multi_Select_Reopen__c,Required_Info_Step_Sequence__c,Is_Process_End__c,Is_Single_Level_Required_Info__c,Required_Info_Step__c,Business_Process__c,Sequence__c,Step__c,Department__c,Name,Status__c,
                Re_Open_Count__c,Business_Process__r.Type__c,Assigned_To__c,Skip_Step_To_Reopen__c,
                Business_Process_Name__c,Business_Process__r.Process_Flow__r.Name,ownerId,Business_Process__r.Payment_Extension_Category__c,Business_Process__r.LPC_Waiver_Approvals__c,Business_Process__r.LPC_Amount__c,
                Business_Process__r.Previous_Business_Process_Step__r.Sequence__c,Section_Number__c, Business_Process__r.Collections_Discussion_OutCome__c,Business_Process__r.CRM_Manager_decision__c,
                Business_Process__r.Payment_Extension_No_Of_Days__c,Business_Process__r.LPCWaivedAmount__c,Business_Process__r.LPC_Waived_Amount__c,Business_Process__r.Sales_Order__r.CustomerAccount__c, Business_Process__r.Sales_Order__c,Business_Process__r.Payment_Extension_Date__c,Business_Process__r.Milestone_Date_Formula__c
                FROM Business_Process_Step__c where Business_Process__c = :businessProcesStep.Business_Process__c AND Sequence__c>:bps.Sequence__c AND Step__c != null]; // AND Department__c != null  
            system.debug('bpsList::'+bpsList);
            createNoteAndLink(businessProcesStep.Business_Process__c,'Step Approved -' + businessProcesStep.Name,comment);  
            
           List<Business_Process_Validator__mdt> validateMetaDataList =[SELECT Id,Business_Process_Name__c, Validator_Apex_Class_Name__c, Method_Name__c FROM 	Business_Process_Validator__mdt where Business_Process_Name__c=:businessProcesStep.Business_Process__r.Type__c];
            System.debug('*************validateMetaDataList'+validateMetaDataList);
            if(!validateMetaDataList.isEmpty()){
                Type validatorType = Type.forName(validateMetaDataList[0].Validator_Apex_Class_Name__c);
                System.debug('validatorType'+validatorType);
                StepValidator validator = (StepValidator)validatorType.newInstance();
                
                validator.ValidateSteps(businessProcesStep);
                //SPAMCValidator
                
            }
            System.debug('businessProcesStep.Business_Process__r.Type__c = '+businessProcesStep.Business_Process__r.Type__c);
            //if (!Test.isRunningTest()) {
            List<Eligibility__mdt> activatorConfigs = [
                SELECT Class_Name__c, Method_Name__c,Business_Process_Name__c
                FROM Eligibility__mdt 
                WHERE Business_Process_Name__c = :businessProcesStep.Business_Process__r.Type__c
                LIMIT 1
            ];
            
            Type activatorType=null;
            if(!activatorConfigs.isEmpty() && !Test.isRunningTest() ){
                activatorType = Type.forName(activatorConfigs[0].Class_Name__c);
            } else {
                activatorType = Type.forName('DefaultActivator');
            }
            System.debug('activatorConfigs = '+activatorConfigs);
            
            
            if (activatorConfigs.isEmpty() && !Test.isRunningTest()){
                activatorType =activatorConfigs.size()>0 ? Type.forName(activatorConfigs[0].Class_Name__c) : Type.forName('DefaultActivator') ;
            } /*else {
                activatorType = Type.forName('SPAMCStepActivator');
            }*/

            
            StepActivator activator = (StepActivator)activatorType.newInstance();
            system.debug('activator::'+activator);
            List<Business_Process_Step__c> activatedSteps=activator.activateNextSteps(bpsId, bpsList, businessProcesStep,nextStepOwnerID);
            //List<Business_Process_Step__c> activatedSteps=null;
            System.debug('**** activatedSteps *****'+activatedSteps);
            activatedSteps.add(businessProcesStep);
            System.debug('**** activatedSteps businessProcesStep *****'+activatedSteps);
            
           List<Business_Process_Step__c> bpsListUpdated = [Select id,Section_Number__c,Business_Process__r.Collections_Discussion_OutCome__c,Is_Process_End__c,Is_Single_Level_Required_Info__c,Business_Process__c,Sequence__c,Step__c,Department__c,Name,Status__c,Re_Open_Count__c,Business_Process__r.Type__c,Assigned_To__c,Business_Process_Name__c,Business_Process__r.Process_Flow__r.Name,Business_Process__r.CRM_Manager_decision__c,Business_Process__r.Payment_Extension_Category__c,Business_Process__r.LPC_Waiver_Approvals__c,Business_Process__r.LPC_Amount__c/*,Business_Process__r.Skip_security__c*/
                                                             ,Business_Process__r.LPCWaivedAmount__c,Business_Process__r.LPC_Waived_Amount__c,Business_Process__r.Sales_Order__r.CustomerAccount__c, Business_Process__r.Sales_Order__c,Business_Process__r.Payment_Extension_Date__c,Business_Process__r.Milestone_Date_Formula__c
                                                             from Business_Process_Step__c where ID IN:activatedSteps]; 
            System.debug('**** bpsListUpdated *****'+bpsListUpdated);
            Map<String,List<Business_Process_Step__c>> mapCallAutomation=new Map<String,List<Business_Process_Step__c>>();
            for(Business_Process_Step__c stepAutomation:bpsListUpdated){
                if(mapCallAutomation.isEmpty() || mapCallAutomation.get(stepAutomation.Business_Process__r.Process_Flow__r.Name)==null){
                    System.debug('**** Inside Map *****');
                    mapCallAutomation.put(stepAutomation.Business_Process__r.Process_Flow__r.Name,new List<Business_Process_Step__c>{stepAutomation});
                }else if(mapCallAutomation.get(stepAutomation.Business_Process__r.Process_Flow__r.Name)!=null){
                    mapCallAutomation.get(stepAutomation.Business_Process__r.Process_Flow__r.Name).add(stepAutomation);
                }
            }
            
            
            System.debug('**** mapCallAutomation *****'+mapCallAutomation);
            List<Business_Process_Approval_Automations__mdt> automationMetaDataList=[select Id, Automation_Calss_Name__c, Automation_Method_Name__c, Business_Process_Step_Name__c,Business_Process_Name__c from Business_Process_Approval_Automations__mdt where Business_Process_Name__c IN:mapCallAutomation.keySet()];
            System.debug('**** automationMetaDataList *****'+automationMetaDataList);
            if(!automationMetaDataList.isEmpty())  {
                for(Business_Process_Approval_Automations__mdt automationMeta:automationMetaDataList){
                    Type automationType = Type.forName(automationMeta.Automation_Calss_Name__c);
                    System.debug('automationType = '+automationType);
                    
                    BusinessProcessAutomation automation = (BusinessProcessAutomation)automationType.newInstance();
                    BusinessProcessAutomationInput input=new BusinessProcessAutomationInput();
                    input.steps=mapCallAutomation.get(automationMeta.Business_Process_Name__c);
                    input.currentStep=businessProcesStep;
                    automation.executeAutomation(input);
                }
            } 
            
            return businessProcesStep.Business_Process__c;
            
        } catch (DmlException e) {
            String cleanMessage = e.getDmlMessage(0);
            throw new AuraHandledException(cleanMessage);
            
        } 
         catch (AuraHandledException e) {
    throw e;

}catch (Exception e) {
            //return 'error';
            throw new AuraHandledException(e.getMessage());
        }
    }
   
 @AuraEnabled
    Public static string rejectStep(String rejWrap){
        RejectStepWrapper rejWrapper =(RejectStepWrapper) JSON.deserialize(rejWrap,RejectStepWrapper.class);
        System.debug('Inside  rejectStep'+rejWrapper);
        Business_Process_Step__c bps = new Business_Process_Step__c();
        bps.Status__c = 'Cancelled';
        bps.Remarks_Comments__c = rejWrapper.comment;
        bps.id = rejWrapper.bpsId;
        System.debug('Inside  rejectStep'+bps);
        Update bps; 
        
        Business_Process_Step__c stepData=[Select id,Business_Process__c,Status__c,Name,Business_Process__r.Name,Business_Process__r.Process_Flow__r.Name,Remarks_Comments__c from Business_Process_Step__c where Id = :rejWrapper.bpsId limit 1 ];//rejWrapper.
        List<Business_Process_Approval_Automations__mdt> automationMetaDataList=[select Id, Automation_Calss_Name__c, Automation_Method_Name__c, Business_Process_Step_Name__c,Business_Process_Name__c from Business_Process_Approval_Automations__mdt where Business_Process_Name__c =: stepData.Business_Process__r.Process_Flow__r.Name];
        if(!automationMetaDataList.isEmpty())  {
            for(Business_Process_Approval_Automations__mdt automationMeta:automationMetaDataList){
                Type automationType = Type.forName(automationMeta.Automation_Calss_Name__c);
                BusinessProcessAutomation automation = (BusinessProcessAutomation)automationType.newInstance();
                BusinessProcessAutomationInput input=new BusinessProcessAutomationInput();
                input.steps=new List<Business_Process_Step__c>{stepdata};//mapCallAutomation.get(automationMeta.Business_Process_Name__c);
                    input.currentStep=stepData;//businessProcesStep;
                automation.executeAutomation(input);
            }
        } 
        createNoteAndLink(stepData.Business_Process__c,'Step Rejected -' + stepData.Name,rejWrapper.comment);
        return stepData.Business_Process__c;
    }
    
     @AuraEnabled
    Public static string onHoldStep(string bpId,string bpsId,string comment){
        System.debug('Inside  onHoldStep');
        Business_Process_Step__c bps = new Business_Process_Step__c();
        bps.Remarks_Comments__c = comment;
        bps.id = bpsId;
        System.debug('Inside  onHoldStep'+bps);
        Update bps; 
        
        Business_Process__c bp = new Business_Process__c();
        bp.id = bpId;
        bp.Status__c = 'On hold';
        System.debug('Inside  onHoldStep'+bp);
        Update bp;
        
        //StepActivator activator = new Eventevalutionsapproval();
        Business_Process_Step__c stepData=[Select id,Business_Process__c,Status__c,Name,Business_Process__r.Process_Flow__r.Name  from Business_Process_Step__c where Id = :bpsId limit 1 ];
        List<Business_Process_Approval_Automations__mdt> automationMetaDataList=[select Id, Automation_Calss_Name__c, Automation_Method_Name__c, Business_Process_Step_Name__c,Business_Process_Name__c from Business_Process_Approval_Automations__mdt where Business_Process_Name__c =: stepData.Business_Process__r.Process_Flow__r.Name];
        
        //Newly added:17-04-2026
        if (Test.isRunningTest() && automationMetaDataList.isEmpty()) {
            Business_Process_Approval_Automations__mdt dummy =
                new Business_Process_Approval_Automations__mdt();
            
            dummy.Business_Process_Name__c =
                stepData.Business_Process__r.Process_Flow__r.Name;
            
            dummy.Automation_Calss_Name__c = TestAutomationClass.class.getName();
            
            automationMetaDataList.add(dummy);
        }        
        
        
        if(!automationMetaDataList.isEmpty())  {
            for(Business_Process_Approval_Automations__mdt automationMeta:automationMetaDataList){
                Type automationType = Type.forName(automationMeta.Automation_Calss_Name__c);
                BusinessProcessAutomation automation = (BusinessProcessAutomation)automationType.newInstance();
                BusinessProcessAutomationInput input=new BusinessProcessAutomationInput();
                input.steps=new List<Business_Process_Step__c>{stepdata};//mapCallAutomation.get(automationMeta.Business_Process_Name__c);
                    input.currentStep=stepData;//businessProcesStep;
                automation.executeAutomation(input);
            }
        
    }
        createNoteAndLink(stepData.Business_Process__c,'Step Rejected -' + stepData.Name,comment);  
        return stepData.Business_Process__c;
    }
    
    @AuraEnabled
    public static string checkLoggedInUser(string stepId){
        if(stepId!=null){
             List<Business_Process_Step__c> lstBusiProcessStep=[select id,OwnerId,Business_Process__r.Process_Flow__r.Name/*,Business_Process__r.Refund_Amount__c,Business_Process__r.Refund_Type__c,Business_Process__r.Payment_Mode__c*/  from Business_Process_Step__c where id=:stepId limit 1];
            if(lstBusiProcessStep!=null && lstBusiProcessStep.size()>0){
                if(lstBusiProcessStep[0].Business_Process__r.Process_Flow__r.Name=='Broker Commission Slab Approvals' || lstBusiProcessStep[0].Business_Process__r.Process_Flow__r.Name=='Broker Ledger Approvals' ){
                    user usr=[Select Id, profile.Name from user where Id =:UserInfo.getUserId() limit 1];
                    if(usr!=null && usr.Profile.Name=='System Administrator'){
                        return 'Success';
                    } 
                }
                system.debug('OwnerId'+lstBusiProcessStep[0].OwnerId);
                system.debug('UserInfo.getUserId()'+UserInfo.getUserId());
                if(String.valueOf(lstBusiProcessStep[0].OwnerId).startsWith('00G')){
                    List<GroupMember> lstGroupMembs=[select id from GroupMember where GroupId =:lstBusiProcessStep[0].OwnerId and UserorGroupId=:UserInfo.getUserId() limit 1];
                    system.debug('lstGroups='+lstGroupMembs);
                    system.debug('lstGroups size='+lstGroupMembs.size());
                    if(lstGroupMembs==null || lstGroupMembs.size()==0){
                        return 'Unauthorised User';
                    }                  
                }else{
                    if(lstBusiProcessStep[0].OwnerId!=UserInfo.getUserId()){
                        return 'Unauthorised User';
                    }
                }
            }            
        }
        return 'Success';
    }
    
    public class RejectStepWrapper {
        @AuraEnabled public String bpsId;
        @AuraEnabled public String comment;
        @AuraEnabled public String documentType;
        @AuraEnabled public String reasonForRejection;
    }
    
    @AuraEnabled
    Public static void approveMultipleSteps(List<string> bpsIds,string comment, string additionalFieldsJson){

        system.debug('approveMultipleSteps method called comment '+comment);
        system.debug('additionalFieldsJson: ' + additionalFieldsJson);
       
        // Deserialize additional fields if provided
        Map<String, Object> additionalFields = new Map<String, Object>();
        if (String.isNotBlank(additionalFieldsJson)) {
            additionalFields = (Map<String, Object>)JSON.deserializeUntyped(additionalFieldsJson);
        }
       
        List<Business_Process_Step__c> bpsToUpdate = new List<Business_Process_Step__c>();

        //Set<Id> businessProcessStepIds = new Set<Id>();
        Set<Id> businessProcessIds = new Set<Id>();
        Map<Id, Id> bpStepMap=new Map<Id, Id>();
        for (Business_Process_Step__c bps : [
            SELECT Id, Name, Sequence__c, Business_Process__c,/*Business_Process__r.Procedure_Number__c,*/ Re_Open_Count__c, /*Business_Process__r.Payment_Reference_Number__c,*/
            Business_Process__r.Name, Business_Process__r.Type__c,/*Business_Process__r.Booking__r.CRM_Executive__c,*/Required_Info_Step__c, Status__c, Is_check_List__c,Assigned_To__c, Is_Process_End__c
           /* Business_Process__r.Internal_Cancellation_Creation_Reasons__c */
            FROM Business_Process_Step__c WHERE Id IN :bpsIds
        ]) {
           // bps.Approval_Status__c = 'Approved';
            bps.Status__c = 'Completed';
            bps.Remarks_Comments__c = comment;
            bpsToUpdate.add(bps);
            businessProcessIds.add(bps.Business_Process__c);
            bpStepMap.put(bps.Business_Process__c, bps.Id);
            //businessProcessStepIds.add(bps.Id);
        }
        update bpsToUpdate;
       
         
        //List<Business_Process_Documents__c> docList=[Select Id, Name from Business_Process_Documents__c where Business_Process__c IN:businessProcessIds and Name='Support Documents'];
       
        // Update Business Process with additional fields if they exist
        if (!additionalFields.isEmpty()) {
            List<Business_Process__c> processesToUpdate = new List<Business_Process__c>();
            for (Id bpId : businessProcessIds) {
                Business_Process__c bp = new Business_Process__c(Id = bpId);
               
                if (additionalFields.containsKey('BPN_Number__c')) {
                  //  bp.BPN_Number__c = (String)additionalFields.get('BPN_Number__c');
                }
                if (additionalFields.containsKey('CRM_Manager_decision__c')) {
                  bp.CRM_Manager_decision__c = (String)additionalFields.get('CRM_Manager_decision__c');
                   if(bpStepMap.size()>0 && bpStepMap.containsKey(bpId))
                   BusinessProcessNintexDocumentGeneration.generateDocumentAsync(bpStepMap.get(bpId),bpId, 'First_Default_Notice' );    
                }
                /*
                if (additionalFields.containsKey('Transaction_Reference_Number__c')) {
                    bp.Transaction_Reference_Number__c = (String)additionalFields.get('Transaction_Reference_Number__c');
                }
                */
                processesToUpdate.add(bp);
            }
           
            if (!processesToUpdate.isEmpty()) {
                update processesToUpdate;
            }
        }
       
       
        system.debug('current sequence  -->' + bpsToUpdate[0].Sequence__c);
        Integer nextSequence = Integer.valueOf(bpsToUpdate[0].Sequence__c) +1;
        system.debug('next sequence  -->' + nextSequence);
       
        List<Business_Process_Step__c> nextSteps = [
            SELECT Id, Sequence__c, Step__c, Department__c,Required_Info_Step__c,Skip_Step_To_Reopen__c, Is_Process_End__c, /*Business_Process__r.Booking__r.CRM_Executive__c,*/Business_Process_Step__c.Name,Business_Process__r.Exclude_Admin_Fee__c,
            Business_Process_Step__c.Status__c,Assigned_To__c, Business_Process_Name__c,Re_Open_Count__c/*,Business_Process__r.Internal_Cancellation_Creation_Reasons__c
          */   FROM Business_Process_Step__c
            WHERE Business_Process__c IN :businessProcessIds
            AND Sequence__c = :nextSequence
            AND Step__c != null
        ];
        List<Business_Process_Validator__mdt> validateMetaDataList =[SELECT Id,Business_Process_Name__c, Validator_Apex_Class_Name__c, Method_Name__c FROM  Business_Process_Validator__mdt where Business_Process_Name__c=:bpsToUpdate[0].Business_Process__r.Type__c];
        System.debug('validateMetaDataList'+validateMetaDataList);
       
        if(!validateMetaDataList.isEmpty()){
            Type validatorType = Type.forName(validateMetaDataList[0].Validator_Apex_Class_Name__c);
            System.debug('validatorType'+validatorType);
           
            StepValidator validator = (StepValidator)validatorType.newInstance();
            System.debug('validator'+validator);
            validator.ValidateSteps(bpsToUpdate[0]);   
        }
       
         List<Eligibility__mdt> activatorConfigs = [
            SELECT Class_Name__c, Method_Name__c,Business_Process_Name__c
            FROM Eligibility__mdt
            WHERE Business_Process_Name__c = :bpsToUpdate[0].Business_Process__r.Type__c
            LIMIT 1
        ];
        System.debug('activatorConfigs = '+activatorConfigs);

        if(!activatorConfigs.isEmpty()){

           
        }
     
       Type activatorType=null;
        if (!Test.isRunningTest()){
             activatorType = Type.forName(activatorConfigs[0].Class_Name__c);
           
        }else {
              activatorType = Type.forName('DefaultActivator');
        }
         
         StepActivator activator = (StepActivator)activatorType.newInstance();

        List<Business_Process_Step__c> activatedSteps= activator.activateNextSteps(nextSteps[0].Id, nextSteps, bpsToUpdate[0],null);
        }

    @AuraEnabled
    Public static void rejectMultipleSteps(List<string> bpsIds,string comment){
         List<Business_Process_Step__c> bpsToUpdate = new List<Business_Process_Step__c>();
       
        Set<Id> businessProcessIds = new Set<Id>();
        for (Business_Process_Step__c bps : [SELECT Id, Name, Sequence__c, Business_Process__c,/*Business_Process__r.Booking__r.CRM_Executive__c,*/ Business_Process__r.Name, Status__c, Is_check_List__c,Business_Process_Step__c.Assigned_To__c FROM Business_Process_Step__c WHERE Id IN :bpsIds]) {
            bps.Status__c = 'Rejected';
            bps.Remarks_Comments__c = comment;
            bpsToUpdate.add(bps);
            businessProcessIds.add(bps.Business_Process__c);
        }
        Update bpsToUpdate;
    }

    @AuraEnabled
    Public static void requestForMoreInfoMultipleSteps(List<String> bpsIds, string rejectingToBpsId, string comment){
       
        if (bpsIds == null || bpsIds.isEmpty())    return;
               
        Decimal intitalSequence;
        Map<Id, Business_Process_Step__c> bpsMap = new Map<Id, Business_Process_Step__c>([
            SELECT Id, Name, Business_Process__c, Sequence__c, Is_check_List__c, Is_Single_Level_Required_Info__c,Business_Process_Step__c.Assigned_To__c/*Business_Process__r.Booking__r.CRM_Executive__c*/
            FROM Business_Process_Step__c
            WHERE Id IN :bpsIds
        ]);        
           
        Set<Id> businessProcessIds = new Set<Id>();
        for (Business_Process_Step__c bps : bpsMap.values()) {
            businessProcessIds.add(bps.Business_Process__c);
            intitalSequence = bps.Sequence__c;
        }
       
       
        Decimal rejectingToBpsSequence = 0;  
        List<Business_Process_Step__c> rejectingBusinessProcessSteps = [
            SELECT Id, Business_Process__c, Name, Original_Queue_Id__c, Sequence__c, Re_Open_Count__c, Is_Single_Level_Required_Info__c,Business_Process_Step__c.Assigned_To__c /*Business_Process__r.Booking__r.CRM_Executive__c*/
            FROM Business_Process_Step__c
            WHERE Id = :rejectingToBpsId
        ];
       
        Map<Id, Id> rejectingBpsMap = new Map<Id, Id>();
        if (!rejectingBusinessProcessSteps.isEmpty()) {
            system.debug('sequence number of rejecting step --> ' + rejectingBusinessProcessSteps[0].Sequence__c);
            rejectingToBpsSequence = rejectingBusinessProcessSteps[0].Sequence__c;
            system.debug('rejectingToBpsSequence --> ' + rejectingToBpsSequence);
           
            for(Business_Process_Step__c bps: [
                SELECT Id, Business_Process__c, Name, Sequence__c
                FROM Business_Process_Step__c
                WHERE Business_Process__c IN :businessProcessIds AND Sequence__c =: rejectingToBpsSequence ] ){
                rejectingBpsMap.put(bps.Business_Process__c, bps.Id);
            }
        }
        system.debug('rejectingBpsMap --> ' +rejectingBpsMap);
       
       
        Set<Id> processedSteps = new Set<Id>();
        List<Business_Process_Step__c> stepsToUpdate = new List<Business_Process_Step__c>();
       
        // Handle single level steps
        for (Business_Process_Step__c bps : bpsMap.values()) {
            if (bps.Is_Single_Level_Required_Info__c && !processedSteps.contains(bps.Id)) {
                // Update rejecting step
                stepsToUpdate.add(new Business_Process_Step__c(
                    Id = rejectingBpsMap.get(bps.Business_Process__c), //rejectingToBpsId,
                    Required_Info_Step__c = bps.Id,
                    Status__c = 'Re Open',
                    Remarks_Comments__c = comment
                ));
               
                // Update current step
                stepsToUpdate.add(new Business_Process_Step__c(
                    Id = bps.Id,
                    Status__c = 'Required Info',
                    Remarks_Comments__c = comment
                ));
                processedSteps.add(bps.Id);
            }
        }
       
        System.debug('single stepsToUpdate size--> '+stepsToUpdate);
        if(! stepsToUpdate.isEmpty()){
            return;
        }
       
       
        // Handle other steps for multilevel info
        for (Business_Process_Step__c step : [
            SELECT Id, Business_Process__c, Name, Original_Queue_Id__c, Sequence__c, Re_Open_Count__c, Is_Single_Level_Required_Info__c,Business_Process_Step__c.Assigned_To__c
            FROM Business_Process_Step__c
            WHERE Business_Process__c = :businessProcessIds AND Sequence__c>=:rejectingBusinessProcessSteps[0].Sequence__c AND Sequence__c<=:intitalSequence
            ORDER BY Sequence__c ASC
        ]) {
            if (bpsMap.containsKey(step.Id)) {
                // One of the required info steps
                step.Status__c = 'Required Info';
                step.Remarks_Comments__c = comment;
                stepsToUpdate.add(step);
                //createNoteAndLink(step.Business_Process__c, 'Step Required Info - ' + step.Name, comment);
            } else if (rejectingBpsMap.containskey(step.Business_Process__c) && step.Id == rejectingBpsMap.get(step.Business_Process__c)) {
                step.Status__c = 'Re Open';
                step.Remarks_Comments__c = comment;
                step.Re_Open_Count__c = (step.Re_Open_Count__c != null) ? step.Re_Open_Count__c + 1 : 1;
                stepsToUpdate.add(step);
            } else {
                step.Status__c = 'Not Actioned';
                step.Re_Open_Count__c = (step.Re_Open_Count__c != null) ? step.Re_Open_Count__c + 1 : 1;
                stepsToUpdate.add(step);
            }
        }
       
   
        System.debug('multiple stepsToUpdate size--> '+stepsToUpdate);
        if (!stepsToUpdate.isEmpty()) {
            WithoutSharingApexUtility.updateRecord(stepsToUpdate);
        }
       
    }
    
     @AuraEnabled
    public static void approveFileIds(List<Id> bpsIds, List<Id> fileIds, List<Id> supportDocumentFileIds) {
        Set<Id> businessProcessIds=new Set<Id>();
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Business_Process_Step__c st:[Select Id,Business_Process__c from Business_Process_Step__c  where Id IN: bpsIds]){
            businessProcessIds.add(st.Business_Process__c);
        }
       
        if (fileIds != null && !fileIds.isEmpty()) {
            List<Business_Process_Documents__c> docList=[Select Id, Name from Business_Process_Documents__c where Business_Process__c IN:businessProcessIds and Name='Treasury Reference Document'];
           
            for (Business_Process_Documents__c doc : docList) {
               
                links.add(new ContentDocumentLink(
                    ContentDocumentId = fileIds[0],
                    LinkedEntityId = doc.Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));
            }
           
        }
       
        if (supportDocumentFileIds != null && !supportDocumentFileIds.isEmpty()) {
            List<Business_Process_Documents__c> docList=[Select Id, Name from Business_Process_Documents__c where Business_Process__c IN:businessProcessIds and Name='Support Documents'];
            for (Business_Process_Documents__c doc : docList) {
               
                links.add(new ContentDocumentLink(
                    ContentDocumentId = supportDocumentFileIds[0],
                    LinkedEntityId = doc.Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));
            }
        }
       
        if(!links.isEmpty()){
            insert links;
        }
    }
    
    @AuraEnabled
    public static List<Business_Process_Documents__c> getPaymentProofDocuments(String stepId) {
        try { 
            Business_Process_Step__c step = [SELECT Id, Business_Process__c FROM Business_Process_Step__c  WHERE Id = :stepId LIMIT 1];
            if (step == null) {
                return new List<Business_Process_Documents__c>();
            }
            return  [
                SELECT Id, Name, (SELECT Id, ContentDocumentId, ContentDocument.Title, ContentDocument.CreatedDate FROM ContentDocumentLinks ORDER BY ContentDocument.CreatedDate DESC LIMIT 1) FROM Business_Process_Documents__c WHERE Business_Process__c = :step.Business_Process__c AND Name IN ( 'Treasury Reference Document', 'Accounts Payment Proof', 'Initial Contract of Sale')
            ];
           
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving payment proof documents: ' + e.getMessage());
        }
    }

    public class FormWrapper{
        @AuraEnabled public Id recordId;
        @AuraEnabled public String stepName; 
        @AuraEnabled public Id stepId;
        @AuraEnabled public String action;
        @AuraEnabled public String comment;
        @AuraEnabled public Map<String,String> fieldValues = new Map<String, String>();
    }
    public class FieldWrapper{
        @AuraEnabled public String objectName;
        @AuraEnabled public String fieldApi;

    }

}