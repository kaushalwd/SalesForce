@isTest
private class OIC_SalesLaunchOpportunityDetailsTest {

    @isTest
    static void testGetOpportunityDetails_Success() {
        Campaign campaign = new Campaign(Name = 'Sales Launch Opportunity Campaign');
        insert campaign;

        Account accountRecord = new Account(
            Name = 'Opportunity API Account',
            CustomerType__c = 'VIP Client'
        );
        insert accountRecord;

        Contact contactRecord = new Contact(
            LastName = 'Primary Contact',
            AccountId = accountRecord.Id,
            Email = 'primarycontact@example.com',
            Phone = '+971401234567',
            MobilePhone = '+971501234567'
        );
        insert contactRecord;

        Account brokerAgencyRecord = new Account(Name = 'Broker Agency');
        insert brokerAgencyRecord;

        Contact brokerAgentRecord = new Contact(
            LastName = 'Broker Agent',
            AccountId = brokerAgencyRecord.Id,
            Email = 'brokeragent@example.com',
            Phone = '+971551234567'
        );
        insert brokerAgentRecord;

        String activeStage = [SELECT MasterLabel FROM OpportunityStage WHERE IsActive = true LIMIT 1].MasterLabel;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'Sales Launch Opportunity',
            StageName = activeStage,
            CloseDate = System.today().addDays(30),
            AccountId = accountRecord.Id,
            PrimaryContact__c = contactRecord.Id,
            BrokerAgency__c = brokerAgencyRecord.Id,
            BrokerAgent__c = brokerAgentRecord.Id,
            SalesLaunchCampaign__c = campaign.Id,
            LeadSource = 'Walk-In',
            CustomerType__c = 'New Client',
            UAE_Resident_Status__c = 'Resident'
        );
        insert opportunityRecord;

        ExpressionOfInterest__c clearedEoi = new ExpressionOfInterest__c(
            Opportunity__c = opportunityRecord.Id,
            Status__c = 'Completed'
        );
        ExpressionOfInterest__c overrideEoi = new ExpressionOfInterest__c(
            Opportunity__c = opportunityRecord.Id,
            Status__c = 'Completed'
        );
        insert new List<ExpressionOfInterest__c>{ clearedEoi, overrideEoi };

        insert new List<Receipt__c>{
            buildEoiReceipt(accountRecord.Id, clearedEoi.Id, 'Cleared', false, 'TXN-OPP-001'),
            buildEoiReceipt(accountRecord.Id, overrideEoi.Id, 'In Progress', true, 'TXN-OPP-002')
        };

        Map<Id, ExpressionOfInterest__c> eoisById = new Map<Id, ExpressionOfInterest__c>([
            SELECT Id, Name
            FROM ExpressionOfInterest__c
            WHERE Id IN :new List<Id>{ clearedEoi.Id, overrideEoi.Id }
        ]);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/saleslaunch/opportunitydetails/';
        req.httpMethod = 'GET';
        req.addParameter('CampaignId', campaign.Id);
        req.addParameter('ModifiedDateTime', '2025-04-10T04:00:00.000Z');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_SalesLaunchOpportunityDetails.getOpportunityDetails();
        Test.stopTest();

