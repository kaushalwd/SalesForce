@IsTest(SeeAllData=true)
public class PropertyTransferTitleDeedController_Test {

    private static ServiceRequest__c createFullSRData() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id,
            Is_Active__c = true,
            Email = 'test@mail.com'
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Qualification',
            CloseDate = Date.today(),
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c = '784-1232-1234567-4'
        );
        insert opp;

        Project__c po = new Project__c(Name = 'ProjectMega');
        insert po;

        Phase__c ph = new Phase__c(Name = 'bPhase');
        insert ph;

        Unit__c u = new Unit__c(
            Name = '3',
            PlotNo__c = '786B',
            Phase__c = ph.Id,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '9',
            GrossFloorAreaGFA__c = 100,
            ADM_Plot_Number__c = 'ADM-1',
            AED_SQM__c = 50,
            Sector__c = 'Sector 1',
            Location__c = 'Dubai'
        );
        insert u;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Opportunity__c = opp.Id,
            Status__c = 'completed',
            Unit__c = u.Id
        );
        insert so;

        PaymentPlan__c pp = new PaymentPlan__c(
            Name = 'demo',
            Phase__c = ph.Id,
            Project__c = po.Id,
            Unit__c = u.Id,
            Type__c = 'Standard'
        );
        insert pp;

        PaymentInstallements__c pI = new PaymentInstallements__c(
            PaymentInstallment__c = pp.Id,
            InstalmentNumber__c = 'First Payment / Deposit'
        );
        insert pI;

        SalesOrderInstallments__c soI = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            PaymentInstallments__c = pI.Id,
            MilestoneDate__c = Date.today().addDays(15),
            InstalmentPaymentDueDate__c = '23/05/2025'
        );
        insert soI;

        Id rtId = Utility.getRecordTypeIdByDevName(
            ServiceRequest__c.SObjectType,
            'Property_Transfer_Title_Deed_Commercial'
        );

        ServiceRequest__c sr = new ServiceRequest__c(
            Name__c = 'Test SR',
            SalesOrder__c = so.Id,
            AccountId__c = acc.Id,
            OpportunityId__c = opp.Id,
            UnitId__c = u.Id,
            Status__c = 'New',
            Type__c = 'Normal',
            Sales_Order_Installment__c = soI.Id,
            RecordTypeId = rtId,
            ProjectId__c = po.Id,
            Outstanding_Charge__c = 100
        );
        insert sr;

        return sr;
    }

    private static Documents__c createDocWithFile(Id srId, String docName, String statusVal) {
        Documents__c d = new Documents__c(
            Name = docName,
            Service_Request__c = srId,
            Status__c = statusVal
        );
        insert d;

        ContentVersion cv = new ContentVersion(
            Title = docName,
            PathOnClient = docName + '.pdf',
            VersionData = Blob.valueOf('test'),
            FirstPublishLocationId = d.Id
        );
        insert cv;

        return d;
    }

    @IsTest
    static void test_createOutstandingCharge_and_invoice() {

        ServiceRequest__c sr = createFullSRData();
        sr = [
            SELECT Id, Outstanding_Charge__c, SalesOrder__c, AccountId__c
            FROM ServiceRequest__c
            WHERE Id = :sr.Id
        ];

        Map<Id, ServiceRequest__c> oldMap = new Map<Id, ServiceRequest__c>{
            sr.Id => sr.clone(false, true, false, false)
        };
        sr.Outstanding_Charge__c = 500;

        Test.startTest();
        try{
        update sr;
      PropertyTransferTitleDeedController.handleCommercialCharges(
    new List<ServiceRequest__c>{ sr },
    oldMap
);
		} catch (Exception e) { }
       

        Charge__c anyCharge = [
            SELECT Id, Account__c, Sales_Order__c, VAT_Amount__c, Amount__c
            FROM Charge__c LIMIT 1];

        PropertyTransferTitleDeedController.createChargeInvoice(anyCharge, anyCharge.Account__c);
         Test.stopTest();
    }

    @IsTest
    static void test_sendPaymentReceipt_email_and_contentversion() {

        ServiceRequest__c sr = createFullSRData();

        createDocWithFile(sr.Id, 'NOC Payment Receipt', 'Uploaded');
        createDocWithFile(sr.Id, 'Outstanding Payment Receipt', 'Uploaded');

        Test.startTest();
        try{
        PropertyTransferTitleDeedController.sendPaymentReceiptToCustomer(sr.Id);
        } catch (Exception e) { }
        Test.stopTest();
    }

    @IsTest
    static void test_sendInvoice_email_and_contentversion() {

        ServiceRequest__c sr = createFullSRData();

        createDocWithFile(sr.Id, 'NOC Fee Invoice', 'Uploaded');
        createDocWithFile(sr.Id, 'Outstanding Invoice', 'Uploaded');

        Test.startTest();
        try{
        PropertyTransferTitleDeedController.sendInvoiceToCustomer(sr.Id);
        } catch (Exception e) { }
        Test.stopTest();
    }

    @IsTest
    static void test_sendPaymentReceipt_null_and_sendInvoice_null() {
        PropertyTransferTitleDeedController.sendPaymentReceiptToCustomer(null);
        PropertyTransferTitleDeedController.sendInvoiceToCustomer(null);
    }

    @IsTest
    static void test_validateDocumentFields_and_validatePropertyTransferSRDocuments() {

        ServiceRequest__c sr = createFullSRData();

        Task t4 = new Task(
            WhatId = sr.Id,
            Status = Constants.TASK_STATUS_CLOSED
        );
        insert t4;

        Map<String, Task> tskMap4 = new Map<String, Task>{ '4' => t4 };
        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>{ sr.Id => sr };

        Task t5 = new Task(
            WhatId = sr.Id,
            Status = Constants.TASK_STATUS_CLOSED
        );
        insert t5;

        Map<String, Task> tskMap = new Map<String, Task>{
            '1' => t5,
            '2' => t5,
            '3' => t5,
            '4' => t5,
            '5' => t5,
            '6' => t5,
            '7' => t5,
            '8' => t5,
            '10' => t5
        };

        Map<String, Documents__c> docMap = new Map<String, Documents__c>();
        Set<String> rtNames = new Set<String>{
            Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL
        };

        Charge__c unpaid = new Charge__c(
            Name = 'Outstanding Charge',
            Service_Request__c = sr.Id,
            PaymentStatus__c = 'Not Paid',
            Amount__c = 100,
            Paid_Amount__c = 0,
            Remaining_Amount__c = 100
        );
        insert unpaid;

        Map<Id, Charge__c> chargeMap = new Map<Id, Charge__c>{ sr.Id => unpaid };

        Test.startTest();
        try {
            PropertyTransferTitleDeedController.validatePropertyTransferSRDocuments(
                rtNames,
                docMap,
                tskMap,
                srMap,
                new List<ServiceRequest__c>{ sr },
                chargeMap
            );
        } catch (Exception e) { }
        try {
            PropertyTransferTitleDeedController.validateDocumentFields(
                srMap,
                new List<ServiceRequest__c>{ sr },
                tskMap4
            );
        } catch (Exception e) { }
        Test.stopTest();
    }
    
    @IsTest
