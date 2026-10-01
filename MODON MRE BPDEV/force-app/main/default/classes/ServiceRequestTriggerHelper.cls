/**********************************************************************************************************************
* Name               : ServiceRequestTriggerHelper                                                        
* Description        : This class is used to handle all the Service Request trigger instances
* Usage              : Called from ServiceRequestTrigger
* Created By         : Active Minds                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Manoj         13 Dec 2024     Initial Draft 
* 1.0           KC            12 JAN 2024     Initial Draft
* 1.0           Sireesha      16 JAN 2024     Initial Draft 
* 1.1			Raghu Gajjela 03 Apr 2026		added a method to update charge details when selling price is updated.
* 1.2			Chandu battu  04 Apr 2026		added a method to update charge adm amount, total installment paid amount and assign queue method
* 1.3           Sireesha      12 May 2026     updated charge related logic for commertial plots  
* 1.4          Siva           12 AUG 2026     ADM Assignment Changes    
******************************************************************************************************************/
public class ServiceRequestTriggerHelper { 
    
    private static final string SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_ADDITION { get { return 'Joint_Owner_Addition_And_Deletion'; } }
    private static final string SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER { get { return 'Service_Request_Management_Property_Transfer_OffPlan'; } }
    private static final string SERVICE_REQUEST_RT_DEV_NAME_ADM { get { return 'Service_Request_Management_ADM'; } }
    private static final string SERVICE_REQUEST_RT_DEV_NAME_OFF_PLAN { get { return 'Service_Request_Management_Property_Transfer_OffPlan'; } }
    private static final string SERVICE_REQUEST_RT_DEV_PE { get { return 'Request_Payment_Extension'; } }
    private static final string SERVICE_REQUEST_UC { get { return 'Unit_Consolidation'; } }
    private static final string SERVICE_REQUEST_LPC { get { return 'LPC_Waiver'; } }
    private static final string SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED { get { return 'Service_Request_Management_Property_Transfer_Title_Deed'; } }
    private static final string SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED { get { return 'Service_Request_Management_Joint_Owner_Title_Deed'; } }
    private static final string SERVICE_REQUEST_RT_DEV_NAME_Milestone_Update { get { return 'Service_Request_Milestone_Update'; } }
    private static final string SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP { get { return 'Payment_Plan_Swap'; } }  // for payment plan swap
    private static final string SERVICE_REQUEST_RT_Unit_SWAP { get { return 'SRM_Unit_Swap'; } }  // for payment plan swap
    private static final string SERVICE_REQUEST_RT_Unit_Upgrade { get { return 'Service_Request_Management_Unit_Upgrade'; } }  // for payment plan swap
    private static final string SERVICE_REQUEST_Broker_Registration { get { return 'Broker_Registration'; } }  // for broker registration
    private static final string SERVICE_REQUEST_RT_PROPERTY_TRANSFER_TITLE_DEED_CM { get { return 'Property_Transfer_Title_Deed_Commercial'; } }  
    
    /**
* @description Handles before-insert trigger logic for ServiceRequest__c.
*              Categorizes records by Record Type and routes them to the
*              appropriate controller for duplicate checking, field population,
*              and owner assignment.
* @param newList List of new ServiceRequest__c records being inserted.
*/
    
