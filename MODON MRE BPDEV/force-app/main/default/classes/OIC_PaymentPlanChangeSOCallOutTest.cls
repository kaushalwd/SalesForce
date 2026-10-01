@IsTest
private class OIC_PaymentPlanChangeSOCallOutTest {
    
    @IsTest
    static void testCreateSalesOrders() {
        
        Id personRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        
        Id InvoiceCreditMemo = Schema.SObjectType.Invoice__c.getRecordTypeInfosByDeveloperName()
            .get('Credit_Memo').getRecordTypeId(); 
        
        Id receiptRTId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Receipt__c'
            AND Name = 'Receipt'
            LIMIT 1
        ].Id;
        
        // ── Project / Phase / Unit ────────────────────────────────────
        Project__c project = new Project__c(
            Name = 'Test Project'
        );
        insert project;
        
        Phase__c phase = new Phase__c(
            Name = 'Phase 1',
            Project__c = project.Id,
            EntityName__c = 'Modon Properties PJSC'
        );
        insert phase;
        
        Unit__c unitRec = new Unit__c(
            Phase__c              = phase.Id,
            PlotAreasqm__c        = 1.0,
            PlotNo__c             = '1',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2'
            //Name                  = 'TestUnit',
            //Project_Name__c       = 'Test Project'
        );
        insert unitRec;
        
        // ── Person Account ────────────────────────────────────────────
        Account personAcc = new Account(
            RecordTypeId       = personRTId,
            PersonEmail        = 'test@example.com',
            FirstName          = 'Test',
            LastName           = 'User',
            Swift_Code__c      = '123456',
            OraclePartyId__c   = 'PARTY-001',
            Bank_Name__c       = 'Test Bank',
            Beneficiary_Name__c = 'Test User',
            Bank_Account_Number__c = '123456789',
            IBAN_Number__c     = 'AE000000000000000000000'
            // Name = 'Test User'
        );
        insert personAcc;
        
        // ── Contact / Opportunity / EOI ───────────────────────────────
        Contact conObj = new Contact(
            LastName = 'Test Contact',
            Email    = 'test@test.com'
        );
        insert conObj;
        
        Opportunity oppObj = new Opportunity(
            Name                    = 'Test opportunity',
            StageName               = 'Discussion In Progress',
            CloseDate               = System.today(),
            PrimaryContact__c       = conObj.Id,
            Nationality__c          = 'Egypt',
            AccountId               = personAcc.Id,
            UAE_Resident_Status__c  = 'Resident',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c            = '784-1232-1234567-4',
            En_Nationality__c       = 'India',
            En_PassportNumber__c    = 'P1234567',
            En_EIDNumber__c         = '784-1232-1234567-4'
        );
        insert oppObj;
        
        Expressionofinterest__c eoiObj = new Expressionofinterest__c(
            Opportunity__c = oppObj.Id
        );
        insert eoiObj;
        
        // ── Escrow / Virtual Account ──────────────────────────────────
        EscrowAccount__c escrowAcc = new EscrowAccount__c(
            Name              = 'Escrow 1',
            AccountNumber__c  = 'ESC-001',
            IBANNo__c         = 'AEESCROW0000000000001',
            StoreId__c        = 'STORE-001',
            SwiftCode__c      = 'SWIFT001',
            TradeID__c        = 'TRADE001',
            BankName__c       = 'Escrow Bank',
            BeneficiaryName__c = 'Escrow Beneficiary'
        );
        insert escrowAcc;
        
        VirtualAccount__c virtualAcc = new VirtualAccount__c(
            Name                   = 'VA 1',
            EscrowAccount__c       = escrowAcc.Id,
            VirtualAccountNumber__c = 'VA-001',
            VirtualIBANNumber__c    = 'AEVA000000000000000001'
        );
        insert virtualAcc;
        
        // ── Sales Order / SOI ─────────────────────────────────────────
        SalesOrder__c soUAE = new SalesOrder__c(
            //Name                    = 'SO-UAE-001',
            TotalAmount__c          = 200,
            Source_Entity__c        = 'Modon - UAE',
            Status__c               = 'Completed',
            Unit__c                 = unitRec.Id,
            VirtualAccount__c       = virtualAcc.Id,
            //NotToBeShownOnRD__c     = false,
            OraclePartySiteID__c    = 'SITE-001',
            OracleCustAcctSiteID__c = 'ACCTSITE-001',
            OracleSiteUseID__c      = 'SITEUSE-001',
            CustAcctId__c           = 'CUST-001'
        );
        insert soUAE;
        
        // Prepare invocable request
        OIC_PaymentPlanChangeSOCallOut.Request req =
            new OIC_PaymentPlanChangeSOCallOut.Request();
        req.recordId = soUAE.Id;
        
        Test.startTest();
        
        OIC_PaymentPlanChangeSOCallOut.createSalesOrders(
            new List<OIC_PaymentPlanChangeSOCallOut.Request>{ req }
        );
        
        Test.stopTest();
        
        // Verify Queueable job was created
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, JobType
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
        ];
    }
    
    @IsTest
    static void testCreateSalesOrders_EmptyRequest() {
        
        Test.startTest();
        
        OIC_PaymentPlanChangeSOCallOut.createSalesOrders(
            new List<OIC_PaymentPlanChangeSOCallOut.Request>()
        );
        
        Test.stopTest();
        
        List<AsyncApexJob> jobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
        ];
        
        System.assertEquals(
            0,
            jobs.size(),
            'No Queueable job should be created for an empty request.'
        );
    }
}