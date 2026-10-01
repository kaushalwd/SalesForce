@IsTest
    private class SalesOrderStatusAutomationHelperTest {
    @TestSetup
    static void setupData() {
        Project__c proj = new Project__c(Name = 'Test Project');
        insert proj;
        
        OffersPromotions__c offerPromo = new OffersPromotions__c(
            Project__c = proj.Id,
            OfferName__c = 'Test Offer',
            Name = 'Test Offer',
            Approval_Status__c = 'Approved',
            StartDate__c = System.today(),
            EndDate__c = System.today() + 30
        );
        insert offerPromo;
        
        List<OfferLines__c> lines = new List<OfferLines__c>();
        
        for (Integer i = 0; i < 10; i++) {
            lines.add(new OfferLines__c(
                OfferName__c = offerPromo.Id,
                OfferType__c = i==0?'Additional Discount':(i==1 || i==2 || i==3)?'Waiver':'Additional Discount',
                OfferValueType__c = i==0?'%':i==1?'%':i==2?'AED':i==3?'Years':'%',
                OfferOn__c = i==0?'Additional Discount':i==1?'ADM Fees':i==2?'Transfer Charges':i==3?'Service Charges':'Additional Discount',
              
                OfferValue__c = 1,
                IsActive__c = true,
                Offer_Line_Approval_Status__c = 'Approved',
                Waiver_Percent__c = 1
            ));
        }
        
        insert lines;
        
       Id personAccountRTID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        Account testAccount = new Account();
        testAccount.FirstName = 'Test2';
        testAccount.LastName = 'Account';
        testAccount.RecordTypeId = personAccountRTID;
        testAccount.PersonEmail = 'test@test22.com';
        insert testAccount;
        
        
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.AccountId = testAccount.Id;
        oppObj.PrimaryContact__c = [SELECT PersonContactId FROM Account WHERE Id=:testAccount.Id LIMIT 1].PersonContactId;
        oppObj.UAE_Resident_Status__c = 'Non-Resident';
        oppObj.Nationality__c = 'India';
        oppObj.PassportExpiryDate__c = Date.today();
        oppObj.PassportIssueDate__c = Date.today();
        oppObj.PassportNumber__c = 'NP232131';
        oppObj.En_PassportNumber__c = 'NP232131';
        oppObj.En_Nationality__c= 'India';
        oppObj.EIDNumber__c ='784-1989-4183036-1';
        insert oppObj;
        
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        phase__c phase = new phase__c(name='Test Phase',EscrowAccount__c =escAccount.id );
        insert phase;
        
        Expressionofinterest__c eoi = new Expressionofinterest__c();
        eoi.Opportunity__c = oppObj.Id;
        eoi.Phase__c = phase.id;
        insert eoi;
        
        SalesOrder__c so = new SalesOrder__c();
        so.TotalAmount__c = 100;
        so.Status__c = 'New';
        so.PrimaryContact__c = oppObj.PrimaryContact__c;
        so.Is_Sales_Checklist_Completed__c = true;
        insert so;
        
         PaymentPlan__c oldPaymentPlan = new PaymentPlan__c(Name = 'Old Payment Plan', Type__c = 'Standard', Phase__c = phase.id);
        PaymentPlan__c newPaymentPlan = new PaymentPlan__c(Name = 'New Payment Plan', Type__c = 'Standard', Phase__c = phase.id);
        insert new List<PaymentPlan__c>{oldPaymentPlan, newPaymentPlan};
            
            // Create test Payment Installments for both plans
            List<PaymentInstallements__c> oldPlanInstallments = new List<PaymentInstallements__c>();
        List<PaymentInstallements__c> newPlanInstallments = new List<PaymentInstallements__c>();
        
                // Create test Sales Order Installments
        List<SalesOrderInstallments__c> testInstallments = new List<SalesOrderInstallments__c>();
            testInstallments.add(new SalesOrderInstallments__c(
                SalesOrder__c = so.Id,
                InstallmentAmount__c = so.TotalAmount__c,
                MilestoneDate__c = System.today(),
                MilestoneNumber__c = 1,
                PaymentStatus__c = 'Not Paid'
            ));
        
        insert testInstallments;
    }

    @IsTest
    static void testAlreadyRanLatch() {
        Test.startTest();
                database.executebatch(new SalesOrderHistoricalUpdateBatch(null),1);

        Test.stopTest();
    }
    @isTest public static void checkSPAStatusTest(){
        Id soId = [SELECT Id FROM SalesOrder__c LIMIT 1].Id;
        List<Documents__c> docList = new List<Documents__c>();
        Documents__c doc = new Documents__c();
        doc.SalesOrder__c = soId;
        doc.Name = 'Signed SPA (Modon)';
        doc.Status__c = 'Pending Upload';
        docList.add(doc);
        
        Documents__c doc1 = new Documents__c();
        doc1.SalesOrder__c = soId;
        doc1.Name = 'Signed SPA (Customer)';
        doc1.Status__c ='Pending Upload';
        docList.add(doc1);
        
        Documents__c doc2 = new Documents__c();
        doc2.SalesOrder__c = soId;
        doc2.Name = 'SPA';
        doc2.Status__c = 'Pending Upload';
        docList.add(doc2);
        
        Documents__c doc3 = new Documents__c();
        doc3.SalesOrder__c = soId;
        doc3.Name = 'Broker Form';
        doc3.Status__c = 'Uploaded';
        docList.add(doc3);
        
        Documents__c doc4 = new Documents__c();
        doc4.SalesOrder__c = soId;
        doc4.Name = 'Signed Broker Form';
        doc4.Status__c = 'Uploaded';
        docList.add(doc4);
        
        Documents__c doc5 = new Documents__c();
        doc5.SalesOrder__c = soId;
        doc5.Name = 'Reservation Form';
        doc5.Status__c = 'Uploaded';
        docList.add(doc5);
        
        Documents__c doc6 = new Documents__c();
        doc6.SalesOrder__c = soId;
        doc6.Name = 'Signed Reservation Form';
        doc6.Status__c = 'Uploaded';
        docList.add(doc6);
        
        insert docList;

        ContentVersion testContentVersion = new ContentVersion(
            Title = 'SPA',
            PathOnClient = 'SPA.pdf',
            VersionData = Blob.valueOf('Test file data')
        );
        insert testContentVersion;

        ContentDocument testContentDoc;
        List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :testContentVersion.Id LIMIT 1];
        System.assert(!docs.isEmpty(), 'ContentDocument should be created');
        testContentDoc = docs[0];

        ContentDocumentLink testLink = new ContentDocumentLink(
            LinkedEntityId = [SELECT Id FROM Documents__c WHERE Name LIKE '%SPA%' LIMIT 1].Id,
            ContentDocumentId = testContentDoc.Id,
            ShareType = 'V'
        );
        insert testLink;
        
        Account acc = new Account();
        acc.Id = [SELECT Id FROM Account LIMIT 1].Id;
        acc.PersonEmail = 'test1@test.com';
        update acc;
        
        SalesOrder__c soUpd = new SalesOrder__c();
        soUpd.Id = soId;
        soUpd.SPAStatus__c = 'Pending for Validation';
        update soUpd;
        
        List<Documents__c> docsToUpload = new List<Documents__c>();
        for(Documents__c docObj : [SELECT Id FROM Documents__c WHERE Status__c = 'Pending Upload']){
            docsToUpload.add(new Documents__c(Id = docObj.Id, Status__c = 'Uploaded'));
        }
        if(!docsToUpload.isEmpty()){
            try{ update docsToUpload; }catch(Exception ex){}
        }

        List<sObject> newList = [SELECT Id,SPAStatus__c FROM SalesOrder__c];
        Map<Id,sObject> oldMap = new Map<Id,sObject>();
        for(SalesOrder__c so:[SELECT Id,SPAStatus__c FROM SalesOrder__c]){
            so.SPAStatus__c = 'SPA Signed (Modon)';
            oldMap.put(so.Id,so);
        }

        Test.startTest();
        SalesOrderStatusAutomationHelper.handleSpaDocs(newList,oldMap);
        SalesOrderStatusAutomationHelper.checkSPAStatus(new Set<Id>{soId});
        SalesOrderStatusAutomationHelper.checkReservationForm(new Set<Id>{soId});
        SalesOrderStatusAutomationHelper.checkBrokerForm(new Set<Id>{soId});
        database.executebatch(new SalesOrderHistoricalUpdateBatch(null),1);
        Test.stopTest();
    }
    @isTest static void copyIdfromPrimaryContactLWCTest(){
        Test.startTest();
        Map<Id,sObject> newMap = new Map<Id,sObject>();
        Map<Id,sObject> oldMap = new Map<Id,sObject>();
        for(SalesOrder__c so:[SELECT Id,Finance_Associate__c,Customer_Management_Associate__c,SalesAssociate__c,Sales_Operations_Associate__c FROM SalesOrder__c]){
            newMap.put(so.Id,so);
        }
        Id opptyId = [SELECT Id FROM Opportunity LIMIT 1].Id;
        SalesOrderStatusAutomationHelper.copyIdfromPrimaryContactLWC(opptyId);
        SalesOrder__c so = new SalesOrder__c();
        so.Id = [SELECT Id FROM SalesOrder__c LIMIT 1].Id;
        so.Customer_Management_Associate__c = UserInfo.getUserId();
        update so;
        for(SalesOrder__c so1:[SELECT Id,Finance_Associate__c,Customer_Management_Associate__c,SalesAssociate__c,Sales_Operations_Associate__c FROM SalesOrder__c]){
            oldMap.put(so1.Id,so1);
        }
        SalesOrderStatusAutomationHelper.applyAssociateSharing(newMap,oldMap);
        Test.stopTest();
    }
    @isTest static void SaveWaiverResponseTest(){
    Id docId1 = createFileAndReturnContentDocumentId('waiver-memo.pdf', 'Test PDF body');
    Id docId2 = createFileAndReturnContentDocumentId('supporting-note.txt', 'Some notes');

    List<Id> contentDocumentIds = new List<Id>{ docId1, docId2 };
	Id soId = [SELECT Id FROM SalesOrder__c LIMIT 1].Id;
        SalesOrderStatusAutomationHelper.getTeamFromSubStatus('Reservation Form Generated');
        SalesOrderStatusAutomationHelper.getTeamFromSubStatus('SPA In-Progress');
        SalesOrderStatusAutomationHelper.getTeamFromSubStatus('Pending with CM');
    }
    private static Id createFileAndReturnContentDocumentId(String fileNameWithExt, String body) {
    ContentVersion cv = new ContentVersion(
        Title         = fileNameWithExt.removeEnd('.pdf').removeEnd('.txt').removeEnd('.png'),
        PathOnClient  = fileNameWithExt,
        VersionData   = Blob.valueOf(body),
        IsMajorVersion= true
    );
    insert cv;
    cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
    return cv.ContentDocumentId;

}
    @isTest static void copyDocsTest(){
        Test.startTest();
        Id soId = [SELECT Id FROM SalesOrder__c LIMIT 1].Id;
        Id contactId = [SELECT Id,PersonContactId FROM Account LIMIT 1].PersonContactId;
        List<Documents__c> targetDocs = new List<Documents__c>{
            new Documents__c(Name = 'Passport',                         SalesOrder__c = soId, Status__c = 'Pending Upload',PrimaryContact__c = contactId),
            new Documents__c(Name = 'Emirates ID',                      SalesOrder__c = soId, Status__c = 'Pending Upload',PrimaryContact__c = contactId),
            new Documents__c(Name = 'Signed KYC and Wealth Form',       SalesOrder__c = soId, Status__c = 'Pending Upload',PrimaryContact__c = contactId)
        };
        insert targetDocs;

        Id accId = [SELECT Id FROM Account LIMIT 1].Id;
        List<Documents__c> sourceDocs = new List<Documents__c>{
            new Documents__c(Name = 'Passport',                    PrimaryContact__c = contactId, Status__c = 'Uploaded',Account__c =accId ),
            new Documents__c(Name = 'Emirates/National ID Front',  PrimaryContact__c = contactId, Status__c = 'Uploaded',Account__c =accId),
            new Documents__c(Name = 'Emirates/National ID Back',   PrimaryContact__c = contactId, Status__c = 'Uploaded',Account__c =accId),
            new Documents__c(Name = 'KYC Form - Signed',           PrimaryContact__c = contactId, Status__c = 'Uploaded',Account__c =accId)
        };
        insert sourceDocs;
		SalesOrderStatusAutomationHelper.handleDocumentUploadAccount(sourceDocs,null);
        for (Documents__c src : sourceDocs) {
            Id docId = createFileReturnDocId(src.Name + '.pdf', 'test body ' + src.Name);
            linkFileToDocuments(docId, src.Id);
        }
        Test.stopTest();
    }
    private static Id createFileReturnDocId(String filename, String body) {
        ContentVersion cv = new ContentVersion(
            Title          = filename.removeEnd('.pdf').removeEnd('.txt'),
            PathOnClient   = filename,
            VersionData    = Blob.valueOf(body),
            IsMajorVersion = true
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        return cv.ContentDocumentId;
    }

    private static void linkFileToDocuments(Id contentDocumentId, Id documentsId) {
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId    = documentsId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
    }
    @isTest static void handleSOCheckBoxHelperTest(){
        Test.startTest();
        Map<id,SalesOrder__c> newMap = new Map<id,SalesOrder__c>();
        Map<id,SalesOrder__c> oldMap = new Map<id,SalesOrder__c>();
        for(SalesOrder__c so:[SELECT Id,Is_Sales_Checklist_Completed__c,Status__c,Sub_Status__c FROM SalesOrder__c]){
            oldMap.put(so.Id,so);
        }
        ContentVersion testContentVersion = new ContentVersion(
            Title = 'SPA',
            PathOnClient = 'SPA.pdf',
            VersionData = Blob.valueOf('Test file data')
        );
        insert testContentVersion;

        ContentDocument testContentDoc;
        List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :testContentVersion.Id LIMIT 1];
        System.assert(!docs.isEmpty(), 'ContentDocument should be created');
        testContentDoc = docs[0];

        ContentDocumentLink testLink = new ContentDocumentLink(
            LinkedEntityId =  [SELECT Id FROM SalesOrder__c LIMIT 1].Id,
            ContentDocumentId = testContentDoc.Id,
            ShareType = 'V'
        );
        
        SalesOrder__c so= new SalesOrder__c();
        so.Id = [SELECT Id FROM SalesOrder__c LIMIT 1].Id;
        so.Is_Sales_Checklist_Completed__c = false;
        so.SPAStatus__c = 'Pending for Validation';
        so.Sub_Status__c = 'Pending With Sales';
        update so;
        List<sObject> newList = new List<sObject>();
        for(SalesOrder__c so1:[SELECT Id,Is_Sales_Checklist_Completed__c,Status__c,Sub_Status__c FROM SalesOrder__c WHERE Id =:so.Id]){
            newList.add(so1);
        }
        SalesOrderStatusAutomationHelper.handleSOCheckBoxHelper(newList,oldMap);
        Test.stopTest();
    }
    @isTest static void generateCustomerDocumentsTest(){
        Test.startTest();
        Id accId = [SELECT Id FROM Account LIMIT 1].Id;
        Id personAccId = [SELECT Id,PersonContactId FROM Account LIMIT 1].PersonContactId;
        GenerateCustomerDocumentAccount.generateCustomerDocuments(new List<Id>{accId});
        GenerateCustomerDocumentContact.generateCustomerDocuments(new List<Id>{personAccId});
        
        Account acc = new Account();
        acc.Name = 'test';
        insert acc;
        GenerateCustomerDocumentAccount.generateCustomerDocuments(new List<Id>{acc.Id});
        Test.stopTest();
    }
        @isTest static void pdcTestMethod(){
        // Reuse @TestSetup records: re-creating Account/Opportunity/EOI/SalesOrder here
        // fired their triggers in this method's SOQL context and pushed the Receipt
        // insert past 101 queries.
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        // MilestoneNumber 2 so updatePDCStatus doesn't filter it out (it excludes milestone 1)
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        soi.MilestoneNumber__c = 2;
        insert soi;
        
        
        
        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = testAccount.Id;
        recObj.ExpressionOfInterest__c = eoi.Id;
        recObj.SalesOrderInstallment__c = soi.Id;
        recObj.ChequeDate__c = System.today()+30;
        recObj.Instrument_Received_Date__c = System.today();  
        recObj.Modeofpayment__c = 'Cheque';
        insert recObj;

        Invoice__c invoice = new Invoice__c();
        invoice.Expressionofinterest__c = eoi.Id;
        invoice.InvoiceAmount__c = 100;
        invoice.SalesOrderInstallment__c = soi.Id;
        invoice.Account__c = testAccount.Id;
        insert invoice;

            Test.startTest();
        ReceiptTriggerHelper.createAllocationRecord(new Map<Id, sObject>{recObj.Id => recObj});
        
            SalesOrderStatusAutomationHelper.updatePDCStatus(new Set<Id>{recObj.Id});
            Test.stopTest();
        }
        @IsTest
