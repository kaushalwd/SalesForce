/**********************************************************************************************************************
* Name               : OIC_SABookingFeePaymentAPITest                                                        
* Description        : Test suite for OIC_SABookingFeePaymentAPI REST Web Service.
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Modon Dev Team              13 07 2026      Initial       
***********************************************************************************************************************/
@isTest
private class OIC_SABookingFeePaymentAPITest {

    @testSetup
    static void setupTestData() {
        // 1. Create a Test User context profile
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'paytest',
            Email = 'payments@modon.ae',
            EmailEncodingKey = 'UTF-8',
            LastName = 'PaymentTester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'Asia/Dubai',
            UserName = 'paytester' + DateTime.now().getTime() + '@modon.ae'
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
    static void testCreateBookingFeePaymentSuccess() {
        Booking_Fee_Line__c bfl = [SELECT Id, Opportunity__c FROM Booking_Fee_Line__c LIMIT 1];

        OIC_SABookingFeePaymentAPI.PaymentRequest reqBody = new OIC_SABookingFeePaymentAPI.PaymentRequest();
        reqBody.BookingFeeId = bfl.Id;
        reqBody.OpportunityId = bfl.Opportunity__c;
        reqBody.CustomerName = 'Suresh Kumar';
        reqBody.CustomerEmail = 'suresh.kumar@modon.ae';
        reqBody.SourceSystem = 'SuperApp-Portal';
        reqBody.ModeOfPayment = 'Online';
        reqBody.TransactionNumber = 'TXN_SUCCESS_7761';
        reqBody.Bank = 'Abu Dhabi Commercial Bank';
        reqBody.IBANorSwiftCodeLast4Digits = '4321';
        reqBody.CardLast4Digits = 0987; 
        reqBody.Remarks = 'Staging automated validation payment transaction.';
        reqBody.Amount = 25000.00;
        reqBody.TransactionDate = DateTime.now();

        reqBody.FileAttachments = new List<OIC_SABookingFeePaymentAPI.FileDetails>();
        OIC_SABookingFeePaymentAPI.FileDetails file = new OIC_SABookingFeePaymentAPI.FileDetails();
        file.FileName = 'receipt_attachment.pdf';
        file.Base64FileContent = 'JVBERi0xLjQKJVRleHQgQmFzZTY0IEV4YW1wbGUgRGF0YQo=';
        reqBody.FileAttachments.add(file);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/superapp/bookingfee/createpayment/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqBody));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_SABookingFeePaymentAPI.createBookingFeePayment();
        Test.stopTest();

    }

    @isTest
    static void testCreateBookingFeePaymentMalformedJson() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/superapp/bookingfee/createpayment/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{ "BookingFeeId" : "a008d0000012345", "Amount" : 15000.00, --- MALFORMED --- }');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_SABookingFeePaymentAPI.createBookingFeePayment();
        Test.stopTest();
    }
}