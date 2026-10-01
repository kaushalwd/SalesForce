@isTest
public without sharing class ApprovalModalController_Test {

    @testSetup
    static void setupData() {

        Project__c project = new Project__c();
        insert project;

        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;

        Milestone__c ms = new Milestone__c(
            Name = 'MS',
            Phase__c = phase.Id,
            Milestone_Due_Date__c = Date.today()
        );
        insert ms;

        Business_Process__c bp = new Business_Process__c(

            Milestone__c = ms.Id,
            MileStone_Confirmation_Date__c = Date.today(),
            MileStone_Extension_Date__c = Date.today().addDays(5)
        );
        insert bp;

        Business_Process_Documents__c doc = new Business_Process_Documents__c(
            Name = 'Test Doc',
            Business_Process__c = bp.Id
        );
        insert doc;

        ContentVersion cv = new ContentVersion(
            Title = 'File',
            PathOnClient = 'file.pdf',
            VersionData = Blob.valueOf('test')
        );
        insert cv;

        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = doc.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;

        Account vipPersonAccount = new Account(
        LastName = 'vipPersonAccount',
        CustomerType__c = 'VIP Client',

        Account_Manager__c =UserInfo.getUserId(),
        PersonEmail = 'vippersonaccountemail@mail.com',
        EIDNumber__pc = '784-1234-1234567-1',
        PersonMobilePhone = '+971888999654'
    );

        insert vipPersonAccount;

          Unit__c unitObj = new Unit__c(
            Name = 'Unit 101',
            Phase__c = phase.Id,
            PlotNo__c='1234',
            UnitClassification__c='Villa',
            Number_of_Bedrooms__c='1',
            Status__c='Sold'

        );
        insert unitObj;

        SalesOrder__c so = new SalesOrder__c(Status__c='Sold', Unit__c = unitObj.Id);
        insert so;

        SalesOrderInstallments__c inst = new SalesOrderInstallments__c(
            MilestoneNumber__c=1,
            SalesOrder__c = so.Id,
            PaymentStatus__c = 'Not Paid',
            MilestoneDate__c = Date.today()

        );
        insert inst;

        SalesOrderInstallments__c inst1 = new SalesOrderInstallments__c(
            MilestoneNumber__c=2,
            SalesOrder__c = so.Id,
            PaymentStatus__c = 'Not Paid',
            MilestoneDate__c = Date.today()+10

        );
        insert inst1;

        // Latest_Sales_Order__c is auto-populated by CaseTriggerHelper from Unit__c
        // (ServiceUtility.getLatestSalesOrderOfUnit), so it isn't set directly here.
        Case c = new Case(
            Subject = 'Test Case',
            Sales_Order_Installment__c = inst.Id,
            Description='Test',
            AccountId=vipPersonAccount.Id,
            Unit__c=unitObj.ID

        );
        insert c;

        Approval_Type_Config__mdt cfg = new Approval_Type_Config__mdt();
        // custom metadata cannot be inserted in test; just used for coverage via try
    }

    @isTest
    static void testGetProcessData() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        ApprovalModalController.getProcessData(bp.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetDocuments() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        ApprovalModalController.getDocuments(bp.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetFiles() {

        Business_Process_Documents__c doc = [
            SELECT Id FROM Business_Process_Documents__c LIMIT 1
        ];

        Test.startTest();
        ApprovalModalController.getFiles(new List<Id>{ doc.Id });
        Test.stopTest();
    }

    @isTest
    static void testDeleteFile() {

        ContentDocument cd = [
            SELECT Id FROM ContentDocument LIMIT 1
        ];

        Test.startTest();
        ApprovalModalController.deleteFile(cd.Id);
        Test.stopTest();
    }

    @isTest
    static void testUpdateBusinessProcess_Confirmation() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        ApprovalModalController.updateBusinessProcess(
            bp.Id,
            'CONFIRMATION',
            Date.today(),
            null
        );
        Test.stopTest();
    }

    @isTest
    static void testUpdateBusinessProcess_Extension() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        ApprovalModalController.updateBusinessProcess(
            bp.Id,
            'EXTENSION',
            null,
            Date.today().addDays(10)
        );
        Test.stopTest();
    }

    @isTest
    static void testGetApprovalTypes() {

        Test.startTest();
        ApprovalModalController.getApprovalTypes();
        Test.stopTest();
    }

    @isTest
    static void testGetInstallments_SalesOrder() {

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        ApprovalModalController.getInstallments(so.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetInstallments_Case() {

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<SalesOrderInstallments__c> results = ApprovalModalController.getInstallments(c.Id);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected unpaid installments for the Case\'s Latest Sales Order.');
    }

    @isTest
    static void testGetInstallments_Case_NoSalesOrder() {

        Case c = new Case(
            Subject = 'Test Case No SO',
            Description = 'Test'
        );
        insert c;

        Test.startTest();
        try {
            ApprovalModalController.getInstallments(c.Id);
            System.assert(false, 'Expected an AuraHandledException when the Case has no Latest Sales Order.');
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetInstallments_Other() {
        Id fakeId = UserInfo.getUserId();
        SalesOrder__c soTest=[select ID from SalesOrder__c limit 1];
        Test.startTest();
        ApprovalModalController.getInstallments(soTest.ID);
        Test.stopTest();
    }

    @isTest
    static void testProcessInstallments() {

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Payment Extension',
            Process_Flow_Unique_Name__c='Payment Extension'
        );
        insert pf;
        SalesOrderInstallments__c soTest=[select ID from SalesOrderInstallments__c limit 1];
        Test.startTest();
        String result = ApprovalModalController.processInstallments(soTest.ID, Date.today().addDays(1), 'Customer Request', 'Payment Extension Reason', 'Approval Justification', null);
        Test.stopTest();

        System.assertEquals(null, result, 'No files were uploaded, so no attachment warning should be returned.');
    }

    @isTest
    static void testProcessInstallments_NoProofOfRequestPlaceholder_ReturnsWarning() {

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Payment Extension',
            Process_Flow_Unique_Name__c = 'Payment Extension'
        );
        insert pf;

        SalesOrderInstallments__c soTest = [SELECT Id FROM SalesOrderInstallments__c LIMIT 1];
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1];

        ApprovalModalController.UploadedFileWrapper fileWrap = new ApprovalModalController.UploadedFileWrapper();
        fileWrap.documentId = cv.ContentDocumentId;
        fileWrap.name = 'Test Document';

        Test.startTest();
        String result = ApprovalModalController.processInstallments(
            soTest.Id,
            Date.today().addDays(1),
            'Customer Request',
            'Payment Extension Reason',
            'Approval Justification',
            new List<ApprovalModalController.UploadedFileWrapper>{ fileWrap }
        );
        Test.stopTest();

        // No Process_Flow_Document__c records are configured in this test, so no
        // "Proof of Request" placeholder gets created — the method should return a
        // warning instead of silently dropping the uploaded file.
        System.assert(
            result != null && result.contains('Proof of Request'),
            'Expected a warning when no "Proof of Request" checklist item is configured for the process.'
        );
    }

    @isTest
    static void testLinkUploadedFilesToProofOfRequest_ResolvesDocumentIdFromContentVersion() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Business_Process_Documents__c proofOfRequestDoc = new Business_Process_Documents__c(
            Name = 'Proof of Request',
            Business_Process__c = bp.Id
        );
        insert proofOfRequestDoc;

        ContentVersion cv = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 1];

        // documentId intentionally left blank to exercise the contentVersionId fallback.
        ApprovalModalController.UploadedFileWrapper fileWrap = new ApprovalModalController.UploadedFileWrapper();
        fileWrap.contentVersionId = cv.Id;
        fileWrap.name = 'Test Document';

        Test.startTest();
        String result = ApprovalModalController.linkUploadedFilesToProofOfRequest(
            bp.Id,
            new List<ApprovalModalController.UploadedFileWrapper>{ fileWrap }
        );
        Test.stopTest();

        System.assertEquals(
            null,
            result,
            'Expected the file to resolve and link successfully via contentVersionId even without documentId.'
        );

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :proofOfRequestDoc.Id
            AND ContentDocumentId = :cv.ContentDocumentId
        ];
        System.assert(!links.isEmpty(), 'Expected a ContentDocumentLink to the Proof of Request record.');
    }

    @isTest
    static void testLinkUploadedFilesToProofOfRequest_NoPlaceholder_ReturnsWarning() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1];

        ApprovalModalController.UploadedFileWrapper fileWrap = new ApprovalModalController.UploadedFileWrapper();
        fileWrap.documentId = cv.ContentDocumentId;
        fileWrap.name = 'Test Document';

        Test.startTest();
        String result = ApprovalModalController.linkUploadedFilesToProofOfRequest(
            bp.Id,
            new List<ApprovalModalController.UploadedFileWrapper>{ fileWrap }
        );
        Test.stopTest();

        System.assert(
            result != null && result.contains('Proof of Request'),
            'Expected a warning when no "Proof of Request" checklist item exists for the process.'
        );
    }


