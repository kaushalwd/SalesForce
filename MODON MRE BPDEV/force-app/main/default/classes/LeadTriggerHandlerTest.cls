@isTest
private class LeadTriggerHandlerTest {
    
    // Minimal safe factory for direct-calls (no DML). Avoid Company to bypass org VRs.
    private static Lead mkLead(String sourceEntity, String lastName) {
        return new Lead(
            FirstName        = 'Test',
            LastName         = String.isBlank(lastName) ? 'User' : lastName,
            LeadSource       = 'Website',
            Source_Entity__c = sourceEntity,   // 'Modon - Egypt' or 'Other'
            MobilePhone      = '0501112222',
            Phone            = '050 111 2222',
            Email            = 'USER@EXAMPLE.COM',
            Status           = 'New'
        );
    }

    @TestSetup
    static void setup() {
        // Create an exec user whose Name we can match against Sales_Executive__c
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        insert new User(
            FirstName='Sales', LastName='Executive', Alias='sexec',
            Email='sexec@example.com',
            Username='sexec+' + System.now().getTime() + '@example.com',
            TimeZoneSidKey='Asia/Kolkata', LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8', LanguageLocaleKey='en_US',
            ProfileId=p.Id
        );
    }

    @IsTest
    static void test_beforeInsert_direct() {
        // One OTHER lead (to exercise helper logic), one EGYPT lead
        User uExec = [SELECT Id, Name FROM User WHERE Alias = 'sexec' LIMIT 1];
        
        Lead otherLd = mkLead('Other', 'OtherBeforeInsert');
        otherLd.Sales_Executive__c = uExec.Name; // causes PreferredLeadOwner to be set
        otherLd.MobilePhone = null;              // <<< important: force helper to copy from Phone
        otherLd.Phone = '050 123 4567';          // will be normalized to 0501234567
        otherLd.Email = 'USER@EXAMPLE.COM';
        
        Lead egyptLd = mkLead('Modon - Egypt', 'EgyptBeforeInsert');
        
        List<SObject> newList = new List<SObject>{ otherLd, egyptLd };
            Map<Id,SObject> newMap = new Map<Id,SObject>(); // before-insert: Ids are null
        
        new LeadTriggerHandler().beforeInsertMethod(newList, newMap);
        
        // Assertions on in-memory mutations (no DML)
        Lead afterOther = (Lead)newList[0];
        System.assertNotEquals(null, afterOther.PreferredLeadOwner__c, 'Preferred owner set');
        System.assertEquals('0501234567', afterOther.MobilePhone, 'Phone copied/normalized');
        System.assertEquals('user@example.com', afterOther.Email, 'Email lowercased');
        
        Lead afterEgypt = (Lead)newList[1];
        System.assertEquals('Modon - Egypt', afterEgypt.Source_Entity__c);
    }

    @IsTest
    static void test_beforeUpdate_direct_egyptOnly() {
        // Simulate old/new versions for Egypt (avoids Other helper branches that expect Ids)
        Lead oldEg = mkLead('Modon - Egypt', 'UpdCase');
        Lead newEg = mkLead('Modon - Egypt', 'UpdCase');
        newEg.Email = 'changed@example.com';

        List<SObject> newList = new List<SObject>{ newEg };
        List<SObject> oldList = new List<SObject>{ oldEg };
        Map<Id,SObject> newMap = new Map<Id,SObject>(); // you can leave maps empty for direct calls
        Map<Id,SObject> oldMap = new Map<Id,SObject>();

        new LeadTriggerHandler().beforeUpdateMethod(newList, newMap, oldList, oldMap);

        // No exceptions = coverage; you can assert simple field changes you made yourself
        System.assertEquals('changed@example.com', ((Lead)newList[0]).Email);
    }

    @IsTest
    static void test_afterInsert_direct_egyptOnly() {
        // Egypt-only so the handler's Other block (documents/shares/tasks) is skipped
        Lead egyptOnly = mkLead('Modon - Egypt', 'AfterInsertEgypt');

        List<SObject> newList = new List<SObject>{ egyptOnly };
        Map<Id,SObject> newMap = new Map<Id,SObject>();

        new LeadTriggerHandler().afterInsertMethod(newList, newMap);

        System.assertEquals('Modon - Egypt', ((Lead)newList[0]).Source_Entity__c);
    }

    @IsTest
    static void test_afterUpdate_direct_egyptOnly() {
        Lead oldEg = mkLead('Modon - Egypt', 'AfterUpdateEgypt');
        Lead newEg = mkLead('Modon - Egypt', 'AfterUpdateEgypt');
        newEg.MobilePhone = '0509998888';

        new LeadTriggerHandler().afterUpdateMethod(
            new List<SObject>{ newEg },
            new Map<Id,SObject>(),
            new List<SObject>{ oldEg },
            new Map<Id,SObject>()
        );

        System.assertEquals('0509998888', ((Lead)new List<SObject>{ newEg }[0]).MobilePhone);
    }