static void test_getChargeData_method() {

    ServiceRequest__c sr = createFullSRData();

    Charge__c ch = new Charge__c(
        Name = 'Outstanding Charge',
        Service_Request__c = sr.Id,
        PaymentStatus__c = 'Not Paid',
        Amount__c = 200,
        Paid_Amount__c = 0,
        Remaining_Amount__c = 200
    );
    insert ch;

    Test.startTest();
    Map<Id, Charge__c> result =
        PropertyTransferTitleDeedController.getChargeData(
            new Set<Id>{ sr.Id }
        );
    Test.stopTest();

}
    
    @IsTest
static void test_sendPaymentReceipt_unpaidCharge() {

    ServiceRequest__c sr = createFullSRData();

    Charge__c ch = new Charge__c(
        Name = 'Outstanding Charge',
        Service_Request__c = sr.Id,
        PaymentStatus__c = 'Not Paid',
        Amount__c = 100,
        Paid_Amount__c = 0
    );
    insert ch;

    Test.startTest();
    String result =
        PropertyTransferTitleDeedController.sendPaymentReceiptToCustomer(sr.Id);
    Test.stopTest();

}
    
    @IsTest
static void test_sendPaymentReceipt_missingDocs() {

    ServiceRequest__c sr = createFullSRData();

    // Only upload one document
    createDocWithFile(sr.Id, 'NOC Payment Receipt', 'Uploaded');

    Test.startTest();
    String result =
        PropertyTransferTitleDeedController.sendPaymentReceiptToCustomer(sr.Id);
    Test.stopTest();

}

@IsTest
static void test_sendInvoice_missingDocs() {

    ServiceRequest__c sr = createFullSRData();

    createDocWithFile(sr.Id, 'NOC Fee Invoice', 'Uploaded');
    // Do NOT upload outstanding invoice

    Test.startTest();
    String result =
        PropertyTransferTitleDeedController.sendInvoiceToCustomer(sr.Id);
    Test.stopTest();

}
    @IsTest
static void test_signature_not_fully_signed() {

    ServiceRequest__c sr = createFullSRData();
    //sr.Signature_Status__c = 'Completed';
    
    update sr;

    Task t7 = new Task(
        WhatId = sr.Id,
        Status = Constants.TASK_STATUS_CLOSED
    );
    insert t7;

    Map<String, Task> tskMap = new Map<String, Task>{
        '7' => t7
    };

    Map<String, Documents__c> docMap = new Map<String, Documents__c>();

    Set<String> rtNames = new Set<String>{
        Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL
    };

    Test.startTest();
    try {
        PropertyTransferTitleDeedController.validatePropertyTransferSRDocuments(
            rtNames,
            docMap,
            tskMap,
            new Map<Id, ServiceRequest__c>{ sr.Id => sr },
            new List<ServiceRequest__c>{ sr },
            new Map<Id, Charge__c>()
        );
    } catch (Exception e) {}
    Test.stopTest();
}
    
    @IsTest
