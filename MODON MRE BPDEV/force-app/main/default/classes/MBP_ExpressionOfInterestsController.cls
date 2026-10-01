/**********************************************************************************************************************
* Name               : MBP_ExpressionOfInterestsController
* Description        : Handle Eoi creation
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Upendra                         15 May 2026       Server-side Apex class for managing eois  in Salesforce
* 2.0           Rushi Patel                     29 September 2026 Broker EOI submit: an Individual customer's Person
*                                                                 Account (new or matched) gets its missing placeholder
*                                                                 documents and the KYC link, unless KYC is already active
*                                                                 or a KYC link sent earlier is still live
**********************************************************************************************************************/



global without sharing class MBP_ExpressionOfInterestsController {

    /* BP-070: a range reaches the broker portal only when the client has ticked Show On =
       Broker Portal on the record. Same literal as MBP_EoiPaymentLinkController.SHOW_ON_BROKER,
       so the list the broker picks from and the price the server charges can never disagree. */
    @TestVisible private static final String SHOW_ON_BROKER = 'Broker Portal';
    private static final String KYC_STATUS_ACTIVE = 'KYC Active'; // v2.0 updated by Rushi Patel - 29 September 2026 - Account.KYC_Status__c formula value

    @AuraEnabled
    public static User getUserDetails() {
        return [
            SELECT Id, ContactId, Contact.Broker_Type__c, Contact.AccountId,Contact.Phone
            FROM User WHERE Id =: UserInfo.getuserId()];
    }
    
    @AuraEnabled
    public static Map<String,Object> createLead(
        
        String firstName,
        String lastName,
        String email,
        String mobile,
        String residentStatus,
        String country,
        String nationality,
        String emiratesId,
        
        String passportNumber,
        
        String company,
        String tradeLicenseNumber
        
    ) {
        
        Map<String,Object> response = new Map<String,Object>();
        
        try {
            
            User loggedInUser = [
                SELECT Id,
                ContactId,
                Contact.Name,
                Contact.MobilePhone,
                Contact.AccountId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            Lead leadRecord = new Lead();
            
            
            leadRecord.OwnerId =  UserInfo.getUserId();
            leadRecord.FirstName = String.isBlank(firstName)? 'Test': firstName;
            leadRecord.LastName = String.isBlank(lastName)? 'EOI': lastName;
            if(String.isNotBlank(company)) {
                leadRecord.Company = company;
            }
            
            leadRecord.Email = email;
            leadRecord.MobilePhone = mobile;
            leadRecord.LeadSource ='Broker Portal';
            leadRecord.Nationality__c =nationality;
            leadRecord.PassportNumber__c =passportNumber;
            leadRecord.PassportExpiryDate__c =
                System.today().addYears(10);
            
            leadRecord.EmiratesIDExpiryDate__c =
                System.today().addYears(5);
            leadRecord.PassportIssueDate__c =  System.today().addDays(-1);
            leadRecord.UAEResidentStatus__c = residentStatus;
            leadRecord.CountryOfResidence__c = country;
            leadRecord.EIDNumber__c = emiratesId;
            
             String projectname =
                System.Label.MBP_DynamicProject;
            leadRecord.ProjectInterest__c =projectname;
            leadRecord.UnifiedNumber__c = tradeLicenseNumber;
            
            leadRecord.BrokerAgency__c = loggedInUser.Contact.AccountId;
            leadRecord.BrokerAgent__c = loggedInUser.ContactId;
            leadRecord.BrokerAgentMobile__c = loggedInUser.Contact.MobilePhone;
            leadRecord.BrokerAgentName__c = loggedInUser.Contact.Name;
            leadRecord.Trade_License_Expiry_Date__c =
                System.today().addYears(5);
            leadRecord.IsEOI__c = true;
            Id leadId;
            insert leadRecord;
            
            leadId = leadRecord.id;
            
            
            response.put( 'success',true);
            response.put('lead', leadRecord);
            response.put('leadId', leadRecord.Id);
            response.put('otpSent', true);
            return response;
        }
        
        catch(Exception e) {
            response.put('success',false); response.put('otpSent', false);response.put( 'pageErrors', new List<String>{e.getMessage() }); response.put('fieldErrors', new Map<String,String>()); return response;
        }
    }
    @future(callout=true)
    public static void sendOtpFuture(
        
        Id leadId,
        String mobile,
        String generatedOtp,
        String firstName,
        String lastName
    ) {
        
        try {
            
            OIC_Credential__mdt cred = [SELECT Endpoint__c,
                                        Username__c,  Password__c FROM OIC_Credential__mdt  WHERE DeveloperName =
                                        'CommunicationAPI'  LIMIT 1 ];
            
            HttpRequest req =  new HttpRequest();
            
            req.setEndpoint( cred.Endpoint__c);
            req.setMethod('POST');
            req.setHeader( 'Content-Type', 'application/json' );
            String authString = cred.Username__c +':' + cred.Password__c;
            String encodedAuth = EncodingUtil.base64Encode(  Blob.valueOf(authString));
            req.setHeader( 'Authorization', 'Basic ' + encodedAuth );
            List<Object> payload = new List<Object>();
            Map<String,Object> body =new Map<String,Object>();
            body.put( 'CustomerName',  firstName + ' ' + lastName );
            body.put( 'MobileNumber', mobile);
            body.put( 'TextMessage',  'Your OTP is ' + generatedOtp);
            body.put('TemplateName','muheira_launch_jan2026_qr_code_public' );
            body.put('QRCodeURL','Bashayer' );
            body.put( 'SendWhatsapp',false);
            body.put('SendSMS', true);
            body.put('InvitationFormURL','test' );
            payload.add(body);
            req.setBody( JSON.serialize(payload));
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug(  'OTP RESPONSE => ' + res.getBody());
        }
        
        catch(Exception e) {
            System.debug('OTP ERROR => ' + e.getMessage() );
        }
    }@AuraEnabled(cacheable=true)
    public static List<String> getUnitTypologies(
        Id projectId,
        Id phaseId,
        String unitType,
        String bedrooms
    ) {
        
        List<String> out = new List<String>();
        
        List<AggregateResult> results = [
            
            SELECT UnitTypologyMRE__c typology
            
            FROM EOI_Range__c
            
            WHERE Project__c = :projectId
            AND Phase__c = :phaseId
            AND Unit_Type__c = :unitType
            AND No_of_Bedrooms__c = :bedrooms
            AND Is_Active__c = true
            AND UnitTypologyMRE__c != null
               AND Applicable_for_Broker__c=true
            
            GROUP BY UnitTypologyMRE__c
            
            ORDER BY UnitTypologyMRE__c ASC
        ];
        
        for (AggregateResult r : results) {
            
            out.add(
                (String) r.get('typology')
            );
        }
        
        return out;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String,List<String>>
        getPicklistValues() {
            
            Map<String,List<String>> result =
                new Map<String,List<String>>();
            
            result.put(
                'residentStatus',
                getValues(Lead.UAEResidentStatus__c)
            );
            
            result.put(
                'country',
                getValues(Lead.CountryOfResidence__c)
            );
            
            result.put(
                'nationality',
                getValues(Lead.Nationality__c)
            );
            
            result.put(
                'salutation',
                getValues(Lead.Salutation)
            );
            
            result.put(
                'paymentType',
                getValues(
                    Expressionofinterest__c.Payment_Type__c
                )
            );
            
            return result;
        }
    
    private static List<String>
        getValues(Schema.SObjectField field) {
            List<String> values = new List<String>();
            for( Schema.PicklistEntry entry :  field.getDescribe().getPicklistValues()) {
                values.add( entry.getValue());
            }
            return values;
        }
    
    
    
    // ------------ Wrapper List ----------- //
    public class RequestWrap{
        @AuraEnabled public String eoiId;
        @AuraEnabled public String comments;
    }
    
    public class RespondWrap {
        @AuraEnabled public String result;
    }
    
    /**
     * BP-054 (11 Sep 2026): the broker interest form is Project + Unit Type + Bedrooms. This returns the
     * active broker catalogue in one read so the form needs no phase-by-phase cascade, and so it can
     * never depend on Phase__c or UnitTypologyMRE__c being empty in the data - whatever those rows carry,
     * the server reads back off the row that matched. Nothing here filters on either field.
     * Additive: no existing method changed, so every other screen keeps the methods it already calls.
     */
    public class BrokerRangeOption implements Comparable {
        @AuraEnabled public String rangeId;
        @AuraEnabled public String projectId;
        @AuraEnabled public String projectName;
        @AuraEnabled public String unitType;
        @AuraEnabled public String bedrooms;
        @AuraEnabled public Decimal amount;

        public Integer compareTo(Object other) {
            BrokerRangeOption o = (BrokerRangeOption) other;
            Integer byProject = blankLast(projectName).compareTo(blankLast(o.projectName));
            if (byProject != 0) return byProject;
            Integer byType = blankLast(unitType).compareTo(blankLast(o.unitType));
            if (byType != 0) return byType;
            return blankLast(bedrooms).compareTo(blankLast(o.bedrooms));
        }
        private String blankLast(String v) {
            return v == null ? 'zzzz' : v;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<BrokerRangeOption> getBrokerRangeOptions() {
        List<BrokerRangeOption> out = new List<BrokerRangeOption>();
        for (EOI_Range__c r : [
            SELECT Id, Project__c, Project__r.Name, Unit_Type__c, No_of_Bedrooms__c, Amount__c
            FROM   EOI_Range__c
            /* BP-070: Show On is the only channel switch for the revamped portal. The legacy
               broker checkbox is gone from HERE ONLY; the five other queries in this class still
               carry it because the legacy mbpManageExpressionOfInterests component reads them. */
            WHERE  Is_Active__c = true
            AND    Show_On__c INCLUDES (:SHOW_ON_BROKER)
            AND    Project__c != null
            AND    Amount__c > 0
            ORDER BY Project__r.Name ASC, Unit_Type__c ASC, No_of_Bedrooms__c ASC, CreatedDate ASC
        ]) {
            BrokerRangeOption o = new BrokerRangeOption();
            o.rangeId     = String.valueOf(r.Id);
            o.projectId   = String.valueOf(r.Project__c);
            o.projectName = r.Project__r.Name;
            o.unitType    = r.Unit_Type__c;
            o.bedrooms    = r.No_of_Bedrooms__c;
            o.amount      = r.Amount__c;
            out.add(o);
        }
        out.sort();
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> getProjects() {
        Map<Id, String> seen = new Map<Id, String>();
        for (EOI_Range__c r : [
            SELECT Project__c, Project__r.Name
            FROM   EOI_Range__c
            WHERE  Is_Active__c = true
            AND  Project__c  != null
               AND Applicable_for_Broker__c=true
            ORDER BY Project__r.Name ASC
        ]) {
            if (!seen.containsKey(r.Project__c)) {
                seen.put(r.Project__c, r.Project__r.Name);
            }
        }
        List<LookupOption> options = new List<LookupOption>();
        for (Id pid : seen.keySet()) {
            options.add(new LookupOption(pid, seen.get(pid)));
        }
        options.sort();
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<LookupOption> getPhases(Id projectId) {
        Map<Id, String> seen = new Map<Id, String>();
        for (EOI_Range__c r : [
            SELECT Phase__c, Phase__r.Name
            FROM   EOI_Range__c
            WHERE  Project__c   = :projectId
            AND  Is_Active__c = true
            AND  Phase__c    != null
            ORDER BY Phase__r.Name ASC
        ]) {
            if (!seen.containsKey(r.Phase__c)) {
                seen.put(r.Phase__c, r.Phase__r.Name);
            }
        }
        List<LookupOption> options = new List<LookupOption>();
        for (Id pid : seen.keySet()) {
            options.add(new LookupOption(pid, seen.get(pid)));
        }
        options.sort();
        return options;
    }
    @AuraEnabled
    public static void updateBrokerAllocationTimer(Id eoiId) {
        
        Integer allocationHours =
            Integer.valueOf(
                System.Label.MBP_BrokerAllocationHours
            );
        
        Datetime allocationTime =
            System.now().addHours(
                allocationHours
            );
        
        Expressionofinterest__c eoi =
            new Expressionofinterest__c(
                Id = eoiId,
                
                Broker_Allocation_Timer__c =
                allocationTime.formatGmt(
                    'yyyy-MM-dd\'T\'HH:mm:ss\'Z\''
                )
            );
        
        update eoi;
    }
    @AuraEnabled
    public static List<Expressionofinterest__c> getEOIRecords() {
        
        User currentUser = [ SELECT Id, Contact.AccountId, Contact.Broker_Type__c, Contact.Id 
                            FROM User WHERE Id = :UserInfo.getUserId()];
        
        String brokerType = currentUser.Contact.Broker_Type__c;
        Id contactId = [ SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()  LIMIT 1].ContactId;
        
        List<Expressionofinterest__c>
            expressionOfInterestsList =
            new List<Expressionofinterest__c>();
        if(brokerType == 'Agent'){
            expressionOfInterestsList = [SELECT Id, Name,Broker_Allocation_Timer__c,  Phase__c, Phase__r.Name, EOI_Amount_AED__c,
                                         Project__c,Project__r.Name,UnitType__c,Opportunity__c, Opportunity__r.Name, NumberofBedrooms__c,
                                         Status__c, Number_of_Units__c, EOIComments__c, EOIId__c, Account__r.Name, Account__r.Email__c, 
                                         Account__r.PersonMobilePhone
                                         FROM Expressionofinterest__c WHERE Opportunity__r.BrokerAgent__c = :currentUser.Contact.Id
                                         ORDER BY CreatedDate DESC
                                        ];
        }else if(brokerType == 'Owner' || brokerType == 'Agency Admin') {
            expressionOfInterestsList = [SELECT Id, Name,Broker_Allocation_Timer__c,  Phase__c, Phase__r.Name, EOI_Amount_AED__c,
                                         Project__c,Project__r.Name,UnitType__c,Opportunity__c, Opportunity__r.Name, NumberofBedrooms__c,
                                         Status__c, Number_of_Units__c, EOIComments__c, EOIId__c, Account__r.Name, Account__r.Email__c, 
                                         Account__r.PersonMobilePhone   FROM Expressionofinterest__c  WHERE Opportunity__r.BrokerAgency__c = :currentUser.Contact.AccountId
                                         ORDER BY CreatedDate DESC
                                        ];
        }
        // BP-041: the EOI number reaches the broker only once the payment is held or taken
        redactEoiNumbers(expressionOfInterestsList);
        return expressionOfInterestsList;
        
    }

    /**
     * BP-041: blanks EOIId__c on every EOI whose newest payment is not yet Authorized / Captured, so the token the
     * customer knows never reaches a browser before the money is held. The LWC applies the same rule to Name.
     */
    private static void redactEoiNumbers(List<Expressionofinterest__c> eois) {
        if (eois == null || eois.isEmpty()) return;
        Map<Id, String> newestLinkStatus = new Map<Id, String>();
        for (Checkout_Payment__c cp : [
            SELECT Expression_of_Interest__c, Status__c
            FROM Checkout_Payment__c
            WHERE Expression_of_Interest__c IN :eois
            ORDER BY CreatedDate DESC, Id DESC
        ]) {
            if (!newestLinkStatus.containsKey(cp.Expression_of_Interest__c)) {
                newestLinkStatus.put(cp.Expression_of_Interest__c, cp.Status__c);
            }
        }
        for (Expressionofinterest__c eoi : eois) {
            String status = newestLinkStatus.get(eoi.Id);
            if (status == null || !MBP_EoiPaymentLinkController.EOI_NUMBER_VISIBLE_STATUSES.contains(status)) {
                eoi.EOIId__c = null;
            }
        }
    }
    public class expressionOfInterestWrapper {
        
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountEmail;
        @AuraEnabled public String accountPhone;
        @AuraEnabled public List<Expressionofinterest__c> eoiList;
        
        public expressionOfInterestWrapper() {
            eoiList = new List<Expressionofinterest__c>();
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<expressionOfInterestWrapper> getExpressionOfInterests() {
        List<expressionOfInterestWrapper> responseList = new List<expressionOfInterestWrapper>();
        Map<Id, List<Expressionofinterest__c>> accountEOI_Map = new Map<Id, List<Expressionofinterest__c>>();
        Map<Id, expressionOfInterestWrapper> accountEOIMap = new Map<Id, expressionOfInterestWrapper>();
        
        User currentUser = [ SELECT Id, 
                            Contact.AccountId,
                            Contact.Broker_Type__c,
                            Contact.Id 
                            FROM User WHERE Id = :UserInfo.getUserId()];
        
        String brokerType = currentUser.Contact.Broker_Type__c;
        
        List<Expressionofinterest__c> expressionOfInterestsList;
        if(brokerType == 'Agent'){
            expressionOfInterestsList = [SELECT Id, Name,Broker_Allocation_Timer__c,  Phase__c, Phase__r.Name, EOI_Amount_AED__c,
                                         Project__c,Project__r.Name,UnitType__c,Opportunity__c, Opportunity__r.Name, NumberofBedrooms__c,
                                         Status__c, Number_of_Units__c, EOIComments__c, EOIId__c, Account__r.Name, Account__r.Email__c, 
                                         Account__r.PersonMobilePhone
                                         FROM Expressionofinterest__c WHERE Opportunity__r.BrokerAgent__c = :currentUser.Contact.Id
                                         ORDER BY CreatedDate DESC
                                        ];
        }else if(brokerType == 'Owner' || brokerType == 'Agency Admin') {
            expressionOfInterestsList = [SELECT Id, Name,Broker_Allocation_Timer__c,  Phase__c, Phase__r.Name, EOI_Amount_AED__c,
                                         Project__c,Project__r.Name,UnitType__c,Opportunity__c, Opportunity__r.Name, NumberofBedrooms__c,
                                         Status__c, Number_of_Units__c, EOIComments__c, EOIId__c, Account__r.Name, Account__r.Email__c, 
                                         Account__r.PersonMobilePhone, Account__c
                                         FROM Expressionofinterest__c  WHERE Opportunity__r.BrokerAgency__c = :currentUser.Contact.AccountId
                                         ORDER BY CreatedDate DESC
                                        ];
        }
        for (Expressionofinterest__c eoi : expressionOfInterestsList) {
            if (!accountEOIMap.containsKey(eoi.Account__c)) {
                expressionOfInterestWrapper wrapper = new expressionOfInterestWrapper();
                wrapper.accountId = eoi.Account__c;
                wrapper.accountName = eoi.Account__r.Name;
                wrapper.accountEmail = eoi.Account__r.Email__c;
                wrapper.accountPhone = eoi.Account__r.PersonMobilePhone;
                accountEOIMap.put(eoi.Account__c, wrapper);
            }
            accountEOIMap.get(eoi.Account__c).eoiList.add(eoi);
        }
        responseList.addAll(accountEOIMap.values());
        return responseList;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getUnitTypes(Id projectId, Id phaseId) {
        List<AggregateResult> results = [
            SELECT Unit_Type__c ut
            FROM   EOI_Range__c
            WHERE  Project__c   = :projectId
            AND  Phase__c     = :phaseId
            AND  Is_Active__c = true
               AND Applicable_for_Broker__c=true
            GROUP BY Unit_Type__c
            ORDER BY Unit_Type__c ASC
        ];
        List<String> out = new List<String>();
        for (AggregateResult r : results) {
            out.add((String) r.get('ut'));
        }
        return out;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getBedrooms(Id projectId, Id phaseId, String unitType) {
        List<AggregateResult> results = [
            SELECT No_of_Bedrooms__c br
            FROM   EOI_Range__c
            WHERE  Project__c    = :projectId
            AND  Phase__c      = :phaseId
            AND  Unit_Type__c  = :unitType
            AND  Is_Active__c  = true
            AND Applicable_for_Broker__c=true
            GROUP BY No_of_Bedrooms__c
            ORDER BY No_of_Bedrooms__c ASC
        ];
        List<String> out = new List<String>();
        for (AggregateResult r : results) {
            out.add((String) r.get('br'));
        }
        return out;
    }
    
    @AuraEnabled(cacheable=true)
    public static EOIRangeResult getEOIRange(
        Id     projectId,
        Id     phaseId,
        String unitType,
        String bedrooms,
        String unitTypology
    ) {
        
        List<EOI_Range__c> ranges = [
            
            SELECT Id,
            Amount__c
            
            FROM EOI_Range__c
            
            WHERE Project__c = :projectId
            AND Phase__c = :phaseId
            AND Unit_Type__c = :unitType
               AND Applicable_for_Broker__c=true
            AND No_of_Bedrooms__c = :bedrooms
            AND UnitTypologyMRE__c = :unitTypology
            AND Is_Active__c = true
            
            LIMIT 1
        ];
        
        if (ranges.isEmpty()) {
            return null;
        }
        
        EOIRangeResult res = new EOIRangeResult();
        
        res.rangeId = ranges[0].Id;
        
        res.amount = ranges[0].Amount__c;
        
        return res;
    }
    
    
    
    
    @AuraEnabled
    public static Map<String,Object> convertLeadAndCreateEOIs(
        Id leadId,
        String eoiJson
    ) {
        
        Map<String,Object> response =
            new Map<String,Object>();
        
        List<String> pageErrors =
            new List<String>();
        
        Map<String,String> fieldErrors =
            new Map<String,String>();
        
        List<Id> createdEOIIds =
            new List<Id>();
        
        // BP-031: one savepoint for the whole submit, so a failure leaves no half-created records
        Savepoint sp = Database.setSavepoint();
        try {
            
            List<EOIWrapper> wrapperList =
                (List<EOIWrapper>) JSON.deserialize(
                    eoiJson,
                    List<EOIWrapper>.class
                );
            
            // BP-041: everything up to the one Opportunity is the shared step (prepareInternal);
            // this method keeps creating the EOIs afterwards for the legacy page. Same savepoint, same response keys.
            PreparedOpportunity prep = prepareInternal(leadId);
            Opportunity opp = prep.opp;
            Id accountId = prep.accountId;
            Id contactId = prep.contactId;
            User loggedInUser = prep.loggedInUser;
            Id convertedOppId = opp.Id;

            // =====================================================
            // CREATE EOIs - all under the one opportunity
            // =====================================================
            
            List<Expressionofinterest__c> eoisToInsert =
                new List<Expressionofinterest__c>();
            
            for(
                EOIWrapper item :
                wrapperList
            ){
                
                // =============================================
                // CREATE EOI
                // =============================================
                
                Expressionofinterest__c eoi =
                    new Expressionofinterest__c();
                
                eoi.Opportunity__c =
                    opp.Id;
                
                eoi.Project__c =
                    item.projectId;
                
                eoi.Phase__c =
                    item.phaseId;
                
                eoi.UnitType__c =
                    item.unitType;
                
                eoi.UnitTypologyMRE__c =
                    item.unitTypology;
                
                eoi.Payment_Type__c =
                    item.paymentType;
                
                eoi.NumberofBedrooms__c =
                    item.bedrooms;
                
                eoi.Number_of_Units__c =
                    item.numberOfUnits;
                
                eoi.EOI_Range__c =
                    item.eoiRangeId;
                
                eoi.EOI_Amount_AED__c =
                    item.eoiAmount;
                
                eoi.EOIComments__c =
                    item.remarks;
                
                eoi.Contact__c =
                    contactId;
                
                eoi.Account__c =
                    accountId;
                
                eoi.BrokerAgency__c =
                    loggedInUser.Contact.AccountId;
                
                eoi.BrokerAgent__c =
                    loggedInUser.ContactId;
                
                eoi.Status__c =
                    'New';
                
                eoisToInsert.add(eoi);
            }
            
            // BP-031: one insert for all interests - all EOIs are created or none
            insert eoisToInsert;
            
            for(Expressionofinterest__c created : eoisToInsert){
                createdEOIIds.add(created.Id);
            }
            
            response.put(
                'success',
                true
            );
            
            response.put(
                'createdEOIIds',
                createdEOIIds
            );
            
            response.put(
                'opportunityId',
                convertedOppId
            );
            
            response.put(
                'accountId',
                accountId
            );
            
            response.put(
                'contactId',
                contactId
            );
            
            return response;
            
        } catch(Exception ex){
            
            // BP-031: undo the conversion / opp / EOIs of this submit
            Database.rollback(sp);
            
            System.debug(
                'Exception ::: ' +
                ex.getMessage()
            );
            
            System.debug(
                'Stack ::: ' +
                ex.getStackTraceString()
            );
            
            pageErrors.add(
                ex.getMessage()
            );
            
            response.put(
                'success',
                false
            );
            
            response.put(
                'pageErrors',
                pageErrors
            );
            
            response.put(
                'fieldErrors',
                fieldErrors
            );
            
            return response;
        }
    }

    /**
     * BP-041 (Aurelix IT, 10 Sep 2026): Submit on the broker portal no longer creates EOIs. This converts the lead
     * and creates the one Opportunity with the broker stamps, exactly as convertLeadAndCreateEOIs does, and stops
     * there. The EOI is created by the shared Checkout rail once the customer's payment is authorized.
     * Response keys mirror convertLeadAndCreateEOIs minus createdEOIIds.
     */
    @AuraEnabled
    public static Map<String,Object> prepareBrokerOpportunity(Id leadId) {
        Map<String,Object> response = new Map<String,Object>();
        List<String> pageErrors = new List<String>();
        Map<String,String> fieldErrors = new Map<String,String>();
        Savepoint sp = Database.setSavepoint();
        try {
            if(leadId == null){
                throw new BrokerSubmitException('Lead id is required.');
            }
            PreparedOpportunity prep = prepareInternal(leadId);
            // v2.0 updated by Rushi Patel - 29 September 2026 - documents + KYC link, last so a failed submit never sends one
            sendKYCForBrokerCustomer(prep.accountId, prep.loggedInUser);
            response.put('success', true);
            response.put('opportunityId', prep.opp.Id);
            response.put('accountId', prep.accountId);
            response.put('contactId', prep.contactId);
            return response;
        } catch(Exception ex){
            Database.rollback(sp);
            System.debug('prepareBrokerOpportunity exception ::: ' + ex.getMessage());
            pageErrors.add(ex.getMessage());
            response.put('success', false);
            response.put('pageErrors', pageErrors);
            response.put('fieldErrors', fieldErrors);
            return response;
        }
    }

    /* v2.0 updated by Rushi Patel - 29 September 2026
       @description : Runs after a broker EOI submit has prepared the customer. For an Individual customer
                      (Person Account, new or matched) it creates the placeholder documents the customer does
                      not have yet, then sends the KYC link unless their KYC is still active or a link sent
                      earlier is still live (Is_KYC_Link_Active__c). Organization accounts are skipped. Runs only for broker users. A failure here is logged and rolled
                      back without stopping the submit. */
    @TestVisible
    private static void sendKYCForBrokerCustomer(Id accountId, User loggedInUser) {
        if (accountId == null || loggedInUser == null || loggedInUser.ContactId == null) {
            return;
        }
        Savepoint sp = Database.setSavepoint();
        try {
            Account acc = [SELECT Id, IsPersonAccount, KYC_Status__c, Is_KYC_Link_Active__c FROM Account WHERE Id = :accountId];
            if (!acc.IsPersonAccount) {
                return;
            }

            // Adds only the document names the customer does not have yet, so a matched account is safe
            GenerateCustomerDocumentAccount.createDocumentRecords(new List<Account>{ acc });

            // No new link while KYC is active or a link already sent is still live, so repeat EOIs don't resend it.
            // KYC link goes out async, sendKYCForm makes a callout. Keep this last in the try.
            if (acc.KYC_Status__c != KYC_STATUS_ACTIVE && !acc.Is_KYC_Link_Active__c) {
                System.enqueueJob(new MBP_BrokerLeadKYCQueueable(acc.Id));
            }
        } catch (Exception e) {
            Database.rollback(sp);
            LoggerService.save(LoggerService.createApexLog(e, 'Broker EOI KYC Link', 'MBP_ExpressionOfInterestsController', 'sendKYCForBrokerCustomer'));
        }
    }

    public class BrokerSubmitException extends Exception {}

    /** BP-041: what the shared step hands back to both submit paths. */
    private class PreparedOpportunity {
        Opportunity opp;
        Id accountId;
        Id contactId;
        User loggedInUser;
    }

    /**
     * BP-041: the shared step of every broker submit - lead read, account / contact matching, lead conversion and
     * the one Opportunity with the broker stamps (BP-031). Lifted verbatim from convertLeadAndCreateEOIs; no
     * savepoint here, the callers own the transaction. Throws on any failure.
     */
    private static PreparedOpportunity prepareInternal(Id leadId) {
            Lead leadRec = [
                
                SELECT Id,
                Name,
                FirstName,
                LastName,
                Email,
                MobilePhone,
                Phone,
                Company,
                OwnerId,
                Status,
                IsConverted,
                ConvertedAccountId,
                ConvertedContactId,
                ConvertedOpportunityId,
                EIDNumber__c,
                EmiratesIDExpiryDate__c,
                PassportNumber__c,
                PassportExpiryDate__c,
                UAEResidentStatus__c,
                Nationality__c,
                CountryOfResidence__c,
                UnifiedNumber__c,
                Trade_License_Expiry_Date__c
                
                FROM Lead
                
                WHERE Id = :leadId
                
                LIMIT 1
            ];
            
            User loggedInUser = [
                
                SELECT Id,
                ContactId,
                Contact.Name,
                Contact.MobilePhone,
                Contact.AccountId
                
                FROM User
                
                WHERE Id = :UserInfo.getUserId()
                
                LIMIT 1
            ];
            
            String ownerUsername =
                System.Label.MBP_OwnerAssignment;
            
            Id oppOwnerId;
            
            List<User> ownerUsers = [
                
                SELECT Id,
                Name
                
                FROM User
                
                WHERE Username = :ownerUsername
                AND IsActive = true
                
                LIMIT 1
            ];
            
            if(!ownerUsers.isEmpty()){
                
                oppOwnerId =
                    ownerUsers[0].Id;
            }
            
            // =====================================================
            // MATCH ACCOUNT + CONTACT
            // =====================================================
            
            Account matchedAccount;
            
            Contact matchedContact;
            
            // =====================================================
            // ORGANIZATION FLOW
            // =====================================================
            
            if(String.isNotBlank(leadRec.Company)){
                
                System.debug(
                    'Organization Flow'
                );
                
                List<Account> orgAccounts = [
                    
                    SELECT Id,
                    Name,
                    UnifiedNumber__c,
                    Company_Email_Address__c
                    
                    FROM Account
                    
                    WHERE IsPersonAccount = false
                    
                 AND (
    
    UnifiedNumber__c != null
    
    AND UnifiedNumber__c =
    :leadRec.UnifiedNumber__c
)
                    
                    
                    
                    LIMIT 1
                ];
                
                // =================================================
                // ACCOUNT FOUND
                // =================================================
                
                if(!orgAccounts.isEmpty()){
                    
                    matchedAccount =
                        orgAccounts[0];
                    
                    System.debug(
                        'Matched Org Account ::: ' +
                        matchedAccount.Id
                    );
                    
                    List<Contact> contacts = [
                        
                        SELECT Id,
                        FirstName,
                        LastName,
                        Email,
                        MobilePhone
                        
                        FROM Contact
                        
                        WHERE AccountId =
                        :matchedAccount.Id
                        
                      AND (
    
    (
        Email != null
        
        AND Email =
        :leadRec.Email
    )
    
    OR
    
    (
        MobilePhone != null
        
        AND MobilePhone =
        :leadRec.MobilePhone
    )
)
                        
                        LIMIT 1
                    ];
                    
                    // =============================================
                    // CONTACT FOUND
                    // =============================================
                    
                    if(!contacts.isEmpty()){
                        
                        matchedContact =
                            contacts[0];
                        
                        System.debug(
                            'Matched Contact ::: ' +
                            matchedContact.Id
                        );
                        
                    } else {
                        
                        // =========================================
                        // CREATE CONTACT
                        // =========================================
                        
                        matchedContact =
                            new Contact();
                        
                        matchedContact.AccountId =
                            matchedAccount.Id;
                        
                        matchedContact.FirstName =
                            leadRec.FirstName;
                        
                        matchedContact.LastName =
                            
                            String.isBlank(
                                leadRec.LastName
                            )
                            
                            ? 'Customer'
                            : leadRec.LastName;
                        
                        matchedContact.Email =
                            leadRec.Email;
                        
                        matchedContact.MobilePhone =
                            leadRec.MobilePhone;
                        
                        insert matchedContact;
                        
                        System.debug(
                            'Created Contact ::: ' +
                            matchedContact.Id
                        );
                    }
                    
                } else {
                    
                    // =============================================
                    // CREATE ACCOUNT
                    // =============================================
                    
                    matchedAccount =
                        new Account();
                    
                    matchedAccount.Name =
                        leadRec.Company;
                    
   Id orgRecordTypeId =
    
    Schema.SObjectType.Account
    .getRecordTypeInfosByDeveloperName()
    .get('OrganizationAccount')
    .getRecordTypeId();

System.debug(
    'ORG RECORD TYPE ID ::: ' +
    orgRecordTypeId
);

matchedAccount.RecordTypeId =
    orgRecordTypeId;
                    matchedAccount.UnifiedNumber__c =
                        leadRec.UnifiedNumber__c;
                    
                    matchedAccount.Company_Email_Address__c =
                        leadRec.Email;
                    
                    insert matchedAccount;
                    
                    System.debug(
                        'Created Org Account ::: ' +
                        matchedAccount.Id
                    );
                    
                    // =============================================
                    // CREATE CONTACT
                    // =============================================
                    
                    matchedContact =
                        new Contact();
                    
                    matchedContact.AccountId =
                        matchedAccount.Id;
                    
                    matchedContact.FirstName =
                        leadRec.FirstName;
                    
                    matchedContact.LastName =
                        
                        String.isBlank(
                            leadRec.LastName
                        )
                        
                        ? 'Customer'
                        : leadRec.LastName;
                    
                    matchedContact.Email =
                        leadRec.Email;
                    
                    matchedContact.MobilePhone =
                        leadRec.MobilePhone;
                    
                    insert matchedContact;
                    
                    System.debug(
                        'Created Contact ::: ' +
                        matchedContact.Id
                    );
                }
                
            } else {
                
                // =================================================
                // PERSON ACCOUNT FLOW
                // =================================================
                
                System.debug(
                    'Person Account Flow'
                );
                
                List<Account> personAccounts = [
                    
                    SELECT Id,
                    Name,
                    PersonContactId,
                    PersonEmail,
                    PersonMobilePhone,
                    EIDNumber__pc,
                    PassportNumber__pc
                    
                    FROM Account
                    
                    WHERE IsPersonAccount = true
                    
               AND (
    
    (
        EIDNumber__pc != null
        AND EIDNumber__pc =
        :leadRec.EIDNumber__c
    )
    
    OR
    
    (
        PassportNumber__pc != null
        AND PassportNumber__pc =
        :leadRec.PassportNumber__c
    )
    
    OR
    
    (
        PersonEmail != null
        AND PersonEmail =
        :leadRec.Email
    )
)      
                    LIMIT 1
                ];
                
                // =============================================
                // ACCOUNT FOUND
                // =============================================
                
                if(!personAccounts.isEmpty()){
                    
                    matchedAccount =
                        personAccounts[0];
                    
                    System.debug(
                        'Matched Person Account ::: ' +
                        matchedAccount.Id
                    );
                    
                    if(
                        matchedAccount.PersonContactId
                        != null
                    ){
                        
                        matchedContact = [
                            
                            SELECT Id
                            
                            FROM Contact
                            
                            WHERE Id =
                            :matchedAccount.PersonContactId
                            
                            LIMIT 1
                        ];
                    }
                    
                } else {
                    
                    // =========================================
                    // CREATE PERSON ACCOUNT
                    // =========================================
                    
                    matchedAccount =
                        new Account();
                    
                    matchedAccount.RecordTypeId =
                        
                        Schema.SObjectType.Account
                        .getRecordTypeInfosByDeveloperName()
                        .get('PersonAccount')
                        .getRecordTypeId();
                    
                    matchedAccount.FirstName =
                        leadRec.FirstName;
                    
                    matchedAccount.LastName =
                        
                        String.isBlank(
                            leadRec.LastName
                        )
                        
                        ? 'Customer'
                        : leadRec.LastName;
                    
                    matchedAccount.PersonEmail =
                        leadRec.Email;
                    
                    matchedAccount.PersonMobilePhone =
                        leadRec.MobilePhone;
                    
                    matchedAccount.EIDNumber__pc =
                        leadRec.EIDNumber__c;
                    
                    matchedAccount.PassportNumber__pc =
                        leadRec.PassportNumber__c;
                    
                    insert matchedAccount;
                    
                    System.debug(
                        'Created Person Account ::: ' +
                        matchedAccount.Id
                    );
                    
                    matchedAccount = [
                        
                        SELECT Id,
                        PersonContactId
                        
                        FROM Account
                        
                        WHERE Id =
                        :matchedAccount.Id
                        
                        LIMIT 1
                    ];
                    
                    if(
                        matchedAccount.PersonContactId
                        != null
                    ){
                        
                        matchedContact = [
                            
                            SELECT Id
                            
                            FROM Contact
                            
                            WHERE Id =
                            :matchedAccount.PersonContactId
                            
                            LIMIT 1
                        ];
                    }
                }
            }
            
            // =====================================================
            // FINAL IDS
            // =====================================================
            
            Id accountId =
                matchedAccount != null
                ? matchedAccount.Id
                : null;
            
            Id contactId =
                matchedContact != null
                ? matchedContact.Id
                : null;
            
            Id convertedOppId;
            
            System.debug(
                'Final Account Id ::: ' +
                accountId
            );
            
            System.debug(
                'Final Contact Id ::: ' +
                contactId
            );
            
            // =====================================================
            // HANDLE LEAD CONVERSION
            // =====================================================
            
            if(leadRec.IsConverted){
                
                System.debug(
                    'Lead Already Converted'
                );
                
                accountId =
                    leadRec.ConvertedAccountId;
                
                contactId =
                    leadRec.ConvertedContactId;
                
                convertedOppId =
                    leadRec.ConvertedOpportunityId;
                
                // =============================================
                // IF OPP NOT AVAILABLE
                // =============================================
                
                if(convertedOppId == null){
                    
                    List<Opportunity> opps = [
                        
                        SELECT Id
                        
                        FROM Opportunity
                        
                        WHERE AccountId =
                        :accountId
                        
                        ORDER BY CreatedDate DESC
                        
                        LIMIT 1
                    ];
                    
                    if(!opps.isEmpty()){
                        
                        convertedOppId =
                            opps[0].Id;
                    }
                }
                
            } else {
                
                // =================================================
                // CONVERT LEAD
                // =================================================
                
                Database.LeadConvert lc =
                    new Database.LeadConvert();
                
                lc.setLeadId(
                    leadRec.Id
                );
                
                lc.setConvertedStatus(
                    'Qualified'
                );
                
                // =============================================
                // MERGE ACCOUNT
                // =============================================
                
                if(accountId != null){
                    
                    lc.setAccountId(
                        accountId
                    );
                }
                
                // =============================================
                // MERGE CONTACT
                // =============================================
                
                if(contactId != null){
                    
                    lc.setContactId(
                        contactId
                    );
                }
                
                // =============================================
                // CREATE OPPORTUNITY
                // =============================================
                
                lc.setDoNotCreateOpportunity(
                    false
                );
                
                lc.setOpportunityName(
                    
                    leadRec.FirstName +
                    ' ' +
                    leadRec.LastName
                );
                
                // =============================================
                // OWNER
                // =============================================
                
                if(oppOwnerId != null){
                    
                    lc.setOwnerId(
                        oppOwnerId
                    );
                }
                
                System.debug(
                    'Before Lead Convert'
                );
                
                Database.LeadConvertResult lcr =
                    Database.convertLead(
                        lc
                    );
                
                System.debug(
                    'After Lead Convert ::: ' +
                    lcr.isSuccess()
                );
            
            // BP-041: the single-record overload throws on failure, so this only guards a silent non-success
            if(!lcr.isSuccess()){
                String reason = lcr.getErrors().isEmpty() ? 'Lead conversion failed.' : lcr.getErrors()[0].getMessage();
                throw new BrokerSubmitException(reason);
            }
                
                // =============================================
                // FAILED
                // =============================================
                
                
                
                // =============================================
                // FINAL IDS
                // =============================================
                
                accountId =
                    lcr.getAccountId();
                
                contactId =
                    lcr.getContactId();
                
                convertedOppId =
                    lcr.getOpportunityId();
                
                System.debug(
                    'Converted Account ::: ' +
                    accountId
                );
                
                System.debug(
                    'Converted Contact ::: ' +
                    contactId
                );
                
                System.debug(
                    'Converted Opp ::: ' +
                    convertedOppId
                );
            }
            
            // =====================================================
            // ONE OPPORTUNITY FOR ALL EOIs (BP-031)
            // =====================================================
            
            Opportunity opp;
            
            if(convertedOppId != null){
                
                // BP-031: the converted opp is reused for every interest; stamp the broker on it
                opp = [
                    SELECT Id, Name
                    FROM Opportunity
                    WHERE Id = :convertedOppId
                    LIMIT 1
                ];
                
                opp.BrokerAgency__c      = loggedInUser.Contact.AccountId;
                opp.BrokerAgent__c       = loggedInUser.ContactId;
                opp.BrokerAgentMobile__c = loggedInUser.Contact.MobilePhone;
                opp.BrokerAgentName__c   = loggedInUser.Contact.Name;
                opp.LeadSource           = 'Broker Portal';
                update opp;
                
            } else {
                
                // BP-031: no opp came out of conversion (converted lead without one) - create the single opp
                opp = new Opportunity();
                
                opp.Name =
                    leadRec.Name;
                
                opp.StageName =
                    '0-Buyer Awareness';
                
                opp.LeadSource =
                    'Broker Portal';
                
                opp.CloseDate =
                    System.today().addMonths(1);
                
                opp.AccountId =
                    accountId;
                
                if(
                    Schema.sObjectType.Opportunity
                    .fields.getMap()
                    .containsKey('ContactId')
                ){
                    
                    opp.ContactId =
                        contactId;
                }
                
                opp.OwnerId =
                    oppOwnerId;
                
                opp.BrokerAgency__c =
                    loggedInUser.Contact.AccountId;
                
                opp.BrokerAgent__c =
                    loggedInUser.ContactId;
                
                opp.BrokerAgentMobile__c =
                    loggedInUser.Contact.MobilePhone;
                
                opp.BrokerAgentName__c =
                    loggedInUser.Contact.Name;
                
                insert opp;
                
                convertedOppId = opp.Id;
            }
            
            PreparedOpportunity prepared = new PreparedOpportunity();
            prepared.opp = opp;
            prepared.accountId = accountId;
            prepared.contactId = contactId;
            prepared.loggedInUser = loggedInUser;
            return prepared;
    }

    public class LookupOption implements Comparable {
        @AuraEnabled public Id     value;
        @AuraEnabled public String label;
        public LookupOption(Id v, String l) { value = v; label = l; }
        public Integer compareTo(Object other) {
            return label.compareTo(((LookupOption) other).label);
        }
    }
    public class BrokerEOILimitWrapper {
        @AuraEnabled public Integer brokerClassificationLimit;
        @AuraEnabled public Integer brokerClassificationUsed;
        @AuraEnabled public Integer brokerClassificationRemaining;
        @AuraEnabled public Integer projectLimit;
        @AuraEnabled public Integer projectUsed;
        @AuraEnabled public Integer projectRemaining;        
        @AuraEnabled public Boolean canCreateEOI;
    }
    
    
    @AuraEnabled
    public static void sendEOISuccessEmail(List<Id> eoiIds) {
        try {
            List<Expressionofinterest__c> eoiList = [
                SELECT Id,
                Name,
                Contact__r.FirstName,
                Contact__r.LastName,
                Contact__r.Email,
                BrokerAgent__r.Email,
                EOIId__c
                FROM Expressionofinterest__c
                WHERE Id IN :eoiIds
            ];
            
            for (Expressionofinterest__c eoi :eoiList ) {
                if (eoi.Contact__r == null ||String.isBlank( eoi.Contact__r.Email)) {
                    continue;
                }
                String subject;
                String body;
                
                subject = 'Your Expression Of Interest Has Been Successfully Submitted';
                body =
                    'Dear ' +
                    eoi.Contact__r.FirstName +
                    ' ' +
                    eoi.Contact__r.LastName +
                    
                    ',<br><br>' +
                    
                    'We are pleased to confirm that your Expression Of Interest (EOI) has been successfully submitted with Modon.<br><br>' +
                    
                    '<strong>EOI Number: ' +
                    eoi.EOIId__c +
                    '</strong><br><br>' +
                    
                    'Kindly visit the Modon branch within <strong>24 hours</strong> and submit your cheque to complete the reservation process.<br><br>' +
                    'Please note that failure to submit the cheque within the required timeline may result in automatic cancellation of your EOI.<br><br>' +
                    'If you require any assistance, please contact the Modon Broker Team.<br><br>' +
                    'Thank you for choosing Modon.<br><br>';
                
                String emailHtml = MBP_ModonEmailUtilityClass.getFullEmailHtml(body);
                String personalizationsEntry =
                    
                    '[{"to": [{"email": "' +
                    
                    eoi.Contact__r.Email +
                    
                    '" } ],'+ '"cc":[{"email":"' +eoi.BrokerAgent__r.Email+'" } ] }]';
                
                String gridConfigName =
                    'Al Naseem';
                BP_SendGridUtilityClass.sendEmail(
                    personalizationsEntry,
                    gridConfigName,
                    subject,
                    emailHtml,
                    true
                );
                
            }
        }
        
        catch(Exception ex) {
            
            System.debug(
                'EOI EMAIL ERROR => ' +
                ex.getMessage()
            );
        }
    }
    @AuraEnabled(cacheable=false)
    public static BrokerEOILimitWrapper getBrokerEOIAvailability(Id projectId) {
        BrokerEOILimitWrapper res =  new BrokerEOILimitWrapper();
        User usr = [
            SELECT Id,
            ContactId,
            Contact.AccountId,
            Contact.Account.Broker_Classification__c,
            Contact.Account.Broker_Classification__r.EOI_Limit__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1 ];
        Integer brokerLimit = 0;
        
        if(usr.Contact.Account.Broker_Classification__c != null &&
           usr.Contact.Account.Broker_Classification__r.EOI_Limit__c != null) {
               brokerLimit = Integer.valueOf(usr.Contact.Account.Broker_Classification__r.EOI_Limit__c);
           }else {
               brokerLimit = Integer.valueOf([SELECT Id, Name, EOI_Limit__c FROM Broker_Classification__c WHERE Name = 'Standard'].EOI_Limit__c);
           }
        Project__c proj = [ SELECT Id,EOI_Limit__c  FROM Project__c WHERE Id = :projectId LIMIT 1];
        Integer projectLimit = proj.EOI_Limit__c != null ? Integer.valueOf(proj.EOI_Limit__c): 0;
        Integer brokerUsed = [SELECT COUNT() FROM Expressionofinterest__c 
                              WHERE Opportunity__r.BrokerAgency__c =:usr.Contact.AccountId ];
        Integer projectUsed = [ SELECT COUNT()  FROM Expressionofinterest__c  WHERE Project__c = :projectId];
        Integer brokerRemaining =  brokerLimit - brokerUsed;
        Integer projectRemaining = projectLimit - projectUsed;
        
        if(brokerRemaining < 0) {
            brokerRemaining = 0;
        }if(projectRemaining < 0) {
            projectRemaining = 0;
        }
        res.brokerClassificationLimit =brokerLimit;
        res.brokerClassificationUsed = brokerUsed;
        res.brokerClassificationRemaining = brokerRemaining;
        res.projectLimit = projectLimit;
        res.projectUsed = projectUsed;
        res.projectRemaining = projectRemaining;
        res.canCreateEOI =  brokerRemaining > 0 &&  projectRemaining > 0;
        return res;
    }
    
    @AuraEnabled
    public static void voidEOI(
        Id eoiId,
        String reason
    ) {
        // BP-032: one void rule for every caller - agency scope + link still 'Link Created' - lives in MBP_EoiPaymentLinkController
        MBP_EoiPaymentLinkController.voidEoi(eoiId, reason);
    }

    public class BrokerValidationResult {
        @AuraEnabled public Boolean isBlocked = false;
        @AuraEnabled public String message = '';  
    }
    public class EOIRangeResult {
        @AuraEnabled public Id rangeId;
        @AuraEnabled public Decimal amount;
    }
    public class EOIWrapper {
        
        @AuraEnabled public Id eoiId;
        @AuraEnabled public Id projectId;
        @AuraEnabled public Id phaseId;
        @AuraEnabled public String unitType;
        @AuraEnabled public String bedrooms;
        @AuraEnabled public Integer numberOfUnits;
        @AuraEnabled public Id eoiRangeId;
        @AuraEnabled public Decimal eoiAmount;
        @AuraEnabled public String remarks;
        @AuraEnabled public String unitTypology;
        @AuraEnabled
        public String paymentType;
        
    }
    public class ValidationResult {
        @AuraEnabled public Boolean isDuplicate    = false;
        @AuraEnabled public String  existingEOIRef;
        @AuraEnabled public Integer quotaLimit     = 0;
        @AuraEnabled public Integer quotaUsed      = 0;
        @AuraEnabled public Integer quotaRemaining = 0;
        @AuraEnabled public Boolean quotaExceeded  = false;
    }
}