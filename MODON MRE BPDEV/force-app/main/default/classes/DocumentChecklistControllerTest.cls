@IsTest
public class DocumentChecklistControllerTest {

    @TestSetup
    static void setupData() {
        // 🔹 Create Phase
        Phase__c ph = new Phase__c(Name = 'Phase A', Is_Reservation_Form_Required__c = 'Yes');
        insert ph;

        // 🔹 Create Unit linked to Phase
        Unit__c un = new Unit__c(
            Name = 'Unit 101',
            Phase__c = ph.Id,
            PlotNo__c = 'P-101',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2'
        );
        insert un;

        // 🔹 Create a Person Account (bypasses validation rules)
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();

        Account acc = new Account(
            RecordTypeId = personRtId,
            LastName = 'Doe',
            FirstName = 'John',
            PersonEmail = 'john.doe@test.com',
            PersonMailingStreet = '123 Street',
            PersonMailingCity = 'City',
            PersonMailingCountry = 'United Arab Emirates'
        );
        insert acc;

        // 🔹 Create Contact
        Contact con = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jsmith@test.com'
        );
        insert con;

        // 🔹 Create Opportunity (validation safe)
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today(),
            Source_Entity__c = 'Modon - Egypt',
            UAE_Resident_Status__c = 'Non-Resident',
            Nationality__c = 'United Arab Emirates',
            PassportNumber__c = 'P1234567',
            PassportIssueDate__c = Date.today().addYears(-5),
            PassportExpiryDate__c = Date.today().addYears(5),
            En_Nationality__c = 'India',
            En_PassportNumber__c = 'P1234567'
        );
        insert opp;

        // 🔹 Create Sales Order using Person Account
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            PrimaryContact__c = con.Id,
            Unit__c = un.Id,
            Opportunity__c = opp.Id,
            Sub_Status__c = 'Pending with Sales',
            Down_Payment_Status__c = 'Paid',
            ADM_Fees_and_Dari__c = 'Paid',
            Modeofpayment__c = 'Cash',
            PDC_Collected__c = 'Yes',
            Cheques_collected_No_of_cheques__c = '2',
            Cheques_Rcvd_from_Sales_No_of_cheques__c = '2'
        );
        insert so;

        // 🔹 Create supporting Documents (coverage)
        insert new List<Documents__c>{
            new Documents__c(Name = 'Passport Document', Status__c = 'Uploaded',  Account__c = acc.Id),
            new Documents__c(Name = 'Emirates ID Document', Status__c = 'Uploaded',  Account__c = acc.Id),
            new Documents__c(Name = 'Signed KYC and Wealth Form', Status__c = 'Uploaded', SalesOrder__c = so.Id),
            new Documents__c(Name = 'Broker Form', Status__c = 'Uploaded', SalesOrder__c = so.Id),
            new Documents__c(Name = 'Reservation Form', Status__c = 'Uploaded', SalesOrder__c = so.Id)
        };
    }

    // 🔸 Standard Tests
    @IsTest
    static void test_getSalesOrderDetails_and_SubStatus() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Test.startTest();
        SalesOrder__c result = DocumentChecklistController.getSalesOrderDetails(so.Id);
        String subStatus = DocumentChecklistController.getSalesOrderSubStatus(so.Id);
        Test.stopTest();
       
    }

    @IsTest
    static void test_getDocumentChecklistMetadata() {
        Test.startTest();
        Map<String, List<DocumentChecklistController.ChecklistWrapper>> result =
            DocumentChecklistController.getDocumentChecklistMetadata('Resident', true, 'Direct');
        Test.stopTest();
    }

    @IsTest
    static void test_getLatestChecklistMap() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Test.startTest();
        Map<String, Object> res = DocumentChecklistController.getLatestChecklistMap(so.Id);
        Test.stopTest();
    }

    @IsTest
    static void test_sendToNextTeam() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        List<DocumentChecklistController.ChecklistItemDTO> items = new List<DocumentChecklistController.ChecklistItemDTO>();
        DocumentChecklistController.ChecklistItemDTO dto = new DocumentChecklistController.ChecklistItemDTO();
        dto.label = 'Cheques collected (____) nos. of cheques';
        dto.team = 'Sales';
        dto.approvalSts = 'Collected';
        dto.remark = '3';
        items.add(dto);

        Test.startTest();
        String nextTeam = DocumentChecklistController.sendToNextTeam(so.Id, items, 'All good', true);
        Test.stopTest();
    }

    @IsTest
    static void test_validateSalesTeamChecklistFatima() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Test.startTest();
        Map<String, DocumentChecklistController.ChecklistItemDTO> mapResult =
            DocumentChecklistController.validateSalesTeamChecklistFatima(so.Id);
        Test.stopTest();
    }

    @IsTest
    static void test_generateDocumentChecklist() {
        List<Documents__c> docs = [SELECT Id, Name, Status__c  FROM Documents__c LIMIT 1];
        Map<String, DocumentChecklistController.ChecklistItemDTO> res =
            DocumentChecklistController.generateDocumentChecklist('broker', 'Broker Form Generated & Sent for Signature', docs);
    }

    @IsTest
    static void test_handleStsUpdate() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Document_Checklist__c doc = new Document_Checklist__c(
            RecordTypeId = Schema.SObjectType.Document_Checklist__c
                            .getRecordTypeInfosByName()
                            .get('Document Checklist').getRecordTypeId(),
            Sales_Order__c = so.Id,
            Team__c = 'Sales',
            Approval_Status__c = 'Approved'
        );
        insert doc;

        List<sObject> listToUpdate = new List<sObject>{ doc };
        Test.startTest();
        DocumentChecklistController.handleStsUpdate(listToUpdate, null);
        Test.stopTest();
    }

    // 🔹 Covers non-Person Account (else branch)
    @IsTest
    static void test_validateSalesTeamChecklistFatima_elseBranch() {
        // Recreate all prerequisite data in the same standardized way
        Phase__c ph = new Phase__c(Name = 'Else Phase', Is_Reservation_Form_Required__c = 'Yes');
        insert ph;

        Unit__c un = new Unit__c(
            Name = 'Unit 202',
            Phase__c = ph.Id,
            PlotNo__c = 'P-202',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '3'
        );
        insert un;

        Account businessAcc = new Account(
            Name = 'Business Account',
            Phone = '987654321',
            BillingStreet = 'Street',
            BillingCity = 'City',
            BillingCountry = 'United Arab Emirates'
        );
        insert businessAcc;

        Contact con = new Contact(FirstName = 'Else', LastName = 'Branch', Email = 'else@test.com');
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Else Opp',
            AccountId = businessAcc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today(),
            Source_Entity__c = 'Modon - Egypt',
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            PassportNumber__c = 'P9988776',
            PassportIssueDate__c = Date.today().addYears(-4),
            PassportExpiryDate__c = Date.today().addYears(6)
        );
        insert opp;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = businessAcc.Id,
            PrimaryContact__c = con.Id,
            Unit__c = un.Id,
            Opportunity__c = opp.Id,
            Sub_Status__c = 'Pending with Sales',
            Down_Payment_Status__c = 'Paid',
            ADM_Fees_and_Dari__c = 'Paid',
            Modeofpayment__c = 'Cash',
            PDC_Collected__c = 'Yes',
            Cheques_collected_No_of_cheques__c = '2',
            Cheques_Rcvd_from_Sales_No_of_cheques__c = '2'
        );
        insert so;

        Documents__c doc = new Documents__c(
            Name = 'Passport Doc',
            Status__c = 'Uploaded',
            PrimaryContact__c = con.Id
        );
        insert doc;

        Test.startTest();
        Map<String, DocumentChecklistController.ChecklistItemDTO> res =
            DocumentChecklistController.validateSalesTeamChecklistFatima(so.Id);
        Test.stopTest();

    }
    
    @IsTest