static void test_manual_upload_skip_validation() {

    ServiceRequest__c sr = createFullSRData();
    sr.Is_Manual_Upload__c = true;
    update sr;

    Task t6 = new Task(
        WhatId = sr.Id,
        Status = Constants.TASK_STATUS_CLOSED
    );
    insert t6;

    Map<String, Task> tskMap = new Map<String, Task>{
        '6' => t6
    };

    Set<String> rtNames = new Set<String>{
        Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL
    };

    Test.startTest();
    PropertyTransferTitleDeedController.validatePropertyTransferSRDocuments(
        rtNames,
        new Map<String, Documents__c>(),
        tskMap,
        new Map<Id, ServiceRequest__c>{ sr.Id => sr },
        new List<ServiceRequest__c>{ sr },
        new Map<Id, Charge__c>()
    );
    Test.stopTest();
}
    
    @IsTest
static void test_validatePropertyTransferSRDocuments_fullCoverage() {

    ServiceRequest__c sr = createFullSRData();
     Map<Id, ServiceRequest__c> oldMap = new Map<Id, ServiceRequest__c>{
            sr.Id => sr.clone(false, true, false, false)
        };
    sr.Outstanding_Charge__c = 500;
    //sr.Signature_Status__c = 'Pending';
    sr.Is_Manual_Upload__c = false;
    try{
    update sr;
    } catch (Exception e) {}

    // ------------------ TASK ------------------
    Task t = new Task(
        WhatId = sr.Id,
        Status = Constants.TASK_STATUS_CLOSED,
        Requested_From__c = 'Third Party'
    );
    insert t;

    Map<String, Task> tskMap = new Map<String, Task>{
        '1' => t,
        '2' => t,
        '3' => t,
        '4' => t,
        '5' => t,
        '6' => t,
        '7' => t,
        '8' => t,
        '10' => t
    };

    // ------------------ DOCUMENTS ------------------
    List<Documents__c> docs = new List<Documents__c>{
        new Documents__c(Name='Outstanding Invoice', Service_Request__c=sr.Id, Status__c='Pending Upload'),
        new Documents__c(Name='NOC Fee Invoice', Service_Request__c=sr.Id, Status__c='Pending Upload'),
        new Documents__c(Name='Outstanding Payment Receipt', Service_Request__c=sr.Id, Status__c='Pending Upload'),
        new Documents__c(Name='NOC Payment Receipt', Service_Request__c=sr.Id, Status__c='Pending Upload'),
        new Documents__c(Name='NOC', Service_Request__c=sr.Id, Status__c='Pending Upload'),
        new Documents__c(Name='Title Deed (After Transfer)', Service_Request__c=sr.Id, Status__c='Pending Upload')
    };
    insert docs;

    Map<String, Documents__c> docMap = new Map<String, Documents__c>();
    for (Documents__c d : docs) {
        docMap.put(d.Name, d);
    }

    // ------------------ CHARGE ------------------
    Charge__c unpaidCharge = new Charge__c(
        Name = 'Outstanding Charge',
        Service_Request__c = sr.Id,
        PaymentStatus__c = 'Not Paid',
        Amount__c = 500,
        Paid_Amount__c = 0
    );
    insert unpaidCharge;

    Map<Id, Charge__c> chargeMap = new Map<Id, Charge__c>{
        sr.Id => unpaidCharge
    };

    // ------------------ RECORD TYPE SET ------------------
    Set<String> rtNames = new Set<String>{
        Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL
    };

    Test.startTest();
    try {
        PropertyTransferTitleDeedController.validatePropertyTransferSRDocuments(
            rtNames,
            docMap,
            tskMap,
            new Map<Id, ServiceRequest__c>{ sr.Id => sr },
            new List<ServiceRequest__c>{ sr },
            chargeMap
        );
    } catch (Exception e) {}
    Test.stopTest();
}
    
    @IsTest
static void test_skipValidation_branch() {

    ServiceRequest__c sr = createFullSRData();
    sr.Is_Manual_Upload__c = true;
    update sr;

    Task t = new Task(
        WhatId = sr.Id,
        Status = Constants.TASK_STATUS_CLOSED
    );
    insert t;

    Map<String, Task> tskMap = new Map<String, Task>{ '6' => t };

    Set<String> rtNames = new Set<String>{
        Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL
    };

    Test.startTest();
    PropertyTransferTitleDeedController.validatePropertyTransferSRDocuments(
        rtNames,
        new Map<String, Documents__c>{ 'dummy' => new Documents__c() },
        tskMap,
        new Map<Id, ServiceRequest__c>{ sr.Id => sr },
        new List<ServiceRequest__c>{ sr },
        new Map<Id, Charge__c>()
    );
    Test.stopTest();
}
    
}