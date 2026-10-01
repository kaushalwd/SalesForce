/**********************************************************************************************************************
* Name               : SFGenesys_Services                                                        
* Description        : Used for create or Qualifying the lead from Genesys or Whatsapp
* Usage              : 
* Created By         :                                                      
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           HZTL                             15 Sep 2025        Added Unit field for Modon Egypt   
* 2.0			Suresh							 06 May 2026		UAEResidenceStatus and Nationality added 
* 3.0           Arvind                           16 Jul 2026        FIX: Duplicate Round-Robin assignment on lead creation.
*                                                                   Set Constants.runRoundRobin = false before insert so the
*                                                                   after-insert trigger skips Round Robin. The single,
*                                                                   authoritative assignment is done by assignLeadToAgent()
*                                                                   (@future) / Modon_LeadTriggerHandler (Egypt).
* 3.1           Arvind                           18 Jul 2026        Added Conversation_Id__c: capture conversation_id from the
*                                                                   Genesys request and store it on the Lead (insert + update
* 3.4           Arvind                           28 Sep 2026        Create Lead API now ALWAYS creates a new Lead, even when
*                                                                   the phone or email matches an existing Lead. Removed the
*                                                                   duplicate lookup and the update-existing-lead branch, so an
*                                                                   existing Lead's LeadSource, SubSource__c, Email, etc. are
*                                                                   never overwritten. Removed unused Integration User query.
*                                                                   Insert uses DMLOptions allowSave so Alert-type Duplicate
*                                                                   Rules do not block the insert.
******************************************************************************************************************/
//Service Class: Contains business logic for Genesys APIs
global class SFGenesys_Services {
    
    //
    public static void processRequest(String phoneNumber, String email, RestRequest req, RestResponse res) {
        System.debug('processRequest >>>>> '+phoneNumber+'     '+email);
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        Integer totalCount = 0;
        
        try {
            // Search and aggregate results
            //Fetching sorceEntity from the request and searching records accordingly
            totalCount += addResults(results, searchLeads(phoneNumber, email, req.params.get('sourceEntity')));
            totalCount += addResults(results, searchAccounts(phoneNumber, email, req.params.get('sourceEntity')));
            totalCount += addResults(results, searchContacts(phoneNumber, email, req.params.get('sourceEntity')));
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(e, 'SF Genesys Customer Identification API','SFGenesys_Services','processRequest'));
        }
        
        // Build JSON response
        Map<String, Object> response = new Map<String, Object>{
            'totalCount' => totalCount,
                'records' => results
                };
                    res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(response));
        
        // Create API Callout Log (for both Success and Error)
        //PARAMS: string processName, string className, string methodName, string intReqBody, string intRespBody, string intStatusCode
        LoggerService.save(LoggerService.createAPILog('SF Genesys Customer Identification API', 'SFGenesys_Services', 'processRequest', JSON.serialize(req),res.responseBody != null ? res.responseBody.toString() : '', 'Status Code: ' + res.statusCode, 'WebService Callout Log'));
    }
    
    @TestVisible
    private static Integer addResults(List<Map<String, Object>> mainList, List<Map<String, Object>> newResults) {
        mainList.addAll(newResults);
        return newResults.size();
    }
    
    // Searches Leads by phone number.
    @TestVisible
    private static List<Map<String, Object>> searchLeads(String phoneNumber, String email, String sourceEntity) {
        List<Map<String, Object>> leadResults = new List<Map<String, Object>>();
        String query = 'SELECT Id, FirstName, LastName, Phone, MobilePhone, LanguagePreference__c, Email FROM Lead WHERE ';
        List<String> conditions = new List<String>();
        
        List<String> mainConditions = new List<String>();
        
        // Phone conditions based on sourceEntity
        if (sourceEntity == 'Modon - Egypt') {
            if (String.isNotBlank(phoneNumber)) {
                String egyptPhoneNumber = phoneNumber.remove('+');
                conditions.add('Phone = :egyptPhoneNumber');
                conditions.add('MobilePhone = :egyptPhoneNumber');
            }
        } else {
            if (String.isNotBlank(phoneNumber)) {
                conditions.add('(Phone = :phoneNumber OR MobilePhone = :phoneNumber)');
            }
        }
        
        // Combine phone conditions
        if (!conditions.isEmpty()) {
            mainConditions.add('(' + String.join(conditions, ' OR ') + ')');
        }

        // ✅ Email is separate AND condition now
        if (String.isNotBlank(email) && email != 'NA') {
            mainConditions.add('Email = :email');
        }
        
        // Source entity condition
        if (String.isNotBlank(sourceEntity)) {
            mainConditions.add('Source_Entity__c = :sourceEntity');
        } else {
            mainConditions.add('Source_Entity__c != \'Modon - Egypt\'');
        }
        
        // Final query execution
        if (!mainConditions.isEmpty()) {
            query += String.join(mainConditions, ' AND ');
            System.debug('query=>' + query);
            for (Lead lead : Database.query(query)) {
                leadResults.add(GenesysDTO.formatLead(lead));
            }
        }
        
        return leadResults;
    }
    
    
    // Searches Accounts by phone number.
    @TestVisible
    private static List<Map<String, Object>> searchAccounts(String phoneNumber, String email, String sourceEntity) {
        List<Map<String, Object>> accountResults = new List<Map<String, Object>>();
        String query = 'SELECT Id, FirstName, LastName, Phone, PersonGenderIdentity, PersonEmail, PersonMobilePhone FROM Account WHERE ';
        List<String> conditions = new List<String>();
        List<String> mainConditions = new List<String>();
        
        if (String.isNotBlank(phoneNumber)) {
            conditions.add('(Phone = :phoneNumber OR PersonMobilePhone = :phoneNumber)');
        }
        
        
        if (!conditions.isEmpty()) {
            mainConditions.add('(' + String.join(conditions, ' OR ') + ')');
        }

        if (String.isNotBlank(email) && email != 'NA') {
            mainConditions.add('PersonEmail = :email');
        }

        // Fetching Account record based on sourceEntity --> (Email AND Phone AND sourceEntity)
        if (String.isNotBlank(sourceEntity)) {
            mainConditions.add('Source_Entity__c = :sourceEntity');
        } else {
            mainConditions.add('Source_Entity__c != \'Modon - Egypt\'');
        }
        
        if (!mainConditions.isEmpty()) {
            query += String.join(mainConditions, ' AND ');
            for (Account account : Database.query(query)) {
                accountResults.add(GenesysDTO.formatAccount(account));
            }
        }
        return accountResults;
    }
    
    // Searches Contacts by phone number.
    @TestVisible
    private static List<Map<String, Object>> searchContacts(String phoneNumber, String email, String sourceEntity) {
        List<Map<String, Object>> contactResults = new List<Map<String, Object>>();
        String query = 'SELECT Id, FirstName, LastName, Phone, Email, GenderIdentity, MobilePhone FROM Contact WHERE ';
        List<String> conditions = new List<String>();
        List<String> mainConditions = new List<String>();
        
        if (String.isNotBlank(phoneNumber)) {
            conditions.add('(Phone = :phoneNumber OR MobilePhone = :phoneNumber)');
        }
        
        if (!conditions.isEmpty()) {
            mainConditions.add('(' + String.join(conditions, ' OR ') + ')');
        }

        if (String.isNotBlank(email) && email != 'NA') {
            mainConditions.add('Email = :email');
        }

        // Fetching Contact record based on sourceEntity --> (Email AND Phone AND sourceEntity)
        if (String.isNotBlank(sourceEntity)) {
            mainConditions.add('Source_Entity__c = :sourceEntity');
        } else {
            mainConditions.add('Source_Entity__c != \'Modon - Egypt\'');
        }
        
        if (!mainConditions.isEmpty()) {
            query += String.join(mainConditions, ' AND ');
            for (Contact contact : Database.query(query)) {
                contactResults.add(GenesysDTO.formatContact(contact));
            }
        }
        return contactResults;
    }
    //Utility Method: Sanitizes the phone number by removing non-numeric characters and adding wildcards.
    public static String sanitizePhoneNumber(String phoneNumber) {
        phoneNumber = phoneNumber.replaceAll('[^\\d]', '');
        if(String.isNotBlank(phoneNumber)){
            return '+' + phoneNumber;            
        }else{
            return null;
        }
    }
    //Utility Method: Matching the phone number by removing non-numeric characters and adding wildcards.
    public static String matchPhoneNumberPattern(String phoneNumber, String sourceEntity) {
        String phoneNumberPattern;
        if (String.isBlank(phoneNumber)) {
            return null;
        }
        
        if (sourceEntity == 'Modon - Egypt') {
            phoneNumberPattern = '^[0-9]{3,15}$';
        } else {
            phoneNumberPattern = '^\\+(?:[0-9]\\ {0,1}){6,14}[0-9]$';
        }
        return Pattern.matches(phoneNumberPattern, phoneNumber) ? phoneNumber : null;
    }
    // Utility Method: Sanitizes the Email by checking the email pattern.
    public static String sanitizeEmail(String email) {
        String emailPattern = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
        if (String.isNotBlank(email) && Pattern.matches(emailPattern, email)) {
            return email;
        } else {
            return null;
        }
    }
    
    //Updates the preferred language for a given record.
    public static Boolean updatePreferredLanguage(String objectId, String language) {
        // Identify SObject type
        Map<String, Object> responseMap = GenesysDTO.initializeResponse();
        Map<String, String> prefixMap = new Map<String, String>{
            'Lead' => Lead.SObjectType.getDescribe().getKeyPrefix(),
                'Account' => Account.SObjectType.getDescribe().getKeyPrefix(),
                'Contact' => Contact.SObjectType.getDescribe().getKeyPrefix()
                };
                    SObject recordToUpdate;
        try{                  
            if (objectId.startsWith(prefixMap.get('Account'))) {
                recordToUpdate = [SELECT Id FROM Account WHERE Id = :objectId LIMIT 1];
            } else if (objectId.startsWith(prefixMap.get('Contact'))) {
                recordToUpdate = [SELECT Id FROM Contact WHERE Id = :objectId LIMIT 1];
            } else if (objectId.startsWith(prefixMap.get('Lead'))) {
                recordToUpdate = [SELECT Id, LanguagePreference__c FROM Lead WHERE Id = :objectId LIMIT 1];
            }
        }
        catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(e, 'SF Genesys Update Customer Identification API','SFGenesys_Services','updatePreferredLanguage'));
        }
        // Update language
        if(recordToUpdate.get('LanguagePreference__c') != language){
            recordToUpdate.put('LanguagePreference__c', language);
            update recordToUpdate;
            return true;
        }else{
            return false;
        }
    }
    //Create New Lead Record
    //v3.1 Arvind (18 Jul 2026): backward-compatible overload - existing callers without conversationId keep working.
    public static Boolean createLeadInSF(String fname, String lname, String email, String phone, String leadSource,
                                         String leadSubSource, String lang, String projectName, String sourceEntity, RestRequest req,
                                         RestResponse res, String UUID) {
        return createLeadInSF(fname, lname, email, phone, leadSource, leadSubSource, lang, projectName, sourceEntity, null, req, res, UUID);
    }

    //v3.1 Arvind (18 Jul 2026): added conversationId - stored on Lead.Conversation_Id__c only. Response is UNCHANGED.
    //v3.2 Arvind (20 Jul 2026): request 'ani' ignored; AWS callback requirement dropped (OIC does the outbound).
    //v3.4 Arvind (28 Sep 2026): ALWAYS create a new Lead. The duplicate lookup (email/phone match) and the
    //                           update-existing-lead branch are removed, so the Create Lead API never modifies
    //                           an existing Lead (LeadSource, SubSource__c, Email, etc. stay as they were).
    public static Boolean createLeadInSF(String fname, String lname, String email, String phone, String leadSource,
                                         String leadSubSource, String lang, String projectName, String sourceEntity,
                                         String conversationId, RestRequest req,
                                         RestResponse res, String UUID) {
        Map<String, Object> responseMap = GenesysDTO.initializeResponse();

        // Create Lead record
        Lead newLead = new Lead(
            FirstName = fname,
            LastName = lname,
            Email = email,
            LeadSource = leadSource,
            Status = 'New',
            SubSource__c = leadSubSource,
            LanguagePreference__c = lang,
            ProjectInterest__c = projectName,
            Source_Entity__c = sourceEntity,
            InitiationType__c = 'Genesys',
            Conversation_Id__c = conversationId   // v3.1 Arvind: store Genesys conversation id on the Lead
        );

        // Set phone field based on sourceEntity
        if (sourceEntity == 'Modon - Egypt') {
            newLead.MobilePhone = phone;
        } else {
            newLead.Phone = phone;
        }

        try {
            /*************************************************************************************
            * v3.0 FIX - Arvind - 16 Jul 2026 - DUPLICATE ROUND ROBIN ASSIGNMENT
            *************************************************************************************/
            Constants.runRoundRobin = false; // v3.0 Arvind: skip trigger RR, future method will assign

            // v3.4 Arvind: always insert. allowSave lets the insert pass when an org Duplicate Rule
            // with an ALERT action matches. A rule with a BLOCK action will still stop the insert.
            Database.DMLOptions dml = new Database.DMLOptions();
            dml.DuplicateRuleHeader.allowSave = true;
            dml.DuplicateRuleHeader.runAsCurrentUser = true;
            dml.OptAllOrNone = true;
            Database.insert(newLead, dml);

            if (sourceEntity == 'Modon - UAE' || sourceEntity == null) {
                assignLeadToAgent(newLead.Id);
            } else if (sourceEntity == 'Modon - Egypt') {
                Modon_LeadTriggerHandler.assignLeads(new List<Lead>{newLead});
            }

            Lead obj_Lead = [SELECT Id, LeadNumber__c FROM Lead WHERE Id = :newLead.Id LIMIT 1];
            GenesysDTO.createLeadResponse(responseMap, obj_Lead.Id, obj_Lead.LeadNumber__c, true, 'Lead has been created successfully', UUID);
            System.debug('SFGenesys_Services >>>>  ' + System.JSON.serialize(responseMap));
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(e, 'SF Genesys Create Lead API','SFGenesys_Services','createLead'));
            GenesysDTO.updateResponse(responseMap, false, e.getMessage(), 400, '');
        }

        System.debug('Javalog---------->' + res.statusCode);
        // Create API Callout Log (for both Success and Error)
        //PARAMS: string processName, string className, string methodName, string intReqBody, string intRespBody, string intStatusCode
        LoggerService.save(LoggerService.createAPILogforGenesys('SF Genesys Create Lead API', 'SFGenesys_Services', 'createLeadInSF', JSON.serialize(req), res.responseBody != null ? res.responseBody.toString() : '', 'Status Code: ' + res.statusCode, 'WebService Callout Log', UUID));
        return true;
    }
    
    //Future method to assign sales agent using round robin method
    //v3.0 Arvind (16 Jul 2026): This is now the ONLY place a Genesys (UAE) lead gets Round-Robin
    //      assigned, because Constants.runRoundRobin = false suppressed the trigger-side
    //      assignment during the insert transaction.
    @future
    public static void assignLeadToAgent(Id leadId){
        List<Lead> lst_LeadforAssignment = new List<Lead>();
        // v3.2 Arvind: added Is_Duplicate__c - LeadTriggerHelper.roundRobinAssignment reads it and throws
        // 'SObject row was retrieved via SOQL without querying the requested field' if it's not queried here.
        // NOTE: any field the helper reads MUST be in this query (trigger context has all fields, this query does not).
        List<Lead> lst_Lead = [select Id, FirstName, LastName, Email, Phone, LeadSource, Status, SubSource__c, LanguagePreference__c,
                               ProjectInterest__c, InitiationType__c, OwnerId, PreferredLeadOwner__c,
                               CustomerType__c, UTMSource__c, AdName__c, Sales_Executive__c, Cross_Sell_Lead_Number__c,
                               ReAssignRRToSalesAssociate__c, Is_Duplicate__c from Lead where Id = :leadId];
        if(lst_Lead != null && lst_Lead.size() > 0){
            for(Lead obj_Lead : lst_Lead){
                obj_Lead.InitiationType__c = '';
                lst_LeadforAssignment.add(obj_Lead);
            }
        }
        if(lst_LeadforAssignment.size() > 0){
            LeadTriggerHelper.roundRobinAssignment(lst_LeadforAssignment, null, null, null);
        }        
    }
    
    //Update Qualify Lead
    public static Boolean updateQualifyLeadInSF(String leadId, Boolean qualifyLead, String projectName, String bedroomType, 
                                                String investment, String budgetOption, String finance, String contactChannel, 
                                                String callbackTime, String comments, String unitType, 
                                                String uaeResidenceStatus, String nationality,
                                                RestRequest req, RestResponse res, String UUID) {
        Map<String, Object> responseMap = GenesysDTO.initializeResponse();
        
        // Check if qualifyLead is true and finance is blank
        if (Boolean.valueOf(qualifyLead) && String.isBlank(finance)) {
            GenesysDTO.updateLeadResponse(responseMap, '', false, 'Finance field is required when you qualify a lead', 400, UUID);
            LoggerService.save(LoggerService.createAPILogforGenesys('SF Genesys Update Lead API Validation', 'SFGenesys_Services', 'updateQualifyLeadInSF', JSON.serialize(req), res.responseBody != null ? res.responseBody.toString() : '', 'Validation Failed: Finance field is required', 'Validation Log', UUID));
            return false;
        }
        //1.0  
        Lead leadToUpdate = [SELECT Id, LeadNumber__c, Owner.Name, Status, ProjectInterest__c, NumberOfBedrooms__c, Investment__c, CustomerBudget__c, 
                             Source_Entity__c, UAEResidentStatus__c, Nationality__c, 
                             Finance__c, PreferredModeOfContact__c, PreferredContactTime__c, IsConverted, LeadSource, UnitType__c 
                             FROM Lead WHERE Id = :leadId LIMIT 1];
        
        Boolean isUpdated = false;
        
        // Update lead fields based on provided values
        System.debug('qualifyLead:' + Boolean.valueOf(qualifyLead));
        if (Boolean.valueOf(qualifyLead)) {
            leadToUpdate.Status = Constants.LEAD_STATUS_QUALIFY;
            leadToUpdate.ReAssignRRToSalesAssociate__c = true;
        }
        if (String.isNotBlank(projectName) && leadToUpdate.ProjectInterest__c != projectName) {
            leadToUpdate.ProjectInterest__c = projectName;
            isUpdated = true;
        }
        if (String.isNotBlank(bedroomType) && leadToUpdate.NumberOfBedrooms__c != bedroomType) {
            leadToUpdate.NumberOfBedrooms__c = bedroomType;
            isUpdated = true;
        }
        if (String.isNotBlank(budgetOption) && leadToUpdate.CustomerBudget__c != budgetOption) {
            leadToUpdate.CustomerBudget__c = budgetOption;
            isUpdated = true;
        }
        if (String.isNotBlank(investment) && leadToUpdate.Investment__c != investment) {
            leadToUpdate.Investment__c = investment;
            isUpdated = true;
        }
        if (String.isNotBlank(finance) && leadToUpdate.Finance__c != finance) {
            leadToUpdate.Finance__c = finance;
            isUpdated = true;
        }
        if (String.isNotBlank(contactChannel) && leadToUpdate.PreferredModeOfContact__c != contactChannel) {
            leadToUpdate.PreferredModeOfContact__c = contactChannel;
            isUpdated = true;
        }
        //1.0  
        if (String.isNotBlank(callbackTime) && leadToUpdate.PreferredContactTime__c != callbackTime) {
            leadToUpdate.PreferredContactTime__c = callbackTime;
            isUpdated = true;
        }
        if (String.isNotBlank(unitType) && leadToUpdate.UnitType__c != unitType && leadToUpdate.Source_Entity__c == 'Modon - Egypt') {
            leadToUpdate.UnitType__c = unitType;
            isUpdated = true;
        }
        
        //2.0
        if (String.isNotBlank(uaeResidenceStatus) && leadToUpdate.UAEResidentStatus__c != uaeResidenceStatus) {
            leadToUpdate.UAEResidentStatus__c = uaeResidenceStatus;
            isUpdated = true;
        }
        //2.0                                          
        if (String.isNotBlank(nationality) && leadToUpdate.Nationality__c != nationality) {
            leadToUpdate.Nationality__c = nationality;
            isUpdated = true;
        }                                           
                                                    
        /*if (String.isNotBlank(comments)) {
            leadToUpdate.Comments__c = comments;            
        }
        if (String.isNotBlank(unitType) && leadToUpdate.UnitType__c != unitType) {
            leadToUpdate.UnitType__c = unitType;
            isUpdated = true;
        }*/  

        System.debug('isUpdated: ' + isUpdated);
        
        if (isUpdated) {
            // Save the updated lead
            try {
                update leadToUpdate;
                List<Lead> lst_UpdateLead = [Select Id, Owner.Name, LeadNumber__c from Lead where Id = :leadToUpdate.Id];
                Lead obj_UpdateLead = new Lead();
                if(lst_UpdateLead.size() > 0){
                    obj_UpdateLead = lst_UpdateLead.get(0);
                }
                if (Boolean.valueOf(qualifyLead)) {
                    GenesysDTO.updateLeadResponse(responseMap, String.valueOf(obj_UpdateLead.Owner.Name), true, 'Lead '+obj_UpdateLead.LeadNumber__c+' has been updated successfully', 200, UUID);
                } else {
                    GenesysDTO.updateLeadResponse(responseMap, '', true, 'Lead '+obj_UpdateLead.LeadNumber__c+' has been updated successfully', 200, UUID);
                }
            } catch (Exception e) {
                LoggerService.save(LoggerService.createApexLog(e, 'SF Genesys Update Lead API', 'SFGenesys_Services', 'updateQualifyLeadInSF'));
                GenesysDTO.updateLeadResponse(responseMap, null, false, 'Error updating lead: ' + e.getMessage(), 500, UUID);
            }
        } else {
            // No fields were updated
            if (Boolean.valueOf(qualifyLead)) {
                GenesysDTO.updateLeadResponse(responseMap, String.valueOf(leadToUpdate.Owner.Name), true, 'Lead '+leadToUpdate.LeadNumber__c+' is already updated', 200, '');
            } else {
                GenesysDTO.updateLeadResponse(responseMap, '', true, 'Lead is already updated', 200, '');
            }
        }
        System.debug('Javalog---------->' + res.statusCode);
        LoggerService.save(LoggerService.createAPILogforGenesys('SF Genesys Update Lead API', 'SFGenesys_Services', 'updateQualifyLeadInSF', JSON.serialize(req), res.responseBody != null ? res.responseBody.toString() : '', 'Status Code: ' + res.statusCode, 'WebService Callout Log', UUID));
        return true;
    }
}