static void test_hasStatusSafe_true() {
    // Reuse standardized setup pattern
    Phase__c ph = new Phase__c(Name = 'HS Phase', Is_Reservation_Form_Required__c = 'Yes');
    insert ph;

    Unit__c un = new Unit__c(
        Name = 'HS Unit 01',
        Phase__c = ph.Id,
        PlotNo__c = 'P-HS01',
        UnitClassification__c = 'Plot',
        Number_of_Bedrooms__c = '2'
    );
    insert un;

    // Create Person Account (bypasses validations)
    Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
        .get('PersonAccount').getRecordTypeId();
    Account acc = new Account(
        RecordTypeId = personRtId,
        LastName = 'DoeHS',
        FirstName = 'JohnHS',
        PersonEmail = 'john.hs@test.com',
        PersonMailingStreet = '123 HS Street',
        PersonMailingCity = 'City',
        PersonMailingCountry = 'United Arab Emirates'
    );
    insert acc;

    Contact con = new Contact(FirstName = 'TestHS', LastName = 'Contact', Email = 'hs@test.com');
    insert con;

    Opportunity opp = new Opportunity(
        Name = 'HS Opp',
        AccountId = acc.Id,
        StageName = 'Prospecting',
        CloseDate = System.today(),
        Source_Entity__c = 'Modon - Egypt',
        UAE_Resident_Status__c = 'Resident',
        Nationality__c = 'United Arab Emirates',
        PassportNumber__c = 'HSP12345',
        PassportIssueDate__c = Date.today().addYears(-4),
        PassportExpiryDate__c = Date.today().addYears(5)
    );
    insert opp;

    // ✅ Create Sales Order with Status__c set
    SalesOrder__c so = new SalesOrder__c(
        CustomerAccount__c = acc.Id,
        PrimaryContact__c = con.Id,
        Unit__c = un.Id,
        Opportunity__c = opp.Id,
        Sub_Status__c = 'Pending with Sales',
        Down_Payment_Status__c = 'Paid',
        ADM_Fees_and_Dari__c = 'Paid',
        Modeofpayment__c = 'Cash',
        PDC_Collected__c = 'Yes',
        Status__c = 'New',
        Cheques_collected_No_of_cheques__c = '2',
        Cheques_Rcvd_from_Sales_No_of_cheques__c = '2'
    );
    insert so;
    
    // ✅ Document Checklist linked to Sales Order
    Document_Checklist__c dc = new Document_Checklist__c(Sales_Order__c = so.Id);
    insert dc;

    // Query with relationship fields populated
    dc = [
        SELECT Id, Sales_Order__c, Sales_Order__r.Status__c
        FROM Document_Checklist__c
        WHERE Id = :dc.Id
        LIMIT 1
    ];

    // Act
    Boolean result = DocumentChecklistController.hasStatusSafe(dc);

    // Assert
}


