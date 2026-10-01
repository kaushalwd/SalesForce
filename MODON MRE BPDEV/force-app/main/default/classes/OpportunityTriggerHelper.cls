/**********************************************************************************************************************
* Name               : OpportunityTriggerHelper                                                        
* Description        : This class is used as a helper for opportunity trigger
* Usage              : Called from OpportunityTriggerHandler

* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           abdallah.hdaib@pwc.com         19 Dec 2023     Initial Draft       
* 2.0           Manoj.v						26 Oct 2025		Update encryptedMapping
* 2.1           Arvind                          13 May 2026     SLA Start Time for Broker Portal — sets SLA_Start_Time__c when Opportunity owner changes to Sales Management profile
******************************************************************************************************************/
public without sharing class OpportunityTriggerHelper {
    
   // Commented by Naga - Not able to find any reference in the OpportunityTriggerHandler Class
   /* public static void setOwner(list<SObject> newList, Map<Id, SObject> oldMap){ // Call this Before Insert and Before Update
    
        //list<Group> vipManagementGrp = [select Id, DeveloperName, Type from Group where Type = 'Queue' and DeveloperName = 'VIP_Managers'];
        list<User> VIPOwner = [Select Id, username from User where username =: label.VIP_Customer_Assignment_User];


        for(Opportunity newOpp : (List<Opportunity>)newList){

                if(oldMap == null){
                    if(VIPOwner <> null && !VIPOwner.isEmpty() && (newOpp.CustomerType__c == Constants.CUSTOMER_TYPE_VIP || newOpp.CustomerType__c == Constants.CUSTOMER_TYPE_VVIP))
                    newOpp.OwnerId = VIPOwner[0].Id;
                }

                Opportunity oldRecord;
                if(oldMap <> null){
                    oldRecord = (Opportunity)oldMap.get(newOpp.Id);
                    if(VIPOwner <> null && !VIPOwner.isEmpty() && ( (newOpp.CustomerType__c == Constants.CUSTOMER_TYPE_VIP && newOpp.CustomerType__c <> oldRecord.CustomerType__c) || (newOpp.CustomerType__c == Constants.CUSTOMER_TYPE_VVIP && newOpp.CustomerType__c <> oldRecord.CustomerType__c)))
                    newOpp.OwnerId = VIPOwner[0].Id;
                }
        }
    } */

    // public static void transferDocumentFromLeads(List<sObject> newList){
    //     set<Id> oppIds = new set<Id>();
    //     for(Opportunity oppObj : (List<Opportunity>)newList){
    //         oppIds.add(oppObj.Id);
    //     }

    //     List<Documents__c> docLst = [SELECT Id, Lead__r.convertedOpportunityId FROM Documents__c WHERE Lead__r.convertedOpportunityId IN : oppIds AND Name IN ('Passport Copy','Emirates ID')];
    //     for(Documents__c docObj : docLst){
    //         docObj.Opportunity__c = docObj.Lead__r.convertedOpportunityId;
    //         docObj.Lead__c = null;
    //     }
    //     if(!docLst.isEmpty()){
    //         UPDATE docLst;
    //     }
    // }

    public static void createDocumentRecords(List<SObject> newList){ // call this After Insert.
        
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Opportunity');
        if(!lstDocumentsCurrent.isEmpty()){
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(Opportunity oppObj : (List<Opportunity>)newList){
                for(Documents__c doc: lstDocumentsCurrent){
                    Documents__c tempD = doc.clone();
                    tempD.Opportunity__c = oppObj.Id;
                    lstDocumentsToInsert.add(tempD);
                }
            }
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
    }

    public static void createDocumentRecordsForEgypt(List<SObject> newList){ // call this After Insert.
        
        // List to hold documnet we will insert
        list<Documents__c> documentsToInsert = new list<Documents__c>();

        //Get Document for both account type
        list<Documents__c> egyptianPersonAccountDocumentList  = DocumentsUtility.getEgyptDocumentsForSObject('EgyptianPersonAccount' , 'Modon - Egypt');
        list<Documents__c> nonEgyptianPersonAccountDocumentList  = DocumentsUtility.getEgyptDocumentsForSObject('NonEgyptianPersonAccount' , 'Modon - Egypt');
        list<Documents__c> organizationAccountDocumentList = DocumentsUtility.getEgyptDocumentsForSObject('OrganizationAccount' , 'Modon - Egypt');

        
        List<Opportunity> oppList = (List<Opportunity>)newList;

        //Collect all related AccountIds from the Opportunities
        Set<Id> relatedAccountIds = new Set<Id>();
        for(Opportunity opp : oppList){
            if(opp.AccountId != null){
                relatedAccountIds.add(opp.AccountId);
            }
        }

        //Query Account with RecordType
        Map<Id,Account> accountMap = new Map<Id,Account>([SELECT Id, RecordType.DeveloperName , Nationality__pc From Account Where Id IN :relatedAccountIds]);
        
        //Loop through each opportunity and create documnet records accordingly
        for(Opportunity opp : oppList){
            if(opp.AccountId == null || !accountMap.containsKey(opp.AccountId)) continue; // Skip if no related account found in map
            Account acc = accountMap.get(opp.AccountId);
            List<Documents__c> selectedDocs;

            // Determine which documnet to use based on account record type
            if(acc.RecordType != null && acc.RecordType.DeveloperName == 'PersonAccount' && acc.Nationality__pc == 'Egypt'){
                selectedDocs = egyptianPersonAccountDocumentList;
            }else if(acc.RecordType != null && acc.RecordType.DeveloperName == 'PersonAccount' && acc.Nationality__pc != 'Egypt'){
                selectedDocs = nonEgyptianPersonAccountDocumentList;
            }else if(acc.RecordType != null && acc.RecordType.DeveloperName == 'OrganizationAccount'){
                selectedDocs = organizationAccountDocumentList;
            }else{
                continue; // Skip if account record type doesn't match expected values
            }

            for(Documents__c doc : selectedDocs){
                Documents__c tempDoc = doc.clone();
                tempDoc.Opportunity__c = opp.Id;
                documentsToInsert.add(tempDoc);
            }
        }
        if(!documentsToInsert.isEmpty()){
            insert documentsToInsert;
        }
    }

    public static void updateContactDetails(List<SObject> newList,Map<Id, SObject> oldMap){ 
        map<id,Contact> contactMap = new map<id,Contact>();
        
        for(Opportunity opportunityRecord : (List<Opportunity>)newList){
            Opportunity oldOpportunity = (Opportunity) oldMap.get(opportunityRecord.Id);
            if(opportunityRecord.PrimaryContact__c!=null && (opportunityRecord.EIDNumber__c != oldOpportunity.EIDNumber__c ||
                                                            opportunityRecord.EmiratesIDExpiryDate__c  != oldOpportunity.EmiratesIDExpiryDate__c  ||
                                                            opportunityRecord.PassportNumber__c  != oldOpportunity.PassportNumber__c  ||
                                                            opportunityRecord.PassportIssueDate__c  != oldOpportunity.PassportIssueDate__c  ||
                                                            opportunityRecord.PassportExpiryDate__c  != oldOpportunity.PassportExpiryDate__c ||
                                                            opportunityRecord.UAE_Resident_Status__c != oldOpportunity.UAE_Resident_Status__c) ) {
                contactMap.put(opportunityRecord.PrimaryContact__c,null );
            }
        }
        if(!contactMap.isEmpty()){
            contactMap = new map<id,Contact>([select id,EIDNumber__c,EmiratesIDExpiryDate__c,PassportNumber__c,PassportIssueDate__c,PassportExpiryDate__c, UAE_Resident_Status__c from contact where id in :contactMap.keySet() ]);
        	list<Contact> contactListToUpdate = new list<Contact>();
            for(Opportunity opportunityRecord : (List<Opportunity>)newList){
            	if(opportunityRecord.PrimaryContact__c!=null && contactMap.containsKey(opportunityRecord.PrimaryContact__c) && (contactMap.get(opportunityRecord.PrimaryContact__c).EIDNumber__c ==null ||
                  																												contactMap.get(opportunityRecord.PrimaryContact__c).EmiratesIDExpiryDate__c ==null ||
                                                                                                                                contactMap.get(opportunityRecord.PrimaryContact__c).PassportNumber__c ==null ||
                                                                                                                                contactMap.get(opportunityRecord.PrimaryContact__c).PassportIssueDate__c ==null ||
                                                                                                                                contactMap.get(opportunityRecord.PrimaryContact__c).PassportExpiryDate__c ==null ||
                                                                                                                               contactMap.get(opportunityRecord.PrimaryContact__c).UAE_Resident_Status__c ==null) ){
                	Contact contactRecordToUpdate = new Contact(Id = opportunityRecord.PrimaryContact__c);
                    if(contactMap.get(opportunityRecord.PrimaryContact__c).EIDNumber__c ==null ){contactRecordToUpdate.EIDNumber__c = opportunityRecord.EIDNumber__c; }
					if(contactMap.get(opportunityRecord.PrimaryContact__c).EmiratesIDExpiryDate__c ==null ){contactRecordToUpdate.EmiratesIDExpiryDate__c = opportunityRecord.EmiratesIDExpiryDate__c; }
					if(contactMap.get(opportunityRecord.PrimaryContact__c).PassportNumber__c ==null ){contactRecordToUpdate.PassportNumber__c = opportunityRecord.PassportNumber__c; }
					if(contactMap.get(opportunityRecord.PrimaryContact__c).PassportIssueDate__c ==null ){contactRecordToUpdate.PassportIssueDate__c = opportunityRecord.PassportIssueDate__c; }
					if(contactMap.get(opportunityRecord.PrimaryContact__c).PassportExpiryDate__c ==null ){contactRecordToUpdate.PassportExpiryDate__c = opportunityRecord.PassportExpiryDate__c; }
                    if(contactMap.get(opportunityRecord.PrimaryContact__c).UAE_Resident_Status__c ==null ){contactRecordToUpdate.UAE_Resident_Status__c = opportunityRecord.UAE_Resident_Status__c; }
                	contactListToUpdate.add(contactRecordToUpdate);                                                                                                                     
            	}
                  
            }
            if(!contactListToUpdate.isEmpty()){
                Database.DMLOptions dml = new Database.DMLOptions(); 
                dml.DuplicateRuleHeader.AllowSave = true;
                Database.update(contactListToUpdate, dml);
            	//update contactListToUpdate;    
        	}
        }
            
        
        
        
        
    }
    

    public static void updateOppName(List<SObject> newList){
        for(Opportunity oppObj : (List<Opportunity>)newList ){
            String dd = String.valueOf(System.today().day());
            String mm = String.valueOf(System.today().month());
            String yy = String.valueOf(System.today().year());
            String dtString = (dd.length() == 1 ? '0': '') + dd + (mm.length() == 1 ? '0': '') + mm + yy.right(2);
            if(String.isNotBlank(oppObj.Name) && oppObj.Name.endsWith('-')){
                oppObj.Name += dtString;
            }else{
                oppObj.Name += ('-' + dtString);
            }
        }
    }
    /*public static void updateOppName(List<SObject> newList) {
       
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity oppObj : (List<Opportunity>) newList) {
            if (oppObj.Id != null) {
                oppIds.add(oppObj.Id);
            }
        }
    
        
        Map<Id, Lead> leadMap = new Map<Id, Lead>(
            [SELECT Id, LeadNumber__c, ConvertedOpportunityId FROM Lead WHERE ConvertedOpportunityId IN :oppIds]
        );
    
        
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
    
        for (Opportunity oppObj : (List<Opportunity>) newList) {
            if (oppIds.contains(oppObj.Id) && leadMap.containsKey(oppObj.Id)) {
                Lead relatedLead = leadMap.get(oppObj.Id);
                String leadNumber = relatedLead.LeadNumber__c;
    
                if (String.isNotBlank(leadNumber)) {
                    
                    if (String.isNotBlank(oppObj.Name) && oppObj.Name.endsWith('-')) {
                        oppObj.Name += leadNumber;
                    } else {
                        oppObj.Name += ('-' + leadNumber);
                    }
    
                    
                    oppObj.Lead_LeadNumber__c = leadNumber;
    
                    opportunitiesToUpdate.add(oppObj);
                }
            }
        }
    
        
        if (!opportunitiesToUpdate.isEmpty()) {
            try {
                update opportunitiesToUpdate;
            } catch (Exception e) {
                System.debug('Error updating Opportunities: ' + e.getMessage());
            }
        }
    }*/
    
    
    
    
    public static void shareVIPOpportunitis(map<ID,SObject> OpportunityMap){
        //list<Group> VIPOwner = [select id,name, DeveloperName,Type from Group where type ='Queue' and DeveloperName = 'VIP_Managers'];
        list<User> VIPOwner = [Select Id, username from User where username =: label.VIP_Customer_Assignment_User];

        set<ID> OpportunityIDs = new set<ID>();
        for(Opportunity opty : (List<Opportunity>)OpportunityMap.values()){
            if(opty.OwnerID == VIPOwner[0].Id){
                OpportunityIDs.add(opty.Id);
            }
        }
    	list<Group> VIPGroup = [select id,name, DeveloperName,Type from Group where type ='Regular' and DeveloperName = 'VIP_Managers'];
        list<OpportunityShare> shareRecordToBeCreated = new list<OpportunityShare> ();
        
        
        if(!VIPGroup.isEmpty()){
            map<id,OpportunityShare> existingShareRecords = new map<id,OpportunityShare>();
            for(OpportunityShare existingRecord : [select id,OpportunityId from OpportunityShare where OpportunityId in :OpportunityIDs and UserOrGroupId=:VIPGroup[0].Id ]){
                existingShareRecords.put(existingRecord.OpportunityId,existingRecord);
            }
            for(Id tempOpportunityID : OpportunityIDs){
                if(!existingShareRecords.containsKey(tempOpportunityID)){
                    shareRecordToBeCreated.add(new OpportunityShare(OpportunityAccessLevel ='Edit', OpportunityId=tempOpportunityID,RowCause='Manual',UserOrGroupId=VIPGroup[0].Id));
                }
            }   
            if(!shareRecordToBeCreated.IsEmpty()){
                database.insert(shareRecordToBeCreated,false);
            }
        }
    }
    // Changes Added by Naga Chaitanya 
    public static void createCallTask(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){ 
        // Set initial values for milestone and record type ID for Opportunity tasks
        Integer mileStoneForNewTask = 1; // Assuming milestone 1 as default for the new task
        String oppRecordTypeID = Schema.getGlobalDescribe().get('Task').getDescribe().getRecordTypeInfosByName().get('Opportunity').getRecordTypeId();
        
        // Initialize necessary collections to store tasks and metadata
        List<Task> lst_Task = new List<Task>();
        Map<Decimal, Task_Management__mdt> map_TaskMetadata = new Map<Decimal, Task_Management__mdt>();
        
        // Retrieve active and default business hours for the organization
        List<BusinessHours> orgBusinessHours = [SELECT Id FROM BusinessHours WHERE IsActive = TRUE AND IsDefault = TRUE];
        
        // Retrieve task metadata related to Opportunity objects
        List<Task_Management__mdt> lst_TaskMetadata = [SELECT Label, ObjectName__c, Milestone__c, SLA__c, SLATimeType__c, Category__c, 
                                                       Subcategory__c FROM Task_Management__mdt WHERE ObjectName__c = 'Opportunity'];
        
        // Populate map of task metadata using Milestone__c as the key
        for (Task_Management__mdt obj_TaskMetadata : lst_TaskMetadata) {
            if (!map_TaskMetadata.containsKey(obj_TaskMetadata.Milestone__c)) {
                map_TaskMetadata.put(obj_TaskMetadata.Milestone__c, obj_TaskMetadata);
            }
        }
    
        // Loop through the newly created Opportunity records
        for (Opportunity obj_Opp : (List<Opportunity>) newList) {
            Long taskInterval = 0;
            DateTime addHoursToTaskDueDate;
    
            // Check if the Opportunity has an OwnerId (i.e., it's assigned to a user)
            if (obj_Opp.OwnerId != null) {
                // Get the task metadata based on the milestone for the new task
                Task_Management__mdt obj_TaskMetadata = map_TaskMetadata.get(Integer.valueOf(mileStoneForNewTask));
                
                // If task metadata exists, determine the SLA time interval for the task
                if (!map_TaskMetadata.isEmpty() && obj_TaskMetadata != null) {
                    if (obj_TaskMetadata.SLATimeType__c == 'seconds') {
                        taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 1000;
                    } else if (obj_TaskMetadata.SLATimeType__c == 'minutes') {
                        taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 60 * 1000;
                    } else if (obj_TaskMetadata.SLATimeType__c == 'hours') {
                        taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 60 * 60 * 1000;
                    }
                }
    
                // Create the task if a valid SLA time interval was determined
                if (taskInterval != 0) {
                    // Calculate the due date for the task based on the business hours and SLA interval
                    addHoursToTaskDueDate = BusinessHours.add(orgBusinessHours[0].Id, System.now(), taskInterval);
                    addHoursToTaskDueDate = DateTime.parse(addHoursToTaskDueDate.format());
                    Date dueDate = Date.newInstance(addHoursToTaskDueDate.year(), addHoursToTaskDueDate.month(), addHoursToTaskDueDate.day());
    
                    // Create the task with necessary fields
                    Task obj_Task = new Task();
                    obj_Task.whatId = obj_Opp.Id;
                    obj_Task.OwnerId = obj_Opp.OwnerId;
                    obj_Task.Subject = Constants.TASK_CALL_SUBJECT + ' ' + obj_TaskMetadata.Milestone__c + ' - ' + obj_Opp.Name;
                    obj_Task.ActivityDate = dueDate;
                    obj_Task.CurrentTaskSLA__c = addHoursToTaskDueDate;
                    obj_Task.Status = Constants.TASK_STATUS_OPEN;
                    obj_Task.NextTaskMilestone__c = obj_TaskMetadata.Milestone__c;
                    obj_Task.Type = 'Call';
                    obj_Task.System_Created__c = true;
                    obj_Task.RecordTypeId = oppRecordTypeID;
    
                    // Add the task to the list of tasks to be created
                    lst_Task.add(obj_Task);
                }
            }
        }
    
        // If any tasks were created, insert them into the database
        if (lst_Task.size() > 0) {
            System.debug('>>>>>>>>> createCallTask : Before creating task : Inside the opportunity Trigger handler');
            System.debug(lst_Task);
            insert(lst_Task);
        }
    }


    public static void ValidationOnClose(List<SObject> newList, Map<Id, SObject> oldMap) {
        
        Set<Id> opportunityIds  =  new Set<Id>();
        Set<Id> opptyDocPendingIds  =  new Set<Id>();
        System.debug('Inside the opportunity trigger handler validation on close method');
        System.debug(newList);
        for (Opportunity opp : (List<Opportunity>) newList) {
            Opportunity oldRecord;
            if (oldMap != null && oldMap.size() > 0 && oldMap.containsKey(opp.Id)) {
                oldRecord = (Opportunity) oldMap.get(opp.Id);
            } else {
                oldRecord = null; // If no old record exists, set it to null
            } 
            if (oldRecord != null && opp.StageName == Constants.OPPORTUNITY_STAGE_CLOSED_WON  && opp.StageName != oldRecord.StageName) {
                opportunityIds.add(opp.Id);
            } 
        }

        if(!opportunityIds.isEmpty()){
            
            for(Documents__c  docs:[select Id,Opportunity__c  from Documents__c where Opportunity__c IN:opportunityIds AND Status__c != 'Uploaded']){
                opptyDocPendingIds.add(docs.Opportunity__c);
            }
            for (Opportunity opp : (List<Opportunity>) newList) {
               
                if (opptyDocPendingIds.contains(opp.Id)) {
                    opp.addError('There are some incomplete documents');
                }

            }
            
        }

    }
    public static void handleCrossSellLeadCreation(List<SObject> newList, Map<Id, SObject> oldMap) {
        List<Lead> leadsToInsert = new List<Lead>();
        Map<Id, Opportunity> oppOldMap = new Map<Id, Opportunity>();
        List<Opportunity> oppList = new List<Opportunity>();
        List<Id> relatedAccountIds = new List<Id>(); // index-aligned
        List<Id> projectInterestedList = new List<Id>(); // index-aligned
    
        // Collect Opportunities from Trigger.new
        for (SObject sObj : newList) {
            oppList.add((Opportunity) sObj);
        }
        for (Id oppId : oldMap.keySet()) {
            oppOldMap.put(oppId, (Opportunity) oldMap.get(oppId));
        }
    
        // Step 1: Collect all picklist project names
        Set<String> projectNames = new Set<String>();
        for (Opportunity opp : oppList) {
            if (opp.ProjectInterest__c != null) {
                projectNames.add(opp.ProjectInterest__c);
            }
        }
    
        // Step 2: Query Project__c records by Name
        Map<String, Id> projectNameToIdMap = new Map<String, Id>();
        for (Project__c proj : [
            SELECT Id, Name FROM Project__c WHERE Name IN :projectNames
        ]) {
            projectNameToIdMap.put(proj.Name, proj.Id);
        }
    
        System.debug('>>>> Starting Cross-Sell Lead Creation');
        System.debug('>>>> Total Opportunities to check: ' + oppList.size());
    
        for (Opportunity opp : oppList) {
            Opportunity oldOpp = oppOldMap.get(opp.Id);
            System.debug('>>>> Evaluating Opportunity: ' + opp.Id);
            System.debug('>>>> Current Stage: ' + opp.StageName + ', Loss Reason: ' + opp.Loss_Reason__c);
    
            if (
                opp.StageName == 'Closed Lost' &&
                opp.Loss_Reason__c == 'Lost-Cross Sell' &&
                (oldOpp == null || opp.StageName != oldOpp.StageName || opp.Loss_Reason__c != oldOpp.Loss_Reason__c)
            ) {
                System.debug('>>>> Matched conditions for Cross-Sell Lead creation');
    
                List<Lead> parentLeads = [
                    SELECT Id, OwnerId, ConvertedAccountId, ProjectInterest__c,
                           FirstName, LastName, Company, Status, Email, Phone, MobilePhone, LeadSource
                    FROM Lead
                    WHERE ConvertedAccountId = :opp.AccountId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
    
                System.debug('>>>> Parent Leads found: ' + parentLeads.size());
    
                if (!parentLeads.isEmpty()) {
                    Lead parent = parentLeads[0];
    
                    // Skip logic if parent lead was not interested in Reem Hills
                    if (parent.ProjectInterest__c != 'Reem Hills') {
                        System.debug('>>>> Skipping Cross-Sell logic as parent Lead ProjectInterest__c is not Reem Hills');
                        continue;
                    }
    
                    // Prevent same project cross-sell
                    if (parent.ProjectInterest__c == opp.ProjectInterest__c) {
                        opp.addError('Please select a different project for cross-sell. Same project is already selected in the parent lead.');
                        continue;
                    }
    
                    System.debug('>>>> Cloning parent Lead: ' + parent.Id);
                    Lead child = new Lead();
    
                    Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Lead.fields.getMap();
                    for (String fieldName : fieldMap.keySet()) {
                        Schema.DescribeFieldResult fDesc = fieldMap.get(fieldName).getDescribe();
                        if (fDesc.isCreateable() && fDesc.isAccessible() && !fDesc.isAutoNumber() &&
                            fieldName != 'Id' && fieldName != 'OwnerId') {
                            try {
                                Object val = parent.get(fieldName);
                                child.put(fieldName, val);
                            } catch (Exception e) {
                                System.debug('Skipping field ' + fieldName + ' due to error: ' + e.getMessage());
                            }
                        }
                    }
    
                    child.Parent_Lead__c = parent.Id;
                    child.Is_Cross_Sell_Lead__c = true;
                    child.OwnerId = parent.OwnerId;
                    child.ProjectInterest__c = opp.ProjectInterest__c;
    
                    leadsToInsert.add(child);
                    relatedAccountIds.add(opp.AccountId);
    
                    // Look up Project__c Id from map
                    Id projectLookupId = projectNameToIdMap.get(opp.ProjectInterest__c);
                    projectInterestedList.add(projectLookupId);
    
                    System.debug('>>>> Prepared child lead with ProjectInterest__c: ' + child.ProjectInterest__c);
                } else {
                    System.debug('No parent Lead found for AccountId: ' + opp.AccountId);
                }
            } else {
                System.debug('Conditions not met for Opportunity: ' + opp.Id);
            }
        }
    
        if (!leadsToInsert.isEmpty()) {
            System.debug('Inserting ' + leadsToInsert.size() + ' new cross-sell leads...');
            insert leadsToInsert;
    
            for (Integer i = 0; i < leadsToInsert.size(); i++) {
                Lead lead = leadsToInsert[i];
                Id acctId = relatedAccountIds[i];
                Id projectInterested = projectInterestedList[i];
    
                try {
                    Database.LeadConvert lc = new Database.LeadConvert();
                    lc.setLeadId(lead.Id);
                    lc.setDoNotCreateOpportunity(false);
                    lc.setOwnerId(lead.OwnerId);
                    lc.setAccountId(acctId);
                    lc.setConvertedStatus('Qualified'); 
    
                    if (acctId != null) {
                        lc.setAccountId(acctId);
                        System.debug('Converting lead: ' + lead.Id + ' into existing Account: ' + acctId);
                    } else {
                        System.debug('No account mapping found for lead: ' + lead.Id);
                        continue;
                    }
    
                    Database.LeadConvertResult result = Database.convertLead(lc);
                    if (result.isSuccess()) {
                        Id oppId = result.getOpportunityId();
                        System.debug('Lead converted: ' + lead.Id + ' → Opportunity: ' + oppId);
    
                        if (oppId != null) {
                            Opportunity oppToUpdate = [
                                SELECT Id, Name FROM Opportunity WHERE Id = :oppId LIMIT 1
                            ];
    
                            if (String.isNotBlank(oppToUpdate.Name) && !oppToUpdate.Name.startsWith('CS-')) {
                                oppToUpdate.Name = 'CS-' + oppToUpdate.Name;
                            }
    
                            oppToUpdate.Project__c = projectInterested;
                            update oppToUpdate;
                            System.debug('Updated Opportunity name and Project__c: ' + oppToUpdate.Name);
                        }
                    } else {
                        System.debug('Conversion failed for: ' + lead.Id);
                    }
    
                } catch (Exception e) {
                    System.debug('Exception during Lead Conversion: ' + e.getMessage());
                }
            }
    
        } else {
            System.debug('No leads to insert');
        }
    }
    public static void encryptedMapping(list<SObject> newList, Map<Id, SObject> oldMap) {
        /*Set<Id> primaryContactIds = new Set<Id>();
        for(Opportunity opp : (List<Opportunity>)newList)
        {
            if (opp.PrimaryContact__c != null) {
            primaryContactIds.add(opp.PrimaryContact__c);
        	}
        }
        
        Map<Id, Contact> contactsMap = new Map<Id, Contact>([SELECT Id, Email,MobilePhone FROM Contact WHERE Id IN :primaryContactIds]);
        */
        if(oldMap == null){
          for(Opportunity opporRecord : (List<Opportunity>)newList){
              /*String contactEmail = '';
              String contactMobilePhone = '';
              if (opporRecord.PrimaryContact__c != null && contactsMap.containsKey(opporRecord.PrimaryContact__c)) {
                  contactEmail = contactsMap.get(opporRecord.PrimaryContact__c).Email;
              }
              if (opporRecord.PrimaryContact__c != null && contactsMap.containsKey(opporRecord.PrimaryContact__c)) {
                  contactMobilePhone = contactsMap.get(opporRecord.PrimaryContact__c).MobilePhone;
              }*/
              
              if(opporRecord.PassportNumber__c <> null){
                  opporRecord.En_PassportNumber__c =opporRecord.PassportNumber__c;
              }else if(opporRecord.En_PassportNumber__c <> null){
                  opporRecord.PassportNumber__c =opporRecord.En_PassportNumber__c;
              }
              if(opporRecord.EIDNumber__c <> null){
                  opporRecord.En_EIDNumber__c =opporRecord.EIDNumber__c;
              }else if(opporRecord.En_EIDNumber__c <> null){
                  opporRecord.EIDNumber__c =opporRecord.En_EIDNumber__c;
              }
              if(opporRecord.Nationality__c <> null){
                  opporRecord.En_Nationality__c =opporRecord.Nationality__c;
              }else if(opporRecord.En_Nationality__c <> null){
                  opporRecord.Nationality__c =opporRecord.En_Nationality__c;
              }
              /*if(contactMobilePhone <> null){
                  opporRecord.En_Mobile__c =contactMobilePhone;
              }
              if(contactEmail <> null){
                  opporRecord.En_Email__c =contactEmail;
              }*/
          }
        }else  if(oldMap <> null){
            for(Opportunity newOppRec : (List<Opportunity>)newList){
              /*String contactEmail = '';
              String contactMobilePhone = '';
              if (newOppRec.PrimaryContact__c != null && contactsMap.containsKey(newOppRec.PrimaryContact__c)) {
                  contactEmail = contactsMap.get(newOppRec.PrimaryContact__c).Email;
              }
              if (newOppRec.PrimaryContact__c != null && contactsMap.containsKey(newOppRec.PrimaryContact__c)) {
                  contactMobilePhone = contactsMap.get(newOppRec.PrimaryContact__c).MobilePhone;
              }*/
                
                Opportunity oldOppRec = (Opportunity) oldMap.get(newOppRec.Id);
              if(newOppRec.PassportNumber__c <> oldOppRec.PassportNumber__c && newOppRec.PassportNumber__c != null){
                  newOppRec.En_PassportNumber__c =newOppRec.PassportNumber__c;
              }else if(newOppRec.En_PassportNumber__c <> oldOppRec.En_PassportNumber__c && newOppRec.En_PassportNumber__c != null){
                  newOppRec.PassportNumber__c =newOppRec.En_PassportNumber__c;
              }
              if(newOppRec.EIDNumber__c <> oldOppRec.EIDNumber__c && newOppRec.EIDNumber__c != null){
                  newOppRec.En_EIDNumber__c =newOppRec.EIDNumber__c;
              }else if(newOppRec.En_EIDNumber__c <> oldOppRec.En_EIDNumber__c && newOppRec.En_EIDNumber__c != null){
                  newOppRec.EIDNumber__c =newOppRec.En_EIDNumber__c;
              }
              if(newOppRec.Nationality__c <> oldOppRec.Nationality__c && newOppRec.Nationality__c != null){
                  newOppRec.En_Nationality__c =newOppRec.Nationality__c;
              }else if(newOppRec.En_Nationality__c <> oldOppRec.En_Nationality__c && newOppRec.En_Nationality__c != null){
                  newOppRec.Nationality__c =newOppRec.En_Nationality__c;
              }
              /*if(contactMobilePhone <> oldOppRec.Mobile__c){
                  newOppRec.En_Mobile__c =contactMobilePhone;
              }
              if(contactEmail <> oldOppRec.Email__c){
                  newOppRec.En_Email__c =contactEmail;
              }*/        
          }
        }
  }

    // ============================================================
    // v2.1 — Arvind — 13 May 2026
    // ============================================================
   /* public static void setSLAStartTimeForBrokerPortal(
        List<SObject>    newList,
        Map<Id, SObject> oldMap
    ) {
       
        if (System.Label.EOI_SLA_Enabled != 'true') return;

        String brokerPortalValue = System.Label.EOI_SLA_Broker_Portal_LeadSource;
        String salesProfileName  = System.Label.EOI_SLA_Sales_Profile_Name;
        Set<Id> newOwnerIds     = new Set<Id>();
        Set<Id> candidateOppIds = new Set<Id>();
        for (Opportunity opp : (List<Opportunity>) newList) {
            Opportunity oldOpp = (Opportunity) oldMap.get(opp.Id);
            if (opp.OwnerId != oldOpp.OwnerId && opp.LeadSource == brokerPortalValue) {
                newOwnerIds.add(opp.OwnerId);
                candidateOppIds.add(opp.Id);
            }
        }
        if (candidateOppIds.isEmpty()) return; // Arvind v2.1: nothing qualifies — exit early
        Set<Id> salesMgmtUserIds = new Set<Id>();
        for (User u : [
            SELECT Id FROM User
            WHERE  Id IN :newOwnerIds
              AND  Profile.Name = :salesProfileName
        ]) {
            salesMgmtUserIds.add(u.Id);
        }
        if (salesMgmtUserIds.isEmpty()) return; 
        Set<Id> qualifiedOppIds = new Set<Id>();
        for (Opportunity opp : (List<Opportunity>) newList) {
            if (candidateOppIds.contains(opp.Id) && salesMgmtUserIds.contains(opp.OwnerId)) {
                qualifiedOppIds.add(opp.Id);
            }
        }
        if (qualifiedOppIds.isEmpty()) return;
        List<Expressionofinterest__c> relatedEOIs = [
            SELECT Id
            FROM   Expressionofinterest__c
            WHERE  Opportunity__c    IN :qualifiedOppIds
              AND  Skip_SLA__c        = false
              AND  SLA_Start_Time__c  = null
              AND  Status__c         IN ('In Progress')
        ];
        if (relatedEOIs.isEmpty()) return; // Arvind v2.1: no eligible EOIs found — exit early

        // Arvind v2.1: Step 5 — DML: stamp SLA start = now on all eligible EOIs
        // Single DML call — no update inside any loop
        Datetime now = Datetime.now();
        List<Expressionofinterest__c> toUpdate = new List<Expressionofinterest__c>();
        for (Expressionofinterest__c eoi : relatedEOIs) {
            toUpdate.add(new Expressionofinterest__c(
                Id                = eoi.Id,
                SLA_Start_Time__c = now  // Arvind v2.1: SLA clock starts from owner assignment time
            ));
        }
        update toUpdate; // Arvind v2.1: single DML — bulk-safe
    }*/
    // ============================================================
    // End v2.1 — Arvind
    // ============================================================

}