    public static void beforeInsert(List<ServiceRequest__c> newList)
    {
        Id offPlanRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_OFF_PLAN);
        Id joRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_ADDITION);
        Id peRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_PE);
        Id lpcRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_LPC);
        Id joTitleDeedRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED);
        Id ptTitleDeedRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED);
        Id unitswapRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Unit_SWAP);
        Id unitupgradeRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Unit_Upgrade);
        Id admrRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        Id plotHandoverRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,'Service_Request_Plot_Handover');
        Id defaultRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,'Default_SR');
        Id cancellationRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,'DefaultUnitCancellation');
        
        List<ServiceRequest__c> srList = new List<ServiceRequest__c>();
        List<ServiceRequest__c> peList = new List<ServiceRequest__c>();
        List<ServiceRequest__c> admList= new List<ServiceRequest__c>();
        List<ServiceRequest__c> plothandoverList = new List<ServiceRequest__c>();
        List<ServiceRequest__c> defaultSRList = new List<ServiceRequest__c>();
        List<ServiceRequest__c> lpcList = new List<ServiceRequest__c>();
        List<ServiceRequest__c> defaultSRCancellation = new List<ServiceRequest__c>();
        
        for(ServiceRequest__c sr: newList)
        {
            if(sr.RecordTypeiD == unitupgradeRecordTypeId  || sr.RecordTypeiD ==  unitswapRecordTypeId|| sr.RecordTypeiD == offPlanRecordTypeId || sr.RecordTypeId == joRecordTypeId  || sr.RecordTypeId == joTitleDeedRecordTypeId  || sr.RecordTypeId == ptTitleDeedRecordTypeId || sr.RecordTypeId == lpcRecordTypeId)
            {
                srList.add(sr);
            }
            if(sr.RecordTypeId == peRecordTypeId){
                peList.add(sr);
            }
            if(sr.RecordTypeId == lpcRecordTypeId){
                lpcList.add(sr);
            }
            // 1.4 ADM Assignment changes
            if(sr.RecordTypeiD == admrRecordTypeId){
                admList.add(sr);
            }
            if(sr.RecordTypeiD == plotHandoverRecordTypeId){
                plothandoverList.add(sr);
            }
            if(sr.RecordTypeiD == defaultRecordTypeId){
                defaultSRList.add(sr);
            }
            if(sr.RecordTypeiD == cancellationRecordTypeId){
                defaultSRCancellation.add(sr);
            }
            
        }
        
        // Ensure that the status of the salesorder is valid for SR creation
        //ServiceRequestContoller.checkSalesOrderStatusForSRCreation(newList);
        
        // Ensure there is no existing open ServiceRequest for same recordtype on the same salesorder
        ServiceRequestContoller.checkDuplicateServiceRequest(newList);
        // ServiceRequestContoller.blockSRCreationForDefaulters(Trigger.new);
        
        if(srList.size() > 0)
        {
            ServiceRequestContoller.updateAccUnitOnOffPlanSR(srList);
        }
        if(peList.size() > 0)
        {
            ServiceRequestContoller.updateSOInstallmentOnPESR(peList);  
        }
        if(lpcList.size() > 0)
        {
            ServiceRequestContoller.updateSOInstallmentOnLPCSR(lpcList);  
        }
        system.debug('from AMDServiceRequestAssigner');
        // Add Owner for Service Request
        if(admList.size() >0){
            ADM_SR_Assignment.assignServiceRequests(newList);
        }
        system.debug('------from plothandoverList----------------------'+plothandoverList);
        
        // this can be uncommented in UAT after 16/06/2025 Production release
        if(plothandoverList.size()>0){
            ADM_SR_Assignment.assignServiceRequestsCMTeam(plothandoverList,'Plot Handover','CM Team SR');
        }
        
        if(defaultSRList.size()>0){
            ADM_SR_Assignment.assignServiceRequestsCMTeam(defaultSRList,'Default SR','CollectionTeam'); 
        }
        
        if(defaultSRCancellation.size()>0){
            ADM_SR_Assignment.assignServiceRequestsCMTeam(defaultSRCancellation,'Default Unit Cancellation','CollectionTeam');
        }
        
    }
    
    /**
* @description Handles before-update trigger logic for ServiceRequest__c.
*              Applies penalty updates, enforces closure rules, generates
*              external approval tokens for Payment Extension SRs awaiting
*              CEO approval, and tracks Fast Track enablement for Broker
*              Registration records.
* @param newList List of updated ServiceRequest__c records (new values).
* @param oldList List of ServiceRequest__c records before the update.
* @param oldMap  Map of ServiceRequest__c Id to old record values.
*/
    
    public static void beforeUpdate(List<SObject> newList,List<SObject> oldList, Map<Id, SObject> oldMap) 
    {
        Id admrRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        Id brokerRegistrationRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_Broker_Registration);
        //Id paymentPlanSwapRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP);
        for(ServiceRequest__c newServiceRequest : (List<ServiceRequest__c>)newList) 
        {
            if(newServiceRequest.RecordTypeId == admrRecordTypeId){
                List<ServiceRequest__c> oldSRs = (List<ServiceRequest__c>)oldList;
                ServiceRequestContoller.updatePenality(newList,oldSRs);
                ServiceRequestContoller.serviceRequestClosed(newList, oldSRs);
            }else if(newServiceRequest.RecordTypeId != admrRecordTypeId){
                List<ServiceRequest__c> oldSRs = (List<ServiceRequest__c>)oldList;
                ServiceRequestContoller.serviceRequestClosed(newList, oldSRs);
            }
        }
        for (ServiceRequest__c sr : (List<ServiceRequest__c> )newList) 
        {
            system.debug('debug: sr.Name ' + sr.Name);
            if (String.isBlank(sr.External_Approval_Token__c)&& sr.Payment_Extension_Approval__c =='Awaiting CEO Approval' && sr.recordTypeId == Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_PE)) {
                String raw = sr.Id + String.valueOf(Datetime.now().getTime());
                String token = EncodingUtil.convertToHex(
                    Crypto.generateDigest('SHA256', Blob.valueOf(raw))
                );
                sr.External_Approval_Token__c = token;
            }
            
        }
        
        Map<Id, ServiceRequest__c> oldSrMap = new Map<Id, ServiceRequest__c>();
        for(ServiceRequest__c oldSr : (List<ServiceRequest__c>)oldList){
            oldSrMap.put(oldSr.Id, oldSr);
        }
        
        for(ServiceRequest__c sr : (List<ServiceRequest__c>)newList) {
            if(sr.RecordTypeId == brokerRegistrationRecordTypeId){
                ServiceRequest__c oldSr = oldSrMap.get(sr.Id);
                if(oldSr != null){
                    // Check if Fast_Track__c changed from false to true
                    if(sr.Fast_Track__c == true && (oldSr.Fast_Track__c != true)) {
                        sr.Fast_Track_Enabled_By__c = UserInfo.getUserId();
                        sr.Fast_Track_Enabled_Date__c = Date.today();
                    }
                }
            }
        }
        
    }
    
    /**
* @description Handles after-insert trigger logic for ServiceRequest__c.
*              Creates initial workflow tasks, document placeholders, charges,
*              and SLA records for qualifying ADM New Sale service requests.
* @param newList List of newly inserted ServiceRequest__c records (as SObject).
*/
    
    public static void afterInsert(List<sObject> newList) {
        Id jointOwnerAdditionRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_ADDITION);
        Id propertyTransferRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);
        Id admrRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        //added Sireesha v1.2
         Id propertyTransferRecordTypeCommertiaId =Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_PROPERTY_TRANSFER_TITLE_DEED_CM);

        
        Id MilUpdateRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_Milestone_Update);
        system.debug('propertyTransferRecordTypeId'+propertyTransferRecordTypeId);
        List<ServiceRequest__c> jointOwnerAdditionList = new List<ServiceRequest__c>();
        List<ServiceRequest__c> propertyTransferList = new List<ServiceRequest__c>();
        List<ServiceRequest__c> admList = new List<ServiceRequest__c>();
        List<ContentDocumentLink> oldContentDoclinkList = new List<ContentDocumentLink>();
        List<ServiceRequest__c> admiSRforNewSale = new List<ServiceRequest__c>();


        System.debug('newList------>'+newList);
        //Create Intial Tasks for Service Requests
        ServiceRequestTaskController.createIntialTasks((List<ServiceRequest__c>)newList);
        DocumentTypeController.creatingDocment(newList,'Service Request');
        
        for(ServiceRequest__c srRec : (List<ServiceRequest__c>)newList){
            
            if(srRec.RecordTypeId == admrRecordTypeId && Constants.SERVICE_REQUEST_TYPE_NEWSALE == srRec.Type__c && ServiceUtility.isSFUserId(srRec.OwnerId)
               && Constants.SERVICE_REQUEST_STATUS_CLOSED != srRec.Status__c && Constants.SERVICE_REQUEST_STATUS_CANCELLED != srRec.Status__c) {
                   admiSRforNewSale.add(srRec);
               }
  //added Sireesha v1.2
            if(srRec.RecordTypeId == propertyTransferRecordTypeCommertiaId ){

               PropertyTransferTitleDeedController.handleCommercialCharges((List<ServiceRequest__c>)newList, null);
            }

        }
        
        
        /*for(ServiceRequest__c objServiceRequest :(List<ServiceRequest__c>)newList){
if(objServiceRequest.RecordTypeId == jointOwnerAdditionRecordTypeId){
jointOwnerAdditionList.add(objServiceRequest);
}
if(objServiceRequest.RecordTypeId == propertyTransferRecordTypeId){
propertyTransferList.add(objServiceRequest);
}
if(objServiceRequest.RecordTypeId == admrRecordTypeId){
admList.add(objServiceRequest);
}
}

if(!jointOwnerAdditionList.isEmpty()){
JointOwnerAdditionHandler.afterInsert(jointOwnerAdditionList);
}*/
        // List<ContentDocumentLink> conClone = new List<ContentDocumentLink>();
        // Map<String,Documents__c> docMap = new Map<String,Documents__c>();
        // set<Id> setOfDocIds= new set<Id>();
        // set<Id> parentId = new set<Id>();
        // for(ServiceRequest__c srRec : (List<ServiceRequest__c>)newList){
        //     setOfDocIds.add(srRec.Id);
        //     parentId.add(srRec.SalesOrder__c);
        //     if(srRec.RecordTypeId == admrRecordTypeId && Constants.SERVICE_REQUEST_TYPE_NEWSALE == srRec.Type__c && ServiceUtility.isSFUserId(srRec.OwnerId)
        //        && Constants.SERVICE_REQUEST_STATUS_CLOSED != srRec.Status__c && Constants.SERVICE_REQUEST_STATUS_CANCELLED != srRec.Status__c) {
        //            admiSRforNewSale.add(srRec);
        //        }
        // }
        
        // List<Id> olddocId = new List<Id>();
        // if(!parentId.isEmpty()){
        //     for(Documents__c docRec : [SELECT Id,Name,Service_Request__c from Documents__c Where Service_Request__c = : parentId LIMIT 49000]){
        //         olddocId.add(docRec.id);
        //     }
        //     if(olddocId.size() > 0){
        //         oldContentDoclinkList = [SELECT ContentDocumentId,ContentDocument.Title, 
        //                                  ContentDocument.ContentModifiedDate, ContentDocument.ContentSize,LinkedEntity.Name FROM 
        //                                  ContentDocumentLink WHERE LinkedEntityId IN :olddocId];
        //     }
        // }
        // if(!setOfDocIds.isEmpty()){
        //     List<Documents__c> docNewList =[SELECT Id,Name FROM Documents__c WHERE Service_Request__c IN :setOfDocIds];
        //     for(Documents__c dcNew:docNewList){
        //         docMap.put(dcNew.Name,dcNew);
        //     }
        //     for(ContentDocumentLink cdl:oldContentDoclinkList){
        //         if(docMap.containsKey(cdl.LinkedEntity.Name)){
        //             ContentDocumentLink newclnk = cdl.clone();
        //             newclnk.LinkedEntityId =  docMap.get(cdl.LinkedEntity.Name).Id;
        //             newclnk.ShareType = 'V';
        //             conClone.add(newclnk);                    
        //         }
        //     }    
        //     insert conClone; 
        // }
        
        system.debug('Chargerssss------>'+newList);
        ChargeService.createChargesOnSR((List<ServiceRequest__c>)newList);   
        
        // Send emails to customer // the functionality of this block is being handled from ServiceRequestEmailDispatcher
        /* for(ServiceRequest__c sr:(List<ServiceRequest__c>)newList)
{
//ServiceRequest__c srUpdated = [Select Id,RecordTypeName__c from ServiceRequest__c where Id =: sr.Id];
if(sr.RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER)
{
SendGridServiceRequestCustomerEmail.sendEmailToCustomer(sr.Id,ServiceConstants.CEMAIL_SR_CREATED);
}
else if(sr.RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION)
{
SendGridServiceRequestCustomerEmail.sendEmailToCustomer(sr.Id,ServiceConstants.CEMAIL_SR_JO_ACKNOWLEDGE);
}
else if(sr.RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED)
{
SendGridServiceRequestCustomerEmail.sendEmailToCustomer(sr.Id,ServiceConstants.SREMAIL_JO_TITLEDEED_ACKNOWLEDGE);
}
else if(sr.RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED)
{
SendGridServiceRequestCustomerEmail.sendEmailToCustomer(sr.Id,ServiceConstants.SREMAIL_JO_TITLEDEED_COMPLETED);
}
}*/


        if(!admiSRforNewSale.isEmpty()) {
            createSLAforSR(admiSRforNewSale);
        }
    }
    
    /**
* @description Handles after-update trigger logic for ServiceRequest__c.
*              Chains SR creation on closure of PT/JO records, creates
*              charges on penalty/NOC changes, closes approval tasks on
*              approval or rejection events across multiple SR types, and
*              triggers broker agency creation on Fast Track activation.
* @param newList List of updated ServiceRequest__c records (new values, as SObject).
* @param oldMap  Map of ServiceRequest__c Id to old SObject state for field comparison.
*/
    
    public static void afterUpdate(list<SObject> newList,Map<Id, sObject> oldMap) {
        Id admrRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        Id jointOwnerAdditionRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_ADDITION);
        Id propertyTransferRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);
        Id propertyTransferTdRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED);
        Id jointOwnerTitleDeedRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED);
        Id PERecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_PE);
        Id UCRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_UC);
        Id LPCRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_LPC);
        Id propertyTransferRecordTypeCommertiaId =Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_PROPERTY_TRANSFER_TITLE_DEED_CM);
        
        
        Id PSRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP); // for payment plan swap.
        System.debug('propertyTransferTdRecordTypeId--->'+propertyTransferTdRecordTypeId);
        Id unitswapRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Unit_SWAP);
        Id unitupgradeRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Unit_Upgrade);
        Id brokerRegistrationRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,SERVICE_REQUEST_Broker_Registration);
        
        list<string> AdmCreatefrom = System.label.AdmCreatefrom.split(',');
        list<ServiceRequest__c> SrCreationList=new list<ServiceRequest__c>();
        Map<Id,ServiceRequest__c> oldSrMap = (Map<Id,ServiceRequest__c>)oldMap;
        for(ServiceRequest__c newServiceRequest : (List<ServiceRequest__c>)newList) {
            ServiceRequest__c oldRecord;
            
            if(oldMap.size()>0 && !oldMap.isEmpty()){
                oldRecord = (ServiceRequest__c)oldMap.get(newServiceRequest.Id);
            }
            System.debug('Labels'+AdmCreatefrom);
            if((newServiceRequest.RecordTypeId == propertyTransferRecordTypeId ||newServiceRequest.RecordTypeId ==jointOwnerAdditionRecordTypeId) && newServiceRequest.Status__c=='Closed' && oldRecord.Status__c <> newServiceRequest.Status__c ){
                System.debug('ServiceRequest After Updat'+newServiceRequest);               
                SrCreationList.add(newServiceRequest);
            }
            
            if( newServiceRequest.RecordTypeId == admrRecordTypeId && (!oldMap.isEmpty()) && (oldRecord.Penality_Charge__c <> newServiceRequest.Penality_Charge__c )&&newServiceRequest.Penality_Charge__c == True  ){ 
                ChargeService.createChargesOnSR(newList);
            }
            
            if( (newServiceRequest.RecordTypeId == jointOwnerTitleDeedRecordTypeId || newServiceRequest.RecordTypeId == propertyTransferTdRecordTypeId) && (!oldMap.isEmpty()) && ( (oldRecord.Is_NOC_Extended__c <> newServiceRequest.Is_NOC_Extended__c && newServiceRequest.Is_NOC_Extended__c == True) ||
                                                                                                                                                                                   (newServiceRequest.Is_NOC_Extended__c == True && (oldRecord.Actual_Requested_Date__c <> newServiceRequest.Actual_Requested_Date__c || (oldRecord.NOC_Extension_Date__c <> newServiceRequest.NOC_Extension_Date__c))
                                                                                                                                                                                    
                                                                                                                                                                                   ) )){ 
                                                                                                                                                                                       System.debug('ServiceRequest After Updat'+newServiceRequest);               
                                                                                                                                                                                       
                                                                                                                                                                                       ChargeService.createChargesOnSR(newList);
                                                                                                                                                                                   } 
            if(newServiceRequest.RecordTypeId == PERecordTypeId  && newServiceRequest.Payment_Extension_Approval__c == Constants.PE_APPROVAL_STATUS && oldSrMap.get(newServiceRequest.Id).Payment_Extension_Approval__c != Constants.PE_APPROVAL_STATUS){
                ServiceRequestTriggerHelper.updateTaskStatusAfterApproval(newServiceRequest, Constants.PE_APPROVAL_TASK_SUBJECT,false,0);
                // System.enqueueJob(new PaymentExtensionPDFQueueable(newServiceRequest.Id));
            }else if(newServiceRequest.RecordTypeId == PERecordTypeId  && newServiceRequest.Payment_Extension_Approval__c == Constants.PE_REJECTION_STATUS && oldSrMap.get(newServiceRequest.Id).Payment_Extension_Approval__c != Constants.PE_REJECTION_STATUS){
                ServiceRequestTriggerHelper.updateTaskStatusAfterApproval(newServiceRequest, Constants.PE_APPROVAL_TASK_SUBJECT,true,2);
            }
            
            if(newServiceRequest.RecordTypeId == LPCRecordTypeId  && newServiceRequest.LPC_Waiver_Approvals__c == Constants.PE_APPROVAL_STATUS && oldSrMap.get(newServiceRequest.Id).LPC_Waiver_Approvals__c != Constants.PE_APPROVAL_STATUS){
                ServiceRequestTriggerHelper.updateTaskStatusAfterApproval(newServiceRequest, Constants.PE_APPROVAL_TASK_SUBJECT,false,0);
                // System.enqueueJob(new LPCPDFQueueable(newServiceRequest.Id));
            }else if(newServiceRequest.RecordTypeId == LPCRecordTypeId  && newServiceRequest.LPC_Waiver_Approvals__c == Constants.PE_REJECTION_STATUS && oldSrMap.get(newServiceRequest.Id).LPC_Waiver_Approvals__c != Constants.PE_REJECTION_STATUS){
                ServiceRequestTriggerHelper.updateTaskStatusAfterApproval(newServiceRequest, Constants.PE_APPROVAL_TASK_SUBJECT,true,3);
            }
           
            
            if(newServiceRequest.RecordTypeId == UCRecordTypeId  && newServiceRequest.Unit_Consolidation_Approvals__c == Constants.PE_APPROVAL_STATUS && oldSrMap.get(newServiceRequest.Id).Unit_Consolidation_Approvals__c != Constants.PE_APPROVAL_STATUS){
                ServiceRequestTriggerHelper.updateTaskStatusAfterApproval(newServiceRequest, Constants.PE_APPROVAL_TASK_SUBJECT,false,0);
                //System.enqueueJob(new UnitConsolidationPDFQueueable(newServiceRequest.Id));
            }else if(newServiceRequest.RecordTypeId == UCRecordTypeId  && newServiceRequest.Unit_Consolidation_Approvals__c == Constants.PE_REJECTION_STATUS && oldSrMap.get(newServiceRequest.Id).Unit_Consolidation_Approvals__c != Constants.PE_REJECTION_STATUS){
                ServiceRequestTriggerHelper.updateTaskStatusAfterApproval(newServiceRequest, Constants.PE_APPROVAL_TASK_SUBJECT,true,1);
            }
            // for payment plan swap
            if(newServiceRequest.RecordTypeId == PSRecordTypeId  && newServiceRequest.Plan_Swap_Approval_Status__c == Constants.PS_APPROVAL_STATUS && oldSrMap.get(newServiceRequest.Id).Plan_Swap_Approval_Status__c != Constants.PS_APPROVAL_STATUS){
                ServiceRequestTriggerHelper.updateTaskStatusAfterApproval(newServiceRequest, Constants.PS_APPROVAL_TASK_SUBJECT,false,0);
                // System.enqueueJob(new PaymentExtensionPDFQueueable(newServiceRequest.Id));
            }else if(newServiceRequest.RecordTypeId == PSRecordTypeId  && newServiceRequest.Plan_Swap_Approval_Status__c == Constants.PS_REJECTION_STATUS && oldSrMap.get(newServiceRequest.Id).Plan_Swap_Approval_Status__c != Constants.PS_REJECTION_STATUS){
                ServiceRequestTriggerHelper.updateTaskStatusAfterApproval(newServiceRequest, Constants.PS_APPROVAL_TASK_SUBJECT,true,5);
            }
            if((newServiceRequest.RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER || newServiceRequest.RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION) && 
               newServiceRequest.CM_Approval_Status__c == Constants.CM_APPROVAL_STATUS_APPROVED && oldSrMap.get(newServiceRequest.Id).CM_Approval_Status__c != Constants.CM_APPROVAL_STATUS_APPROVED){
                   ServiceRequestTriggerHelper.updateTaskStatusAfterApproval(newServiceRequest, Constants.CM_APPROVAL_TASK_SUBJECT,false,0);
               }  
            
            if((newServiceRequest.RecordTypeId == unitswapRecordTypeId   || newServiceRequest.RecordTypeId == unitupgradeRecordTypeId)  && newServiceRequest.Unit_Upgrade_Approval__c == Constants.UT_STATUS_APPROVED && oldSrMap.get(newServiceRequest.Id).Unit_Upgrade_Approval__c != Constants.UT_STATUS_APPROVED){
                // System.enqueueJob(new UntUpgradeOrSwapPDFQueueable(newServiceRequest.Id));
                
                ServiceRequestUnitController.updateTaskStatusAfterApproval(newServiceRequest, Constants.UT_APPROVAL_TASK_SUBJECT,false,0);
            }else if((newServiceRequest.RecordTypeId == unitswapRecordTypeId   || newServiceRequest.RecordTypeId == unitupgradeRecordTypeId)  && newServiceRequest.Unit_Upgrade_Approval__c == Constants.UT_STATUS_REJECTED && oldSrMap.get(newServiceRequest.Id).Unit_Upgrade_Approval__c != Constants.UT_STATUS_REJECTED){
                ServiceRequestUnitController.updateTaskStatusAfterApproval(newServiceRequest, Constants.UT_APPROVAL_TASK_SUBJECT,true,2);
            }
            
            if( newServiceRequest.RecordTypeId ==brokerRegistrationRecordTypeId && 
               oldRecord.Fast_Track__c != newServiceRequest.Fast_Track__c && 
               newServiceRequest.Fast_Track__c){
                   MBP_RegistrationService.createBrokerAgency(newServiceRequest, null);
               } 
           if( newServiceRequest.RecordTypeId == propertyTransferRecordTypeCommertiaId && (!oldMap.isEmpty()) && (oldRecord.Outstanding_Charge__c <> newServiceRequest.Outstanding_Charge__c )){ 
           //// v1.2 | Sireesha | 12 may 2026
			// After Update: Create/Update Outstanding charge when Outstanding_Charge__c changes
                PropertyTransferTitleDeedController.handleCommercialCharges((List<ServiceRequest__c>)newList,(Map<Id, ServiceRequest__c>)oldMap);

            }
        }
        if(SrCreationList.size() > 0){
            ServiceRequestContoller.createNewServiceReuest(SrCreationList, 'ServiceRequest__c');
        }
    }
    
    /**
* @description Closes the open Task matching the given subject criteria on
*              a ServiceRequest__c after an approval or rejection event.
*              On rejection, increments the task's Order__c by the given
*              offset to advance the workflow to the appropriate next step.
* @param newServiceRequest The ServiceRequest__c record whose tasks should be updated.
* @param subjectCriteria   The Subject value used to identify the target task.
* @param statusCriteria    True if this is a rejection (increments Order__c),
*                          false if this is an approval (closes task as-is).
* @param order             The integer offset to add to Order__c on rejection.
*                          Pass 0 for approval events (no offset needed).
*/
    
    public static void updateTaskStatusAfterApproval(ServiceRequest__c newServiceRequest, String subjectCriteria, boolean statusCriteria,Integer order) {
        Id unitswapRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Unit_SWAP);
        Id unitupgradeRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Unit_Upgrade);
        System.debug('updateTaskStatusAfterApproval called');
        System.debug('newServiceRequest.Id: ' + newServiceRequest.Id);
        System.debug('subjectCriteria: ' + subjectCriteria);
        System.debug('statusCriteria: ' + statusCriteria);
        List<Task> taskList = [SELECT Id, Status, Subject, Order__c 
                               FROM Task 
                               WHERE WhatId = :newServiceRequest.Id 
                               AND Status != :Constants.TASK_STATUS_CLOSED];
        
        list<ServiceRequest__c> SrCreationList=new list<ServiceRequest__c>();
        List<Task> taskListToUpdate = new List<Task>();
        for (Task task : taskList) {
            if (task.Subject == subjectCriteria && !statusCriteria) {
                task.Status = Constants.TASK_STATUS_CLOSED;
                taskListToUpdate.add(task);
            }else if(task.Subject == subjectCriteria && statusCriteria) {
                task.Order__c = task.Order__c+order;
                task.Status = Constants.TASK_STATUS_CLOSED;
                taskListToUpdate.add(task);
            }
        }
        List<Database.SaveResult> taskResult = new List<Database.SaveResult>();
        if (!taskListToUpdate.isEmpty()) {
            taskResult = Database.update(taskListToUpdate, false);
        }
        
    }   
    
    /**
* @description Creates CaseSLA__c records for ADM New Sale ServiceRequest__c records.
*              Retrieves active business hours and holidays, finds the applicable
*              Master SLA configuration, and calculates a due date for each SR
*              based on the configured SLA hours. Inserts the resulting SLA records.
* @param newList List of ServiceRequest__c records that require SLA records.
*               Expected to be ADM New Sale SRs filtered prior to this call.
*/
    
    public static void createSLAforSR(List<ServiceRequest__c> newList) {
        system.debug('createSLAforSR.........');
        BusinessHours bussHours = SystemContextClass.getBusinessHours();
        Holiday[] holidays = SystemContextClass.getHolidays();
        Master_SLA__c masterSLA;
        for(Master_SLA__c thisSLA :  SystemContextClass.getMasterSLADetailsForSR()) {
            if(thisSLA.Category__c == Constants.SERVICE_REQUEST_TYPE_NEWSALE && thisSLA.Case_Origin__c == 'Service Request Management -ADM') {
                masterSLA = thisSLA;
                break;
            }
        }
        system.debug('masterSLA'+ masterSLA);
        if(masterSLA != null) {
            List<CaseSLA__c> slas = new List<CaseSLA__c>();
            for(ServiceRequest__c thisRequest : newList) {
                DateTime currTime = DateTime.now();
                
                DateTime dueDate = ServiceUtility.CalculateDueDate(currTime, (Integer)masterSLA.SLA_Hrs__c * 60, bussHours, holidays);
                system.debug('debug: dueDate in prepareCaseSLARecorda:' + dueDate);
                CaseSLA__c csSLA = new CaseSLA__c();
                csSLA.Service_Request__c = thisRequest.Id;
                csSLA.CaseOwner__c = thisRequest.OwnerId;
                csSLA.OwnerId = thisRequest.OwnerId;
                csSLA.StartTime__c = currTime;
                csSLA.DueTime__c = dueDate;
                csSLA.Master_SLA__c = masterSLA.Id;
                csSLA.Status__c = ServiceConstants.CaseSLA_STATUS_ONTRACK;
                csSLA.Is_Extension_Allowed__c = masterSLA.Is_Available_For_Extension__c;
                slas.add(csSLA);
            }
            
            if(!slas.isEmpty()) {
                DataBase.SaveResult[] results = DataBase.insert(slas, false);
                for(DataBase.SaveResult thisResult: results) {
                    system.debug('thisResult'+ thisResult);
                }
            }
        }
    }    
      // this is to update charge record whne selling oprice is changed.
    public static void recalculateADMChargeOnSellingPriceUpdate(List<ServiceRequest__c> newList,Map<Id, ServiceRequest__c> oldMap) {


    Set<Id> srIds = new Set<Id>();

    for (ServiceRequest__c sr : newList) {

        ServiceRequest__c oldSr = oldMap.get(sr.Id);

        if (oldSr == null)
            continue;

        if (sr.Selling_Price__c != oldSr.Selling_Price__c) {

            if (sr.Step_Order__c != null && sr.Step_Order__c <= 7) {
                srIds.add(sr.Id);
            }
        }

    }

    if (srIds.isEmpty())

        return;


    List<ServiceRequest__c> srList = [SELECT Id,Selling_Price__c,Type__c,SubType__c,RecordType.DeveloperName,UnitId__r.Phase__c,
               SalesOrder__r.TotalAmount__c FROM ServiceRequest__c WHERE Id IN :srIds];

    Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>(srList);

    List<Charge__c> chargeList = [SELECT Id,Amount__c,VAT_Amount__c,VAT_Percentage__c,Service_Request__c,Type__c FROM Charge__c
        WHERE Service_Request__c IN :srIds AND Type__c = 'ADM & Dari Fee'];

    if (chargeList.isEmpty())

        return;

    Set<String> phaseSet = new Set<String>();
    Set<String> recordTypeSet = new Set<String>();
    Set<String> subTypeSet = new Set<String>();

    for (ServiceRequest__c sr : srList) {

        if (sr.UnitId__r.Phase__c != null)
            phaseSet.add(sr.UnitId__r.Phase__c);

        if (sr.RecordType.DeveloperName != null)
            recordTypeSet.add(sr.RecordType.DeveloperName);

        if (sr.SubType__c != null)
            subTypeSet.add(sr.SubType__c);

    }

    //Build Financial Setup map exactly like createChargesOnSR

    Map<String, Financial_Setup__c> fsMap = new Map<String, Financial_Setup__c>();

    for (Financial_Setup__c fs : [SELECT Value__c,Default_Amount__c,Fee_Type__c,VAT_Percnetage__c,Phase__c,
               SR_RecordType__c,Type__c,Sub_Type__c FROM Financial_Setup__c
        WHERE Phase__c IN :phaseSet AND SR_RecordType__c IN :recordTypeSet AND Type__c = 'ADM & Dari Fee']) {

        for (String st : fs.Sub_Type__c.split(';')) {
            String key = fs.Phase__c + '-' + fs.SR_RecordType__c + '-' + st;
            fsMap.put(key, fs);
        }
    }

    // Recalculate amount using same logic

    List<Charge__c> chargesToUpdate = new List<Charge__c>();

    for (Charge__c ch : chargeList) {

        ServiceRequest__c sr = srMap.get(ch.Service_Request__c);

        if (sr == null)
            continue;

        String key = sr.UnitId__r.Phase__c + '-' + sr.RecordType.DeveloperName + '-' + sr.SubType__c;

        if (!fsMap.containsKey(key))
            continue;

        Financial_Setup__c fs = fsMap.get(key);

        Decimal sellingPrice = sr.Selling_Price__c != null ? sr.Selling_Price__c : 0;

        Decimal defaultAmount = fs.Default_Amount__c != null ? fs.Default_Amount__c : 0;

        Decimal newAmount;

        if (fs.Fee_Type__c == Constants.PERECENTAGE_BASED_CALCULATION) {

            newAmount = ((sellingPrice * fs.Value__c) / 100)+ defaultAmount;

        } else {

            newAmount = fs.Value__c;
        }

        ch.Amount__c = newAmount;

        ch.VAT_Amount__c =(fs.VAT_Percnetage__c != null) ? (newAmount * fs.VAT_Percnetage__c) / 100 : 0;

        ch.VAT_Percentage__c = fs.VAT_Percnetage__c;

        chargesToUpdate.add(ch);

    }

    if (!chargesToUpdate.isEmpty()) {

        update chargesToUpdate;

        System.debug( 'ADM charge recalculated using Financial Setup logic: '+ chargesToUpdate );

    }
}



    //Author: Chandu
	//Version:1.2  start
    //assign the service request to queue based on recordtype before insert
    public static void assignToQueue(List<ServiceRequest__c> newList) {

    Map<String, Id> recordTypeMap = new Map<String, Id>();
    
    for (RecordType rt : [
        SELECT Id, Name 
        FROM RecordType 
        WHERE SObjectType = 'ServiceRequest__c'
        AND Name IN (
            :Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION,
            :Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION
        )
    ]) {
        recordTypeMap.put(rt.Name, rt.Id);
    }

    if (recordTypeMap.isEmpty()) {
        System.debug('No matching record types found');
        return;
    }

    // Fetch both queues
    Map<String, Id> queueMap = new Map<String, Id>();

    for (Group g : [
        SELECT Id, DeveloperName 
        FROM Group 
        WHERE Type = 'Queue'
        AND DeveloperName IN ('Sales_Manager', 'CM_Manager')
    ]) {
        queueMap.put(g.DeveloperName, g.Id);
    }

    if (queueMap.isEmpty()) {
        System.debug('Queues not found');
        return;
    }

    // Assign Owner based on Record Type
    for (ServiceRequest__c sr : newList) {

        if (sr.RecordTypeId == recordTypeMap.get(Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION)) {
            sr.OwnerId = queueMap.get('Sales_Manager');
        }

        else if (sr.RecordTypeId == recordTypeMap.get(Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION)) {
            sr.OwnerId = queueMap.get('CM_Manager');
        }
    }
}
    
    //This method is to autopopulate the salesorders total paid amount of installments by the customer at the time of pre or post unit cancellation sr creation
    public static void populateTotalPaidAmount(List<ServiceRequest__c> newList) {
        
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName();
        
        Set<Id> cancellationRTIds = new Set<Id>();
        
        if (rtMap.containsKey(Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION)) {
            cancellationRTIds.add(
                rtMap.get(Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION).getRecordTypeId()
            );
        }
        
        if (rtMap.containsKey(Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION)) {
            cancellationRTIds.add(
                rtMap.get(Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION).getRecordTypeId()
            );
        }
        
        if (cancellationRTIds.isEmpty()) {
            System.debug('Record Types not found');
            return;
        }
        
        Set<Id> salesOrderIds = new Set<Id>();
        
        for (ServiceRequest__c sr : newList) {
            if (cancellationRTIds.contains(sr.RecordTypeId) && sr.SalesOrder__c != null) {
                salesOrderIds.add(sr.SalesOrder__c);
            }
        }
        
        if (salesOrderIds.isEmpty()) return;
        
        Map<Id, Decimal> soIdToPaidAmount = new Map<Id, Decimal>();
        
        List<AggregateResult> aggResults = [
            SELECT SalesOrder__c soId, SUM(InstallmentAmount__c) totalPaid
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c IN :salesOrderIds
            AND PaymentStatus__c IN ('Paid', 'Partially Paid')
            GROUP BY SalesOrder__c
        ];
        
        for (AggregateResult ar : aggResults) {
            soIdToPaidAmount.put(
                (Id) ar.get('soId'),
                (Decimal) ar.get('totalPaid')
            );
        }
        
        for (ServiceRequest__c sr : newList) {
            if (cancellationRTIds.contains(sr.RecordTypeId) && sr.SalesOrder__c != null) {
                sr.Total_Paid_Amount__c =
                    soIdToPaidAmount.containsKey(sr.SalesOrder__c)
                    ? soIdToPaidAmount.get(sr.SalesOrder__c)
                    : 0;
            }
        }
    }
	
	
    //This method is to populate the salesorder adm paid amount at the time of pre or post unit cancellation sr creation
    public static void populateADMPaidAmount(List<ServiceRequest__c> newList) {
    
    Map<String, Schema.RecordTypeInfo> rtMap =
        Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName();
    
    Set<Id> cancellationRTIds = new Set<Id>();
    
    if (rtMap.containsKey(Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION)) {
        cancellationRTIds.add(
            rtMap.get(Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION).getRecordTypeId()
        );
    }
    
    if (rtMap.containsKey(Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION)) {
        cancellationRTIds.add(
            rtMap.get(Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION).getRecordTypeId()
        );
    }
    
    if (cancellationRTIds.isEmpty()) {
        System.debug('Record Types not found');
        return;
    }
    
    Set<Id> salesOrderIds = new Set<Id>();
    
    for (ServiceRequest__c sr : newList) {
        if (cancellationRTIds.contains(sr.RecordTypeId) && sr.SalesOrder__c != null) {
            salesOrderIds.add(sr.SalesOrder__c);
        }
    }
    
    if (salesOrderIds.isEmpty()) return;
    
    Map<Id, SalesOrder__c> soMap = new Map<Id, SalesOrder__c>(
        [
            SELECT Id, Collected_ADM_Amount__c
            FROM SalesOrder__c
            WHERE Id IN :salesOrderIds
        ]
    );
    
    for (ServiceRequest__c sr : newList) {
        if (cancellationRTIds.contains(sr.RecordTypeId) && sr.SalesOrder__c != null) {
            
            SalesOrder__c so = soMap.get(sr.SalesOrder__c);
            
            if (so != null) {
                Decimal adm = so.Collected_ADM_Amount__c != null ? so.Collected_ADM_Amount__c : 0;
                
                sr.ADM_Paid_Amount__c = adm;
            } else {
                sr.ADM_Paid_Amount__c = 0;
            }
        }
    }
}
    //this method helps to execute above two methods at a time called in lwc progress indicator button named check for amounts
    @AuraEnabled
    public static void executemethodforamounts(Id srId) {
        
        List<ServiceRequest__c> srList = [
            SELECT Id, SalesOrder__c, RecordTypeId
            FROM ServiceRequest__c
            WHERE Id = :srId
        ];
        
        if (srList.isEmpty()) return;
        
        ServiceRequestTriggerHelper.populateTotalPaidAmount(srList);
        ServiceRequestTriggerHelper.populateADMPaidAmount(srList);
        
        update srList;
    }
    
	
	//This method is used to update the salesorder fields based on sr creation
    @future
    public static void markCancelUnitOnConsolidationAsync(Set<Id> salesOrderIds) {
        
        if (salesOrderIds == null || salesOrderIds.isEmpty()) return;
        
        List<Unit_Consolidation__c> ucList = [
            SELECT Id, Sales_Order__c, IsConsolidated__c
            FROM Unit_Consolidation__c
            WHERE Sales_Order__c IN :salesOrderIds
        ];
        
        if (ucList.isEmpty()) return;
        
        for (Unit_Consolidation__c uc : ucList) {
            uc.IsConsolidated__c = true;
        }
        
        update ucList;
    }
    
	
	//Auto close the step no 4 when all the approvals are completed
    public static void autoCloseStep4OnCEOApproval(List<ServiceRequest__c> newList, Map<Id, ServiceRequest__c> oldMap) {
        
        Set<Id> srIds = new Set<Id>();
        
        for (ServiceRequest__c sr : newList) {
            ServiceRequest__c oldRec = oldMap.get(sr.Id);
            
            if (oldRec != null 
                && sr.Approval_Status__c == 'Approved'
                && oldRec.Approval_Status__c != 'Approved') {
                    
                    srIds.add(sr.Id);
                }
        }
        
        if (srIds.isEmpty()) return;
        
        List<Task> step4Tasks = [
            SELECT Id, Status, WhatId, Order__c
            FROM Task
            WHERE WhatId IN :srIds
            AND Subject = 'Management Approval and Execute Unit Cancellation Process'
            AND Status != 'Closed'
        ];
        
        for (Task t : step4Tasks) {
            t.Status = 'Closed'; 
        }
        
        if (!step4Tasks.isEmpty()) {
            update step4Tasks;
        }
    }

 //Update salesorder refund field to inprogress when sr created with cancellation type
    @future
