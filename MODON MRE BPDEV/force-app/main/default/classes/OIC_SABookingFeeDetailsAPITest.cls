/**********************************************************************************************************************
* Name               : OIC_SABookingFeeDetailsAPITest                                                        
* Description        : Test class for OIC_SABookingFeeDetailsAPI.
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                   13 07 2026         Initial       
***********************************************************************************************************************/
@isTest
private class OIC_SABookingFeeDetailsAPITest {

    @testSetup
    static void setupTestData() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'mopay',
            Email = 'testuser@modon.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ModonTester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser' + DateTime.now().getTime() + '@modon.com'
        );
        insert testUser; 
            //Create an account
             Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
             String recordTypeId = recordTypeInfo.getRecordTypeId();
             Account accountObj = new Account(RecordTypeId = recordTypeId);
             accountObj.PersonEmail = 'te123st1231.pdf@outlook.com';
             accountObj.FirstName = 'Firstttt';
             accountObj.LastName = 'Lassstt';
             accountObj.OraclePartyId__c ='22213';
             insert accountObj;
             Account personAcc = [
                SELECT Id, Name, PersonContactId
                FROM Account 
                WHERE Id = :accountObj.Id AND IsPersonAccount = true
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            
            EscrowAccount__c testescrow = new EscrowAccount__c(MerchantID__c = 'test', Current_Acc_Merchant_ID__c = 'test');
            insert testescrow;
            
            // Create Virtual Account
            VirtualAccount__c testVA = new VirtualAccount__c(
                EscrowAccount__c = testescrow.id,
                VirtualIBANNumber__c = 'IBAN123',
                VirtualAccountNumber__c = 'VA123'
                //Escrow_Bank_Name__c = 'Test Bank'
            );
            insert testVA;
        
        	// Create Unit/Property data
            Phase__c testPhase = new Phase__c(Name = 'Test Phase1121',
                EscrowAccount__c = testescrow.Id);
            insert testPhase;
        
            Unit__c testUnit = new Unit__c(
                Name = 'Unit 104',
                UnitClassification__c = 'villa',
                PlotNo__c = 'P-101',
                Number_of_Bedrooms__c ='2',
                Phase__c = testPhase.Id,
                BuildingNo__c = 'B1'
            );
            insert testUnit;
            
            Opportunity opp = new Opportunity(
                Name = 'Test Opp Modon',
                StageName = 'Unit Selection',
                CloseDate = System.today().addDays(30),
                AccountId = accountObj.Id,
                PrimaryContact__c = personAcc.PersonContactId,
                Source_Entity__c = 'Modon - UAE', 
                OwnerId = testUser.Id
            );
            insert opp;

            Booking_Fee_Line__c bfl = new Booking_Fee_Line__c(
                Opportunity__c = opp.Id,
                Type__c = 'ADM & Dari',
                Total_Amount__c = 162678.26,
                Unit__c = testUnit.Id
            );
            insert bfl;
        	
        	Booking_Fee_Line__c bf2 = new Booking_Fee_Line__c(
                Opportunity__c = opp.Id,
                Type__c = 'Down Payment',
                Total_Amount__c = 162678.26,
                Unit__c = testUnit.Id
            );
            insert bf2;
        }

    @isTest
    static void testFindBookingFeeDetailsSuccess() {
        Opportunity opp = [SELECT Id, Owner.Email FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/BookingFeeDetailsAPI/';
        req.httpMethod = 'GET';
        
        req.params.put('OpportunityId', opp.Id);
        req.params.put('UserEmail', opp.Owner.Email);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_SABookingFeeDetailsAPI.findBookingFeeDetails();
        Test.stopTest();        
    }

    @isTest
    static void testFindBookingFeeDetailsMissingParameters() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/BookingFeeDetailsAPI/';
        req.httpMethod = 'GET';
        
        req.params.put('OpportunityId', '0068d00000abcdeAAA');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_SABookingFeeDetailsAPI.findBookingFeeDetails();
        Test.stopTest();        
    }

    
    @isTest
    static void testFindBookingFeeDetailsNoRecordsFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/BookingFeeDetailsAPI/';
        req.httpMethod = 'GET';
        
        req.params.put('OpportunityId', '006000000000000AAA'); 
        req.params.put('UserEmail', 'helooooo@modon.com');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_SABookingFeeDetailsAPI.findBookingFeeDetails();
        Test.stopTest();        
    }
}