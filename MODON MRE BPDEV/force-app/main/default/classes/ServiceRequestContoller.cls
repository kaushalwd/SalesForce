/**
* @description       : 
* @author            : ChangeMeIn@UserSettingsUnder.SFDoc
* @group             : 
* @last modified on  : 08-20-2025
* @last modified by  : Krishna Chaitanya
                                               
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Sirisha                30 Apr 2026     Updated ADM SR creation validation
* 2.0           Siva                   19 Augest 2026  Old Default Process Remove
**/
public class ServiceRequestContoller {
    
    private static final string SERVICE_REQUEST_RT_DEV_NAME_ADM { get { return 'Service_Request_Management_ADM'; } }
    private static final string SERVICE_REQUEST_RT_DEV_PE { get { return 'Request_Payment_Extension'; } }
        private static final string SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER { get { return 'Service_Request_Management_Property_Transfer_OffPlan'; } }
    private static final string SERVICE_REQUEST_UC { get { return 'Unit_Consolidation'; } }
    private static final string SERVICE_REQUEST_LPC { get { return 'LPC_Waiver'; } }
	    private static final string SERVICE_REQUEST_RT_Unit_Upgrade { get { return 'Service_Request_Management_Unit_Upgrade'; } }
private static final string SERVICE_REQUEST_RT_Unit_swap { get { return 'SRM_Unit_Swap'; } }
    private static final string SERVICE_REQUEST_RT_Default_SR { get { return 'Default_SR'; } }
 private static final string SERVICE_REQUEST_RT_Default_UNIT_CANCEL_SR { get { return 'DefaultUnitCancellation'; } }    
    public static void checkDuplicateServiceRequest(List<SObject> newList) /// testing in progress
    {
        system.debug('debug: in ServiceRequestContoller.checkDuplicateServiceRequest method');
        List<ServiceRequest__c> newSRList = (List<ServiceRequest__c>)newList;
        Set<Id> soIds = new Set<Id>();
        Set<Id> srIds = new Set<Id>();
        Set<Id> recTypeIds = new Set<Id>();
        Map<Integer, String> soSRRecTypeMap= new Map<Integer, String>();
        Integer iLoop=0;
        // Collect the SalesOrder Ids of the incoming SR
        for(ServiceRequest__c sr: newSRList)
        {
            if(sr.RecordTypeId != Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_PE) ){
                system.debug('debug: sr.SalesOrder__c ' + sr.SalesOrder__c);system.debug('debug: sr.RecordTypeId ' + sr.RecordTypeId);
                soIds.add(sr.SalesOrder__c);
                recTypeIds.add(sr.RecordTypeId);
                srIds.add(sr.Id);
                soSRRecTypeMap.put(iLoop,sr.salesorder__c + '-' + sr.RecordTypeId);
                iLoop = iLoop + 1;
            }
            if(sr.RecordTypeId == Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Unit_swap) || sr.RecordTypeId == Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Unit_Upgrade) )
                {
                 sr.Type__c='New Sale';  
                }
        }
      // Query Sales Orders to validate their status
    Map<Id, SalesOrder__c> soMap = new Map<Id, SalesOrder__c>([ SELECT Id, Status__c,CustomerAccount__r.Customer_Defaulted__c, Unit__r.Unit_Defaulted__c FROM SalesOrder__c WHERE Id IN :soIds]);

    for(ServiceRequest__c sr : newSRList)
    {
        if(sr.SalesOrder__c != null && soMap.containsKey(sr.SalesOrder__c))
        {
            SalesOrder__c so = soMap.get(sr.SalesOrder__c);
        String soStatus = so.Status__c;
            Boolean allowSR = (Label.CreateSRWithIncompleteSO == 'True');

            if(soStatus != 'Sold' && soStatus != 'Completed' && !allowSR) {
                sr.SalesOrder__c.addError('Cannot create Service request because the Sales Order status is "' + soStatus + '". Only "Sold" or "Completed" Sales Orders are allowed.');
            }
            
            Boolean isAccountDefaulted = so.CustomerAccount__r != null && so.CustomerAccount__r.Customer_Defaulted__c;
        	Boolean isUnitDefaulted = so.Unit__r != null && so.Unit__r.Unit_Defaulted__c;
            //Old Default Process Remove
/*
    if (isAccountDefaulted || isUnitDefaulted) {
    Id cancelRT = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Default_UNIT_CANCEL_SR);
    Id defaultRT = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Default_SR);

    System.debug('SR.RecordTypeId => ' + sr.RecordTypeId);
    System.debug('Cancel RT Id => ' + cancelRT);
    System.debug('Default SR RT Id => ' + defaultRT);

    // Allow only Cancel SR or Default SR
    if (sr.RecordTypeId != cancelRT && sr.RecordTypeId != defaultRT) {
        sr.SalesOrder__c.addError(
            'Service Request cannot be created because the related Account or Unit is marked as defaulted.'
        );
        continue;
    }
}
*/
    }
    }

        // Retrieve the open SRs belonging to the above SalesOrders
        List<ServiceRequest__c> openSRsList = new List<ServiceRequest__c>();
        openSRsList = [Select Id,Name,RecordTypeId,SalesOrder__c,Status__c,SR_OriginID__c,Transferred_Sales_Order__c from ServiceRequest__c 
                            where SalesOrder__c IN: soIds 
                                and Id NOT IN: srIds // We should not consider the incoming SRs again
                               
                                and Status__c != : Constants.SERVICE_REQUEST_STATUS_CANCELLED
                                and RecordTypeId IN: recTypeIds]; // Consider the RecordTypes of the incoming SRs only
     
     // if there are open SR, check if they are matching record type against each SR   
     if(openSRsList.size() > 0)
        {
            for(Integer iLoopVar: soSRRecTypeMap.keyset())
            {
                system.debug('debug: iLoopVar ' + iLoopVar);
                for(ServiceRequest__c sr: openSRsList)
                {
                    system.debug('debug: soSRRecTypeMap.get(iLoopVar) ' + soSRRecTypeMap.get(iLoopVar));
                    system.debug('debug: sr.SalesOrder__c ' + sr.SalesOrder__c);system.debug('debug: sr.RecordTypeId ' + sr.RecordTypeId);
                    if(soSRRecTypeMap.get(iLoopVar) == sr.SalesOrder__c + '-' + sr.RecordTypeId)
                    {
                        system.debug('debug: found duplicate record');
                        for(ServiceRequest__c currSR: newSRList)
                        {
                            if(sr.SalesOrder__c != null && currSR.SalesOrder__c == sr.SalesOrder__c && currSR.RecordTypeId == sr.RecordTypeId){
                               
                                 Id admRecTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,SERVICE_REQUEST_RT_DEV_NAME_ADM);
                                 Id defaultRecId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,SERVICE_REQUEST_RT_Default_SR);
                                 Id PTORecId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);
                                 Id PERecId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,SERVICE_REQUEST_RT_DEV_PE);
                                 Id UCRecId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,SERVICE_REQUEST_UC);
                                 Id LPCRecId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,SERVICE_REQUEST_LPC);

								
							// version 1.0 start                            
                            if(sr.RecordTypeId == admRecTypeId){
                                

                            //  Check duplicate via SR_OriginID__c (Property Transfer scenario)
                            if (currSR.SR_OriginID__c != null && sr.SR_OriginID__c == currSR.SR_OriginID__c) {
                                currSR.SalesOrder__c.addError(
                                  System.Label.ADM_SR_PropertyTransfer_Duplicate
                                );
                            }
                        
                            // Check duplicate via SalesOrder (only when Transferred SO is null and SO is Completed)
                            else if (
                                currSR.SalesOrder__c != null &&
                                currSR.SalesOrder__c == sr.SalesOrder__c &&
                                currSR.Transferred_Sales_Order__c == null &&
                                soMap.containsKey(currSR.SalesOrder__c) &&
                                soMap.get(currSR.SalesOrder__c).Status__c == 'Completed'
                            ) {
                                currSR.SalesOrder__c.addError(
                                   System.Label.ADM_SR_SalesOrder_Duplicate
                                );
                            }
                        
                                                   
                                //currSR.SalesOrder__c.addError('This ADM request cannot be created because a related Service Request (SR) already exists:' + sr.Name);
                                
                            } // version 1.0 end  
                            else if (((sr.RecordTypeId <> admRecTypeId && sr.Status__c != Constants.SERVICE_REQUEST_STATUS_CLOSED) && (sr.Status__c !=  Constants.SERVICE_REQUEST_STATUS_CANCELLED) && (sr.RecordTypeId == defaultRecId && sr.Status__c != Constants.SERVICE_REQUEST_STATUS_CLOSED_PAID)) || 
                                    (
                                        sr.RecordTypeId == defaultRecId &&
                                        sr.Status__c != Constants.SERVICE_REQUEST_STATUS_CLOSED
                                    ))
                            {
                                currSR.SalesOrder__c.addError('Cannot create this request as there is already an open request:' + sr.Name);
                            }else if((sr.RecordTypeId == PTORecId || sr.RecordTypeId == PERecId || sr.RecordTypeId == UCRecId || sr.RecordTypeId == LPCRecId) && sr.Status__c != Constants.SERVICE_REQUEST_STATUS_CLOSED && sr.Status__c !=  Constants.SERVICE_REQUEST_STATUS_CANCELLED){
                                currSR.SalesOrder__c.addError('This SR request cannot be created because a related Service Request (SR) already exists:' + sr.Name);

                            }
                            
                            }
                        }
                    }
                }
            }
        }
    }
    
    /*public static void checkSalesOrderStatusForSRCreation(List<SObject> newList)
    {system.debug('debug: in ServiceRequestContoller.checkSalesOrderStatusForSRCreation method');
        List<ServiceRequest__c> newSRList = (List<ServiceRequest__c>)newList;
        Set<Id> soIds = new Set<Id>();
        List<SalesOrder__c> soList = new List<SalesOrder__c>();
     
        for(ServiceRequest__c sr: newSRList)
        {
            soIds.add(sr.SalesOrder__c);
            //system.debug('debug: sr.SalesOrder__r.Status : ' + sr.SalesOrder__r.Status);
        }
     
        soList = [Select Id,Name,Status__c from SalesOrder__c where Id IN: soIds];
        
        for(ServiceRequest__c sr: newSRList)
        {
            for(SalesOrder__c so: soList)
            {
                if(sr.SalesOrder__c == so.Id && so.Status__c == Constants.SALESORDER_STATUS_NEW)
                {
                    //sr.SalesOrder__c.addError('Not allowed to create Service Requests on the ' + );
                }
            }
        }
        
    }*/
    
    public static void updateAccUnitOnOffPlanSR(List<SObject> newList)
    {
        List<ServiceRequest__c> newSRList = (List<ServiceRequest__c>)newList;
        Set<Id> soIds = new Set<Id>();
        List<SalesOrder__c> soList = new List<SalesOrder__c>();
        Map<Id, Id> srSOMap = new Map<Id, Id>(); // ServiceRequest__c.Id, SalesOrder__c.Id
        Map<Id, SalesOrder__c> soMap = new Map<Id, SalesOrder__c>();
        for(ServiceRequest__c sr: newSRList)
        {
            if(sr.SalesOrder__c != null)
            {
                soIds.add(sr.SalesOrder__c);
                srSOMap.put(sr.Id, sr.SalesOrder__c);
            }
        }
        if(soIds.size() > 0)
        {
            soList = [Select Id, name,CustomerAccount__c,Unit__c,Unit__r.Phase__r.Project__c from SalesOrder__c where id in: soIds];
            for(SalesOrder__C so: soList)
            {
                soMap.put(so.Id, so);
            }
        }
        for(ServiceRequest__c sr: newSRList)
        {
            if(sr.SalesOrder__c != null)
            {
                SalesOrder__c so = soMap.get(srSOMap.get(sr.Id));
                sr.AccountId__c = so.CustomerAccount__c;
                sr.UnitId__c = so.Unit__c;
                sr.ProjectId__c = so.Unit__r.Phase__r.Project__c;
                sr.Finance_Approval_Status__c = 'Draft';
            }
        }
    }

    @AuraEnabled
    public static void updateSOInstallmentOnLPCSR(List<ServiceRequest__c> newList) {
     Set<Id> chargeIds = new Set<Id>();
        for (ServiceRequest__c sr : newList) {
            if (sr.Charge__c != null) {
                chargeIds.add(sr.Charge__c);
            }
        }

        // Fetch related Charge records
        Map<Id, Charge__c> chargeMap = new Map<Id, Charge__c>(
            [SELECT Id, Amount__c FROM Charge__c WHERE Id IN :chargeIds]
        );

        // Set LPC amount from Charge
        for (ServiceRequest__c sr : newList) {
            if (sr.Charge__c != null && chargeMap.containsKey(sr.Charge__c)) {
                sr.LPC_Amount__c = chargeMap.get(sr.Charge__c).Amount__c;
            }
        }
    }

    
    public static void createNewServiceReuest(List<SObject> newList, String sObjectName){
        Id admrRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        List<ServiceRequest__c> ServiceRequestToCreate = new List<ServiceRequest__c>();
        List<ContentDocumentLink> oldContentDoclinkList = new List<ContentDocumentLink>();
        List<Documents__c> oldDocList = new List<Documents__c>();
        Set<Id> parentId = new Set<Id>();
        Set<Id> SalesOrderId= new Set<Id>();
        List<Documents__c> newDocList = new List<Documents__c>();
        string ObjType='Service Requests';
        string RectypName=Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM;
        List<ContentDocumentLink> conClone = new List<ContentDocumentLink>();
        Set<Id> parentSRId = new Set<Id>();
        Id unitId; 
        List<Id>oppId = new List<Id>();
        for(ServiceRequest__c sr:(List<ServiceRequest__c>)newList){
            
            ServiceRequest__c clonedSr = sr.clone(false, true, false, false);
            
            // Set the cloned record's Record Type and other fields
            clonedSr.RecordTypeId = admrRecordTypeId;
            clonedSr.Status__c = 'New';
            clonedSr.Name__c=  'ADM Registration SR - '+sr.Unit_Name__c+' - '+sr.Type__c; 
            clonedSr.SR_OriginID__c=sr.Id;
            clonedSr.ProjectId__c=sr.ProjectId__c;
            System.debug('recordtype--->'+sr.RecordTypeName__c);
            string recordtype=sr.RecordTypeName__c;
             String result;
            if (recordtype.contains('-')) {
                String[] parts = recordtype.split('-');
                 result = parts[1].trim();
                
            } else {
              result = recordtype;
            }
                        System.debug('recordtype--->'+result);
				
            clonedSr.Source_Of_SR__c=result;
            System.debug('  clonedSr.Source_Of_SR__c'+clonedSr.Source_Of_SR__c);
            if(sr.Transferred_Sales_Order__c <>  null){
              clonedSr.SalesOrder__c = sr.Transferred_Sales_Order__c;  
            }else{
                clonedSr.SalesOrder__c =sr.SalesOrder__c;
            }
            if(sr.Transferred_SO_Account__c <> null){
            clonedSr.AccountId__c=sr.Transferred_SO_Account__c;
            }else{
                clonedSr.AccountId__c=sr.AccountId__c;
            }
             if(sr.Transferred_SO_Opp__c <> null){
            clonedSr.OpportunityId__c=sr.Transferred_SO_Opp__c;
                 oppId.add(sr.Transferred_SO_Opp__c);
             }else{
                 clonedSr.OpportunityId__c=sr.OpportunityId__c; 
             }
           
            clonedSr.UnitId__c=sr.UnitId__c;
            unitId =sr.UnitId__c;
            
            clonedSr.SubType__c=null;
            // Add the cloned record to the list
            ServiceRequestToCreate.add(clonedSr);
            
            //SalesOrderId.add(sr.Transferred_Sales_Order__c);
            parentSRId.add(sr.Id);
            
        }            
        
        List<JointOwner__c> joOldList =[SELECT Id,JointOwnerAccount__c,OwnershipPercentage__c,RelationshipSubType__c,RelationshipType__c,Service_Request__c,SalesOrder__c from JointOwner__c Where Service_Request__c =: parentId];
        
       // List<Prospect_Account__c> oldProacc =[SELECT Id,Service_Request__c FROM Prospect_Account__c WHERE Service_Request__c =: parentId];
        System.debug('ServiceRequestToCreate-->'+ServiceRequestToCreate);
        /*if(parentId.size() >0 && !parentId.isEmpty()){
oldDocList=[SELECT Id,Name,Service_Request__c from Documents__c Where Service_Request__c = : parentId];
}
set<Id> olddocId = new set<Id>();
for(Documents__c oldDoc:oldDocList){
olddocId.add(oldDoc.Id);
}

if(oldDocList.size()>0 && !oldDocList.isEmpty()){
oldContentDoclinkList = [SELECT ContentDocumentId,ContentDocument.Title, 
ContentDocument.ContentModifiedDate, ContentDocument.ContentSize,LinkedEntity.Name FROM 
ContentDocumentLink WHERE LinkedEntityId IN :olddocId];
}


List<DocumentType__c> docTypeList = getDocumentTypeList(ObjType,RectypName);

*/
        Database.saveResult[] srList;
        System.debug('ServiceRequestToCreate---->'+ServiceRequestToCreate);
        if(ServiceRequestToCreate.size()>0 && !ServiceRequestToCreate.isEmpty()){
            srList = Database.insert(ServiceRequestToCreate,false);
            System.debug('srList---'+srList);
            /* for(Database.saveResult sr:srList){

if(docTypeList.size()>0 && !docTypeList.isEmpty()){
for(DocumentType__c dt:docTypeList){
Documents__c d=new Documents__c();
d.Name = dt.Type__c;
d.Status__c='Pending Upload';
d.Service_Request__c=sr.getId();

newDocList.add(d);
}

}       
}*/
            
        }
        List<Unit__c> untList = new List<Unit__c>();
        
        if(oppId !=null && oppId.size()>0 && !oppId.isEmpty()){
         unit__c u=new unit__c();
            u.Id=unitId;
            u.Opportunity__c=oppId[0];
            untList.add(u);
        }
        if(untList.size()>0 && !untList.isEmpty()){
        update untList;
        }
        List<JointOwner__c> newJoList = new List<JointOwner__c>();
        if(srList != null)
        { 
        for(Database.saveResult sr:srList){
            if(joOldList.size()>0 && !joOldList.isEmpty()){
                for(JointOwner__c j:joOldList){
                    JointOwner__c clonedJo = j.clone(false, true, false, false);
                    clonedJo.Service_Request__c=sr.getId();
                    newJoList.add(clonedJo);
                }
            }
        }
        }
        
        if(!newJoList.isEmpty() && newJoList.size()>0){
            insert newJoList;
        }
        
        /* set<Id> setOfDocIds= new set<Id>();
if(newDocList.size() > 0 && !newDocList.isEmpty()){
Database.saveResult[] srdocList = Database.insert(newDocList,false);

if(srdocList.size() >0 && !srdocList.isEmpty()){
for(Database.saveResult sr:srdocList){
System.debug('setOfDocIds--->'+setOfDocIds+'Docssss'+sr.getId());
setOfDocIds.add(sr.getId());

}   
}
}*/
        
        /*   Map<String,Documents__c> docMap = new Map<String,Documents__c>();
List<Documents__c> docNewList =[SELECT Id,Name FROM Documents__c WHERE Id IN :setOfDocIds];
for(Documents__c dcNew:docNewList){
docMap.put(dcNew.Name,dcNew);
}
for(ContentDocumentLink cdl:oldContentDoclinkList){
if(docMap.containsKey(cdl.LinkedEntity.Name)){
ContentDocumentLink newclnk = cdl.clone();
newclnk.LinkedEntityId =  docMap.get(cdl.LinkedEntity.Name).Id;
newclnk.ShareType = 'V';
conClone.add(newclnk);

}
}    
insert conClone; */
        
    }
    
    /*private static List<DocumentType__c> getDocumentTypeList(string ObjType,String RectypName){
List<DocumentType__c> docTypeList = [SELECT Id,RecordTypeDevName__c,Type__c,ObjectType__c  From DocumentType__c 
WHERE ObjectType__c=:ObjType AND RecordTypeDevName__c =:RectypName];
return docTypeList;
}*/
    
    public static void updatePenality(List<ServiceRequest__c> newList,List<ServiceRequest__c> oldList){
        for(ServiceRequest__c sr:newList){
            if(sr.SalesOrder_Completed_Date__c < sr.Dari_Application_Submitted_Date__c){
                
                sr.Penality_Charge__c=true;
                System.debug('sr--->'+sr);
            }else {
                sr.Penality_Charge__c=false;
            }
        }
    }

    public static void updateSOInstallmentOnPESR(List<ServiceRequest__c> newList){
        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>();
        Map<Id, Id> soToInstallmentMap = new Map<Id, Id>();
        Map<Id, Date> srToPEDate = new Map<Id, Date>();
        
        for (ServiceRequest__c sr : newList) {
            if (sr.SalesOrder__c != null && sr.Payment_Extension_Date__c != null && sr.Sales_Order_Installment__c != null) {
                soToInstallmentMap.put(sr.SalesOrder__c, sr.Sales_Order_Installment__c);
                srMap.put(sr.Id, sr);
                srToPEDate.put(sr.Id, sr.Payment_Extension_Date__c);
            }
        }

        ServiceRequest__c[] srList = [SELECT Id, SalesOrder__c, Payment_Extension_Date__c, Sales_Order_Installment__c FROM ServiceRequest__c WHERE SalesOrder__c IN :soToInstallmentMap.keySet() AND RecordTypeName__c = 'Request Payment Extension'];
        if(srList.size() > 0) {
            for (ServiceRequest__c sr : srList) {
                if (sr.SalesOrder__c != null && sr.Payment_Extension_Date__c != null && sr.Sales_Order_Installment__c == soToInstallmentMap.get(sr.SalesOrder__c)) {
                    newList[0].addError('Payment Extension can be requested only once per Installment');
                }
            }
        }
        
        if (!soToInstallmentMap.isEmpty()) {
            List<SalesOrderInstallments__c> allInstallments = [
                SELECT Id, MilestoneDate__c, PaymentStatus__c, InstallmentAmount__c, MilestoneNumber__c, SalesOrder__c
                FROM SalesOrderInstallments__c
                WHERE SalesOrder__c IN :soToInstallmentMap.keySet()
                ORDER BY MilestoneNumber__c
            ];
        
            // Group installments by SalesOrder
            Map<Id, List<SalesOrderInstallments__c>> installmentsBySO = new Map<Id, List<SalesOrderInstallments__c>>();
            for (SalesOrderInstallments__c soi : allInstallments) {
                if (!installmentsBySO.containsKey(soi.SalesOrder__c)) {
                    installmentsBySO.put(soi.SalesOrder__c, new List<SalesOrderInstallments__c>());
                }
                installmentsBySO.get(soi.SalesOrder__c).add(soi);
            }
        
            for (ServiceRequest__c sr : newList) {
                if (sr.SalesOrder__c != null && sr.Payment_Extension_Date__c != null && sr.Sales_Order_Installment__c != null) {
                    List<SalesOrderInstallments__c> installmentList = installmentsBySO.get(sr.SalesOrder__c);
                    if (installmentList == null) continue;
        
                    Integer currentMilestone = 0;
                    for (SalesOrderInstallments__c soi : installmentList) {
                        if (soi.Id == sr.Sales_Order_Installment__c) {
                            currentMilestone = Integer.valueOf(soi.MilestoneNumber__c);
                            break;
                        }
                    }
        
                    Integer nextMilestone = currentMilestone + 1;
                    Date nextMilestoneDate;
        
                    for (SalesOrderInstallments__c soi : installmentList) {
                        if (soi.MilestoneNumber__c == nextMilestone) {
                            nextMilestoneDate = soi.MilestoneDate__c;
                            break;
                        }
                    }
        
                    if (nextMilestoneDate != null && sr.Payment_Extension_Date__c >= nextMilestoneDate) {
                        sr.addError('Payment Extension Date cannot be greater than the next installment date');
                    }
                }
            }
        }        
    }
    
    // Method to handle ServiceRequest closure
    public static void serviceRequestClosed(List<ServiceRequest__c> newList, List<ServiceRequest__c> oldList) {
        System.debug('debug: in ServiceRequestController.serviceRequestClosed method');
        String brokerRecordTypeID = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Broker Registration').getRecordTypeId();
                String milestoneUpdateRTId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get('Service_Request_Milestone_Update').getRecordTypeId();
        if (newList.size() > 0) {
            List<ServiceRequest__c> newSRList = new List<ServiceRequest__c>();
            
            Set<String> serviceRequestForClosureSetString = new Set<String>();
            
            // Collect all ServiceRequests that are closed
            for (ServiceRequest__c newRec : newList) {
                ServiceRequest__c oldRec = null;
                // Find the corresponding old record from oldList based on Id
                for (ServiceRequest__c oldServiceRequest : oldList) {
                    if (oldServiceRequest.Id == newRec.Id) {
                        oldRec = oldServiceRequest;
                        break;
                    }
                }
                
                System.debug('debug: oldRec.Id:' + (oldRec != null ? oldRec.Id : 'null'));
                System.debug('debug: oldRec.Status__c:' + (oldRec != null ? oldRec.Status__c : 'null'));
                
                // Check if the status changed to 'closed' and if the status actually changed
                if (oldRec != null && (oldRec.Status__c != newRec.Status__c) && (newRec.Status__c == 'closed') && newRec.RecordTypeId != brokerRecordTypeID) {
                    serviceRequestForClosureSetString.add(newRec.Id);
                }
            }

            if (!serviceRequestForClosureSetString.isEmpty()) {
                // Call the method to send a request to Xibo 
               // sendRequestToXiboApi.getSurvey_Future(serviceRequestForClosureSetString, 'ServiceRequest__c');// uncomment this after prod deployment
               //sendRequestToXiboApiold.getSurvey_Future(serviceRequestForClosureSetString, 'ServiceRequest__c');
                //InvokeSMSApiProcess.sendSMRequest(serviceRequestForClosureSetString,'ServiceRequest__c');// uncomment this after prod deployment
                sendRequestToXiboApi.getSurvey_Future(serviceRequestForClosureSetString, 'ServiceRequest__c');
                                // ONLY FOR MILESTONE UPDATE RECORD TYPE
                
                
                List<ServiceRequest__c> milestoneSRs = [ SELECT Id, Milestone__c FROM ServiceRequest__c WHERE Id IN :serviceRequestForClosureSetString
                                                        AND RecordTypeId = :milestoneUpdateRTId];
                system.debug('milestoneSRs'+ milestoneSRs);
                
                if (milestoneSRs.isEmpty()) return;
                
                Set<Id> milestoneInstallmentIds = new Set<Id>();
                
                for (ServiceRequest__c sr : milestoneSRs) {
                    if (sr.Milestone__c != null) {
                        milestoneInstallmentIds.add(sr.Milestone__c);
                    }
                }
                
                if (milestoneInstallmentIds.isEmpty()) return;
                
                List<SalesOrderInstallments__c> soiList = [ SELECT Id,Milestone_Installment__c,SalesOrder__r.CustomerAccount__r.IsPersonAccount,SalesOrder__r.CustomerAccount__r.PersonEmail,
                                                           SalesOrder__r.PrimaryContact__r.Email FROM SalesOrderInstallments__c WHERE Milestone_Installment__c IN :milestoneInstallmentIds ];
                
                Map<Id, List<SalesOrderInstallments__c>> milestoneToSOIMap = new Map<Id, List<SalesOrderInstallments__c>>();
                
                for (SalesOrderInstallments__c soi : soiList) {
                    if (!milestoneToSOIMap.containsKey(soi.Milestone_Installment__c)) {
                        milestoneToSOIMap.put(soi.Milestone_Installment__c,
                                              new List<SalesOrderInstallments__c>());
                    }
                    milestoneToSOIMap.get(soi.Milestone_Installment__c).add(soi);
                }
                
                // Loop SRs
                for (ServiceRequest__c sr : milestoneSRs) {
                    
                    List<SalesOrderInstallments__c> relatedSOIs =
                        milestoneToSOIMap.get(sr.Milestone__c);
                    
                    if (relatedSOIs == null) continue;
                    
                    // Collect unique emails per SR
                    Set<String> emailSet = new Set<String>();
                    
                    for (SalesOrderInstallments__c soi : relatedSOIs) {
                        
                        String recipientEmail;
                        
                        // Person Account
                        if (soi.SalesOrder__r.CustomerAccount__r != null && soi.SalesOrder__r.CustomerAccount__r.IsPersonAccount &&
                            String.isNotBlank(soi.SalesOrder__r.CustomerAccount__r.PersonEmail)) {
                                    
                                    recipientEmail =soi.SalesOrder__r.CustomerAccount__r.PersonEmail;
                                }
                        // Organization / Broker
                        else if (soi.SalesOrder__r.PrimaryContact__r != null && String.isNotBlank(soi.SalesOrder__r.PrimaryContact__r.Email)) {
                                         
                                         recipientEmail = soi.SalesOrder__r.PrimaryContact__r.Email;
                                     }
                        
                        if (String.isNotBlank(recipientEmail)) {
                            emailSet.add(recipientEmail);
                            System.debug('emailSet'+ emailSet);
                        }
                    }
                    
                  for (String email : emailSet) {

        System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.SREMAIL_MMILESTONE_UPDATE,email,
                'customercare@modon.com','Customer Care', null,null,'Milestone Update','Customer Management',null,null,sr.Id));
                }
            }
            }
        }
    }
    
   /*public static void blockSRCreationForDefaulters(List<SObject> newList) {
    System.debug('debug: in blockSRCreationForDefaulters method');
    
    List<ServiceRequest__c> srList = (List<ServiceRequest__c>) newList;
    
    Set<Id> unitIds = new Set<Id>();
    for (ServiceRequest__c sr : srList) {
        if (sr.UnitId__c != null) {
            unitIds.add(sr.UnitId__c);
        }
    }

    // Query for defaulted units
    Map<Id, Unit__c> defaultedUnits = new Map<Id, Unit__c>(
        [SELECT Id, Name, Unit_Defaulted__c FROM Unit__c WHERE Id IN :unitIds AND Unit_Defaulted__c = true]
    );

    // Query existing open Default SRs for these units
    Map<Id, ServiceRequest__c> openDefaultSRMap = new Map<Id, ServiceRequest__c>();
    for (ServiceRequest__c sr : [
        SELECT Id, UnitId__c, Status__c, SR_Type__c 
        FROM ServiceRequest__c 
        WHERE UnitId__c IN :unitIds AND SR_Type__c = 'Default_SR' AND Status__c != 'Closed'
    ]) {
        openDefaultSRMap.put(sr.UnitId__c, sr);
    }

    for (ServiceRequest__c sr : srList) {
        if (sr.UnitId__c != null && defaultedUnits.containsKey(sr.UnitId__c)) {

            // Case 1: Trying to create a non-default SR for a defaulted unit
            if (sr.SR_Type__c != 'Default_SR') {
                sr.UnitId__c.addError('Cannot create this type of Service Request as the unit/Account is defaulted.');
                continue;
            }

            // Case 2: Trying to create Default_SR but one is already open
            if (openDefaultSRMap.containsKey(sr.UnitId__c)) {
                sr.UnitId__c.addError('An open Default_SR already exists for this unit. Please close it before creating a new one.');
            }
        }
    }
}*/


}