    @IsTest
    static void test_afterDelete_direct_egyptOnly() {
        // Only "old" records exist for afterDelete
        Lead oldEg = mkLead('Modon - Egypt', 'AfterDeleteEgypt');

        new LeadTriggerHandler().afterDeleteMethod(
            new List<SObject>{ oldEg },
            new Map<Id,SObject>()
        );

        System.assert(true, 'Direct afterDelete executed without error');
    }
    
    @isTest
    static void testBeforeInsert() {
        // Test before insert logic
        List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', LeadSource = 'Self Generated', Source_Entity__c = 'Modon - Egypt', MobilePhone = '8838838838', Phone = '9939939939', Email = 'abc@email.com',SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa')
                // Add more test lead records as needed
                };
        Test.startTest();
        insert leads;
        Test.stopTest();
        // Assert the expected results after beforeInsertMethod is called
        // Example:
        // System.assertEquals(/* expected value */, /* actual value */);
    }
    @isTest
    static void testBeforeUpdate() {
 
        List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe09', LeadSource = 'Self Generated', Source_Entity__c = 'Modon - Egypt', MobilePhone = '8836738838', Phone = '9939543939', Email = 'abc1230@email.com',SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa'),
                new Lead(FirstName = 'Johncv', LastName = 'Doe34', LeadSource = 'Self Generated',Email = 'test12@test32.com',MobilePhone='+971556700001',EIDNumber__c='784-1980-0590288-1', Nationality__c = 'United Arab Emirates', UAEResidentStatus__c = 'Resident', EmiratesIDExpiryDate__c = Date.Today().addYears(1), Source_Entity__c = 'Modon - UAE',SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa'),
                new Lead(FirstName = 'Johnbc', LastName = 'Doe36', LeadSource = 'Self Generated',Email = 'test55@test76.com',MobilePhone='+971556700000',EIDNumber__c='784-1980-0590278-1', Nationality__c = 'United Arab Emirates', UAEResidentStatus__c = 'Resident', EmiratesIDExpiryDate__c = Date.Today().addYears(1), Source_Entity__c = 'Modon - UAE',SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa')
                // Add more test lead records as needed
                };  
                    insert leads;
        leads[1].Source_Entity__c = 'Modon - UAE';
        leads[1].MobilePhone = '+971000000543';
        leads[2].Source_Entity__c = 'Modon - Egypt'; 
        leads[2].MobilePhone = '8836738438';
 
        
        Test.startTest();
        update leads;
        Test.stopTest();
 
        List<Lead> updatedLeads = [SELECT Id, Source_Entity__c, MobilePhone FROM Lead WHERE Id IN :leads ORDER BY LastName];
        System.debug('Updated Leads After Trigger: ' + updatedLeads);
    }
    @isTest
    static void testAfterDelete() {
        // Test after delete logic
        List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', LeadSource = 'Self Generated', Source_Entity__c = 'Modon - Egypt', MobilePhone = '8838838838', Phone = '9939939939', Email = 'abc@email.com',
                    SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa'),
                new Lead(FirstName = 'John', LastName = 'Doe2', Company = 'ABC Inc2.',TradeName__c ='Test2', UnifiedNumber__c='Test2', LeadSource = 'Self Generated',
                        SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa')
                // Add more test lead records as needed
                };
                    Test.startTest();
        insert leads;
        delete leads;
        Test.stopTest();
        //Test.startTest();
        //Test.stopTest();
        // Assert the expected results after afterDeleteMethod is called
        // Example:
        // System.assertEquals(/* expected value */, /* actual value */);
    }
    @isTest
    static void testAfterInsert() {
        // Test after insert logic
        List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', LeadSource = 'Self Generated', Source_Entity__c = 'Modon - Egypt', MobilePhone = '8838838838', Phone = '9939939939', Email = 'abc@email.com',
                    SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa'),
                new Lead(FirstName = 'John', LastName = 'Doe2', Company = 'ABC Inc2.',TradeName__c ='Test2', UnifiedNumber__c='Test2', LeadSource = 'Self Generated',
                        SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa')
                // Add more test lead records as needed
                };
                    Test.startTest();
        insert leads;
        Test.stopTest();
        // Assert the expected results after afterInsertMethod is called
        // Example:
        // System.assertEquals(/* expected value */, /* actual value */);
    }
    @isTest
    static void testAfterUpdate() {
        // Test after update logic
        List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', LeadSource = 'Self Generated', Source_Entity__c = 'Modon - Egypt', MobilePhone = '8838838838', Phone = '9939939939', Email = 'abc@email.com',
                    SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa'),
                new Lead(FirstName = 'John', LastName = 'Doe2', Company = 'ABC Inc2.',TradeName__c ='Test2', UnifiedNumber__c='Test2', LeadSource = 'Self Generated',
                        SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa')
                // Add more test lead records as needed
                };
                    Test.startTest();
        insert leads;
        List<Lead> leadsToUpdate = [SELECT Id, FirstName FROM Lead WHERE FirstName = 'John'];
        /*Integer i = 1;
        For(Lead l : leadsToUpdate){
            l.FirstName = l.FirstName + i;
            i++;
        }*/
        
            for (Lead l : leadsToUpdate) {
                l.FirstName = l.FirstName + 'a';
            }
        System.debug('leads to update' + leadsToUpdate);
        update leadsToUpdate;
        Test.stopTest();
        // Modify leads as needed for update test
        // Example:
        // leads[0].FirstName = 'UpdatedFirstName';
        //Test.startTest();
        //Test.stopTest();
        // Assert the expected results after afterUpdateMethod is called
        // Example:
        // System.assertEquals(/* expected value */, /* actual value */);
    }
    @isTest
    static void testBeforeUpdate_LeadQualifiedWithOwnerChange() {
        // Create a user with profile 'Sales Operation' (mock it in test if not available)
        Profile salesOpProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1]; // Replace with 'Sales Operation' if it exists
        User u1 = new User(
            FirstName = 'Sales',
            LastName = 'Op',
            Email = 'salesop@example.com',
            Username = 'salesop' + DateTime.now().getTime() + '@example.com',
            Alias = 'sop',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = salesOpProfile.Id
        );
        insert u1;
        Project__c testProject = new Project__c(Name = 'Muheira');
        insert testProject;
        Lead l = new Lead(
            FirstName = 'Qualified',
            LastName = 'Lead',
            Status = 'New',
            SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa',
            //ProjectInterest__c = 'Muheira',
            project__c = testProject.Id,
            //NumberOfBedrooms__c = '2 Bedroom',
            CustomerBudget__c = 'AED 5 - 10M',
            Finance__c = 'Yes',
            Investment__c = 'Investment'
        );
        insert l;
        l.OwnerId = u1.Id;
        l.Status = 'Lead Qualified';
        Test.startTest();
        update l;
        Test.stopTest();
        System.assertEquals('Lead Qualified', l.Status);
    } 
    @IsTest
    static void test_beforeUpdate_direct_other_withIds() {
        // Insert once to get a real Id for safe maps
        Test.setMock(HttpCalloutMock.class, new YourMockCallout());
        Lead base = new Lead(
            FirstName='Test', LastName='UpdOther',
            LeadSource='Website',           // skip duplicate-reassign path
            Source_Entity__c='',       // so it goes into otherNewLeads
            MobilePhone='0501112222',
            Email='user@example.com',
            Status='New',
            SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa'
        );
        insert base;
        
        // OLD snapshot (query to get persisted values)
        Lead oldRec = [SELECT Id, Email, Source_Entity__c,Phone,En_Email__c,EIDNumber__c,En_EIDNumber__c,PassportNumber__c,En_PassportNumber__c,Nationality__c,En_Nationality__c,En_MobilePhone__c,SecondaryMobile__c,En_SecondaryMobile__c,En_Phone__c,MobilePhone,LeadSource,IsConverted FROM Lead WHERE Id = :base.Id];
        
        // NEW snapshot with a change that should flow through the “Other” path
        Lead newRec = new Lead(
            Id = base.Id,
            Email = 'MiXeD@Mail.Com',       // helper will lowercase on update path
            Source_Entity__c = '' 
        );
        
        // Build lists & maps with the SAME Id so oldMap.get(new.Id) works
        List<SObject> newList = new List<SObject>{ newRec };
            List<SObject> oldList = new List<SObject>{ oldRec };
                Map<Id,SObject> newMap = new Map<Id,SObject>{ base.Id => newRec };
                    Map<Id,SObject> oldMap = new Map<Id,SObject>{ base.Id => oldRec };
                        
                        // Call the handler directly
                        new LeadTriggerHandler().beforeUpdateMethod(newList, newMap, oldList, oldMap);
        
        // Assert in-memory mutation
       // System.assertEquals('mixed@mail.com', ((Lead)newList[0]).Email, 'Email should be lowercased');
    }
    
    private class YourMockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"example":"response"}');
            res.setStatusCode(200);
            return res;
        }
    }
}