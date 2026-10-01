/**********************************************************************************************************************
* Name               : LeadTriggerSupportHelper                                                        
* Description        : Support class for LeadTriggerHelper
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           suresh                      19 Feb 2025     Initial Draft 
* 1.1           Activeminds                 19 Nov 2025     Added Lead Score and SMS
******************************************************************************************************************/
public without sharing class LeadTriggerSupportHelper {

   public static void initiateAIAgent(list<SObject> newList){ 
       System.debug('>>>>>>>>>>>>>>>>>>>>>>>>>>> initiateAIAgent   >>>>>>>>>>>>>>>>.');
       Set<Id> set_LeadIds = new Set<Id>();
       Set<Id> set_SMSLeadIds = new Set<Id>();
       try{
           for(Lead obj_Lead : (List<Lead>)newList){
               set_LeadIds.add(obj_Lead.Id);
               if(obj_Lead.LeadSource == 'Social Media' || obj_Lead.LeadSource == 'Website'){
                   set_SMSLeadIds.add(obj_Lead.Id);
               }
           } 
           if(set_LeadIds.size() > 0){
               LeadTriggerSupportHelper.initiateLeadScore(set_LeadIds);               
           }
           if(set_SMSLeadIds.size() > 0){
               LeadTriggerSupportHelper.initiateSMSMessge(set_SMSLeadIds);
           }
       }catch(Exception exe){}
   }  
   
   @future(callout = true)
   public static void initiateSMSMessge(Set<Id> leadIds) {
       try{
           	List<Lead> lst_Lead = new List<Lead>();
			lst_Lead = [select Id, Title, FirstName, LastName, Email, MobilePhone, ProjectInterest__c, LeadNumber__c 
                        from Lead where Id IN :leadIds];
            List<SMSMessageRequest> lst_SMSMsgRequest = new List<SMSMessageRequest>();
            List<SMSMessageResponse> lst_SMSMsgResponse = new List<SMSMessageResponse>();
            if(lst_Lead.size() > 0){
                for(Lead obj_Lead : lst_Lead){
                    SMSMessageRequest obj_SMSMsgRequest = new SMSMessageRequest();
                    obj_SMSMsgRequest.ProjectName = obj_Lead.ProjectInterest__c;
                    obj_SMSMsgRequest.CustomerName = obj_Lead.FirstName+' '+obj_Lead.LastName;
                    obj_SMSMsgRequest.MobileNumber = obj_Lead.MobilePhone;
                    obj_SMSMsgRequest.LeadNumber = obj_Lead.LeadNumber__c;
                    obj_SMSMsgRequest.LeadStatus = 'Initiated';
                    obj_SMSMsgRequest.BitlyMessageURL = '';
                    lst_SMSMsgRequest.add(obj_SMSMsgRequest);
                }
                HttpRequest req = new HttpRequest();
                req.setTimeout(120000);
                req.setHeader('Accept', 'application/json');
                req = OIC_CredentialsController.getCredentials('LeadCommunicationAPI');
                req.setBody(JSON.serialize(lst_SMSMsgRequest));
                system.debug('SMS >>>>> lst_SMSMsgRequest >> ' + JSON.serialize(lst_SMSMsgRequest));
                Http http = new Http();
                HTTPResponse res = http.send(req);
                System.debug(res.getBody());
                if(res.getBody() != null){
                	lst_SMSMsgResponse = (List<SMSMessageResponse>) JSON.deserialize(res.getBody(), List<SMSMessageResponse>.class);
                    List<Lead> lst_Update = new List<Lead>();
                    Set<String> set_LeadNumber = new Set<String>();
                    Map<String, SMSMessageResponse> map_SMSMessageResponse = new Map<String, SMSMessageResponse>();
                    for(SMSMessageResponse obj_SMSMsgResponse : lst_SMSMsgResponse){
                        set_LeadNumber.add(obj_SMSMsgResponse.LeadNumber);
                        if(!map_SMSMessageResponse.containsKey(obj_SMSMsgResponse.LeadNumber)){
                            map_SMSMessageResponse.put(obj_SMSMsgResponse.LeadNumber, obj_SMSMsgResponse);
                        }
                    }
                    lst_Update = [Select Id, LeadNumber__c, SMSBitlyURL__c from Lead where LeadNumber__c IN :set_LeadNumber];
                    for(Lead obj_Lead : lst_Update){
                        if(map_SMSMessageResponse.containsKey(obj_Lead.LeadNumber__c)){
                            SMSMessageResponse obj_SMSMsgResponse = map_SMSMessageResponse.get(obj_Lead.LeadNumber__c);
                            obj_Lead.SMSBitlyURL__c = obj_SMSMsgResponse.BitlyURL;
                        }
                    }
                    update lst_Update;
                }
            }    
       }catch(Exception exe){}
   }    
    
   @future(callout = true)
   public static void initiateLeadScore(Set<Id> leadIds) {
       try{
           
            if (leadIds == null || leadIds.isEmpty()) {
                System.debug('No leads to AI Agent');
                return;
            }
           
            List<Lead> lst_Lead = new List<Lead>();
			lst_Lead = [select Id, Title, FirstName, LastName, Email, MobilePhone, ProjectInterest__c from Lead where Id IN :leadIds];
            List<AILeadScore> lst_LeadScore = new List<AILeadScore>();
            for(Lead obj_Lead : lst_Lead)
            {
                AILeadScore obj_LeadScore = new AILeadScore();
                obj_LeadScore.ProjectInterest = obj_Lead.ProjectInterest__c;
                obj_LeadScore.FirstName = obj_Lead.FirstName;
                obj_LeadScore.LeadId = obj_Lead.Id;
                obj_LeadScore.LastName = obj_Lead.LastName;
                obj_LeadScore.EmailAddress = obj_Lead.Email;
               
                lst_LeadScore.add(obj_LeadScore);
            }   
                HttpRequest req = new HttpRequest();
                req.setTimeout(120000);
                req.setHeader('Accept', 'application/json');
                req = OIC_CredentialsController.getCredentials('ModonFusionAILeadScore');
                req.setBody(JSON.serialize(lst_LeadScore));
                system.debug('Send Leads to AI Agent >>>>> obj_LeadScore >> ' + JSON.serialize(lst_LeadScore));
                Http http = new Http();
                HTTPResponse res = http.send(req);
                System.debug(res.getBody()); 
       }catch(Exception exe){}  
   }  
   public static void createCrossSellLead(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
    List<Lead> lst_NewLead = new List<Lead>();
    System.debug('>>>>>>>>>>>>>>>>> createCrossSellLead >>>>>>>>>> ');
    //Checking whether lead is updated or not
    if(oldMap != null){
        System.debug('>>>>>>>>>>>>>>>>> createCrossSellLead oldMap >>>>>>>>>> ');
        for(Lead obj_Lead : (List<Lead>)newList){
            Lead Old_Lead = (Lead)oldMap.get(obj_Lead.Id);
            System.debug('>>>>>>>>>>>>>>>>> createCrossSellLead oldMap >>>>>>>>>> '+System.JSON.serialize(Old_Lead));
            if(Old_Lead != null && Old_Lead.ProjectInterest__c == 'Reem Hills' 
                && obj_Lead.Status == 'Retired' && obj_Lead.RetiredReason__c == 'Cross Sell'){
                    System.debug('>>>>>>>>>>>>>>>>> createCrossSellLead >>>>>>>>>> ');
                    Lead obj_NewLead = new Lead();
                    obj_NewLead.FirstName = obj_Lead.FirstName;
                    obj_NewLead.LastName = obj_Lead.LastName;
                    obj_NewLead.Phone = obj_Lead.Phone;
                    obj_NewLead.MobilePhone = obj_Lead.MobilePhone;
                    obj_NewLead.SecondaryMobile__c = obj_Lead.SecondaryMobile__c;
                    obj_NewLead.Email = obj_Lead.Email;
                    obj_NewLead.BrokerAgency__c = obj_Lead.BrokerAgency__c;
                    obj_NewLead.BrokerAgent__c = obj_Lead.BrokerAgent__c;
                    obj_NewLead.BrokerAgentMobile__c = obj_Lead.BrokerAgentMobile__c;
                    obj_NewLead.BrokerAgentName__c = obj_Lead.BrokerAgentName__c;
                    obj_NewLead.LeadSource = obj_Lead.LeadSource;
                    obj_NewLead.Status = 'New';
                    obj_NewLead.RetiredReason__c = '';
                    obj_NewLead.RetirementComments__c = '';
                   // obj_NewLead.Retired_DateTime__c = null;
                    obj_NewLead.Cross_Sell_Lead_Number__c = 'CS-'+obj_Lead.LeadNumber__c;
                    obj_NewLead.OwnerId = obj_Lead.OwnerId;
                    obj_NewLead.ProjectInterest__c = obj_Lead.ProjectInterest__c;
                    lst_NewLead.add(obj_NewLead);
            }
        }
    }  
    if(lst_NewLead.size() > 0){
        System.debug('createCrossSellLead >>>>>>>>>>>>>. '+System.JSON.serialize(lst_NewLead));
        insert lst_NewLead;

    } 
   }     
     //Following method is used to create Call Task for Sales agent 
   public static void createCallTask(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){ 
       System.debug('>>>>>>>>> createCallTask : Initiated');
       Id prospectTaskRecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
       list<Group> sales_operation_queue = [select Id, DeveloperName, Type from Group 
                                            where DeveloperName =: Constants.SALES_OPERATIONS_QUEUE_API_NAME];
       List<Task> lst_Task = new List<Task>();
       Map<Decimal, Task_Management__mdt> map_TaskMetadata = new Map<Decimal, Task_Management__mdt>();
       List<BusinessHours> orgBusinessHours = [select Id from BusinessHours where IsActive = true and IsDefault=true];
       List<Task_Management__mdt> lst_TaskMetadata = [select Label, ObjectName__c,Milestone__c,SLA__c, SLATimeType__c, Category__c, 
                                                      Subcategory__c from Task_Management__mdt where ObjectName__c = 'Lead'];
       for(Task_Management__mdt obj_TaskMetadata : lst_TaskMetadata){
           if(!map_TaskMetadata.containsKey(obj_TaskMetadata.Milestone__c)){
               map_TaskMetadata.put(obj_TaskMetadata.Milestone__c, obj_TaskMetadata);
           }
       }
       for(Lead obj_Lead : (List<Lead>)newList){
        System.debug('Call Task >>>> obj_Lead.OwnerId >> '+obj_Lead.OwnerId);
        System.debug('Call Task >>>> obj_Lead.Call_Task_Milestone__c >> '+obj_Lead.Call_Task_Milestone__c);
        System.debug('Call Task >>>> Metadata >> '+map_TaskMetadata.containsKey(Integer.valueOf(obj_Lead.Call_Task_Milestone__c)));
        System.debug('Call Task >>>> map_TaskMetadata >> '+System.JSON.serialize(map_TaskMetadata));
        if(!sales_operation_queue.isEmpty() &&
            obj_Lead.LeadSource != 'Broker Portal' &&
            obj_Lead.LeadSource != '800-Modon' &&
            (obj_Lead.OwnerId == null || obj_Lead.OwnerId != sales_operation_queue[0].Id)){   
           Long taskInterval = 0;
           DateTime addHoursToTaskDueDate;
           System.debug('Call Task >>>> obj_Lead.OwnerId >> '+obj_Lead.OwnerId);
           System.debug('Call Task >>>> obj_Lead.Call_Task_Milestone__c >> '+obj_Lead.Call_Task_Milestone__c);
           System.debug('Call Task >>>> Metadata >> '+map_TaskMetadata.containsKey(Integer.valueOf(obj_Lead.Call_Task_Milestone__c)));
           System.debug('Call Task >>>> map_TaskMetadata >> '+System.JSON.serialize(map_TaskMetadata));
           if(map_TaskMetadata.containsKey(Integer.valueOf(obj_Lead.Call_Task_Milestone__c))){
                  Task_Management__mdt obj_TaskMetadata = map_TaskMetadata.get(Integer.valueOf(obj_Lead.Call_Task_Milestone__c));
                  Task_Management__mdt obj_NextTaskMetadata = map_TaskMetadata.get(Integer.valueOf(obj_Lead.Call_Task_Milestone__c+1));
                  //Current Task details
                  if(obj_TaskMetadata.SLATimeType__c == 'seconds'){
                      taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 1000;
                  } else if(obj_TaskMetadata.SLATimeType__c == 'minutes'){
                      taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 60 * 1000;
                  } else if(obj_TaskMetadata.SLATimeType__c == 'hours'){
                      taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 60 * 60 * 1000;
                  } else {} 
                 
                  //Create a call task for leads
                  if(taskInterval != 0){
                      addHoursToTaskDueDate = BusinessHours.add( orgBusinessHours[0].id , system.now() , taskInterval  );
                      addHoursToTaskDueDate = DateTime.parse(addHoursToTaskDueDate.format());
                      Date dueDate = Date.newInstance(addHoursToTaskDueDate.year(), addHoursToTaskDueDate.month(), addHoursToTaskDueDate.day());
                      Task obj_Task = new Task();
                      obj_Task.RecordTypeId = prospectTaskRecordTypeId;
                      obj_Task.whoId = obj_Lead.Id;
                      obj_Task.OwnerId = obj_Lead.OwnerId;
                      obj_Task.Subject = Constants.TASK_CALL_SUBJECT+' '+Integer.valueOf(obj_Lead.Call_Task_Milestone__c) + ' - '+obj_Lead.LeadNumber__c;
                      obj_Task.ActivityDate = dueDate;
                      obj_Task.CurrentTaskSLA__c = addHoursToTaskDueDate;
                      obj_Task.Status = Constants.TASK_STATUS_OPEN;
                      obj_Task.System_Created__c = true;
                      obj_Task.Created_DateTime__c = System.now();
                      if(obj_NextTaskMetadata != null){
                         obj_Task.NextTaskMilestone__c =  obj_NextTaskMetadata.Milestone__c;
                      } else {
                         obj_Task.NextTaskMilestone__c = 0; 
                      }
                      
                      lst_Task.add(obj_Task);
                  }
           }
         }     
       }
       if(lst_Task.size() > 0){
           insert(lst_Task);
           //sendBellNotificationToAgents(System.JSON.serialize(lst_Task));
       }       
   }
    
    public static void restrictLeadsforBrokerAgents(List<SObject> newList) {
        Set<String> projectNames = new Set<String>();
        Map<String, Sales_Launch__mdt> map_SalesLaunch = new Map<String, Sales_Launch__mdt>();
        Map<String, Integer> map_NumberLeadsforBroker = new Map<String, Integer>();
        Set<Id> set_BrokerAgency = new Set<Id>();
        Map<String, Date> map_SalesLaunchStartDate = new Map<String, Date>();
        Map<String, Date> map_SalesLaunchEndDate = new Map<String, Date>();
        

        for(Lead obj_Lead : (List<Lead>) newList){
           if(!String.isBlank(obj_Lead.ProjectInterest__c) && !String.isBlank(obj_Lead.LeadSource)
              && !String.isBlank(obj_Lead.BrokerAgency__c)
              && obj_Lead.LeadSource == 'Broker Portal'){
               projectNames.add(obj_Lead.ProjectInterest__c);
               set_BrokerAgency.add(obj_Lead.BrokerAgency__c);                  
           }
        }
 
        System.debug('LeadTriggerHandler >>>>  restrictLeadsforBrokerAgents >> '+System.JSON.serialize(projectNames));

        if(projectNames.size() > 0){
          List<Sales_Launch__mdt> lst_SalesLaunchMdt = [SELECT Id,DeveloperName, CampaignName__c, Project_Name__c, 
                                                        EventDate__c, StartDate__c, EndDate__c, MaxLeadsAllowed__c,
                                                        IsActive__c from Sales_Launch__mdt 
                                                        where Project_Name__c IN : projectNames and IsActive__c = true];
          for(Sales_Launch__mdt obj_SalesLaunchMdt : lst_SalesLaunchMdt){ 
            if(!map_SalesLaunch.containsKey(obj_SalesLaunchMdt.Project_Name__c)){
                map_SalesLaunch.put(obj_SalesLaunchMdt.Project_Name__c, obj_SalesLaunchMdt);
                map_SalesLaunchStartDate.put(obj_SalesLaunchMdt.Project_Name__c, obj_SalesLaunchMdt.StartDate__c);
                map_SalesLaunchEndDate.put(obj_SalesLaunchMdt.Project_Name__c, obj_SalesLaunchMdt.EndDate__c);
            }            
          } 

          System.debug('LeadTriggerHandler >>>>  map_SalesLaunch >> '+System.JSON.serialize(map_SalesLaunch));
            
            for(String projectName : map_SalesLaunch.keySet()){
                List<AggregateResult> lst_TotalBrokerLeads = new List<AggregateResult>();
                lst_TotalBrokerLeads = [select BrokerAgency__c, COUNT(Id) recordCount from Lead 
                                        where ProjectInterest__c = :projectName 
                                        and CreatedDate >= :map_SalesLaunchStartDate.get(projectName)
                                        and CreatedDate <= :map_SalesLaunchEndDate.get(projectName)
                                        GROUP BY BrokerAgency__c];
                if(lst_TotalBrokerLeads.size() > 0){
              		for(AggregateResult brokerLead : lst_TotalBrokerLeads){
                 		String brokerAgencyName = (String)brokerLead.get('BrokerAgency__c');
                 		if(!String.isBlank(brokerAgencyName) && !map_NumberLeadsforBroker.containsKey(brokerAgencyName)){
                    		map_NumberLeadsforBroker.put(brokerAgencyName, Integer.valueOf(brokerLead.get('recordCount')));
                 		}
              	    }
                 }  
            }  

           System.debug('LeadTriggerHandler >>>>  map_NumberLeadsforBroker >> '+System.JSON.serialize(map_NumberLeadsforBroker));

           for(Lead obj_Lead : (List<Lead>) newList){
              if(!String.isBlank(obj_Lead.BrokerAgency__c) && map_NumberLeadsforBroker != null 
                 && map_NumberLeadsforBroker.containsKey(obj_Lead.BrokerAgency__c)){
                  if(map_SalesLaunch != null && !String.isBlank(obj_Lead.ProjectInterest__c) 
                     && map_SalesLaunch.containsKey(obj_Lead.ProjectInterest__c)){

                    Sales_Launch__mdt obj_SalesLaunchMdt = map_SalesLaunch.get(obj_Lead.ProjectInterest__c);
                    Integer totalNumOfLeads = map_NumberLeadsforBroker.get(obj_Lead.BrokerAgency__c);
                    //System.debug('LeadTriggerHandler >>>>  obj_SalesLaunchMdt >> '+System.JSON.serialize(obj_SalesLaunchMdt));
                    System.debug('LeadTriggerHandler >>>>  totalNumOfLeads >> '+totalNumOfLeads);
                    System.debug('LeadTriggerHandler >>>>  obj_SalesLaunchMdt.MaxLeadsAllowed__c >> '+obj_SalesLaunchMdt.MaxLeadsAllowed__c);     
                    if(obj_SalesLaunchMdt != null && totalNumOfLeads > obj_SalesLaunchMdt.MaxLeadsAllowed__c){
                        System.debug('>>>>>>>>>>>>> 12222222222222 >>>>>');
                        obj_Lead.addError('You cannot create more than '+obj_SalesLaunchMdt.MaxLeadsAllowed__c+' records.');
                    }
                  } 
              }
           }
          }        
     }
    public class AILeadScore {
        public String LeadId;
        public String ProjectInterest;
        public String FirstName;
        public String LastName;
        public String EmailAddress;
   } 
   public class AILeadScoreResponse {
        public String Status;        
   } 
  
   public class SMSMessageRequest{
		public String LeadNumber{get;set;}
		public String MobileNumber{get;set;}
		public String LeadStatus{get;set;}
		public String CustomerName{get;set;}
		public String BitlyMessageURL{get;set;}
		public String ProjectName{get;set;}
   }
   public class SMSMessageResponse{
		public String LeadNumber{get;set;}
		public String BitlyURL{get;set;}
		public String Status{get;set;}
   } 
}