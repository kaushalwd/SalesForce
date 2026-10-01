@isTest
public class DirectDebitRequestTriggerHelperTest {
    
    @testSetup
    static void setupData() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User u = new User(
            FirstName = 'Test2112',
            LastName = 'QueueUser',
            Email = 'queueuser123@example.com',
            Username = 'queueuser21131@example.com.test',
            Alias = 'quser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        // Create Queue
        Group queue = new Group(Name = 'DirectDebitQueue', Type = 'Queue');
        insert queue;
    
        GroupMember gm = new GroupMember(GroupId = queue.Id, UserOrGroupId = u.Id);
        insert gm;


        
    }
    
    static Id createTestQueue(String name) {
        Group queue = new Group(Name = name, Type = 'Queue');
        insert queue;
        User u = [SELECT Id FROM User WHERE Profile.Name = 'Standard User' LIMIT 1];
        GroupMember gm = new GroupMember(GroupId = queue.Id, UserOrGroupId = u.Id);
        insert gm;
        return queue.Id;
    }

    static SalesOrder__c createSalesOrderData() {
        Project__c project = new Project__c(Name = 'Test Project12121');
        insert project;
        
        Phase__c phase = new Phase__c(Name = 'Phase 112', Project__c = project.Id);
        insert phase;

        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'Test Escrow112', BeneficiaryName__c = 'Test Beneficiary');
        insert escrow;
        
        phase.EscrowAccount__c = escrow.Id;
        update phase;