public static void updateRefundFlagAsync(Set<Id> srIds) {

    if (srIds == null || srIds.isEmpty()) return;

    List<ServiceRequest__c> srList = [
        SELECT Id, SalesOrder__c, Cancellation_Type__c
        FROM ServiceRequest__c
        WHERE Id IN :srIds
    ];

    Map<Id, SalesOrder__c> salesOrdersToUpdate = new Map<Id, SalesOrder__c>();

    for (ServiceRequest__c sr : srList) {

        if (sr.SalesOrder__c == null) continue;

        if (!salesOrdersToUpdate.containsKey(sr.SalesOrder__c)) {
            salesOrdersToUpdate.put(
                sr.SalesOrder__c,
                new SalesOrder__c(Id = sr.SalesOrder__c)
            );
        }

        SalesOrder__c so = salesOrdersToUpdate.get(sr.SalesOrder__c);

        String type = sr.Cancellation_Type__c;

        if (type == 'Cancellation with Refund' || type == 'Cancellation without Refund') {
            so.Is_Cancelled_SR__c = true;
        }
        else if (type == 'Consolidation Cancellation') {
            so.Is_Cancelled_Unit__c = true;
        }
    }

    if (!salesOrdersToUpdate.isEmpty()) {
        update salesOrdersToUpdate.values();
    }
}
    
    //This method is used to create the place holders for service request when all approvals are completed
    public static void createDocumentPlaceholders(List<ServiceRequest__c> srList){
        
        List<Documents__c> docsToInsert = new List<Documents__c>();
        
        for(ServiceRequest__c sr : srList){
            
            if(sr.RecordTypeId == null || sr.Cancellation_Type__c == null) continue;
            
            String rtName = Schema.SObjectType.ServiceRequest__c
                .getRecordTypeInfosById()
                .get(sr.RecordTypeId)
                .getName();
            
            if((rtName == 'Pre Unit Cancellation' || rtName == 'Post Unit Cancellation') &&
               sr.Cancellation_Type__c == 'Cancellation with Refund'){
                   
                   docsToInsert.add(new Documents__c(
                       Name = 'Bank Details',
                       Service_Request__c = sr.Id
                   ));
               }
            
            if(sr.Cancellation_Type__c == 'Consolidation Cancellation'){
                
                docsToInsert.add(new Documents__c(
                    Name = 'Virtual Account Docs',
                    Service_Request__c = sr.Id
                ));
            }
        }
        
        if(!docsToInsert.isEmpty()){
            insert docsToInsert;
        }
    }

      public static void generatePDFOnApproval(List<ServiceRequest__c> newList,Map<Id, ServiceRequest__c> oldMap) {
        
        Set<Id> approvedSRIds = new Set<Id>();
        
        for (ServiceRequest__c sr : newList) {
            
            ServiceRequest__c oldSR = oldMap.get(sr.Id);
            
            if (sr.Approval_Status__c == 'Approved' &&
                oldSR.Approval_Status__c != 'Approved') {
                    
                    approvedSRIds.add(sr.Id);
                }
        }
        
        if (!approvedSRIds.isEmpty()) {
            generatePDFAsync(approvedSRIds);
        }
    }
    
