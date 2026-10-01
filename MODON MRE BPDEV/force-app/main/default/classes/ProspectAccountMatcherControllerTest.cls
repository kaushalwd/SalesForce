@IsTest
public class ProspectAccountMatcherControllerTest {
    
    // =========================================================
    // HELPERS
    // =========================================================
    
    private static Id getPersonAccountRT() {
        return Account.SObjectType
            .getDescribe()
            .getRecordTypeInfosByName()
            .get('Person Account')
            .getRecordTypeId();
    }
    
    private static Id getProspectRT(String developerName) {
    
    return Prospect_Account__c.SObjectType
        .getDescribe()
        .getRecordTypeInfosByDeveloperName()
        .get(developerName)
        .getRecordTypeId();
}
    
    private static ServiceRequest__c createSR() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create Test Opportunity
        Opportunity testOpportunity = new Opportunity(Name = 'Test Opportunity', StageName = 'Qualification', CloseDate = Date.today(),UAE_Resident_Status__c = 'Resident',Nationality__c = 'United Arab Emirates',EmiratesIDExpiryDate__c = Date.today().addDays(365),EIDNumber__c='784-1232-1234567-4');
        insert testOpportunity;
        
        
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            CustomerAccount__c = testAccount.Id,
            Opportunity__c = testOpportunity.Id,
            Status__c = 'Completed'
        );
        insert testSalesOrder;
        
        // Create Test Service Request
        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = testSalesOrder.Id
        );
          
        insert sr;
        
        return sr;
    }
    
    private static Account createPersonAccount(
        String firstName,
        String lastName,
        String email,
        String mobile,
        String eid,
        String passport
    ) {
        
        Account pa = new Account(
            RecordTypeId = getPersonAccountRT(),
            FirstName = firstName,
            LastName = lastName,
            PersonEmail = email,
            PersonMobilePhone = mobile
        );
        
        pa.put('EIDNumber__pc', eid);
        pa.put('PassportNumber__pc', passport);
        
        insert pa;
        
        return pa;
    }
    
    // =========================================================
    // GET SR STATE
    // =========================================================
    
    @IsTest
    static void test_getSRState() {
        
        ServiceRequest__c sr = createSR();
        
        Account orgAcc = new Account(
            Name = 'Test Org'
        );
        insert orgAcc;
        Contact con = new contact( lastName ='newt');
        insert con;
        Prospect_Account__c orgPA = new Prospect_Account__c(
            RecordTypeId = getProspectRT('Account'),
            Service_Request__c = sr.Id,
            Account__c = orgAcc.Id
        );
        insert orgPA;
        
        Prospect_Account__c childPA = new Prospect_Account__c(
            RecordTypeId = getProspectRT('Contact'),
            Service_Request__c = sr.Id,
            Prospect_Account__c = orgPA.Id,
            Contact__c =con.Id,
            Is_Primary__c =true
        );
        insert childPA;
        
        Test.startTest();
        
        ProspectAccountMatcherController.SRState result =
            ProspectAccountMatcherController.getSRState(sr.Id);
        
        Test.stopTest();
        
        System.assertEquals(true, result.hasOrg);
        System.assertEquals(true, result.hasPrimary);
        System.assertEquals(true, result.hasOrgContact);
        System.assertEquals(orgPA.Id, result.orgProspectId);
    }
    
    // =========================================================
    // SEARCH SIMILAR PARTIES
    // =========================================================
    
    @IsTest
    static void test_searchSimilarParties() {
        
        Account pa = createPersonAccount(
            'Krish',
            'Test',
            'krish@test.com',
            '9999999999',
            'EID123',
            'PASS123'
        );
        
        Account orgAcc = new Account(
            Name = 'Modon'
        );
        insert orgAcc;
        
        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john@test.com',
            MobilePhone = '8888888888',
            AccountId = orgAcc.Id,
            EIDNumber__c = 'EID999',
            PassportNumber__c = 'PASS999'
        );
        insert con;
        
        Test.startTest();
        
        List<ProspectAccountMatcherController.CandidateResult> results =
            ProspectAccountMatcherController.searchSimilarParties(
                'Krish',
                'krish@test.com',
                '9999999999',
                'EID123',
                'PASS123'
            );
        
        Test.stopTest();
        
        System.assert(results.size() > 0);
        
        Boolean foundAccount = false;
        
        for (ProspectAccountMatcherController.CandidateResult row : results) {
            
            if (row.accountId == pa.Id) {
                foundAccount = true;
            }
        }
        
        System.assertEquals(true, foundAccount);
    }
    
    // =========================================================
    // RESOLVE EXISTING ACCOUNT
    // =========================================================
    
    @IsTest
    static void test_resolve_existingAccount() {
        
        Account pa = createPersonAccount(
            'Tony',
            'Stark',
            'tony@test.com',
            '7777777777',
            'EID777',
            'PASS777'
        );
        
        Map<String, Object> fields = new Map<String, Object>{
            'IsPersonAccount__c' => true
        };
        
        Test.startTest();
        
        ProspectAccountMatcherController.ResolveResult result =
            ProspectAccountMatcherController.resolveAccountOrContact(
                'Individual',
                fields,
                pa.Id,
                null
            );
        
        Test.stopTest();
        
        System.assertEquals(pa.Id, result.accountId);
    }
    
    // =========================================================
    // RESOLVE NEW PERSON ACCOUNT
    // =========================================================
    
    @IsTest
    static void test_resolve_newPersonAccount() {
        
        Map<String, Object> fields = new Map<String, Object>{
            'IsPersonAccount__c' => true,
            'First_Name__c' => 'Bruce',
            'Last_Name__c' => 'Wayne',
            'Email__c' => 'bruce@test.com',
            'Mobile__c' => '6666666666',
            'EIDNumber__c' => 'EID666',
            'PassportNumber__c' => 'PASS666'
        };
        
        Test.startTest();
        
        ProspectAccountMatcherController.ResolveResult result =
            ProspectAccountMatcherController.resolveAccountOrContact(
                'Individual',
                fields,
                null,
                null
            );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result.accountId);
        
        Account createdAcc = [
            SELECT Id,
                   PersonEmail,
                   PersonMobilePhone
            FROM Account
            WHERE Id = :result.accountId
        ];
        
        System.assertEquals('bruce@test.com', createdAcc.PersonEmail);
        System.assertEquals('6666666666', createdAcc.PersonMobilePhone);
    }
    
    // =========================================================
    // RESOLVE NEW ORG ACCOUNT
    // =========================================================
    
    @IsTest
    static void test_resolve_newOrgAccount() {
        
        Map<String, Object> fields = new Map<String, Object>{
            'Account_Name__c' => 'Wayne Enterprises',
            'Mobile__c' => '5555555555'
        };
        
        Test.startTest();
        
        ProspectAccountMatcherController.ResolveResult result =
            ProspectAccountMatcherController.resolveAccountOrContact(
                'Account',
                fields,
                null,
                null
            );
        
        Test.stopTest();
        
    }
    
    // =========================================================
    // RESOLVE NEW CONTACT
    // =========================================================
    
    @IsTest
    static void test_resolve_newContact() {
        
        ServiceRequest__c sr = createSR();
        
        Account orgAcc = new Account(
            Name = 'Test Org'
        );
        insert orgAcc;
        
        Prospect_Account__c orgPA = new Prospect_Account__c(
            RecordTypeId = getProspectRT('Account'),
            Service_Request__c = sr.Id,
            Account__c = orgAcc.Id
        );
        insert orgPA;
        
        Map<String, Object> fields = new Map<String, Object>{
            'Prospect_Account__c' => orgPA.Id,
            'First_Name__c' => 'Peter',
            'Last_Name__c' => 'Parker',
            'Email__c' => 'peter@test.com',
            'Mobile__c' => '4444444444',
            'EIDNumber__c' => 'EID444',
            'PassportNumber__c' => 'PASS444',
            'IsPersonAccount__c' => false
        };
        
        Test.startTest();
        
        ProspectAccountMatcherController.ResolveResult result =
            ProspectAccountMatcherController.resolveAccountOrContact(
                'Contact',
                fields,
                null,
                null
            );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result.contactId);
        
        Contact con = [
            SELECT Id,
                   Email,
                   AccountId,
                   MobilePhone
            FROM Contact
            WHERE Id = :result.contactId
        ];
        
        System.assertEquals('peter@test.com', con.Email);
        System.assertEquals(orgAcc.Id, con.AccountId);
        System.assertEquals('4444444444', con.MobilePhone);
    }
    
    // =========================================================
    // RESOLVE EXISTING CONTACT
    // =========================================================
    
    @IsTest
    static void test_resolve_existingContact() {
        
        ServiceRequest__c sr = createSR();
        
        Account orgAcc = new Account(
            Name = 'Marvel Org'
        );
        insert orgAcc;
        
        Prospect_Account__c orgPA = new Prospect_Account__c(
            RecordTypeId = getProspectRT('Account'),
            Service_Request__c = sr.Id,
            Account__c = orgAcc.Id
        );
        insert orgPA;
        
        Account anotherAcc = new Account(
            Name = 'Another Org'
        );
        insert anotherAcc;
        
        Contact con = new Contact(
            FirstName = 'Steve',
            LastName = 'Rogers',
            Email = 'steve@test.com',
            AccountId = anotherAcc.Id
        );
        insert con;
        
        Map<String, Object> fields = new Map<String, Object>{
            'Prospect_Account__c' => orgPA.Id,
            'IsPersonAccount__c' => false
        };
        
        Test.startTest();
        
        ProspectAccountMatcherController.ResolveResult result =
            ProspectAccountMatcherController.resolveAccountOrContact(
                'Contact',
                fields,
                null,
                con.Id
            );
        
        Test.stopTest();
        
        Contact updatedCon = [
            SELECT Id,
                   AccountId
            FROM Contact
            WHERE Id = :con.Id
        ];
        
        System.assertEquals(orgAcc.Id, updatedCon.AccountId);
    }
    
    // =========================================================
    // EXISTING ACCOUNT MATCH
    // =========================================================
    
    @IsTest
    static void test_existingAccountMatch() {
        
        Account existing = createPersonAccount(
            'Clark',
            'Kent',
            'clark@test.com',
            '3333333333',
            'EID333',
            'PASS333'
        );
        
        Map<String, Object> fields = new Map<String, Object>{
            'IsPersonAccount__c' => true,
            'First_Name__c' => 'Clark',
            'Last_Name__c' => 'Kent',
            'Email__c' => 'clark@test.com',
            'Mobile__c' => '3333333333',
            'EIDNumber__c' => 'EID333',
            'PassportNumber__c' => 'PASS333'
        };
        
        Test.startTest();
        
        ProspectAccountMatcherController.ResolveResult result =
            ProspectAccountMatcherController.resolveAccountOrContact(
                'Individual',
                fields,
                null,
                null
            );
        
        Test.stopTest();
        
        System.assertEquals(existing.Id, result.accountId);
    }
    
    // =========================================================
    // EXISTING CONTACT MATCH
    // =========================================================
    
    @IsTest
    static void test_existingContactMatch() {
        
        Account orgAcc = new Account(
            Name = 'DC Org'
        );
        insert orgAcc;
        
        Contact existingCon = new Contact(
            FirstName = 'Barry',
            LastName = 'Allen',
            Email = 'barry@test.com',
            MobilePhone = '2222222222',
            AccountId = orgAcc.Id,
            EIDNumber__c = 'EID222',
            PassportNumber__c = 'PASS222'
        );
        insert existingCon;
        
        ServiceRequest__c sr = createSR();
        
        Prospect_Account__c orgPA = new Prospect_Account__c(
            RecordTypeId = getProspectRT('Account'),
            Service_Request__c = sr.Id,
            Account__c = orgAcc.Id
        );
        insert orgPA;
        
        Map<String, Object> fields = new Map<String, Object>{
            'Prospect_Account__c' => orgPA.Id,
            'First_Name__c' => 'Barry',
            'Last_Name__c' => 'Allen',
            'Email__c' => 'barry@test.com',
            'Mobile__c' => '2222222222',
            'EIDNumber__c' => 'EID222',
            'PassportNumber__c' => 'PASS222',
            'IsPersonAccount__c' => false
        };
        
        Test.startTest();
        
        ProspectAccountMatcherController.ResolveResult result =
            ProspectAccountMatcherController.resolveAccountOrContact(
                'Contact',
                fields,
                null,
                null
            );
        
        Test.stopTest();
        
        System.assertEquals(existingCon.Id, result.contactId);
    }
}