        Unit__c unit = new Unit__c(Name = 'Unit 101112', Phase__c = phase.Id, PlotNo__c = 'P101112', UnitClassification__c ='Apartment', Number_of_Bedrooms__c ='2');
        insert unit;

        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John112', LastName = 'Doe112', RecordTypeId = rtId);
        insert acc;

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Unit__c = unit.Id);
        insert so;

        SalesOrderInstallments__c inst1 = new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 1, MilestoneDate__c = Date.today());
        SalesOrderInstallments__c inst2 = new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 2, MilestoneDate__c = Date.today().addDays(30));
        SalesOrderInstallments__c inst3 = new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 3, MilestoneDate__c = Date.today().addDays(90));
        insert new List<SalesOrderInstallments__c>{inst1, inst2, inst3};

        return so;
    }

    @isTest static void testGetQueueIdByName() {
        Id expectedQueueId = [SELECT Id FROM Group WHERE Name = 'DirectDebitQueue' LIMIT 1].Id;

        Test.startTest();
        Id result = DirectDebitRequestTriggerHelper.getQueueIdByName('DirectDebitQueue');
        Test.stopTest();
        System.assertEquals(expectedQueueId, result, 'Queue ID should match the created one');
    }

    @isTest static void testUpdateDDRequestOwner() {
        SalesOrder__c so = createSalesOrderData();
        DirectDebitRequest__c dd = new DirectDebitRequest__c(SalesOrder__c = so.Id);
        insert dd;
        Test.startTest();
        DirectDebitRequestTriggerHelper.updateDDRequestOwner(new List<SObject>{dd});
        update dd; 
        Test.stopTest();
        dd = [SELECT OwnerId FROM DirectDebitRequest__c WHERE Id = :dd.Id];
		System.assertNotEquals(null, dd.OwnerId, 'Owner should be set');
    }

   @isTest static void testValidateDirectDebitRequestUniqueValidation() {
    SalesOrder__c so = createSalesOrderData();
    
    // Insert first DDR
    DirectDebitRequest__c dd1 = new DirectDebitRequest__c(SalesOrder__c = so.Id);
    insert dd1;

    // Attempt to insert second DDR with same Sales Order — should fail
    DirectDebitRequest__c dd2 = new DirectDebitRequest__c(SalesOrder__c = so.Id);
    
    Test.startTest();
    try {
        insert dd2;
        System.assert(false, 'Expected insertion to fail due to duplicate SalesOrder');
    } catch (DmlException e) {
        System.assert(e.getMessage().contains('Direct Debit Request for this Sales Order already exist'), 'Expected validation error not found');
    }
    Test.stopTest();
}

    /*@isTest static void testCreateDirectDebitTransaction() {
        SalesOrder__c so = createSalesOrderData();
        DirectDebitRequest__c dd = new DirectDebitRequest__c(SalesOrder__c = so.Id, Collection_Amount__c = 1000, Approve__c = false, Request_Type__c = 'New Registration');
        insert dd;
        DirectDebitRequest__c oldClone = dd.clone(false, true);
		oldClone.Approve__c = false;

        dd.Approve__c = true;
        update dd;

        Map<Id, SObject> oldMap = new Map<Id, SObject>{dd.Id => oldClone};
        oldMap.get(dd.Id).put('Approve__c', false);

        Test.startTest();
        DirectDebitRequestTriggerHelper.createDirectDebitTransaction(
            new List<SObject>{dd},
            null,
            new List<SObject>{oldMap.get(dd.Id)},
            oldMap
        );
        Test.stopTest();

        List<DirectDebit_Transactions__c> txns = [SELECT Id FROM DirectDebit_Transactions__c WHERE Direct_Debit_Request__c = :dd.Id];
        System.assertEquals(1, txns.size(), 'One transaction should be created');
    }*/

    @isTest static void testPopulateCommenceAndExpireDates() {
        SalesOrder__c so = createSalesOrderData();
        DirectDebitRequest__c dd = new DirectDebitRequest__c(SalesOrder__c = so.Id);
        insert dd;

        Test.startTest();
        DirectDebitRequestTriggerHelper.populateCommenceAndExpireDates(new List<SObject>{dd});
        Test.stopTest();

    }

    @isTest static void testSendCreateNotifications() {
        SalesOrder__c so = createSalesOrderData();
        DirectDebitRequest__c dd = new DirectDebitRequest__c(SalesOrder__c = so.Id);
        insert dd;

        Test.startTest();
        DirectDebitRequestTriggerHelper.sendCreateNotifications(new List<SObject>{dd});
        Test.stopTest();
    }

    // ------------------------------------------------------------ UAEDDS approval (1.4)

    private class CreateMandateMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{ "ddaReferenceNumber": "DD-00000001", "ddaId": 76849, "ddarId": 76758, "errors": "" }');
            return res;
        }
    }

    /** Custom metadata cannot be inserted in a test, so the switch is handed over directly. */
    private static UAEDDS_Config__mdt uaeddsConfig(Boolean enabled) {
        return new UAEDDS_Config__mdt(
            Mandate_Creation_Enabled__c = enabled,
            Default_Amount_Type__c = 'Variable',
            Default_Payment_Frequency__c = 'Monthly',
            Default_Preferred_Payment_Method__c = 'Bank Account',
            Default_Minimum_Amount__c = 1
        );
    }

    /**
     * Mandates that pass every UAEDDS rule, one per Sales Order because a second live mandate on
     * the same order is refused on insert. Values follow UAEDDS_MandateServiceTest, so a failure
     * here is the trigger and not the vendor validation.
     */
    private static List<DirectDebitRequest__c> uaeddsMandates(Integer howMany) {
        Project__c project = new Project__c(Name = 'UAEDDS Approval Project');
        insert project;
        EscrowAccount__c escrow = new EscrowAccount__c(
            Name = 'UAEDDS Approval Escrow', BeneficiaryName__c = 'UAEDDS Beneficiary'
        );
        insert escrow;
        Phase__c phase = new Phase__c(
            Name = 'UAEDDS Approval Phase', Project__c = project.Id, EscrowAccount__c = escrow.Id
        );
        insert phase;

        // A person account: Customer_Type__c is a formula on IsPersonAccount, and ContactEmail__c
        // falls back to the person email, so both UAEDDS rules are satisfied from here.
        Account acc = new Account(
            FirstName = 'Layla', LastName = 'Al Blooshi',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId(),
            PersonEmail = 'layla.approval@example.com.invalid',
            BillingCity = 'Abu Dhabi'
        );
        insert acc;

        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 0; i < howMany; i++) {
            units.add(new Unit__c(
                Name = 'UAEDDS Approval Unit ' + i, Phase__c = phase.Id, PlotNo__c = 'UA-' + i,
                UnitClassification__c = 'Apartment', Number_of_Bedrooms__c = '2'
            ));
        }
        insert units;

        List<SalesOrder__c> orders = new List<SalesOrder__c>();
        for (Unit__c u : units) {
            orders.add(new SalesOrder__c(CustomerAccount__c = acc.Id, Unit__c = u.Id));
        }
        insert orders;

        Id uaeddsRt = Schema.SObjectType.DirectDebitRequest__c
            .getRecordTypeInfosByDeveloperName().get('UAEDDS').getRecordTypeId();
        List<DirectDebitRequest__c> mandates = new List<DirectDebitRequest__c>();
        for (SalesOrder__c so : orders) {
            mandates.add(new DirectDebitRequest__c(
                RecordTypeId = uaeddsRt,
                Gateway__c = 'UAEDDS',
                Account__c = acc.Id,
                SalesOrder__c = so.Id,
                Status__c = 'Finance Team Approved',
                Approve__c = false,
                Customer_ID_Number__c = '784-1992-2875238-4',
                Customer_Id_Type__c = 'UAE Emirates Identity Card',
                CustomerAccountName__c = 'Layla Al Blooshi',
                Customer_Bank_Account_Name__c = 'Layla Al Blooshi',
                Customer_Bank_Name__c = 'First Abu Dhabi Bank',
                Customer_Bank_Account_Type__c = 'Current',
                Customer_IBAN_Number__c = 'AE070331234567890123456',
                Customer_Mobile__c = '+971564142138',
                Customer_City__c = 'Abu Dhabi',
                Amount_Type__c = 'Variable',
                Minimum_Amount__c = 1,
                Commences_On__c = Date.newInstance(2027, 1, 1),
                Expires_On__c = Date.newInstance(2029, 4, 1),
                Maximum_Amount__c = 500000
            ));
        }
        insert mandates;

        return [
            SELECT Id, Approve__c, Gateway__c, Status__c, DDA_Id__c
            FROM DirectDebitRequest__c WHERE Id IN :mandates
        ];
    }

    /**
     * Finance cannot tick Approve until the required document is on file at a valid status - the
     * before update rule in DocumentValidationHelper refuses the save otherwise. The rows themselves
     * are created by the after insert trigger, so only the status has to be moved.
     */
    private static void fileRequiredDocuments(List<DirectDebitRequest__c> mandates) {
        String validStatus = System.Label.DDDocumentValidStatus.contains(',')
            ? System.Label.DDDocumentValidStatus.split(',')[0]
            : System.Label.DDDocumentValidStatus;
        List<Documents__c> docs = [
            SELECT Id, Status__c FROM Documents__c WHERE Direct_Debit_Request__c IN :mandates
        ];
        for (Documents__c d : docs) {
            d.Status__c = validStatus;
        }
        update docs;
    }
    
    @isTest static void testSendStatusChangeNotifications() {
        SalesOrder__c so = createSalesOrderData();
        DirectDebitRequest__c dd = new DirectDebitRequest__c(SalesOrder__c = so.Id, Status__c = 'Finance Team Approved');
        insert dd;

        DirectDebitRequest__c oldDD = dd.clone(false, true);
        dd.Status__c = 'Approved';
        update dd;

        Map<Id, SObject> oldMap = new Map<Id, SObject>{dd.Id => oldDD};

        Test.startTest();
        DirectDebitRequestTriggerHelper.sendStatusChangeNotifications(new List<SObject>{dd}, oldMap);
        Test.stopTest();
    }
}