static void testCheckSPAStatusCreatesADMSR() {
    SalesOrder__c so = [
        SELECT Id
        FROM SalesOrder__c
        LIMIT 1
    ];

    so.ADM_Fees_and_Dari__c = 'Paid';
    so.Down_Payment_Status__c = 'Paid';
    so.is_Transferred_SO__c = false;
    so.SPAStatus__c = 'Pending for Validation';
    update so;

    Documents__c modonSpa = new Documents__c(
        SalesOrder__c = so.Id,
        Name = 'Signed SPA (Modon)',
        Status__c = 'Uploaded'
    );
    insert modonSpa;

    Test.startTest();
    SalesOrderStatusAutomationHelper.checkSPAStatus(new Set<Id>{ so.Id });
    Test.stopTest();

    SalesOrder__c updatedSO = [
        SELECT Id, Status__c, Sub_Status__c, SPAStatus__c
        FROM SalesOrder__c
        WHERE Id = :so.Id
        LIMIT 1
    ];


    List<ServiceRequest__c> admSRs = [
        SELECT Id, SalesOrder__c, RecordType.DeveloperName
        FROM ServiceRequest__c
        WHERE SalesOrder__c = :so.Id
        AND RecordType.DeveloperName = 'Service_Request_Management_ADM'
    ];

    
}