/**********************************************************************************************************************
 * Test Method 1: Successful Business Process Creation
 **********************************************************************************************************************/
@isTest
static void testCreateBusinessProcessSuccess() {

    SalesOrder__c salesOrder = [
        SELECT Id
        FROM SalesOrder__c
        LIMIT 1
    ];

    Process_Flow__c processFlow = new Process_Flow__c(
        Name = 'Test Business Process',
        Process_Flow_Unique_Name__c = 'Test Business Process'
    );
    insert processFlow;

    Test.startTest();

    ApprovalModalController.createBusinessProcess(
        salesOrder.Id,
        'Test Business Process'
    );

    try{
       ApprovalModalController.createBusinessProcess(
        null,
        'Test Business Process'
    );
    }catch (Exception ex){

    }

      try{
      ApprovalModalController.createBusinessProcess(
        null,
        ''
    );
      } catch (Exception ex){

    }

    Test.stopTest();

    List<Business_Process__c> createdProcesses = [
        SELECT Id,
               Sales_Order__c,
               Type__c,
               Status__c
        FROM Business_Process__c
        WHERE Sales_Order__c = :salesOrder.Id
        AND Type__c = 'Test Business Process'
    ];

    System.assert(
        !createdProcesses.isEmpty(),
        'Business Process should be created successfully.'
    );
}


