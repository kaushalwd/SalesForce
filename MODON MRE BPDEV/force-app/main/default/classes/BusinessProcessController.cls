/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
* 2.0           sivannaryana.p@modon.com     20-07-2026      Default Process Changes 
**********************************************************************************************************************/
public without sharing class BusinessProcessController {
    
    public class SubItem {
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Status;
        @AuraEnabled public String AssignedTo;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String AssignedName;
        @AuraEnabled public Boolean isCheckList;
        @AuraEnabled public String parentId;
        @AuraEnabled public String currentCheckListItem;
     //   @AuraEnabled public Boolean isNextSectionAvailable;
      //  @AuraEnabled public String processIdenOptions;
      //  @AuraEnabled public Boolean formRendering;
      //  @AuraEnabled public Boolean fieldRendering;
        @AuraEnabled public Boolean ChooseNextOwner;
        @AuraEnabled public Boolean isRejectButtonRequired;
        @AuraEnabled public Boolean isRequiredInfoButtonRequired;
     //   @AuraEnabled public Boolean isSubmittoNextDeptRequired; 
        @AuraEnabled public Boolean isReviewCommentsReq;
        @AuraEnabled public Boolean viewReviewComments;
        @AuraEnabled public Boolean canViewReviewComments;
        @AuraEnabled public Boolean isAssinedTO;
        @AuraEnabled public String processFlowStep; 
        @AuraEnabled public String stepDesc; 
        @AuraEnabled public Boolean isMultiStepSelect; 
        @AuraEnabled public String ownerId; 
    }
    
    public class ParentItem {
        @AuraEnabled public String Id; // Will use Section_Number__c as ID
        @AuraEnabled public String Name; // Will use Section_Name__c
        @AuraEnabled public List<SubItem> subItems;
        @AuraEnabled public String businessProcessName;
    }
    
    @AuraEnabled
public static List<ParentItem> getBusinessProcessSteps(String recordId) {

    System.debug('getBusinessProcessSteps recordId => ' + recordId);

    List<Business_Process_Step__c> steps = [SELECT Id, Name,/*Process_Flow_Step__r.step_Description__c,*/ Status__c, Section_Number__c,OwnerId, Section_Name__c, Assigned_To__c, Assigned_To__r.Name, Owner.Name, Is_check_List__c, Choose_Next_Owner__c, Is_Reject_Button_Required__c, Is_Required_More_Button_Required__c, Is_Review_Comments_Req__c, View_review_comments__c, Is_Assigned_TO__c, Process_Flow_Step__c, Is_Multi_Select_Reopen__c, Business_Process__c, Business_Process__r.Latest_Process_Checklist__c, Business_Process__r.Process_Flow__r.Name FROM Business_Process_Step__c WHERE Section_Number__c != null AND Section_Name__c != null AND Business_Process__c = :recordId ORDER BY Section_Number__c, Sequence__c, Name];


    List<Reviewer_Comment__c> reComms = [
        SELECT Id
        FROM Reviewer_Comment__c
        WHERE Business_Process__c = :recordId
    ];

    Map<String, ParentItem> groupedMap = new Map<String, ParentItem>();

    for (Business_Process_Step__c step : steps) {

        String groupKey = step.Section_Number__c + '-' + step.Section_Name__c;

        if (!groupedMap.containsKey(groupKey)) {
            ParentItem pi = new ParentItem();
            pi.Id = groupKey;
            pi.Name = step.Section_Name__c;
            pi.subItems = new List<SubItem>();
            pi.businessProcessName = step.Business_Process__r.Process_Flow__r.Name;
            groupedMap.put(groupKey, pi);
        }

        SubItem si = new SubItem();
        si.Id = step.Id;
        si.Name = step.Name;
        si.Status = step.Status__c;

        // KEY FIELDS FOR UI FILTERING
        si.AssignedTo   = step.Assigned_To__c;
        si.AssignedName = step.Assigned_To__r != null ? step.Assigned_To__r.Name : null;

        si.ownerName = step.Owner != null ? step.Owner.Name : null;
        si.ownerId = step.OwnerId;
        si.isCheckList = step.Is_check_List__c;
        si.parentId = step.Business_Process__c;
        si.currentCheckListItem = step.Business_Process__r.Latest_Process_Checklist__c;
       // si.isNextSectionAvailable = step.Is_Sequence_Business_Process_Available__c;
       // si.processIdenOptions = step.Process_Identifier_Options__c;
       // si.formRendering = step.Form_Rendering__c;
       // si.fieldRendering = step.Field_Rendering__c;
        si.ChooseNextOwner = step.Choose_Next_Owner__c;
        si.isRejectButtonRequired = step.Is_Reject_Button_Required__c;
        si.isRequiredInfoButtonRequired = step.Is_Required_More_Button_Required__c;
       // si.isSubmittoNextDeptRequired = step.Is_Submit_to_Next_Department_Required__c;
        si.isReviewCommentsReq = step.Is_Review_Comments_Req__c;
        si.isAssinedTO = step.Is_Assigned_TO__c;
        si.viewReviewComments =
            step.View_review_comments__c && !reComms.isEmpty();
        si.canViewReviewComments = step.View_review_comments__c;
        si.processFlowStep = step.Process_Flow_Step__c;
      /*  si.stepDesc=step.Process_Flow_Step__r.step_Description__c;*/
        si.isMultiStepSelect = step.Is_Multi_Select_Reopen__c;

        groupedMap.get(groupKey).subItems.add(si);
    }

    return new List<ParentItem>(groupedMap.values());
}

    
    
    
    @AuraEnabled
    public static Business_Process_Step__c assignStepToCurrentUser(Id stepId) {
        if (String.isBlank(stepId)) {
            throw new AuraHandledException('Step Id is required.');
        }
        
        //Need to handile
        if (true) {
            //  throw new AuraHandledException('You are not eligible to accept this step');
        }
        
        Business_Process_Step__c step =new Business_Process_Step__c();
        step.Assigned_To__c = UserInfo.getUserId();
        step.Status__c='Accepted';
        step.Id=stepId;
        update step;
        List<Business_Process_Step__c> businessStepList= [SELECT Id,Name,Business_Process__c, Business_Process__r.Latest_Process_Checklist__c,Business_Process__r.Name,/*Business_Process__r.Booking__c*/Business_Process__r.Process_Flow__r.Name FROM Business_Process_Step__c WHERE Id = :stepId AND ( Name='SPA Maker Verification' OR (Name='Development - Providing Complete Project Details' AND Business_Process__r.Process_Flow__r.Name = 'SPA Execution') )];
        if(!businessStepList.isEmpty() &&  businessStepList[0].Business_Process__r.Latest_Process_Checklist__c == null && businessStepList[0].Business_Process__r.Process_Flow__r.Name == 'SPA Execution' && businessStepList[0].Name == 'Development - Providing Complete Project Details' ) {
            DisplayProcessChecklistItemController.createProcessChecklist('SPA Execution', businessStepList[0].Business_Process__c);
        }
         Business_Process_Step__c stepData=[select Id, Name, Business_Process__c from Business_Process_Step__c where Id=:stepId  LIMIT 1];
           if(stepData.Name=='Collections Customer Negotiations' || stepData.Name=='Collections Customer Engagement' ){
        BusinessProcessStepController.assignTasks( new Set<Id>{stepData.Business_Process__c}, UserInfo.getUserId());
           }
           if(stepData.Name=='Default 2 Notice Approval')
        BusinessProcessNintexDocumentGeneration.generateDocumentAsync(stepData.Id,stepData.Business_Process__c, 'Default_Termination_Notice' );    
    
        return step;   
    }
    
    @AuraEnabled
    public static Boolean isCheckListProvided(String parentId) { 
        Process_Checklist__c  processCheckList= [select Id,Is_Maker_Review_Completed__c from Process_Checklist__c where Business_Process__c =:parentId order by CreatedDate DESC limit 1];
        List<Process_Checklist_Items__c> itemList=   [
            SELECT Id, Name, Maker_Action__c, Checker_Action__c,
            Maker_Comments__c, Checker_Comments__c,
            Process_Checklist__r.Is_Maker_Review_Completed__c,
            Process_Checklist__r.Is_Checker_Review_Completed__c,
            Checker_Rejection_Reasons__c, Process_Checklist__c
            FROM Process_Checklist_Items__c
            WHERE Process_Checklist__c =: processCheckList.ID
        ];
        
        if(!processCheckList.Is_Maker_Review_Completed__c){   
            for(Process_Checklist_Items__c item:itemList){
                if(item.Maker_Action__c=='No Action' ){
                    return false;
                }
                
            }    
        } else {
            for(Process_Checklist_Items__c item:itemList){
                if(item.Checker_Action__c=='No Action' ){
                    return false;
                }  
            }
            
        } 
        return true;  
    }   
}