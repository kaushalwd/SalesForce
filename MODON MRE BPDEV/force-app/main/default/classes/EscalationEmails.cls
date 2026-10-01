/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class EscalationEmails {
   public class ResultWrapper {
        @InvocableVariable public String message;
        @InvocableVariable public String CCmsg;
    }
    
     public class InputParams {
        @InvocableVariable(required=true description='List of Ids')
        public string StepIds;
        
        @InvocableVariable(required=true description='Action')
        public String actionType;
         
          @InvocableVariable(required=true description='queueId')
        public String queueIds; 
    }
     @InvocableMethod(label='Send Escalation Emails')
    public static List<ResultWrapper> getEmails(List<InputParams> inputs ) {
         String finEmails='';
        String finCCEmails='';
         List<Id>  stepEscalationIds=new List<Id>();
        String actionType='';
        string queueId='';
          for (InputParams input : inputs) {
              
          stepEscalationIds.add(input.StepIds);
              actionType=input.actionType;
              queueId=input.queueIds;
          }
        String memEmails='';
        if(queueId!=null){
            List<GroupMember> member =[Select Id, UserOrGroup.Email, GroupId from GroupMember where GroupId=:queueId and UserOrGroup.IsActive=true];
            if(member.size()>0){
                for(GroupMember mem:member){
                 memEmails += (memEmails == '' ? '' : ',') + mem.UserOrGroup.Email;   
                } 
            }else{
                list<user> userList = [Select Id,name,email from user where Id=:queueId];
                if(userList.size() >0){
                    memEmails +=userList[0].email;
                }
            }
        }
      
        List<Business_Process_Step__c> stepList=[Select Id, remainder2__c, remainder3__c,remainderDate1__c, Assigned_To__c,
                                                OwnerId, Process_Flow_Step__c, Assigned_To__r.Manager.Email, Assigned_To__r.ManagerId from Business_Process_Step__c where Id IN:stepEscalationIds
                                                ];
        Set<Id> procStepIds=new Set<Id>();
        for(Business_Process_Step__c step:stepList){
            if(step.Process_Flow_Step__c!=null){
               procStepIds.add(step.Process_Flow_Step__c); 
            } 
        }
        Map<Id,List<Step_Escalation__c>> EscMap=new Map<Id,List<Step_Escalation__c>>();
       for(Step_Escalation__c Esc:[
            SELECT Id, Process_Flow_Step__c,BCC_Email__c, CC_Email__c, 
                   Department_Head__c, Vertical_Head__c, Trigger_To__c, Escalation_Trigger_Days__c
           FROM Step_Escalation__c WHERE Process_Flow_Step__c IN :procStepIds Order by Escalation_Trigger_Days__c ASC]) {
              if(EscMap.size()>0 && EscMap.containsKey(Esc.Process_Flow_Step__c)){
                  List<Step_Escalation__c> stpEscMap=EscMap.get(Esc.Process_Flow_Step__c);
                  stpEscMap.add(Esc);
                  EscMap.put(Esc.Process_Flow_Step__c,stpEscMap);  
                }  
                else{
                   List<Step_Escalation__c> stpEscMap=new List<Step_Escalation__c>();
                   stpEscMap.add(Esc); 
                   EscMap.put(Esc.Process_Flow_Step__c,stpEscMap);    
                }
           }
        
        for(Business_Process_Step__c step: stepList){
            String emailList = ''; 
            String ccList='';
            if(step.Process_Flow_Step__c!=null && EscMap.size()>0 && EscMap.containsKey(step.Process_Flow_Step__c) ){
               Step_Escalation__c es=EscMap.get(step.Process_Flow_Step__c)[Integer.ValueOf(actionType)];
                 List<String> triggerValues = new List<String>();
                if (es.Trigger_To__c != null) {
                   
                if (es.Trigger_To__c.contains(';')) {
                    triggerValues = es.Trigger_To__c.split(';');
                } else {
                    triggerValues.add(es.Trigger_To__c);
                }
                } 
                 for (String triggerVal : triggerValues) {
                    triggerVal = triggerVal.trim();

                    if (triggerVal.equalsIgnoreCase('Department Head') && es.Department_Head__c != null) {
                        emailList += (emailList == '' ? '' : ',') + es.Department_Head__c;
                    }
                    if (triggerVal.equalsIgnoreCase('Vertical Head') && es.Vertical_Head__c != null) {
                        emailList += (emailList == '' ? '' : ',') + es.Vertical_Head__c;
                    }
                    if (triggerVal.equalsIgnoreCase('CC Email') && es.CC_Email__c != null) {
                        ccList += (ccList == '' ? '' : ',') + es.CC_Email__c;
                    }
                    if (triggerVal.equalsIgnoreCase('BCC Email') && es.BCC_Email__c != null) {
                        ccList += (ccList == '' ? '' : ',') + es.BCC_Email__c;
                    }
                    if (triggerVal.equalsIgnoreCase('Assigned TO') && step.Assigned_To__c != null) {
                        emailList += (emailList == '' ? '' : ',') + step.Assigned_To__c;
                    }
                     if (triggerVal.equalsIgnoreCase('Assigned TO Manager') && step.Assigned_To__c != null && 
                        step.Assigned_To__r.ManagerId !=null && step.Assigned_To__r.Manager.Email !=null
                        ) {
                        emailList += (emailList == '' ? '' : ',') + step.Assigned_To__r.Manager.Email;
                    } 
                    if (/*triggerVal.equalsIgnoreCase('Queue') &&*/ memEmails != null && memEmails!='' ) {
                        emailList += (emailList == '' ? '' : ',') + memEmails;
                    }
                }
            }
         finEmails=emailList; 
         finCCEmails=ccList;   
        }
        
        system.debug(finEmails);
      List<ResultWrapper> results = new List<ResultWrapper>();
       ResultWrapper res=new ResultWrapper();
        res.message=finEmails;
        res.CCmsg=finCCEmails;
       results.add(res);
       return results;
        
           }
       
    }