        OIC_SalesLaunchOpportunityDetails.OpportunityDetailsResponse responseBody =
            (OIC_SalesLaunchOpportunityDetails.OpportunityDetailsResponse) JSON.deserialize(
                RestContext.response.responseBody.toString(),
                OIC_SalesLaunchOpportunityDetails.OpportunityDetailsResponse.class
            );

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('Success', responseBody.Status);
        System.assertEquals(1, responseBody.OpportunityRecords.size());
        System.assertEquals(campaign.Id, responseBody.OpportunityRecords[0].CampaignId);
        System.assertEquals(opportunityRecord.Id, responseBody.OpportunityRecords[0].OpportunityId);
        System.assertEquals(accountRecord.Name, responseBody.OpportunityRecords[0].AccountName);
        System.assertEquals('VIP Client', responseBody.OpportunityRecords[0].CustomerType);
        System.assertEquals('primarycontact@example.com', responseBody.OpportunityRecords[0].CustomerEmail);
        System.assertEquals('+971401234567', responseBody.OpportunityRecords[0].CustomerPhone);
        System.assertEquals('+971501234567', responseBody.OpportunityRecords[0].CustomerMobilePhone);
        System.assertEquals('Broker Agency', responseBody.OpportunityRecords[0].BrokerAgencyName);
        System.assertEquals('Broker Agent', responseBody.OpportunityRecords[0].BrokerAgentName);
        System.assertEquals('+971551234567', responseBody.OpportunityRecords[0].BrokerAgentMobilePhone);
        System.assertEquals('brokeragent@example.com', responseBody.OpportunityRecords[0].BrokerAgentEmail);
        System.assert(responseBody.OpportunityRecords[0].EOIs.contains(eoisById.get(clearedEoi.Id).Name));
        System.assert(responseBody.OpportunityRecords[0].EOIs.contains(eoisById.get(overrideEoi.Id).Name));
    }

    @isTest
    static void testGetOpportunityDetails_MissingCampaignId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/saleslaunch/opportunitydetails/';
        req.httpMethod = 'GET';
        req.addParameter('ModifiedDateTime', '2025-04-10T04:00:00.000Z');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_SalesLaunchOpportunityDetails.getOpportunityDetails();
        Test.stopTest();

        OIC_SalesLaunchOpportunityDetails.OpportunityDetailsResponse responseBody =
            (OIC_SalesLaunchOpportunityDetails.OpportunityDetailsResponse) JSON.deserialize(
                RestContext.response.responseBody.toString(),
                OIC_SalesLaunchOpportunityDetails.OpportunityDetailsResponse.class
            );

        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('Failure', responseBody.Status);
        System.assertEquals('Evento-001', responseBody.ErrorCode);
    }

    @isTest
    static void testGetOpportunityDetails_ExcludesOpportunityWithoutEligibleEoi() {
        Campaign campaign = new Campaign(Name = 'Sales Launch Empty Campaign');
        insert campaign;

        Account accountRecord = new Account(Name = 'No Eligible EOI Account');
        insert accountRecord;

        String activeStage = [SELECT MasterLabel FROM OpportunityStage WHERE IsActive = true LIMIT 1].MasterLabel;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'No Eligible EOI Opportunity',
            StageName = activeStage,
            CloseDate = System.today().addDays(30),
            AccountId = accountRecord.Id,
            SalesLaunchCampaign__c = campaign.Id
        );
        insert opportunityRecord;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/saleslaunch/opportunitydetails/';
        req.httpMethod = 'GET';
        req.addParameter('CampaignId', campaign.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_SalesLaunchOpportunityDetails.getOpportunityDetails();
        Test.stopTest();

        OIC_SalesLaunchOpportunityDetails.OpportunityDetailsResponse responseBody =
            (OIC_SalesLaunchOpportunityDetails.OpportunityDetailsResponse) JSON.deserialize(
                RestContext.response.responseBody.toString(),
                OIC_SalesLaunchOpportunityDetails.OpportunityDetailsResponse.class
            );

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('Success', responseBody.Status);
        System.assertEquals(0, responseBody.OpportunityRecords.size());
    }

    private static Receipt__c buildEoiReceipt(
        Id accountId,
        Id eoiId,
        String status,
        Boolean allowAnyStatusForBooking,
        String transactionNumber
    ) {
        return new Receipt__c(
            TotalAmount__c = 10000,
            Status__c = status,
            Account__c = accountId,
            ExpressionOfInterest__c = eoiId,
            Conversion_Rate__c = 1.0,
            CurrencyIsoCode = 'AED',
            Bank__c = 'First Abu Dhabi Bank',
            MIRE_Bank__c = 'First Abu Dhabi Bank',
            Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = transactionNumber,
            TransactionDate__c = DateTime.now(),
            EBS_Clearing_Date__c = status == 'Cleared' ? Date.today() : null,
            IBAN_Swift_Code_last_4_digit__c = '5678',
            Allow_Any_Status_for_Booking__c = allowAnyStatusForBooking
        );
    }
}