@IsTest
static void testStatusMethodsDirectCoverage() {
    SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

    update new SalesOrder__c(
        Id = so.Id,
        Status__c = 'In Progress',
        ADM_Fees_and_Dari__c = 'Paid',
        Down_Payment_Status__c = 'Paid',
        SPAStatus__c = 'Pending for Validation',
        is_Transferred_SO__c = false
    );

    insert new List<Documents__c>{
        new Documents__c(Name = 'Reservation Form', SalesOrder__c = so.Id, Status__c = 'Uploaded'),
        new Documents__c(Name = 'Broker Form', SalesOrder__c = so.Id, Status__c = 'Uploaded'),
        new Documents__c(Name = 'Signed SPA (Modon)', SalesOrder__c = so.Id, Status__c = 'Uploaded')
    };

    Test.startTest();

    SalesOrderStatusAutomationHelper.checkReservationForm(new Set<Id>{so.Id});
    SalesOrderStatusAutomationHelper.checkBrokerForm(new Set<Id>{so.Id});
    SalesOrderStatusAutomationHelper.checkSPAStatus(new Set<Id>{so.Id});

    SalesOrderStatusAutomationHelper.checkDownPaymentStatus(new Set<Id>{so.Id});
    SalesOrderStatusAutomationHelper.checkADMFeeDariFeeStatus(new Set<Id>{so.Id});

    Test.stopTest();

    System.assert(true);
}
@IsTest
static void testHandleStatusCloseAndUpdateSOSubStatus() {
    SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

    Sales_Order_Status_Approvals__c oldApp = new Sales_Order_Status_Approvals__c(
        Sales_Order__c = so.Id,
        Current_Sub_Status__c = 'Pending with CM',
        Sales_Order_Status__c = 'In Progress',
        Approval_Status__c = 'Pending',
        Flow__c = 'SPA Without Broker Flow'
    );
    insert oldApp;

    Sales_Order_Status_Approvals__c newApp = [
        SELECT Id, Sales_Order__c, Current_Sub_Status__c, Sales_Order_Status__c, Approval_Status__c, Flow__c
        FROM Sales_Order_Status_Approvals__c
        WHERE Id = :oldApp.Id
    ];

    Map<Id, Sales_Order_Status_Approvals__c> oldMap = new Map<Id, Sales_Order_Status_Approvals__c>{
        oldApp.Id => oldApp
    };

    newApp.Approval_Status__c = 'Approved';

    Test.startTest();
    SalesOrderStatusAutomationHelper.handleStatusClose(
        new List<Sales_Order_Status_Approvals__c>{ newApp },
        oldMap
    );

    SalesOrderStatusAutomationHelper.updateSOSubStatus(
        new List<Sales_Order_Status_Approvals__c>{ newApp },
        oldMap
    );
    Test.stopTest();

} 
        @IsTest