@future(callout=true)
public static void generatePDFAsync(Set<Id> srIds) {
    
    System.debug('PDF Triggered for SRs: ' + srIds);
    
    Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>(
        [SELECT Id, RecordType.Name FROM ServiceRequest__c WHERE Id IN :srIds]
    );
    
    List<Documents__c> docList = [
        SELECT Id, Service_Request__c, Name, Status__c
        FROM Documents__c
        WHERE Service_Request__c IN :srIds
    ];
    
    Map<Id, Documents__c> srToDocMap = new Map<Id, Documents__c>();
    
    for (Id srId : srIds) {
        
        ServiceRequest__c sr = srMap.get(srId);
        if (sr == null) continue;
        
        for (Documents__c doc : docList) {
            
            if (doc.Service_Request__c != srId) continue;
            
            if (sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION &&
                doc.Name != null && doc.Name.contains('Pre Unit')) {
                srToDocMap.put(srId, doc);
                break;
            }
            
            if (sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION &&
                doc.Name != null && doc.Name.contains('Post Unit')) {
                srToDocMap.put(srId, doc);
                break;
            }
        }
    }
    
    if (srToDocMap.isEmpty()) {
        return;
    }
    
    List<ContentVersion> contentVersions = new List<ContentVersion>();
    Map<Integer, Id> indexToSrMap = new Map<Integer, Id>();
    
    Integer index = 0;
    
    for (Id srId : srToDocMap.keySet()) {
        
        PageReference pdfPage = Page.PreUnitCancellationPDFPage;
        pdfPage.getParameters().put('id', srId);
        
        Blob pdfBlob;
        
        try {
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Dummy PDF Content');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }
        } catch (Exception e) {
            continue;
        }
        
        String fileName;
        
        if (srMap.get(srId).RecordType.Name == Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION) {
            fileName = 'Pre_Unit_' + srId + '.pdf';
        } else {
            fileName = 'Post_Unit_' + srId + '.pdf';
        }
        
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = pdfBlob;
        
        contentVersions.add(cv);
        indexToSrMap.put(index, srId);
        index++;
    }
    
    if (contentVersions.isEmpty()) {
        return;
    }
    
    insert contentVersions;
    
    List<ContentVersion> insertedVersions = [
        SELECT Id, ContentDocumentId
        FROM ContentVersion
        WHERE Id IN :contentVersions
        ORDER BY CreatedDate
    ];
    
    List<ContentDocumentLink> links = new List<ContentDocumentLink>();
    
    for (Integer i = 0; i < insertedVersions.size(); i++) {
        
        Id srId = indexToSrMap.get(i);
        
        if (!srToDocMap.containsKey(srId)) continue;
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = insertedVersions[i].ContentDocumentId;
        cdl.LinkedEntityId = srToDocMap.get(srId).Id;
        cdl.ShareType = 'V';
        
        links.add(cdl);
    }
    
    if (!links.isEmpty()) {
        insert links;
    }
    
    List<Documents__c> docsToUpdate = new List<Documents__c>();
    
    for (Documents__c doc : srToDocMap.values()) {
        doc.Status__c = 'Uploaded';
        docsToUpdate.add(doc);
    }
    
    if (!docsToUpdate.isEmpty()) {
        update docsToUpdate;
    }
} // Version 1.2 ends

}