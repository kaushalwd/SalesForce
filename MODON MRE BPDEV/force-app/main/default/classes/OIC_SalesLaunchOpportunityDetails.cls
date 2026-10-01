/**********************************************************************************************************************
* Name               : OIC_SalesLaunchOpportunityDetails
* Description        : This class is used to fetch opportunities for sales launch.
* Usage              : Used to Integrate with Evento.
* Created By         : Activemindsit
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Prateek                     03 06 2026      Initial Draft
* 1.1           Prateek                     04 06 2026      Added completed EOI and eligible receipt validation
* 1.2           Prateek                     04 06 2026      Removed receipt type dependency from EOI eligibility
* 1.3           Prateek                     04 06 2026      Removed non-opportunity Salesforce Ids from response
* 1.4           Prateek                     04 06 2026      Added campaign id back to response
* 1.5           Prateek                     05 06 2026      Updated customer type source and broker phone fallback
* 1.6           Jay Patel                   22 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/saleslaunch/opportunitydetails/*')
global with sharing class OIC_SalesLaunchOpportunityDetails {

    @HttpGet
    global static void getOpportunityDetails() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        String campaignId = restRequest.params.get('CampaignId');
        String modifiedDateTime = restRequest.params.get('ModifiedDateTime');
        OpportunityDetailsResponse responseBody = new OpportunityDetailsResponse();

        restRequest.addHeader('Content-Type', 'application/json');
        System.debug('OIC_SalesLaunchOpportunityDetails >>>> getOpportunityDetails >> ' + campaignId);

        if (String.isBlank(campaignId)) {
            responseBody.Status = 'Failure';
            responseBody.ErrorCode = 'Evento-001';
            responseBody.ErrorMessage = 'Campaign Id should not be empty';
            writeResponse(restResponse, responseBody);
            return;
        }

        Datetime cutoff;
        try {
            cutoff = parseDateTime(modifiedDateTime);
        } catch (Exception ex) {
            responseBody.Status = 'Failure';
            responseBody.ErrorCode = 'Evento-002';
            responseBody.ErrorMessage = 'ModifiedDateTime is invalid';
            writeResponse(restResponse, responseBody);
            return;
        }

        try {
            List<Opportunity> opportunities;
            if (cutoff != null) {
                //1.6 MCR-73: Enforce CRUD/FLS via USER_MODE on Opportunity query
                opportunities = [
                    SELECT SalesLaunchCampaign__c, SalesLaunchCampaign__r.Name, Id, Name, StageName,
                           UAE_Resident_Status__c, LeadSource, Owner.Name, AccountId,
                           Account.Name, Account.CustomerType__c, PrimaryContact__c, PrimaryContact__r.Name, PrimaryContact__r.Phone,
                           PrimaryContact__r.MobilePhone, PrimaryContact__r.Email, BrokerAgency__r.Name,
                           BrokerAgent__r.Name, BrokerAgent__r.Phone, BrokerAgent__r.MobilePhone, BrokerAgent__r.Email,
                           Probability, LastModifiedDate
                    FROM Opportunity
                    WHERE SalesLaunchCampaign__c = :campaignId
                    AND LastModifiedDate >= :cutoff
                    WITH USER_MODE
                ];
            } else {
                //1.6 MCR-73: Enforce CRUD/FLS via USER_MODE on Opportunity query
                opportunities = [
                    SELECT SalesLaunchCampaign__c, SalesLaunchCampaign__r.Name, Id, Name, StageName,
                           UAE_Resident_Status__c, LeadSource, Owner.Name, AccountId,
                           Account.Name, Account.CustomerType__c, PrimaryContact__c, PrimaryContact__r.Name, PrimaryContact__r.Phone,
                           PrimaryContact__r.MobilePhone, PrimaryContact__r.Email, BrokerAgency__r.Name,
                           BrokerAgent__r.Name, BrokerAgent__r.Phone, BrokerAgent__r.MobilePhone, BrokerAgent__r.Email,
                           Probability, LastModifiedDate
                    FROM Opportunity
                    WHERE SalesLaunchCampaign__c = :campaignId
                    WITH USER_MODE
                ];
            }

            Map<Id, List<String>> eligibleEoisByOpportunity = getEligibleEoisByOpportunity(opportunities);
            List<OpportunityRecord> opportunityRecords = new List<OpportunityRecord>();
            for (Opportunity opportunityRecord : opportunities) {
                if (!eligibleEoisByOpportunity.containsKey(opportunityRecord.Id)) {
                    continue;
                }

                OpportunityRecord row = new OpportunityRecord();
                row.CampaignId = opportunityRecord.SalesLaunchCampaign__c;
                row.CampaignName = opportunityRecord.SalesLaunchCampaign__r != null
                    ? opportunityRecord.SalesLaunchCampaign__r.Name
                    : null;
                row.OpportunityId = opportunityRecord.Id;
                row.OpportunityName = opportunityRecord.Name;
                row.StageName = opportunityRecord.StageName;
                row.CustomerType = opportunityRecord.Account != null
                    ? opportunityRecord.Account.CustomerType__c
                    : null;
                row.UAEResidentStatus = opportunityRecord.UAE_Resident_Status__c;
                row.LeadSource = opportunityRecord.LeadSource;
                row.OpportunityOwnerName = opportunityRecord.Owner != null
                    ? opportunityRecord.Owner.Name
                    : null;
                row.AccountName = opportunityRecord.Account != null
                    ? opportunityRecord.Account.Name
                    : null;
                row.PrimaryContactName = opportunityRecord.PrimaryContact__r != null
                    ? opportunityRecord.PrimaryContact__r.Name
                    : null;
                row.CustomerPhone = opportunityRecord.PrimaryContact__r != null
                    ? opportunityRecord.PrimaryContact__r.Phone
                    : null;
                row.CustomerMobilePhone = opportunityRecord.PrimaryContact__r != null
                    ? opportunityRecord.PrimaryContact__r.MobilePhone
                    : null;
                row.CustomerEmail = opportunityRecord.PrimaryContact__r != null
                    ? opportunityRecord.PrimaryContact__r.Email
                    : null;
                row.BrokerAgencyName = opportunityRecord.BrokerAgency__r != null
                    ? opportunityRecord.BrokerAgency__r.Name
                    : null;
                row.BrokerAgentName = opportunityRecord.BrokerAgent__r != null
                    ? opportunityRecord.BrokerAgent__r.Name
                    : null;
                row.BrokerAgentMobilePhone = opportunityRecord.BrokerAgent__r != null
                    ? (String.isNotBlank(opportunityRecord.BrokerAgent__r.MobilePhone)
                        ? opportunityRecord.BrokerAgent__r.MobilePhone
                        : opportunityRecord.BrokerAgent__r.Phone)
                    : null;
                row.BrokerAgentEmail = opportunityRecord.BrokerAgent__r != null
                    ? opportunityRecord.BrokerAgent__r.Email
                    : null;
                row.Probability = opportunityRecord.Probability;
                row.LastModifiedDate = opportunityRecord.LastModifiedDate;
                row.EOIs = String.join(eligibleEoisByOpportunity.get(opportunityRecord.Id), ', ');
                opportunityRecords.add(row);
            }

            responseBody.OpportunityRecords = opportunityRecords;
            responseBody.Status = 'Success';
            responseBody.ErrorCode = '';
            responseBody.ErrorMessage = '';

            writeResponse(restResponse, responseBody);
        } catch (Exception ex) {
            //1.6 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'Sales Launch Opportunity Details',
                'OIC_SalesLaunchOpportunityDetails',
                'getOpportunityDetails'
            ));
            responseBody.Status = 'Failure';
            responseBody.ErrorCode = 'Evento-999';
            responseBody.ErrorMessage = ex.getMessage();
            writeResponse(restResponse, responseBody);
        }
    }

    private static Datetime parseDateTime(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        return (Datetime) JSON.deserialize('"' + value + '"', Datetime.class);
    }

    private static Map<Id, List<String>> getEligibleEoisByOpportunity(List<Opportunity> opportunities) {
        Map<Id, List<String>> eligibleEoisByOpportunity = new Map<Id, List<String>>();
        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity opportunityRecord : opportunities) {
            opportunityIds.add(opportunityRecord.Id);
        }

        if (opportunityIds.isEmpty()) {
            return eligibleEoisByOpportunity;
        }

        Map<Id, Id> opportunityIdByEoiId = new Map<Id, Id>();
        Map<Id, String> eoiNumberById = new Map<Id, String>();
        //1.6 MCR-73: Enforce CRUD/FLS via USER_MODE on ExpressionOfInterest__c query
        for (ExpressionOfInterest__c eoiRecord : [
            SELECT Id, Name, EOI_Code_Legacy__c, Opportunity__c
            FROM ExpressionOfInterest__c
            WHERE Opportunity__c IN :opportunityIds
            AND Status__c = 'Completed'
            WITH USER_MODE
            ORDER BY CreatedDate ASC
        ]) {
            opportunityIdByEoiId.put(eoiRecord.Id, eoiRecord.Opportunity__c);
            eoiNumberById.put(
                eoiRecord.Id,
                String.isBlank(eoiRecord.EOI_Code_Legacy__c) ? eoiRecord.Name : eoiRecord.EOI_Code_Legacy__c
            );
        }

        if (opportunityIdByEoiId.isEmpty()) {
            return eligibleEoisByOpportunity;
        }

        Set<Id> eligibleEoiIds = new Set<Id>();
        //1.6 MCR-73: Enforce CRUD/FLS via USER_MODE on Receipt__c query
        for (Receipt__c receiptRecord : [
            SELECT Id, ExpressionOfInterest__c
            FROM Receipt__c
            WHERE ExpressionOfInterest__c IN :opportunityIdByEoiId.keySet()
            AND (Status__c = 'Cleared' OR Allow_Any_Status_for_Booking__c = true)
            WITH USER_MODE
        ]) {
            eligibleEoiIds.add(receiptRecord.ExpressionOfInterest__c);
        }

        for (Id eoiId : opportunityIdByEoiId.keySet()) {
            if (!eligibleEoiIds.contains(eoiId)) {
                continue;
            }

            Id opportunityId = opportunityIdByEoiId.get(eoiId);
            if (!eligibleEoisByOpportunity.containsKey(opportunityId)) {
                eligibleEoisByOpportunity.put(opportunityId, new List<String>());
            }
            eligibleEoisByOpportunity.get(opportunityId).add(eoiNumberById.get(eoiId));
        }

        return eligibleEoisByOpportunity;
    }

    private static void writeResponse(RestResponse restResponse, OpportunityDetailsResponse responseBody) {
        System.debug('OIC_SalesLaunchOpportunityDetails >>>> Response >> ' + System.JSON.serialize(responseBody));
        restResponse.statusCode = responseBody != null && responseBody.Status == 'Success' ? 200 : 400;
        restResponse.addHeader('Content-Type', 'application/json');
        restResponse.responseBody = Blob.valueOf(JSON.serialize(responseBody));
    }

    global class OpportunityDetailsResponse {
        public List<OpportunityRecord> OpportunityRecords;
        public String Status;
        public String ErrorCode;
        public String ErrorMessage;
    }

    global class OpportunityRecord {
        public String CampaignId;
        public String CampaignName;
        public String OpportunityId;
        public String OpportunityName;
        public String StageName;
        public String CustomerType;
        public String UAEResidentStatus;
        public String LeadSource;
        public String OpportunityOwnerName;
        public String AccountName;
        public String PrimaryContactName;
        public String CustomerPhone;
        public String CustomerMobilePhone;
        public String CustomerEmail;
        public String BrokerAgencyName;
        public String BrokerAgentName;
        public String BrokerAgentMobilePhone;
        public String BrokerAgentEmail;
        public Decimal Probability;
        public Datetime LastModifiedDate;
        public String EOIs;
    }
}