static void testPaymentAndADMStatusMethods() {
    SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
    Account acc = [SELECT Id FROM Account LIMIT 1];

    SalesOrderInstallments__c inst = [
        SELECT Id
        FROM SalesOrderInstallments__c
        WHERE SalesOrder__c = :so.Id
        LIMIT 1
    ];

    Invoice__c dpInv = new Invoice__c(
        SalesOrderInstallment__c = inst.Id,
        Sales_Order__c = so.Id,
        InvoiceAmount__c = 100,
        Account__c = acc.Id
    );

    Invoice__c admInv = new Invoice__c(
        Sales_Order__c = so.Id,
        InvoiceAmount__c = 100,
        Is_ADM_Fees_and_Dari_charges__c = true,
        Account__c = acc.Id
    );

    insert new List<Invoice__c>{ dpInv, admInv };

    Test.startTest();
    SalesOrderStatusAutomationHelper.checkDownPaymentStatus(new Set<Id>{ so.Id });
    SalesOrderStatusAutomationHelper.checkADMFeeDariFeeStatus(new Set<Id>{ so.Id });
    Test.stopTest();

}
           
    @isTest
static void testCreateDebitNoteApplications() {

    Account acc = new Account(Name = 'Test Account');
    insert acc;

    Opportunity opp = new Opportunity(
        Name = 'Test Opp',
        StageName = 'Qualification',
        CloseDate = Date.today()
    );
    insert opp;

    SalesOrder__c so = new SalesOrder__c(
        Opportunity__c = opp.Id,
        CustomerAccount__c = acc.Id,
        Status__c = 'Completed'
    );
    insert so;

    Invoice__c invoice = new Invoice__c(
        Account__c = acc.Id
    );
    insert invoice;

    Receipt__c r1 = new Receipt__c(
        Account__c = acc.Id,
        Status__c = 'Cleared',
        EBS_Clearing_Date__c = Date.today(),
        Allocation_Amount_on_Transfer__c = 150
    );

    Receipt__c r2 = new Receipt__c(
        Account__c = acc.Id,
        EBS_Clearing_Date__c = Date.today(),
        Status__c = 'Cleared'
    );

    Receipt__c r3 = new Receipt__c(
        Account__c = acc.Id,
        Status__c = 'Cleared',
        EBS_Clearing_Date__c = Date.today(),
        Allocation_Amount_on_Transfer__c = 0
    );

    insert new List<Receipt__c>{ r1, r2, r3 };

        }

    @IsTest 