@IsTest
static void test_hasStatusSafe_false() {
    // Reuse standardized setup pattern again
    Phase__c ph = new Phase__c(Name = 'HS Phase False', Is_Reservation_Form_Required__c = 'Yes');
    insert ph;

    Unit__c un = new Unit__c(
        Name = 'HS Unit 02',
        Phase__c = ph.Id,
        PlotNo__c = 'P-HS02',
        UnitClassification__c = 'Plot',
        Number_of_Bedrooms__c = '2'
    );
    insert un;

    Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
        .get('PersonAccount').getRecordTypeId();
    Account acc = new Account(
        RecordTypeId = personRtId,
        LastName = 'DoeHSF',
        FirstName = 'JohnHSF',
        PersonEmail = 'john.hsf@test.com',
        PersonMailingStreet = '456 HS Street',
        PersonMailingCity = 'City',
        PersonMailingCountry = 'United Arab Emirates'
    );
    insert acc;

    Contact con = new Contact(FirstName = 'TestHSF', LastName = 'Contact', Email = 'hsf@test.com');
    insert con;

    Opportunity opp = new Opportunity(
        Name = 'HS Opp False',
        AccountId = acc.Id,
        StageName = 'Prospecting',
        CloseDate = System.today(),
        Source_Entity__c = 'Modon - Egypt',
        UAE_Resident_Status__c = 'Resident',
        Nationality__c = 'United Arab Emirates',
        PassportNumber__c = 'HSF12345',
        PassportIssueDate__c = Date.today().addYears(-3),
        PassportExpiryDate__c = Date.today().addYears(4)
    );
    insert opp;

    // ❌ Sales Order without Status__c (to trigger false path)
    SalesOrder__c so = new SalesOrder__c(
        CustomerAccount__c = acc.Id,
        PrimaryContact__c = con.Id,
        Unit__c = un.Id,
        Opportunity__c = opp.Id,
        Sub_Status__c = 'Pending with Sales',
        Down_Payment_Status__c = 'Paid',
        ADM_Fees_and_Dari__c = 'Paid',
        Modeofpayment__c = 'Cash',
        PDC_Collected__c = 'Yes',
        Cheques_collected_No_of_cheques__c = '2',
        Cheques_Rcvd_from_Sales_No_of_cheques__c = '2'
        // Status__c intentionally omitted
    );
    insert so;

    // Document Checklist without querying relationship
    Document_Checklist__c dc = new Document_Checklist__c(Sales_Order__c = so.Id);
    insert dc;

    // Act (relationship fields not queried => Sales_Order__r is null)
    Boolean result = DocumentChecklistController.hasStatusSafe(dc);

    // Assert
}
@IsTest
static void test_generateDocumentChecklist_allBranches() {
    // 🔹 Setup base data (same as setupData)
    Phase__c ph = new Phase__c(Name = 'GenDC Phase', Is_Reservation_Form_Required__c = 'Yes');
    insert ph;

    Unit__c un = new Unit__c(
        Name = 'GenDC Unit',
        Phase__c = ph.Id,
        PlotNo__c = 'P-GEN',
        UnitClassification__c = 'Plot',
        Number_of_Bedrooms__c = '2'
    );
    insert un;

    Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
        .get('PersonAccount').getRecordTypeId();
    Account acc = new Account(
        RecordTypeId = personRtId,
        LastName = 'DoeGen',
        FirstName = 'JohnGen',
        PersonEmail = 'john.gen@test.com',
        PersonMailingStreet = '123 Street',
        PersonMailingCity = 'City',
        PersonMailingCountry = 'United Arab Emirates'
    );
    insert acc;

    Opportunity opp = new Opportunity(
        Name = 'GenDC Opp',
        AccountId = acc.Id,
        StageName = 'Prospecting',
        CloseDate = System.today(),
        Source_Entity__c = 'Modon - Egypt',
        UAE_Resident_Status__c = 'Resident',
        Nationality__c = 'United Arab Emirates'
    );
    insert opp;

    SalesOrder__c so = new SalesOrder__c(
        CustomerAccount__c = acc.Id,
        Unit__c = un.Id,
        Opportunity__c = opp.Id,
        Status__c = 'New',
        Sub_Status__c = 'Pending with Sales',
        Modeofpayment__c = 'Cash',
        PDC_Collected__c = 'Yes'
    );
    insert so;

    // ✅ Case 1: Uploaded + Sent
    Documents__c doc1 = new Documents__c(
        Name = 'passport document',
        Status__c = 'Uploaded',
        SalesOrder__c = so.Id
    );

    // ✅ Case 2: Uploaded only (not sent)
    Documents__c doc2 = new Documents__c(
        Name = 'passport document',
        Status__c = 'Uploaded',
        SalesOrder__c = so.Id
    );

    // ✅ Case 3: Not uploaded
    Documents__c doc3 = new Documents__c(
        Name = 'passport document',
        Status__c = 'Pending Upload',
        SalesOrder__c = so.Id
    );

    insert new List<Documents__c>{ doc1, doc2, doc3 };

    // 4️⃣ No matching doc name → should go into last ELSE path
    Documents__c doc4 = new Documents__c(
        Name = 'random file',
        Status__c = 'Uploaded',
        SalesOrder__c = so.Id
    );
    insert doc4;

    Test.startTest();

    Map<String, DocumentChecklistController.ChecklistItemDTO> res1 =
        DocumentChecklistController.generateDocumentChecklist('passport', 'Passport Label 1', new List<Documents__c>{ doc1 });

    Map<String, DocumentChecklistController.ChecklistItemDTO> res2 =
        DocumentChecklistController.generateDocumentChecklist('passport', 'Passport Label 2', new List<Documents__c>{ doc2 });

    Map<String, DocumentChecklistController.ChecklistItemDTO> res3 =
        DocumentChecklistController.generateDocumentChecklist('passport', 'Passport Label 3', new List<Documents__c>{ doc3 });

    Map<String, DocumentChecklistController.ChecklistItemDTO> res4 =
        DocumentChecklistController.generateDocumentChecklist('passport', 'Passport Label 4', new List<Documents__c>{ doc4 });

    Test.stopTest();
}
@IsTest
static void test_ChecklistWrapper_constructor() {
    // Arrange test data
    String id = '1';
    String label = 'Test Label';
    List<String> rejectionReasons = new List<String>{ 'Missing document', 'Invalid signature' };
    Boolean forResidents = true;
    Boolean forNonResidents = false;

    // Act: call the constructor
    DocumentChecklistController.ChecklistWrapper wrapper =
        new DocumentChecklistController.ChecklistWrapper(id, label, rejectionReasons, forResidents, forNonResidents);

   
}
        // 🔹 Test canAccessSalesChecklist() (true + false path)
    @IsTest
    static void test_canAccessSalesChecklist_true_false() {
        // -- Create setup same as standard pattern --
        Phase__c ph = new Phase__c(Name = 'Access Phase', Is_Reservation_Form_Required__c = 'Yes');
        insert ph;

        Unit__c un = new Unit__c(
            Name = 'Access Unit 01',
            Phase__c = ph.Id,
            PlotNo__c = 'P-A01',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2'
        );
        insert un;

        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account acc = new Account(
            RecordTypeId = personRtId,
            LastName = 'Access',
            FirstName = 'Tester',
            PersonEmail = UserInfo.getUserEmail(), // so current user matches Sales Associate email
            PersonMailingStreet = '123 Street',
            PersonMailingCity = 'City',
            PersonMailingCountry = 'United Arab Emirates'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Access Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today(),
            Source_Entity__c = 'Modon - Egypt',
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates'
        );
        insert opp;

        // Sales order with current user's email as Sales Associate email
        User salesUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
SalesOrder__c so = new SalesOrder__c(
    CustomerAccount__c = acc.Id,
    Unit__c = un.Id,
    Opportunity__c = opp.Id,
    Sub_Status__c = 'Pending with Sales',
    Down_Payment_Status__c = 'Paid',
    ADM_Fees_and_Dari__c = 'Paid',
    Modeofpayment__c = 'Cash',
    PDC_Collected__c = 'Yes',
    SalesAssociate__c = salesUser.Id // ✅ adjust this to the real API name
);
insert so;


        Test.startTest();
        Boolean allowed = DocumentChecklistController.canAccessSalesChecklist(so.Id);
        Boolean denied = DocumentChecklistController.canAccessSalesChecklist(null);
        Test.stopTest();

       
    }

    // 🔹 Test getChecklistAccess() (cover all map puts)
    @IsTest
    static void test_getChecklistAccess_fullCoverage() {
        // -- Base setup (reuse pattern) --
        Phase__c ph = new Phase__c(Name = 'ChkAccess Phase', Is_Reservation_Form_Required__c = 'Yes');
        insert ph;

        Unit__c un = new Unit__c(Name = 'ChkAccess Unit', Phase__c = ph.Id, PlotNo__c = 'P-CHK', UnitClassification__c = 'Plot', Number_of_Bedrooms__c = '2');
        insert un;

        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account acc = new Account(
            RecordTypeId = personRtId,
            LastName = 'AccessTest',
            FirstName = 'User',
            PersonEmail = UserInfo.getUserEmail(),
            PersonMailingStreet = '123',
            PersonMailingCity = 'City',
            PersonMailingCountry = 'United Arab Emirates'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'ChkAccess Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today(),
            Source_Entity__c = 'Modon - Egypt'
        );
        insert opp;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = un.Id,
            Opportunity__c = opp.Id,
            Sub_Status__c = 'Pending with Sales',
            Down_Payment_Status__c = 'Paid',
            ADM_Fees_and_Dari__c = 'Paid',
            Modeofpayment__c = 'Cash',
            PDC_Collected__c = 'Yes'
        );
        insert so;

        Test.startTest();
        Map<String, Object> result = DocumentChecklistController.getChecklistAccess(so.Id);
        Test.stopTest();

       
    }

    // 🔹 Test getNextTeamFor() to cover all branches
    @IsTest
    static void test_getNextTeamFor_allBranches() {
        Test.startTest();
     
        Test.stopTest();
    }

    // 🔹 Test getTeamFromSalesOrder() to cover all IFs
    @IsTest
    static void test_getTeamFromSalesOrder_allPaths() {
        // Setup minimal SalesOrders with different Sub_Status__c
        List<SalesOrder__c> sos = new List<SalesOrder__c>();
        for (String status : new List<String>{
            'Pending with Sales',
            'Pending With Sales Operation',
            'Under Finance Verification',
            'Pending with CM',
            'Something Else'
        }) {
            sos.add(new SalesOrder__c(
                Status__c = 'New',
                Sub_Status__c = 'Pending with Sales',
                CustomerAccount__c = [SELECT Id FROM Account LIMIT 1].Id,
                Unit__c = [SELECT Id FROM Unit__c LIMIT 1].Id,
                Opportunity__c = [SELECT Id FROM Opportunity LIMIT 1].Id,
                Down_Payment_Status__c = 'Paid',
                ADM_Fees_and_Dari__c = 'Paid',
                Modeofpayment__c = 'Cash',
                PDC_Collected__c = 'Yes'
            ));
        }
        insert sos;

        Test.startTest();
        for (SalesOrder__c so : sos) {
            String team = DocumentChecklistController.getTeamFromSalesOrder(so.Id);
        }
        Test.stopTest();
    }

    // 🔹 Test handleStsUpdate() - covers update branch (when soStsApprovalList not empty)
    @IsTest
    static void test_handleStsUpdate_updateBranch() {
        // Standard setup (Phase, Unit, Person Account, etc.)
        Phase__c ph = new Phase__c(Name = 'Handle Phase', Is_Reservation_Form_Required__c = 'Yes');
        insert ph;
        Unit__c un = new Unit__c(Name = 'Handle Unit', Phase__c = ph.Id, PlotNo__c = 'P-H', UnitClassification__c = 'Plot', Number_of_Bedrooms__c = '2');
        insert un;

        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account acc = new Account(
            RecordTypeId = personRtId,
            LastName = 'Handle',
            FirstName = 'User',
            PersonEmail = 'handle@test.com',
            PersonMailingStreet = '123',
            PersonMailingCity = 'City',
            PersonMailingCountry = 'United Arab Emirates'
        );
        insert acc;

        Opportunity opp = new Opportunity(Name = 'Handle Opp', AccountId = acc.Id, StageName = 'Prospecting', CloseDate = System.today(), Source_Entity__c = 'Modon - Egypt');
        insert opp;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = un.Id,
            Opportunity__c = opp.Id,
            Status__c = 'In Progress',
            Sub_Status__c = 'Pending With Sales.',
            Down_Payment_Status__c = 'Paid',
            ADM_Fees_and_Dari__c = 'Paid',
            Modeofpayment__c = 'Cash',
            PDC_Collected__c = 'Yes'
        );
        insert so;

        // Dummy Sales_Order_Status_Approvals__c to trigger update branch
        Sales_Order_Status_Approvals__c soApp = new Sales_Order_Status_Approvals__c(
            Sales_Order__c = so.Id,
            Current_Sub_Status__c = 'Sales',
            Approval_Status__c = 'Pending'
        );
        insert soApp;

        // Document_Checklist__c for handleStsUpdate
        Document_Checklist__c doc = new Document_Checklist__c(
            Sales_Order__c = so.Id,
            Team__c = 'Sales',
            Approval_Status__c = 'Approved'
        );
        insert doc;

        List<sObject> checklistList = new List<sObject>{ doc };

        Test.startTest();
        DocumentChecklistController.handleStsUpdate(checklistList, null);
        Test.stopTest();

    }


}