/**********************************************************************************************************************
 * Test Method 2: Duplicate In-Progress Business Process
 **********************************************************************************************************************/
@isTest
static void testCreateBusinessProcessDuplicate() {

    SalesOrder__c salesOrder = [
        SELECT Id
        FROM SalesOrder__c
        LIMIT 1
    ];

    Business_Process__c existingProcess = new Business_Process__c(
        Sales_Order__c = salesOrder.Id,
        Type__c = 'Duplicate Test Process',
        Status__c = 'In Progress'
    );
    insert existingProcess;

    Test.startTest();

    try {

        ApprovalModalController.createBusinessProcess(
            salesOrder.Id,
            'Duplicate Test Process'
        );

        System.assert(
            false,
            'Exception should be thrown for an existing in-progress process.'
        );

    } catch (AuraHandledException ex) {


    }

    Test.stopTest();
}


/**********************************************************************************************************************
 * Test Method 3: Process Flow Configuration Not Found
 **********************************************************************************************************************/
@isTest
static void testCreateBusinessProcessFlowNotFound() {

    SalesOrder__c salesOrder = [
        SELECT Id
        FROM SalesOrder__c
        LIMIT 1
    ];

    Test.startTest();

    try {

        ApprovalModalController.createBusinessProcess(
            salesOrder.Id,
            'Invalid Process Name'
        );

        System.assert(
            false,
            'Exception should be thrown when Process Flow is not configured.'
        );

    } catch (AuraHandledException ex) {


    }

    Test.stopTest();
}

    @isTest
static void testBuildHandledException() {

    Exception ex;

    try {
        Integer i = 1 / 0;
    } catch (Exception e) {
        ex = e;
    }

    Test.startTest();

    AuraHandledException auraEx =
        ApprovalModalController.buildHandledException(
            'Test Error',
            ex
        );

    Test.stopTest();

}

    @isTest
static void testGetDmlErrorMessage() {

    DmlException dmlEx;

    try {

        insert new Account();

    } catch (DmlException ex) {

        dmlEx = ex;
    }

    Test.startTest();

    String message =
        ApprovalModalController.getDmlErrorMessage(
            'Default Message',
            dmlEx
        );

    Test.stopTest();

}

    @isTest
static void testGetProcessData_NullId() {

    Test.startTest();

    try {
        ApprovalModalController.getProcessData(null);

    } catch (AuraHandledException ex) {
    }

    Test.stopTest();
}

    @isTest
static void testGetProcessData_RecordNotFound() {

    Id fakeId = UserInfo.getUserId();

    Test.startTest();

    try {
        ApprovalModalController.getProcessData(fakeId);

    } catch (AuraHandledException ex) {
    }

    Test.stopTest();
}

    @isTest
static void testGetDocuments_NullId() {

    Test.startTest();

    try {
        ApprovalModalController.getDocuments(null);

    } catch (AuraHandledException ex) {

    }

    Test.stopTest();
}

    @isTest
    static void testCreateBusinessProcess_Case() {
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Case c = new Case(
            Subject = 'Test Case',
            Latest_Sales_Order__c = salesOrder.Id,
            CaseCategory__c = 'Payment Extension',
            Status = 'New',
            Origin = 'Email'
        );
        insert c;

        Process_Flow__c processFlow = new Process_Flow__c(
            Name = 'Payment Extension',
            Process_Flow_Unique_Name__c = 'Payment_Extension_Case_Test',
            Type__c = 'Cost Approval'
        );
        insert processFlow;

        Test.startTest();
        try {
            ApprovalModalController.createBusinessProcess(c.Id, 'Payment Extension');
        } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testCreateBusinessProcess_InvalidObject() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Test.startTest();
        try {
            ApprovalModalController.createBusinessProcess(proj.Id, 'Payment Extension');
        } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testProcessInstallments_WithFiles() {
        SalesOrderInstallments__c soTest = [SELECT Id FROM SalesOrderInstallments__c LIMIT 1];
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1];

        ApprovalModalController.UploadedFileWrapper fileWrap = new ApprovalModalController.UploadedFileWrapper();
        fileWrap.documentId = cv.ContentDocumentId;
        fileWrap.name = 'Test Document';

        Test.startTest();
        try {
            ApprovalModalController.processInstallments(
                soTest.Id,
                Date.today().addDays(1),
                'Customer Request',
                'Payment Extension Reason',
                'Approval Justification',
                new List<ApprovalModalController.UploadedFileWrapper>{ fileWrap }
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

}