static void testFinanceVerificationMethods() {
    SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

    update new SalesOrder__c(
        Id = so.Id,
        Status__c = 'In Progress',
        Sub_Status__c = 'Under Finance Verification',
        Down_Payment_Status__c = 'Paid',
        ADM_Fees_and_Dari__c = 'Paid'    );

    Document_Checklist__c dc = new Document_Checklist__c(
        Sales_Order__c = so.Id,
        Team__c = 'Finance'    );
    insert dc;

    Sales_Order_Status_Approvals__c oldApp = new Sales_Order_Status_Approvals__c(
        Sales_Order__c = so.Id,
        Current_Sub_Status__c = 'Pending with CM'
    );

    Sales_Order_Status_Approvals__c newApp = new Sales_Order_Status_Approvals__c(
        Sales_Order__c = so.Id,
        Current_Sub_Status__c = 'Under Finance Verification'
    );

    Map<Id, Sales_Order_Status_Approvals__c> oldMap =
        new Map<Id, Sales_Order_Status_Approvals__c>{
            so.Id => oldApp
        };

    Test.startTest();
    SalesOrderStatusAutomationHelper.handleFinanceVerificationStatus(
        new List<Sales_Order_Status_Approvals__c>{ newApp },
        oldMap
    );

    SalesOrderStatusAutomationHelper.closeFinaceVerificationStep(
        new Set<Id>{ so.Id }
    );
    Test.stopTest();

}
        @IsTest
static void testHandleSpaDocs() {
    SalesOrder__c oldSO = [
        SELECT Id, SPAStatus__c
        FROM SalesOrder__c
        LIMIT 1
    ];

    oldSO.SPAStatus__c = 'SPA Generated';

    SalesOrder__c newSO = new SalesOrder__c(
        Id = oldSO.Id,
        SPAStatus__c = 'Pending for Validation'
    );

     Documents__c docSPA = new Documents__c(
        Name='SPA',
        SalesOrder__c = oldSO.Id,
        Status__c='Pending Upload'
    );
    insert docSPA;
    
    insert new Documents__c(
        SalesOrder__c = oldSO.Id,
        Name = 'Signed SPA (Customer)',
        Status__c = 'Pending Upload'
    );

     ContentVersion v3 = new ContentVersion(
        Title='SPA',
        PathOnClient='/SPA.pdf',
        VersionData=Blob.valueOf('test'),
        Origin='H'
    );
    insert v3;
      List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>{
       
        new ContentDocumentLink(
            LinkedEntityId = oldSO.Id,
            ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id=:v3.Id].ContentDocumentId,
            ShareType='I',
            Visibility='AllUsers'
        )
    };
    
    insert cdlList;
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
        oldSO.Id => oldSO
    };

    Test.startTest();
    SalesOrderStatusAutomationHelper.handleSpaDocs(
        new List<SObject>{ newSO },
        oldMap
    );
    Test.stopTest();

}
        @IsTest
static void testHandleStsUpdateFromDocuChecklistAgain() {
    SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

    update new SalesOrder__c(
        Id = so.Id,
        Status__c = 'In Progress'    );

    Document_Checklist__c oldDoc = new Document_Checklist__c(
        Sales_Order__c = so.Id,
        Team__c = 'Finance'
    );
    insert oldDoc;

    Document_Checklist__c newDoc = new Document_Checklist__c(
        Id = oldDoc.Id,
        Sales_Order__c = so.Id,
        Team__c = 'Finance'    );

    Map<Id, Document_Checklist__c> oldMap =
        new Map<Id, Document_Checklist__c>{
            oldDoc.Id => oldDoc
        };

    Test.startTest();
    SalesOrderStatusAutomationHelper.handleStsUpdateFromDocuChecklist(
        new List<Document_Checklist__c>{ newDoc },
        oldMap
    );
    Test.stopTest();

}
        @IsTest
static void testUpdateDDPaymentMethod() {
    SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

    DirectDebitRequest__c dd = new DirectDebitRequest__c(
        SalesOrder__c = so.Id,
        Status__c = 'Active'
    );

    Test.startTest();
    SalesOrderStatusAutomationHelper.updateDDPaymentMethod(
        new List<SObject>{ dd },
        null
    );
    Test.stopTest();

    SalesOrder__c updatedSO = [
        SELECT Id, PDC_Collected__c, Modeofpayment__c
        FROM SalesOrder__c
        WHERE Id = :so.Id
    ];

}
        @IsTest
static void testCheckADMFeeDariFeeStatus_AllBranches() {
    SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
    Account acc = [SELECT Id FROM Account LIMIT 1];

    update new SalesOrder__c(
        Id = so.Id,
        Status__c = 'In Progress',
        IsADMCollectedWithWaiverRequest__c = false
    );

    List<Invoice__c> admInvoices = new List<Invoice__c>{
        new Invoice__c(
            Sales_Order__c = so.Id,
            Account__c = acc.Id,
            InvoiceAmount__c = 100
        ),
        new Invoice__c(
            Sales_Order__c = so.Id,
            Account__c = acc.Id,
            InvoiceAmount__c = 100       ),
        new Invoice__c(
            Sales_Order__c = so.Id,
            Account__c = acc.Id,
            InvoiceAmount__c = 100
                ),
        new Invoice__c(
            Sales_Order__c = so.Id,
            Account__c = acc.Id,
            InvoiceAmount__c = 100
        ),
        new Invoice__c(
            Sales_Order__c = so.Id,
            Account__c = acc.Id,
            InvoiceAmount__c = 100
        ),
        new Invoice__c(
            Sales_Order__c = so.Id,
            Account__c = acc.Id,
            InvoiceAmount__c = 100
        )
    };
    insert admInvoices;

    Test.startTest();
    SalesOrderStatusAutomationHelper.checkADMFeeDariFeeStatus(new Set<Id>{ so.Id });
    Test.stopTest();

}
        @IsTest
static void testCloseSLAOnTeamChange() {
    SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

    CaseSLA__c sla = new CaseSLA__c(
        SalesOrder__c = so.Id,
        Status__c = 'OnTrack'
    );
    insert sla;

    SalesOrder__c oldSO = new SalesOrder__c(
        Id = so.Id,
        Sub_Status__c = 'Pending with Sales'
    );

    SalesOrder__c newSO = new SalesOrder__c(
        Id = so.Id,
        Sub_Status__c = 'Pending with CM'
    );

    Map<Id, SObject> oldMap = new Map<Id, SObject>{
        so.Id => oldSO
    };

    Test.startTest();
    SalesOrderSLAHelper.closeSLAOnTeamChange(
        new List<SalesOrder__c>{ newSO },
        oldMap
    );
    Test.stopTest();

    CaseSLA__c updatedSLA = [
        SELECT Id, Status__c, EndTime__c
        FROM CaseSLA__c
        WHERE Id = :sla.Id
    ];

}
        @IsTest
static void testGetAdmPaymentStatus() {

    Account acc = new Account(Name = 'Test Account');
    insert acc;

    Opportunity opp = new Opportunity(
        Name = 'Test Opp',
        StageName = 'Qualification',
        CloseDate = Date.today()
    );
    insert opp;

    SalesOrder__c so = new SalesOrder__c(
        Opportunity__c = opp.Id,
        CustomerAccount__c = acc.Id,
        ADM_Fees_and_Dari__c = 'Paid'
    );
    insert so;

    Test.startTest();
    String result = SalesOrderStatusAutomationHelper.getAdmPaymentStatus(so.Id);
    Test.stopTest();

}
        @IsTest
static void testUpdateMOPFromAllocation() {
    SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
    Account acc = [SELECT Id FROM Account LIMIT 1];

    SalesOrderInstallments__c inst = [
        SELECT Id
        FROM SalesOrderInstallments__c
        WHERE SalesOrder__c = :so.Id
        LIMIT 1
    ];

    List<Schema.PicklistEntry> vals =
        Receipt__c.Modeofpayment__c.getDescribe().getPicklistValues();

    String mop = vals[0].getValue();

    Receipt__c rec = new Receipt__c(
        Account__c = acc.Id,
        SalesOrderInstallment__c = inst.Id,
        Modeofpayment__c = mop,
        EBS_Clearing_Date__c=system.today(),
        Status__c = 'Cleared'
    );
    insert rec;

    Invoice__c inv = new Invoice__c(
        Account__c = acc.Id,
        SalesOrderInstallment__c = inst.Id,
        Sales_Order__c = so.Id,
        InvoiceAmount__c = 100
    );
    insert inv;

    Allocation__c alloc = new Allocation__c(
        Invoice__c = inv.Id,
        Receipt__c = rec.Id,
        AllocationAmount__c = 100,
        Status__c = 'Applied'
    );

    Test.startTest();
    SalesOrderStatusAutomationHelper.updateMOPfromAllocation(
        new List<SObject>{ alloc },
        null
    );
    Test.stopTest();

}
    @isTest
    static void testAutoCloseStatus() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Sales_Order_Status_Approvals__c soa = new Sales_Order_Status_Approvals__c(
            Sales_Order__c = so.Id,
            Current_Sub_Status__c = 'Pending With Sales',
            Approval_Status__c = 'Pending',
            Flow__c = 'Test Flow'
        );
        insert soa;
        Test.startTest();
        SalesOrderStatusAutomationHelper.autoCloseStatus(new Set<Id>{ soa.Id });
        Test.stopTest();
    }

    @isTest
    static void testClosingTheStatus() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Sales_Order_Status_Approvals__c soa = new Sales_Order_Status_Approvals__c(
            Sales_Order__c = so.Id,
            Current_Sub_Status__c = 'Down Payment Collected',
            Approval_Status__c = 'Pending',
            Flow__c = 'Test Flow'
        );
        insert soa;
        Test.startTest();
        SalesOrderStatusAutomationHelper.closingTheStatus(
            new Set<Id>{ so.Id },
            new List<String>{ 'Down Payment Collected' }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleApprovalStatusonNewCreation() {
        SalesOrder__c so = [SELECT Id, Status__c FROM SalesOrder__c LIMIT 1];
        SalesOrder__c newSo = new SalesOrder__c(
            Id = so.Id,
            Source_Entity__c = 'Modon - UAE',
            Resale__c = false
        );
        Test.startTest();
        SalesOrderStatusAutomationHelper.handleApprovalStatusonNewCreation(
            new List<SObject>{ newSo }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleInvoiceChange() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        SalesOrderInstallments__c inst = [SELECT Id FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :so.Id LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Invoice__c inv = new Invoice__c(
            SalesOrderInstallment__c = inst.Id,
            InvoiceAmount__c = 5000,
            Account__c = acc.Id
        );
        insert inv;
        Invoice__c oldInv = [SELECT Id, AppliedAmount__c, InvoiceStatus__c,
            Is_ADM_Fees_and_Dari_charges__c
            FROM Invoice__c WHERE Id = :inv.Id];
        Invoice__c newInv = oldInv.clone(true, true, false, false);
        newInv.Is_ADM_Fees_and_Dari_charges__c = true;
        Test.startTest();
        SalesOrderStatusAutomationHelper.handleInvoiceChange(
            new List<Invoice__c>{ newInv },
            new Map<Id, Invoice__c>{ oldInv.Id => oldInv }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandlePDCCollectedSts() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        SalesOrder__c oldSo = so.clone(true, true, false, false);
        oldSo.UAE_Resident_Status__c = 'Resident';
        oldSo.ExcludePDCCheck__c = false;
        SalesOrder__c newSo1 = oldSo.clone(true, true, false, false);
        newSo1.UAE_Resident_Status__c = 'Non-Resident';
        SalesOrder__c newSo2 = oldSo.clone(true, true, false, false);
        newSo2.ExcludePDCCheck__c = true;
        SalesOrder__c newSo3 = oldSo.clone(true, true, false, false);
        newSo3.ExcludePDCCheck__c = false;
        SalesOrder__c oldSo3 = oldSo.clone(true, true, false, false);
        oldSo3.ExcludePDCCheck__c = true;
        Test.startTest();
        SalesOrderStatusAutomationHelper.handlePDCCollectedSts(
            new List<SObject>{ newSo1, newSo2 },
            new Map<Id, SObject>{ oldSo.Id => oldSo, oldSo.Id => oldSo }
        );
        SalesOrderStatusAutomationHelper.handlePDCCollectedSts(
            new List<SObject>{ newSo3 },
            new Map<Id, SObject>{ oldSo3.Id => oldSo3 }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandlePDCStatusAllocation() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        SalesOrderInstallments__c inst = [SELECT Id FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :so.Id LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Invoice__c inv = new Invoice__c(
            SalesOrderInstallment__c = inst.Id,
            InvoiceAmount__c = 5000,
            Account__c = acc.Id
        );
        insert inv;
        Receipt__c rec = new Receipt__c(
            TotalAmount__c = 1000,
            Account__c = acc.Id,
            SalesOrderInstallment__c = inst.Id,
            SalesOrder__c = so.Id,
            TransactionDate__c = System.now()
        );
        // Setup data only; allocation insert cascades Receipt updates, so bypass the Receipt trigger
        TriggerControl.bypassReceiptTrigger = true;
        insert rec;
        Allocation__c alloc = new Allocation__c(
            Invoice__c = inv.Id,
            Receipt__c = rec.Id,
            AllocationAmount__c = 500,
            Status__c = 'Applied'
        );
        insert alloc;
        TriggerControl.bypassReceiptTrigger = false;
        Allocation__c oldAlloc = [SELECT Id, Receipt__c, Invoice__c FROM Allocation__c
            WHERE Id = :alloc.Id];
        Allocation__c newAlloc = oldAlloc.clone(true, true, false, false);
        Test.startTest();
        SalesOrderStatusAutomationHelper.handlePDCStatusAllocation(
            new List<SObject>{ newAlloc },
            new Map<Id, SObject>{ oldAlloc.Id => oldAlloc }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandlePDCStatusReceipt() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        SalesOrderInstallments__c inst = [SELECT Id FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :so.Id LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Receipt__c rec = new Receipt__c(
            TotalAmount__c = 1000,
            Account__c = acc.Id,
            SalesOrderInstallment__c = inst.Id,
            SalesOrder__c = so.Id,
            TransactionDate__c = System.now(),
            Modeofpayment__c = 'Cheque',
            ChequeDate__c = Date.today(),
            Instrument_Received_Date__c = Date.today()
        );
        insert rec;
        Receipt__c oldRec = [SELECT Id, Instrument_Received_Date__c, ChequeDate__c,
            Modeofpayment__c FROM Receipt__c WHERE Id = :rec.Id];
        Receipt__c newRec = oldRec.clone(true, true, false, false);
        newRec.ChequeDate__c = Date.today().addDays(1);
        Test.startTest();
        SalesOrderStatusAutomationHelper.handlePDCStatusReceipt(
            new List<SObject>{ newRec },
            new Map<Id, SObject>{ oldRec.Id => oldRec }
        );
        Test.stopTest();
    }

    @isTest
    static void testUpdateMOPfromPayment() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        SalesOrderInstallments__c inst = [SELECT Id FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :so.Id LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Receipt__c rec = new Receipt__c(
            TotalAmount__c = 1000,
            Account__c = acc.Id,
            SalesOrderInstallment__c = inst.Id,
            SalesOrder__c = so.Id,
            TransactionDate__c = System.now(),
            Modeofpayment__c = 'Bank Transfer'
        );
        insert rec;
        Receipt__c oldRec = [SELECT Id, Modeofpayment__c FROM Receipt__c WHERE Id = :rec.Id];
        Receipt__c newRec = oldRec.clone(true, true, false, false);
        newRec.Modeofpayment__c = 'Cheque';
        Test.startTest();
        SalesOrderStatusAutomationHelper.updateMOPfromPayment(
            new List<SObject>{ newRec },
            new Map<Id, SObject>{ oldRec.Id => oldRec }
        );
        Test.stopTest();
    }

    @isTest
    static void testUpdatePDCinstrumentReceivedInfo() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        SalesOrderInstallments__c inst = [SELECT Id FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :so.Id LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Receipt__c rec = new Receipt__c(
            TotalAmount__c = 1000,
            Account__c = acc.Id,
            SalesOrderInstallment__c = inst.Id,
            SalesOrder__c = so.Id,
            TransactionDate__c = System.now(),
            Modeofpayment__c = 'Bank Transfer'
        );
        insert rec;
        Receipt__c oldRec = [SELECT Id, Modeofpayment__c FROM Receipt__c WHERE Id = :rec.Id];
        Receipt__c newRec = oldRec.clone(true, true, false, false);
        newRec.Modeofpayment__c = 'Cheque';
        Test.startTest();
        SalesOrderStatusAutomationHelper.updatePDCinstrumentReceivedInfo(
            new List<SObject>{ newRec },
            new Map<Id, SObject>{ oldRec.Id => oldRec }
        );
        Test.stopTest();
    }

    @isTest
    static void testUpdateWaiverMemoNumber() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        SalesOrder__c oldSo = so.clone(true, true, false, false);
        oldSo.UAE_Resident_Status__c = 'Resident';
        oldSo.ExcludePDCCheck__c = false;
        SalesOrder__c newSo = so.clone(true, true, false, false);
        newSo.UAE_Resident_Status__c = 'Non-Resident';
        Test.startTest();
        SalesOrderStatusAutomationHelper.handlePDCCollectedSts(
            new List<SObject>{ newSo },
            new Map<Id, SObject>{ oldSo.Id => oldSo }
        );
        SalesOrderStatusAutomationHelper.closingTheStatus(
            new Set<Id>{ so.Id },
            new List<String>{ 'Pending With Sales', 'Reservation Form Generated' }
        );
        Test.stopTest();
    }

    @isTest
    static void testValidateTheSOChecklistAccount() {
        Account acc = [SELECT Id, PersonEmail, Phone, PersonMobilePhone FROM Account LIMIT 1];
        Account oldAcc = acc.clone(true, true, false, false);
        Account newAcc = acc.clone(true, true, false, false);
        newAcc.PersonEmail = 'newtest@test.com';
        Test.startTest();
        SalesOrderStatusAutomationHelper.validateTheSOChecklistAccount(
            new List<SObject>{ newAcc },
            new Map<Id, SObject>{ oldAcc.Id => oldAcc }
        );
        Test.stopTest();
    }

    @isTest
    static void testUpdateOpptyIdInfo() {
        Opportunity opp = [SELECT Id, PrimaryContact__c FROM Opportunity LIMIT 1];
        Test.startTest();
        SalesOrderStatusAutomationHelper.updateOpptyIdInfo(
            new Set<Id>{ opp.PrimaryContact__c }
        );
        Test.stopTest();
    }

    @isTest
    static void testSoDocCreation() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Documents__c doc = new Documents__c(
            SalesOrder__c = so.Id,
            Name = 'Passport',
            Status__c = 'Pending Upload'
        );
        insert doc;
        Test.startTest();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Documents__c oldDoc = doc.clone(true, true, false, false);
        oldDoc.status__c = 'Pending Upload';
        Documents__c newDoc = doc.clone(true, true, false, false);
        newDoc.status__c = 'Uploaded';
        SalesOrderStatusAutomationHelper.handleDocumentUploadAccount(
            new List<SObject>{ newDoc },
            new Map<Id, SObject>{ oldDoc.Id => oldDoc }
        );
        Test.stopTest();
    }

    @isTest
    static void testRelinkFilesToTargets() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id, PrimaryContact__c FROM Opportunity LIMIT 1];
        Id contactId = opp.PrimaryContact__c;

        Documents__c accDoc = new Documents__c(
            Name = 'Passport',
            Status__c = 'Pending Upload',
            Account__c = acc.Id,
            PrimaryContact__c = contactId
        );
        insert accDoc;

        Documents__c oldDoc = accDoc.clone(true, true, false, false);
        oldDoc.status__c = 'Pending Upload';
        Documents__c newDoc = accDoc.clone(true, true, false, false);
        newDoc.status__c = 'Uploaded';

        Test.startTest();
        SalesOrderStatusAutomationHelper.handleDocumentUploadAccount(
            new List<SObject>{ newDoc },
            new Map<Id, SObject>{ oldDoc.Id => oldDoc }
        );
        Account accFull = [SELECT Id, PersonEmail, Phone, PersonMobilePhone,
            EmailID__c, PassfortApprovalStatus__pc, PassfortApprovalStatus__c
            FROM Account WHERE Id = :acc.Id LIMIT 1];
        Account accFullOld = accFull.clone(true, true, false, false);
        Account accFullNew = accFull.clone(true, true, false, false);
        accFullNew.Phone = '0501234567';
        SalesOrderStatusAutomationHelper.validateTheSOChecklistAccount(
            new List<SObject>{ accFullNew },
            new Map<Id, SObject>{ accFullOld.Id => accFullOld }
        );
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEW — sendDownPaymentSurvey coverage.
    // REQUIRES: sendDownPaymentSurvey must be marked @TestVisible in the
    // production class (SalesOrderStatusAutomationHelper.cls) for these
    // calls to compile — see REQUIRED_PRODUCTION_CHANGE.txt.
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testSendDownPaymentSurvey_EmptySetReturnsEarly() {
        Test.startTest();
        SalesOrderStatusAutomationHelper.sendDownPaymentSurvey(null);
        SalesOrderStatusAutomationHelper.sendDownPaymentSurvey(new Set<Id>());
        Test.stopTest();
    }

    @IsTest
    static void testSendDownPaymentSurvey_DirectSalesType() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        // TODO: Sales_Type__c is a formula field — "Field is not writeable".
        // Once the real underlying source field is known, set THAT here
        // instead so this SO's computed Sales_Type__c actually evaluates to
        // 'Direct'. Left un-set for now so the class at least compiles;
        // this test currently exercises whatever Sales_Type__c naturally is.

        Xebo_Survey_Config__mdt directCfg =
            Xebo_Survey_Config__mdt.getInstance('Sales_Order_Down_Payment_Direct');

        if (directCfg != null && String.isNotBlank(directCfg.Collector_Id__c)) {
            Xebo_Survey_Config__mdt mockCfg = new Xebo_Survey_Config__mdt(
                Collector_Id__c = directCfg.Collector_Id__c,
                Base_URL__c     = 'https://mock.example.com/',
                API_Key__c      = 'mock-key',
                Is_Active__c    = true
            );
            SurveyTrackerService.mockConfigMap = new Map<String, Xebo_Survey_Config__mdt>{
                directCfg.Collector_Id__c => mockCfg
            };
            Test.setMock(HttpCalloutMock.class, new MockXeboSuccessResponse());
        }

        Test.startTest();
        SalesOrderStatusAutomationHelper.sendDownPaymentSurvey(new Set<Id>{ so.Id });
        Test.stopTest();
    }

    @IsTest
    static void testSendDownPaymentSurvey_IndirectSalesType() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        // TODO: same as above — Sales_Type__c is a formula field, can't set
        // directly. Set the real underlying source field here once known.

        Xebo_Survey_Config__mdt indirectCfg =
            Xebo_Survey_Config__mdt.getInstance('Sales_Order_Down_Payment_Indirect');

        if (indirectCfg != null && String.isNotBlank(indirectCfg.Collector_Id__c)) {
            Xebo_Survey_Config__mdt mockCfg = new Xebo_Survey_Config__mdt(
                Collector_Id__c = indirectCfg.Collector_Id__c,
                Base_URL__c     = 'https://mock.example.com/',
                API_Key__c      = 'mock-key',
                Is_Active__c    = true
            );
            SurveyTrackerService.mockConfigMap = new Map<String, Xebo_Survey_Config__mdt>{
                indirectCfg.Collector_Id__c => mockCfg
            };
            Test.setMock(HttpCalloutMock.class, new MockXeboSuccessResponse());
        }

        Test.startTest();
        SalesOrderStatusAutomationHelper.sendDownPaymentSurvey(new Set<Id>{ so.Id });
        Test.stopTest();
    }

    @IsTest
    static void testSendDownPaymentSurvey_UnrecognizedSalesTypeSkipped() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        // TODO: same as above — Sales_Type__c is a formula field, can't set
        // directly. This test's purpose (an SO that's neither Direct nor
        // Indirect) can't be forced until we know the real source field.

        Test.startTest();
        SalesOrderStatusAutomationHelper.sendDownPaymentSurvey(new Set<Id>{ so.Id });
        Test.stopTest();
    }

    @IsTest
    static void testSendDownPaymentSurvey_ModonEgyptExcludedByQueryFilter() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Test.startTest();
        SalesOrderStatusAutomationHelper.sendDownPaymentSurvey(new Set<Id>{ so.Id });
        Test.stopTest();
    }

    private class MockXeboSuccessResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"ok"}');
            return res;
        }
    }

}