/**
* @description       : 
* @author            : Krishna Chaitanya
* @group             : 
* @last modified on  : 06-20-2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Krishna                   06-20-2025     Initial Draft       
* 3.0           Manoj                     04-01-2026     Call methods for code coverage
***********************************************************************************************************************/
@isTest
public class PropertyTransferProcessControllerTest {
    @isTest  
    static void testGetProspectAccounts() {
        
        // Test Data
        // Create Test Account
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
        ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = testSalesOrder.Id
        );
        insert testServiceRequest;
        Id accountRtId = Schema.SObjectType.Prospect_Account__c
            .getRecordTypeInfosByDeveloperName()
            .get('Account')
            .getRecordTypeId();
        Prospect_Account__c prospect1 = new Prospect_Account__c(
            RecordTypeId = accountRtId,
            Account_Name__c = 'Test Business Account',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            EIDNumber__c ='784-1234-1234567-1',
            EmiratesIDExpiryDate__c  = Date.today(),
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'UAE',
            State__c = 'Abu Dhabi',
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            PostalCode__c = '00000',
            IsPersonAccount__c = false
        );
        Insert prospect1 ; 
        
        
        Test.startTest();
        
        // Call the method under test
        List<Prospect_Account__c> results = PropertyTransferProcessController.getProspectAccounts(testServiceRequest.Id);
       
        Test.stopTest();
        
    }
    
    @isTest
    static void testCreateAccounts() {
        Test.startTest();
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create Test Opportunity
        Opportunity testOpportunity = new Opportunity(Name = 'Test Opportunity', StageName = 'Qualification', CloseDate = Date.today(),UAE_Resident_Status__c = 'Resident',Nationality__c = 'United Arab Emirates',EmiratesIDExpiryDate__c = Date.today().addDays(365),EIDNumber__c='784-1232-1234567-4');
        
        insert testOpportunity;
        
        // Create Test Sales Order
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            CustomerAccount__c = testAccount.Id,
            Opportunity__c = testOpportunity.Id,
            Status__c = 'Completed'
        );
        insert testSalesOrder;
        
        
        ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = testSalesOrder.Id
        );
        insert testServiceRequest;
        
        Id brokerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();
        Id orgAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization Account').getRecordTypeId();
        Id personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Id contactRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Contact').getRecordTypeId();
        
        
        // Scenario 1: New Business Account
        Prospect_Account__c prospect1 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  accountRecordTypeId,
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            EIDNumber__c ='784-1234-1234567-1',
            EmiratesIDExpiryDate__c  =Date.today(),
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            
            PostalCode__c = '00000'
        );
        
        // Scenario 2: New Person Account
        Prospect_Account__c prospect2 = new Prospect_Account__c(
            Title__c = 'Mr.',
            RecordTypeId = contactRecordTypeId,
            Account_Type__c = 'Broker Agency',
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Middle_Name__c = 'A',
            IsPersonAccount__c = true,
            Birthdate__c = Date.today().addYears(-30),
            Email__c = 'john.doe@test.com',
            Mobile__c = '9876543210',
            Country__c = 'United Arab Emirates',
            City__c = 'Dubai',
            Street__c = 'Street 2',
            PostalCode__c = '11111',
            Description__c = 'Test Person Account',
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            profileId__c = '67890',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Business',
            OtherSourceOfIncome__c = 'Stocks',
            EIDNumber__c ='784-1234-1234567-1',
            EmiratesIDExpiryDate__c  =Date.today(),
            TradeLicenseExpiryDate__c = null,
            UAE_Resident_Status__c = 'Non-Resident',
            UAEVATRegisterNumber__c = 'VAT67890',
            UnifiedNumber__c = 'UN67890',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'None',
            Service_Request__c = testServiceRequest.Id,
            IsTheBusinessEntityRealBeneficiary__c = false,
            NoOfPropertyPurchasedWithModon__c = 2
        );
        
        // Insert Prospect Accounts
        insert new List<Prospect_Account__c>{prospect1};
            
            // **Step 3: Execute Method**
            List<Prospect_Account__c> prospectList = [SELECT Id, Account__c,Account_Type__c,Birthdate__c,City__c,Country__c,CreatedById,DateOfEstablishment__c,
                                                      DeliveryChannel__c,Description__c,Email__c,EIDNumber__c,EmployerBusinessName__c,First_Name__c,Full_Name__c,
                                                      IsPersonAccount__c,Is_Primary__c,IsTheBusinessEntityRealBeneficiary__c,LastModifiedById,Last_Name__c,LegalStructure__c,
                                                      MailingAddress__c,Middle_Name__c,Mobile__c,Nationality__c,NoOfPropertyPurchasedWithModon__c,Occupation__c,
                                                      OtherLegalStructure__c,OtherSourceOfIncome__c,OwnershipPercentage__c,Prospect_Account__c,JO_Deleted__c,Account_Name__c,
                                                      PassfortApprovalStatus__c,PassfortComment__c,profileId__c,PassfortRiskStatus__c,PassportNumber__c,SR_Joint_Owner__c,
                                                      PaymentMethod__c,PostalCode__c,ProfileUpdateTime__c,Name,PurposeOfTransaction__c,RelationshipSubType__c,
                                                      RelationshipType__c,Title__c,Service_Request__c,SourceOfIncome__c,State__c,Street__c,TradeLicenseExpiryDate__c,
                                                      UAE_Resident_Status__c,UAEVATRegisterNumber__c,UnifiedNumber__c,RecordTypeId FROM Prospect_Account__c];
        
        List<Account> createdAccounts = PropertyTransferProcessController.createAccounts(prospectList);
        
        // Insert created accounts (simulating real behavior)
        insert createdAccounts;
        
        Test.stopTest();
        
        // **Step 4: Assertions**
        
        // Verify accounts were inserted
        //System.assertEquals(2, createdAccounts.size(), 'Two new accounts should be created.');
        
        // Verify Business Account
        // Account businessAccount = [SELECT Id, Name, RecordTypeId FROM Account WHERE Name = :prospect1.Account_Name__c LIMIT 1];
        //System.assertNotEquals(null, businessAccount, 'Business account should be created.');
        // System.assertEquals(accountRecordTypeId, businessAccount.RecordTypeId, 'Business account should have correct RecordTypeId.');
        
        // Verify Person Account
        // Account personAccount = [SELECT Id, FirstName, LastName, RecordTypeId FROM Account WHERE FirstName = :prospect2.First_Name__c AND LastName = :prospect2.Last_Name__c LIMIT 1];
        // System.assertNotEquals(null, personAccount, 'Person account should be created.');
        // System.assertEquals(personAccRecordTypeId, personAccount.RecordTypeId, 'Person account should have correct RecordTypeId.');
    }
    
    
    @isTest
    static void testCreateAccounts2(){
        Project__c project = new Project__c();
        insert project;
        
        //Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Service Request Management -Property Transfer OffPlan').getRecordTypeId();
        Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Property Transfer OffPlan').getRecordTypeId();
        
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        
        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name = 'Test account';
        vaObj.Status__c = 'Available';
        vaObj.EscrowAccount__c = escAccount.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c = 'AE3456789456789';
        INSERT vaObj;
        string options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Exterior","picklistApiName":"Exterior__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Interior","picklistApiName":"Interior__c"}]';
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        phase.EscrowAccount__c =escAccount.id;
        phase.PhaseOptions__c =options;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.Status__c = 'Available';
        unit.BlockedFor__c = UserInfo.getUserId();
        unit.BlockedBy__c = UserInfo.getUserId();
        unit.UnitClassification__c='Villa';
        unit.Number_of_Bedrooms__c='9';
        insert unit;
        
        Unit_Option__c unitOp = new Unit_Option__c();
        unitOp.Phase__c = phase.Id;
        unitOp.PlotAreasqm__c = 1.0;
        unitOp.PlotNo__c = '1';
        unitOp.Unit__c =unit.id;
        insert unitOp;
        
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        
        Account personAcc = new Account(
            RecordTypeId = personRtId,
            FirstName = 'Primary',
            LastName = 'User'
        );
        insert personAcc;
        
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        paymentPlan.Status__c = 'Active';
        paymentPlan.StartDate__c = system.today().addDays(-2);
        paymentPlan.ExpiryDate__c = system.today().addDays(5);
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.today().addDays(365);
        oppObj.EIDNumber__c='784-1232-1234567-4';
        INSERT oppObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.VirtualAccount__c = vaObj.Id;
        so.CustomerAccount__c = acc.Id;
        so.Status__c='Completed';
        so.TotalAmount__c = 20000;
        insert so;
        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = acc.Id;
        recObj.EBS_Clearing_Date__c = Date.today()+ 15;
        recObj.SalesOrder__c = so.Id;
        recObj.PaymentEscrowAccount__c = escAccount.Id;
        recObj.Status__c='Cleared';
        insert recObj;
        SalesOrderInstallments__c sotest = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            PaymentInstallments__c = installment.id,
            InstallmentAmount__c = 150
        );
        insert sotest;
        Invoice__c invoice = new Invoice__c();
        invoice.InvoiceAmount__c = 150;
        invoice.SalesOrderInstallment__c =sotest.Id ;
        //invoice.AppliedAmount__c = 50;
        invoice.Account__c = acc.Id;
        insert invoice;
        Allocation__c allocationObj = new Allocation__c();
        allocationObj.Invoice__c = invoice.Id;
        allocationObj.AllocationAmount__c = 150;
        allocationObj.Status__c = 'Applied';
        allocationObj.Receipt__c = recObj.Id;
        //allocationObj.OICIntegrationStatus__c= 'Success';
        INSERT allocationObj;
        
        
        ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            type__c = 'Normal',
            recordtypeId = SRPTRecordTypeId
        );
        insert testServiceRequest;
        
        Id brokerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();
        Id orgAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization Account').getRecordTypeId();
        Id personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Id contactRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Contact').getRecordTypeId();
        
        Id contactRtId = Schema.SObjectType.Prospect_Account__c
            .getRecordTypeInfosByDeveloperName()
            .get('Contact')
            .getRecordTypeId();
        
        Prospect_Account__c prospect1 = new Prospect_Account__c(
            RecordTypeId = contactRtId,
            // RecordTypeName__c = 'Contact',
            IsPersonAccount__c = true,
            Account__c = personAcc.Id,
            Is_Primary__c = true,
            OwnershipPercentage__c = 100,
            Service_Request__c = testServiceRequest.Id
        );
        insert prospect1;
        //List<Account> createdAccounts = PropertyTransferProcessController.createAccounts(newt);
        
        PropertyTransferProcessController.executePropertyExecutionsFlow(testServiceRequest.Id);
        Test.StartTest();
        PropertyTransferProcessController.executePropertyExecutionsFlowstep1(testServiceRequest.Id);
        PropertyTransferProcessController.executePropertyExecutionsFlowstep2(testServiceRequest.Id);
        Test.StopTest();
    }
    
    
    @isTest
    static void testCreateAccounts1(){
        Project__c project = new Project__c();
        insert project;
        
        //Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Service Request Management -Property Transfer OffPlan').getRecordTypeId();
        Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Property Transfer OffPlan').getRecordTypeId();
        
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        
        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name = 'Test account';
        vaObj.Status__c = 'Available';
        vaObj.EscrowAccount__c = escAccount.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c = 'AE3456789456789';
        INSERT vaObj;
        string options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Exterior","picklistApiName":"Exterior__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Interior","picklistApiName":"Interior__c"}]';
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        phase.EscrowAccount__c =escAccount.id;
        phase.PhaseOptions__c =options;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.Status__c = 'Available';
        unit.BlockedFor__c = UserInfo.getUserId();
        unit.BlockedBy__c = UserInfo.getUserId();
        unit.UnitClassification__c='Villa';
        unit.Number_of_Bedrooms__c='9';
        insert unit;
        
        Unit_Option__c unitOp = new Unit_Option__c();
        unitOp.Phase__c = phase.Id;
        unitOp.PlotAreasqm__c = 1.0;
        unitOp.PlotNo__c = '1';
        unitOp.Unit__c =unit.id;
        insert unitOp;
        
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        
        Account acc2 = new Account(Name = 'Second Account');
        insert acc2;
        
        Account joAcc = new Account(Name = 'JO Account');
        insert joAcc;
        
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        paymentPlan.Status__c = 'Active';
        paymentPlan.StartDate__c = system.today().addDays(-2);
        paymentPlan.ExpiryDate__c = system.today().addDays(5);
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.today().addDays(365);
        oppObj.EIDNumber__c='784-1232-1234567-4';
        INSERT oppObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.VirtualAccount__c = vaObj.Id;
        so.CustomerAccount__c = acc.Id;
        so.TotalAmount__c = 20000;
        so.Status__c='Completed';
        insert so;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.SalesOrder__c = so.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        SalesOrderInstallments__c sotest = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            PaymentInstallments__c = installment.id,
            InstallmentAmount__c = 150
        );
        insert sotest;
        
        ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            type__c = 'Normal',
            recordtypeId = SRPTRecordTypeId
        );
        insert testServiceRequest;
        
        Id brokerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();
        Id orgAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization Account').getRecordTypeId();
        Id personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Id contactRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Contact').getRecordTypeId();
        
        List<Prospect_Account__c> newt=  new List<Prospect_Account__c>();
        // Scenario 1: New Business Account
        Prospect_Account__c prospect1 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            Account__c = acc.Id,
            RecordTypeId    = accountRecordTypeId ,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            EmiratesIDExpiryDate__c = Date.today(),
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            EIDNumber__c ='784-1234-1234567-1',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'UAE',
            State__c = 'Abu Dhabi',
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            IsPersonAccount__c =True,
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000',
            Is_Primary__c = true
        );
        
        // Scenario 2: New Person Account
        Prospect_Account__c prospect2 = new Prospect_Account__c(
            Title__c = 'Mr.',
            RecordTypeId = accountRecordTypeId,
            Account__c = joAcc.Id,
            Account_Type__c = 'Broker Agency',
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Middle_Name__c = 'A',
            OwnershipPercentage__c = 50,
            IsPersonAccount__c = true,
            Birthdate__c = Date.today().addYears(-30),
            Email__c = 'john.doe@test.com',
            Mobile__c = '+971525612345',
            Is_Primary__c =true,
            Country__c = 'UAE',
            State__c = 'Dubai',
            City__c = 'Dubai',
            Street__c = 'Street 2',
            PostalCode__c = '11111',
            Description__c = 'Test Person Account',
            EmiratesIDExpiryDate__c = Date.today(),
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            profileId__c = '67890',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Business',
            EIDNumber__c ='784-1234-1234567-1',
            OtherSourceOfIncome__c = 'Stocks',
            TradeLicenseExpiryDate__c = null,
            UAE_Resident_Status__c = 'Non-Resident',
            UAEVATRegisterNumber__c = 'VAT67890',
            UnifiedNumber__c = 'UN67890',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'None',
            Service_Request__c = testServiceRequest.Id,
            RelationshipSubType__c='Friend',
            IsTheBusinessEntityRealBeneficiary__c = false,
            NoOfPropertyPurchasedWithModon__c = 2
        );
        newt.add(prospect1);
        newt.add(prospect2);
        // Insert Prospect Accounts
        insert newt;
        
        //List<Account> createdAccounts = PropertyTransferProcessController.createAccounts(newt);
        
        PropertyTransferProcessController.processServiceRequestJo(testServiceRequest.Id);
        
    } 
    
    @isTest
    static void testCreateAccounts4(){
        
        Project__c project = new Project__c();
        insert project;
        
        //Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Service Request Management -Property Transfer OffPlan').getRecordTypeId();
        Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Property Transfer OffPlan').getRecordTypeId();
        
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        
        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name = 'Test account';
        vaObj.Status__c = 'Available';
        vaObj.EscrowAccount__c = escAccount.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c = 'AE3456789456789';
        INSERT vaObj;
        string options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Exterior","picklistApiName":"Exterior__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Interior","picklistApiName":"Interior__c"}]';
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        phase.EscrowAccount__c =escAccount.id;
        phase.PhaseOptions__c =options;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.Status__c = 'Available';
        unit.BlockedFor__c = UserInfo.getUserId();
        unit.BlockedBy__c = UserInfo.getUserId();
        unit.UnitClassification__c='Villa';
        unit.Number_of_Bedrooms__c='9';
        insert unit;
        
        Unit_Option__c unitOp = new Unit_Option__c();
        unitOp.Phase__c = phase.Id;
        unitOp.PlotAreasqm__c = 1.0;
        unitOp.PlotNo__c = '1';
        unitOp.Unit__c =unit.id;
        insert unitOp;
        
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        
        
        //insert so;
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        paymentPlan.Status__c = 'Active';
        paymentPlan.StartDate__c = system.today().addDays(-2);
        paymentPlan.ExpiryDate__c = system.today().addDays(5);
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.today().addDays(365);
        oppObj.EIDNumber__c='784-1232-1234567-4';
        INSERT oppObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.VirtualAccount__c = vaObj.Id;
        so.CustomerAccount__c = acc.Id;
        so.Status__c = 'Completed';
        so.TotalAmount__c = 20000;
        insert so;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.SalesOrder__c = so.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        SalesOrderInstallments__c sotest = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            PaymentInstallments__c = installment.id,
            InstallmentAmount__c = 150
        );
        insert sotest;
        Invoice__c inv = new Invoice__c();
        inv.Account__c = acc.Id;
        inv.Sales_Order__c=so.Id;
        insert inv;
        
        Receipt__c rec = new Receipt__c();
        rec.Account__c = acc.Id;
        rec.Status__c = 'In Progress';
        insert rec;
        
        
        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        insert alloc;
        ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            type__c = 'Normal',
            recordtypeId = SRPTRecordTypeId
        );
        insert testServiceRequest;
        
        Id brokerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();
        Id orgAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization Account').getRecordTypeId();
        Id personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Id contactRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Contact').getRecordTypeId();
        
        List<Prospect_Account__c> newt=  new List<Prospect_Account__c>();
        // Scenario 1: New Business Account
        Prospect_Account__c prospect1 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            EmiratesIDExpiryDate__c = Date.today(),
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            EIDNumber__c ='784-1234-1234567-1',
            OwnershipPercentage__c = 50,
            IsPersonAccount__c =false,
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        
        Prospect_Account__c prospect3 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            EmiratesIDExpiryDate__c = Date.today(),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            EIDNumber__c ='784-1234-1234567-1',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        insert prospect3;
        Prospect_Account__c prospect4 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            IsPersonAccount__c = false,
            Prospect_Account__c= prospect3.Id,
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            EIDNumber__c ='784-1234-1234567-1',
            EmiratesIDExpiryDate__c = Date.today(),
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        insert prospect4;
        // Scenario 2: New Person Account
        Prospect_Account__c prospect2 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            Title__c = 'Mr.',
            RecordTypeId = accountRecordTypeId,
            Account_Type__c = 'Broker Agency',
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Middle_Name__c = 'A',
            OwnershipPercentage__c = 50,
            IsPersonAccount__c = false,
            Birthdate__c = Date.today().addYears(-30),
            Email__c = 'john.doe@test.com',
            Mobile__c = '+971525612345',
            Is_Primary__c =true,
            Country__c = 'United Arab Emirates',
            City__c = 'Dubai',
            Street__c = 'Street 2',
            EIDNumber__c ='784-1234-1234567-1',
            PostalCode__c = '11111',
            Description__c = 'Test Person Account',
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            profileId__c = '67890',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Business',
            OtherSourceOfIncome__c = 'Stocks',
            TradeLicenseExpiryDate__c = null,
            UAE_Resident_Status__c = 'Non-Resident',
            UAEVATRegisterNumber__c = 'VAT67890',
            UnifiedNumber__c = 'UN67890',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'None',
            Service_Request__c = testServiceRequest.Id,
            RelationshipSubType__c='Friend',
            EmiratesIDExpiryDate__c = Date.today(),
            IsTheBusinessEntityRealBeneficiary__c = false,
            NoOfPropertyPurchasedWithModon__c = 2
        );
        newt.add(prospect1);
        newt.add(prospect2);
        // Insert Prospect Accounts
        insert newt;
        
        //List<Account> createdAccounts = PropertyTransferProcessController.createAccounts(newt);
        List<Allocation__c> newtalloc= new List<Allocation__c>();
        newtalloc.add(alloc);
        List<Invoice__c> newtinv= new List<Invoice__c>();
        newtinv.add(inv);
        Test.StartTest();
        PropertyTransferProcessController.processServiceRequestJo(testServiceRequest.Id);
        //PropertyTransferProcessController.UnApplyReceiptApplicationAndValidateSync(testServiceRequest,'Test');
        //PropertyTransferProcessController.unapplyReceiptApplications(newtalloc);
        //PropertyTransferProcessController.createCreditNotes(newtinv,phase.Id);
        
        PropertyTransferProcessController.executePropertyExecutionsFlow(testServiceRequest.Id);
        Test.StopTest();
        
    }
    
    @isTest
    static void testCreateAccounts5(){
        Test.StartTest();
        Project__c project = new Project__c();
        insert project;
        
        //Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Service Request Management -Property Transfer OffPlan').getRecordTypeId();
        Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Property Transfer OffPlan').getRecordTypeId();
        
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        
        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name = 'Test account';
        vaObj.Status__c = 'Available';
        vaObj.EscrowAccount__c = escAccount.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c = 'AE3456789456789';
        INSERT vaObj;
        string options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Exterior","picklistApiName":"Exterior__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Interior","picklistApiName":"Interior__c"}]';
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        phase.EscrowAccount__c =escAccount.id;
        phase.PhaseOptions__c =options;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.Status__c = 'Available';
        unit.BlockedFor__c = UserInfo.getUserId();
        unit.BlockedBy__c = UserInfo.getUserId();
        unit.UnitClassification__c='Villa';
        unit.Number_of_Bedrooms__c='9';
        insert unit;
        
        Unit_Option__c unitOp = new Unit_Option__c();
        unitOp.Phase__c = phase.Id;
        unitOp.PlotAreasqm__c = 1.0;
        unitOp.PlotNo__c = '1';
        unitOp.Unit__c =unit.id;
        insert unitOp;
        
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        
        
        //insert so;
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        paymentPlan.Status__c = 'Active';
        paymentPlan.StartDate__c = system.today().addDays(-2);
        paymentPlan.ExpiryDate__c = system.today().addDays(5);
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.today().addDays(365);
        oppObj.EIDNumber__c='784-1232-1234567-4';
        INSERT oppObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.VirtualAccount__c = vaObj.Id;
        so.CustomerAccount__c = acc.Id;
        so.Status__c = 'Completed';
        so.TotalAmount__c = 20000;
        insert so;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.SalesOrder__c = so.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        SalesOrderInstallments__c sotest = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            PaymentInstallments__c = installment.id,
            InstallmentAmount__c = 150
        );
        insert sotest;
        Invoice__c inv = new Invoice__c();
        inv.Account__c = acc.Id;
        inv.Sales_Order__c=so.Id;
        insert inv;
        
        Receipt__c rec = new Receipt__c();
        rec.Account__c = acc.Id;
        rec.Status__c = 'In Progress';
        insert rec;
        
        
        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        insert alloc;
        ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            type__c = 'Normal',
            recordtypeId = SRPTRecordTypeId
        );
        insert testServiceRequest;
        
        Id brokerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();
        Id orgAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization Account').getRecordTypeId();
        Id personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Id contactRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Contact').getRecordTypeId();
        
        List<Prospect_Account__c> newt=  new List<Prospect_Account__c>();
        // Scenario 1: New Business Account
        Prospect_Account__c prospect1 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            EIDNumber__c ='784-1234-1234567-1',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            State__c = 'Abu Dhabi',
            EmiratesIDExpiryDate__c = Date.today(),
            OwnershipPercentage__c = 50,
            IsPersonAccount__c =false,
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        
        Prospect_Account__c prospect3 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            EIDNumber__c ='784-1234-1234567-1',
            EmiratesIDExpiryDate__c = Date.today(),
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            State__c = 'Abu Dhabi',
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        insert prospect3;
        Prospect_Account__c prospect4 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            EmiratesIDExpiryDate__c = Date.today(),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            EIDNumber__c ='784-1234-1234567-1',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            IsPersonAccount__c = false,
            State__c = 'Abu Dhabi',
            Prospect_Account__c= prospect3.Id,
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        insert prospect4;
        // Scenario 2: New Person Account
        Prospect_Account__c prospect2 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            Title__c = 'Mr.',
            RecordTypeId = accountRecordTypeId,
            Account_Type__c = 'Broker Agency',
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Middle_Name__c = 'A',
            OwnershipPercentage__c = 50,
            IsPersonAccount__c = false,
            Birthdate__c = Date.today().addYears(-30),
            Email__c = 'john.doe@test.com',
            Mobile__c = '+971525612345',
            Is_Primary__c =true,
            Country__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today(),
            State__c = 'Dubai',
            City__c = 'Dubai',
            Street__c = 'Street 2',
            EIDNumber__c ='784-1234-1234567-1',
            PostalCode__c = '11111',
            Description__c = 'Test Person Account',
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            profileId__c = '67890',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Business',
            OtherSourceOfIncome__c = 'Stocks',
            TradeLicenseExpiryDate__c = null,
            UAE_Resident_Status__c = 'Non-Resident',
            UAEVATRegisterNumber__c = 'VAT67890',
            UnifiedNumber__c = 'UN67890',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'None',
            Service_Request__c = testServiceRequest.Id,
            RelationshipSubType__c='Friend',
            IsTheBusinessEntityRealBeneficiary__c = false,
            NoOfPropertyPurchasedWithModon__c = 2
        );
        newt.add(prospect1);
        newt.add(prospect2);
        // Insert Prospect Accounts
        insert newt;
        
        //List<Account> createdAccounts = PropertyTransferProcessController.createAccounts(newt);
        List<Allocation__c> newtalloc= new List<Allocation__c>();
        newtalloc.add(alloc);
        List<Invoice__c> newtinv= new List<Invoice__c>();
        newtinv.add(inv);
        //PropertyTransferProcessController.executePropertyExecutionsFlowstep1(testServiceRequest.Id);
        PropertyTransferProcessController.executePropertyExecutionsFlowstep2(testServiceRequest.Id);     
        Test.StopTest();
        
    }
    @isTest
    static void testCreateAccounts6(){
        
        Project__c project = new Project__c();
        insert project;
        
        //Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Service Request Management -Property Transfer OffPlan').getRecordTypeId();
        Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Property Transfer OffPlan').getRecordTypeId();
        
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        
        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name = 'Test account';
        vaObj.Status__c = 'Available';
        vaObj.EscrowAccount__c = escAccount.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c = 'AE3456789456789';
        INSERT vaObj;
        string options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Exterior","picklistApiName":"Exterior__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Interior","picklistApiName":"Interior__c"}]';
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        phase.EscrowAccount__c =escAccount.id;
        phase.PhaseOptions__c =options;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.Status__c = 'Available';
        unit.BlockedFor__c = UserInfo.getUserId();
        unit.BlockedBy__c = UserInfo.getUserId();
        unit.UnitClassification__c='Villa';
        unit.Number_of_Bedrooms__c='9';
        insert unit;
        
        Unit_Option__c unitOp = new Unit_Option__c();
        unitOp.Phase__c = phase.Id;
        unitOp.PlotAreasqm__c = 1.0;
        unitOp.PlotNo__c = '1';
        unitOp.Unit__c =unit.id;
        insert unitOp;
        
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        
        Contact con=new Contact();
        con.AccountId=acc.Id;
        con.LastName='test user';
        con.Email='test@gmail.com';
        con.Phone='9490917878';
        insert con;
        
        //insert so;
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        paymentPlan.Status__c = 'Active';
        paymentPlan.StartDate__c = system.today().addDays(-2);
        paymentPlan.ExpiryDate__c = system.today().addDays(5);
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.today().addDays(365);
        oppObj.EIDNumber__c='784-1232-1234567-4';
        INSERT oppObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.VirtualAccount__c = vaObj.Id;
        so.CustomerAccount__c = acc.Id;
        so.Status__c = 'Completed';
        so.TotalAmount__c = 20000;
        insert so;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.SalesOrder__c = so.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        SalesOrderInstallments__c sotest = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            PaymentInstallments__c = installment.id,
            InstallmentAmount__c = 150
        );
        insert sotest;
        Invoice__c inv = new Invoice__c();
        inv.Account__c = acc.Id;
        inv.Sales_Order__c=so.Id;
        insert inv;
        
        Receipt__c rec = new Receipt__c();
        rec.Account__c = acc.Id;
        rec.Status__c = 'In Progress';
        insert rec;
        
        
        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        insert alloc;
        ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            type__c = 'Normal',
            recordtypeId = SRPTRecordTypeId
        );
        insert testServiceRequest;
        
        Id brokerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();
        Id orgAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization Account').getRecordTypeId();
        Id personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Id contactRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Contact').getRecordTypeId();
        
        List<Prospect_Account__c> newt=  new List<Prospect_Account__c>();
        // Scenario 1: New Business Account
        Prospect_Account__c prospect1 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PassportExpiryDate__c =system.today(),
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            OwnershipPercentage__c = 50,
            EIDNumber__c ='784-1234-1234567-1',
            EmiratesIDExpiryDate__c = Date.today(),
            IsPersonAccount__c =false,
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            Nationality__c= 'United Arab Emirates',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000',
            Account__c=acc.Id,
            Contact__c=con.Id 
        );
        
        Prospect_Account__c prospect3 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            PassportExpiryDate__c=system.today(),
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            EIDNumber__c ='784-1234-1234567-1',
            EmiratesIDExpiryDate__c = Date.today(),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            Nationality__c= 'United Arab Emirates',
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        insert prospect3;
        Prospect_Account__c prospect4 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  contactRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            PassportExpiryDate__c = Date.today().addYears(1),
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            Nationality__c= 'United Arab Emirates',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            IsPersonAccount__c = true,
            EIDNumber__c ='784-1234-1234567-1',
            EmiratesIDExpiryDate__c = Date.today(),
            Prospect_Account__c= prospect3.Id,
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000',
            Account__c=acc.Id,
            Contact__c=con.Id
           
        );
        //insert prospect4;
        // Scenario 2: New Person Account
        Prospect_Account__c prospect2 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            Title__c = 'Mr.',
            RecordTypeId = accountRecordTypeId,
            Account_Type__c = 'Broker Agency',
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Middle_Name__c = 'A',
            OwnershipPercentage__c = 50,
            IsPersonAccount__c = false,
            Birthdate__c = Date.today().addYears(-30),
            Email__c = 'john.doe@test.com',
            Mobile__c = '+971525612345',
            Is_Primary__c =true,
            Country__c = 'United Arab Emirates',
            City__c = 'Dubai',
            Street__c = 'Street 2',
            PassportExpiryDate__c = Date.today().addYears(1),
            PostalCode__c = '11111',
            Description__c = 'Test Person Account',
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            profileId__c = '67890',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Business',
            OtherSourceOfIncome__c = 'Stocks',
            TradeLicenseExpiryDate__c = null,
            UAE_Resident_Status__c = 'Non-Resident',
            UAEVATRegisterNumber__c = 'VAT67890',
            UnifiedNumber__c = 'UN67890',
            PassportNumber__c = 'PAS12345',
            Nationality__c ='United Arab Emirates',
            Passport_Issuance_Date__c = system.today(),
            Passport_Issuance_Place__c = 'UAE',
            EIDNumber__c ='784-1234-1234567-1',
            EmiratesIDExpiryDate__c = Date.today(),
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'None',
            Service_Request__c = testServiceRequest.Id,
            RelationshipSubType__c='Friend',
            IsTheBusinessEntityRealBeneficiary__c = false,
            NoOfPropertyPurchasedWithModon__c = 2
        );
        newt.add(prospect1);
        newt.add(prospect2);
        // Insert Prospect Accounts
        insert newt;
        Test.StartTest();
        //List<Account> createdAccounts = PropertyTransferProcessController.createAccounts(newt);
        List<Allocation__c> newtalloc= new List<Allocation__c>();
        newtalloc.add(alloc);
        List<Invoice__c> newtinv= new List<Invoice__c>();
        newtinv.add(inv);
        PropertyTransferProcessController.ptTitleDeedprocessServiceRequest(testServiceRequest.Id); 
        PropertyTransferProcessController.createContacts(newt, new List<Account>{acc, acc});
        Test.StopTest();
        PropertyTransferProcessController.createContacts(new List<Prospect_Account__c>{prospect4}, new List<Account>{acc});
    }
    @isTest
    static void testCreateAccounts7(){
        
        Project__c project = new Project__c();
        insert project;
        
        //Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Service Request Management -Property Transfer OffPlan').getRecordTypeId();
        Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Property Transfer OffPlan').getRecordTypeId();
        
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        
        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name = 'Test account';
        vaObj.Status__c = 'Available';
        vaObj.EscrowAccount__c = escAccount.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c = 'AE3456789456789';
        INSERT vaObj;
        string options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Exterior","picklistApiName":"Exterior__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Interior","picklistApiName":"Interior__c"}]';
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        phase.EscrowAccount__c =escAccount.id;
        phase.PhaseOptions__c =options;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.Status__c = 'Available';
        unit.BlockedFor__c = UserInfo.getUserId();
        unit.BlockedBy__c = UserInfo.getUserId();
        unit.UnitClassification__c='Villa';
        unit.Number_of_Bedrooms__c='9';
        insert unit;
        
        Unit_Option__c unitOp = new Unit_Option__c();
        unitOp.Phase__c = phase.Id;
        unitOp.PlotAreasqm__c = 1.0;
        unitOp.PlotNo__c = '1';
        unitOp.Unit__c =unit.id;
        insert unitOp;
        
        Account acc = new Account();
        acc.name = 'test account';
        //acc.Nationality__pc = 'United Arab Emirates';
        //acc.PersonBirthdate = Date.newInstance(1985, 12, 8);
        //acc.UAE_Resident_Status__pc = 'Resident';
        //acc.EIDNumber__pc = '784-1985-1234567-1';
        //acc.PassportNumber__pc = 'P1234567';
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Primary',
            Email = 'testprimary@test.com',PassportNumber__c = 'P1234567',Nationality__c = 'United Arab Emirates',EIDNumber__c = '784-1985-1234567-1',UAE_Resident_Status__c = 'Resident',
            EmiratesIDExpiryDate__c = system.today().addDays(5),
            AccountId = acc.Id
        );
        insert con;
        
        //insert so;
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        paymentPlan.Status__c = 'Active';
        paymentPlan.StartDate__c = system.today().addDays(-2);
        paymentPlan.ExpiryDate__c = system.today().addDays(5);
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.today().addDays(365);
        oppObj.EIDNumber__c='784-1232-1234567-4';
        INSERT oppObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.VirtualAccount__c = vaObj.Id;
        so.CustomerAccount__c = acc.Id;
        so.Status__c = 'Completed';
        so.TotalAmount__c = 20000;
        so.Reason__c = 'Unit Swap';
        so.PrimaryContact__c = con.Id; 
        
        insert so;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.SalesOrder__c = so.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        SalesOrderInstallments__c sotest = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            PaymentInstallments__c = installment.id,
            InstallmentAmount__c = 150
        );
        insert sotest;
        Invoice__c inv = new Invoice__c();
        inv.Account__c = acc.Id;
        inv.Sales_Order__c=so.Id;
        insert inv;
        
        Receipt__c rec = new Receipt__c();
        rec.Account__c = acc.Id;
        rec.Status__c = 'In Progress';
        insert rec;
        
        
        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        insert alloc;
        ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            type__c = 'Normal',
            recordtypeId = SRPTRecordTypeId,
            Selected_Unit__c = unit.Id,                
            Selected_Payment_Plan__c = paymentPlan.Id
        );
        insert testServiceRequest;
        
        Id brokerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();
        Id orgAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization Account').getRecordTypeId();
        Id personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Id contactRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Contact').getRecordTypeId();
        
        List<Prospect_Account__c> newt=  new List<Prospect_Account__c>();
        // Scenario 1: New Business Account
        Prospect_Account__c prospect1 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Account__c = null,
            Contact__c = null,
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            EIDNumber__c ='784-1234-1234567-1',
            OtherLegalStructure__c = 'Other',
            EmiratesIDExpiryDate__c = Date.today(),
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            State__c = 'Abu Dhabi',
            OwnershipPercentage__c = 50,
            IsPersonAccount__c =true,
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        
        Prospect_Account__c prospect3 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            EIDNumber__c ='784-1234-1234567-1',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            State__c = 'Abu Dhabi',
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            EmiratesIDExpiryDate__c = Date.today(),
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        insert prospect3;
        Prospect_Account__c prospect4 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId    =  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            EIDNumber__c ='784-1234-1234567-1',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            Account__c = null,
            Contact__c = null,
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            EmiratesIDExpiryDate__c = Date.today(),
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            IsPersonAccount__c = false,
            State__c = 'Abu Dhabi',
            Prospect_Account__c= prospect3.Id,
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        insert prospect4;
        // Scenario 2: New Person Account
        Prospect_Account__c prospect2 = new Prospect_Account__c(
            Title__c = 'Mr.',
            RecordTypeId = accountRecordTypeId,
            Account__c = null,
            Contact__c = null,
            Account_Type__c = 'Broker Agency',
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Middle_Name__c = 'A',
            OwnershipPercentage__c = 50,
            IsPersonAccount__c = false,
            Birthdate__c = Date.today().addYears(-30),
            Email__c = 'john.doe@test.com',
            Mobile__c = '+971525612345',
            Is_Primary__c =true,
            Country__c = 'United Arab Emirates',
            State__c = 'Dubai',
            City__c = 'Dubai',
            Street__c = 'Street 2',
            PostalCode__c = '11111',
            Description__c = 'Test Person Account',
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            profileId__c = '67890',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Business',
            OtherSourceOfIncome__c = 'Stocks',
            EIDNumber__c ='784-1234-1234567-1',
            TradeLicenseExpiryDate__c = null,
            UAE_Resident_Status__c = 'Non-Resident',
            UAEVATRegisterNumber__c = 'VAT67890',
            UnifiedNumber__c = 'UN67890',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'None',
            EmiratesIDExpiryDate__c = Date.today(),
            Service_Request__c = testServiceRequest.Id,
            RelationshipSubType__c='Friend',
            IsTheBusinessEntityRealBeneficiary__c = false,
            NoOfPropertyPurchasedWithModon__c = 2
        );
        // Scenario 2: New Person Account
        Prospect_Account__c prospect31 = new Prospect_Account__c(
            Title__c = 'Mr.',
            RecordTypeId = accountRecordTypeId,
            Account__c = null,
            Contact__c = null,
            Account_Type__c = 'Broker Agency',
            First_Name__c = 'John2',
            Last_Name__c = 'Doe2',
            Middle_Name__c = 'A',
            OwnershipPercentage__c = 50,
            IsPersonAccount__c = true,
            Birthdate__c = Date.today().addYears(-30),
            Email__c = 'john.doe2@test.com',
            Mobile__c = '+971525612342',
            Is_Primary__c =true,
            Country__c = 'United Arab Emirates',
            State__c = 'Dubai',
            City__c = 'Dubai',
            Street__c = 'Street 22',
            PostalCode__c = '111112',
            Description__c = 'Test Person Account2',
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            profileId__c = '67890',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Business',
            OtherSourceOfIncome__c = 'Stocks',
            EIDNumber__c ='784-1234-1234567-1',
            TradeLicenseExpiryDate__c = null,
            UAE_Resident_Status__c = 'Non-Resident',
            UAEVATRegisterNumber__c = 'VAT67890',
            UnifiedNumber__c = 'UN67890',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'None',
            EmiratesIDExpiryDate__c = Date.today(),
            Service_Request__c = testServiceRequest.Id,
            RelationshipSubType__c='Friend',
            IsTheBusinessEntityRealBeneficiary__c = false,
            NoOfPropertyPurchasedWithModon__c = 2
        );
        newt.add(prospect1);
        newt.add(prospect2);
        newt.add(prospect31);
        // Insert Prospect Accounts
        insert newt;
        
        //List<Account> createdAccounts = PropertyTransferProcessController.createAccounts(newt);
        List<Allocation__c> newtalloc= new List<Allocation__c>();
        newtalloc.add(alloc);
        List<Invoice__c> newtinv= new List<Invoice__c>();
        newtinv.add(inv);
        Test.StartTest();
        PropertyTransferProcessController.UpgradeprocessServiceRequest(testServiceRequest.Id);
        
        Test.StopTest();
        
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
        Account__c = acc.Id,
        InvoiceAmount__c = 10000
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

    Test.startTest();
    PropertyTransferProcessController.createDebitNoteApplications(
        invoice,
        new List<Receipt__c>{ r1, r2, r3 }
    );
    Test.stopTest();
}
    
    @isTest
static void testCreateJointOwner() {

    Account acc1 = new Account(Name = 'Primary Account');
    Account acc2 = new Account(Name = 'Secondary Account');
    insert new List<Account>{ acc1, acc2 };

    Opportunity opp = new Opportunity(
        Name = 'Cloned Opp',
        StageName = 'Qualification',
        CloseDate = Date.today()
    );
    insert opp;

   /* SalesOrder__c so = new SalesOrder__c(
        Opportunity__c = opp.Id,
        CustomerAccount__c = acc1.Id,
        Status__c = 'Completed'
    );
    insert so;*/
    
    SalesOrder__c so = new SalesOrder__c();
        //so.Unit__c = unit.Id;
        so.Opportunity__c = opp.Id;
        //so.PaymentPlan__c = paymentPlan.Id;
        //so.VirtualAccount__c = vaObj.Id;
        so.CustomerAccount__c = acc1.Id;
        so.Status__c = 'Completed';
        so.TotalAmount__c = 20000;
        insert so;
    
        Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Property Transfer OffPlan').getRecordTypeId();

ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            type__c = 'Normal',
            recordtypeId = SRPTRecordTypeId
        );
        insert testServiceRequest;
    
    Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();


    Prospect_Account__c prospect1 = new Prospect_Account__c(
        Title__c = 'Mr.',
            RecordTypeId = accountRecordTypeId,
            Account__c = null,
            Contact__c = null,
            Account_Type__c = 'Broker Agency',
        Account_Name__c = 'Test',
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Middle_Name__c = 'A',
            OwnershipPercentage__c = 50,
            IsPersonAccount__c = false,
            Birthdate__c = Date.today().addYears(-30),
            Email__c = 'john.doe@test.com',
            Mobile__c = '+971525612345',
            Is_Primary__c =true,
            Country__c = 'United Arab Emirates',
            State__c = 'Dubai',
            City__c = 'Dubai',
            Street__c = 'Street 2',
            PostalCode__c = '11111',
            Description__c = 'Test Person Account',
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            profileId__c = '67890',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Business',
            OtherSourceOfIncome__c = 'Stocks',
            EIDNumber__c ='784-1234-1234567-1',
            TradeLicenseExpiryDate__c = null,
            UAE_Resident_Status__c = 'Non-Resident',
            UAEVATRegisterNumber__c = 'VAT67890',
            UnifiedNumber__c = 'UN67890',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'None',
            EmiratesIDExpiryDate__c = Date.today(),
            Service_Request__c = testServiceRequest.Id,
            RelationshipSubType__c='Friend',
            IsTheBusinessEntityRealBeneficiary__c = false,
            NoOfPropertyPurchasedWithModon__c = 2
    );
    Prospect_Account__c prospect2 = new Prospect_Account__c(
        Title__c = 'Mr.',
            RecordTypeId = accountRecordTypeId,
            Account__c = null,
            Contact__c = null,
            Account_Type__c = 'Broker Agency',
        Account_Name__c = 'Test',
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Middle_Name__c = 'A',
            OwnershipPercentage__c = 50,
            IsPersonAccount__c = false,
            Birthdate__c = Date.today().addYears(-30),
            Email__c = 'john.doe@test.com',
            Mobile__c = '+971525612345',
            Is_Primary__c =true,
            Country__c = 'United Arab Emirates',
            State__c = 'Dubai',
            City__c = 'Dubai',
            Street__c = 'Street 2',
            PostalCode__c = '11111',
            Description__c = 'Test Person Account',
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            profileId__c = '67890',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Business',
            OtherSourceOfIncome__c = 'Stocks',
            EIDNumber__c ='784-1234-1234567-1',
            TradeLicenseExpiryDate__c = null,
            UAE_Resident_Status__c = 'Non-Resident',
            UAEVATRegisterNumber__c = 'VAT67890',
            UnifiedNumber__c = 'UN67890',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'None',
            EmiratesIDExpiryDate__c = Date.today(),
            Service_Request__c = testServiceRequest.Id,
            RelationshipSubType__c='Friend',
            IsTheBusinessEntityRealBeneficiary__c = false,
            NoOfPropertyPurchasedWithModon__c = 2
    );
    insert new List<Prospect_Account__c>{ prospect1, prospect2 };

    acc1.Prospect_Account__c = prospect1.Id;
    acc2.Prospect_Account__c = prospect2.Id;
    update new List<Account>{ acc1, acc2 };

    Map<Id, Prospect_Account__c> prospectMap = new Map<Id, Prospect_Account__c>{
        prospect1.Id => prospect1,
        prospect2.Id => prospect2
    };

    Test.startTest();
    PropertyTransferProcessController.createJointOwner(
        new List<Account>{ acc1, acc2 },
        opp,
        prospectMap,
        so.Id
    );
    Test.stopTest();
}
    
    @isTest
static void testDeleteExistingJointOwners() {

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

    JointOwner__c jo1 = new JointOwner__c(
        SalesOrder__c = so.Id,
        Opportunity__c = opp.Id,
        JointOwnerAccount__c = acc.Id,
        OwnershipPercentage__c = 50,
        RelationshipType__c = 'Joint Owner P-P',
        RelationshipSubType__c = 'Child'
    );

    JointOwner__c jo2 = new JointOwner__c(
        SalesOrder__c = so.Id,
        Opportunity__c = opp.Id,
        JointOwnerAccount__c = acc.Id,
        OwnershipPercentage__c = 50,
        RelationshipType__c = 'Joint Owner P-P',
        RelationshipSubType__c = 'Child'
    );

    insert new List<JointOwner__c>{ jo1, jo2 };

    Test.startTest();
    PropertyTransferProcessController.deleteExistingJointOwners(so.Id);
    Test.stopTest();

}
    
    @isTest
static void testInsertJointOwnersFromProspects() {

    Account acc1 = new Account(Name = 'Primary Account');
    Account acc2 = new Account(Name = 'Joint Owner Account');
    insert new List<Account>{ acc1, acc2 };

    Opportunity opp = new Opportunity(
        Name = 'Test Opportunity',
        StageName = 'Qualification',
        CloseDate = Date.today()
    );
    insert opp;
    


    SalesOrder__c so = new SalesOrder__c(
        Opportunity__c = opp.Id,
        CustomerAccount__c = acc1.Id,
        Status__c = 'Completed'
    );
    insert so;
    
    Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Property Transfer OffPlan').getRecordTypeId();
    
    ServiceRequest__c testServiceRequest = new ServiceRequest__c(
        SalesOrder__c = so.Id,
        type__c = 'Normal',
        recordtypeId = SRPTRecordTypeId
    );
    insert testServiceRequest;
    
    Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();

    Prospect_Account__c p1 = new Prospect_Account__c(
       Title__c = 'Mr.',
            RecordTypeId = accountRecordTypeId,
             Account__c = acc1.Id, 
            Contact__c = null,
            Account_Type__c = 'Broker Agency',
            Account_Name__c = 'Test',
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Middle_Name__c = 'A',
            OwnershipPercentage__c = 50,
            IsPersonAccount__c = false,
            Birthdate__c = Date.today().addYears(-30),
            Email__c = 'john.doe@test.com',
            Mobile__c = '+971525612345',
            Is_Primary__c =true,
            Country__c = 'United Arab Emirates',
            State__c = 'Dubai',
            City__c = 'Dubai',
            Street__c = 'Street 2',
            PostalCode__c = '11111',
            Description__c = 'Test Person Account',
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            profileId__c = '67890',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Business',
            OtherSourceOfIncome__c = 'Stocks',
            EIDNumber__c ='784-1234-1234567-1',
            TradeLicenseExpiryDate__c = null,
            UAE_Resident_Status__c = 'Non-Resident',
            UAEVATRegisterNumber__c = 'VAT67890',
            UnifiedNumber__c = 'UN67890',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'None',
            EmiratesIDExpiryDate__c = Date.today(),
            Service_Request__c = testServiceRequest.Id,
            RelationshipSubType__c='Friend',
            IsTheBusinessEntityRealBeneficiary__c = false,
            NoOfPropertyPurchasedWithModon__c = 2
    );

    Prospect_Account__c p2 = new Prospect_Account__c(
      Title__c = 'Mr.',
            RecordTypeId = accountRecordTypeId,
             Account__c = acc2.Id,
            Contact__c = null,
            Account_Type__c = 'Broker Agency',
            Account_Name__c = 'Test',
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Middle_Name__c = 'A',
            OwnershipPercentage__c = 50,
            IsPersonAccount__c = false,
            Birthdate__c = Date.today().addYears(-30),
            Email__c = 'john.doe@test.com',
            Mobile__c = '+971525612345',
            Is_Primary__c =true,
            Country__c = 'United Arab Emirates',
            State__c = 'Dubai',
            City__c = 'Dubai',
            Street__c = 'Street 2',
            PostalCode__c = '11111',
            Description__c = 'Test Person Account',
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            profileId__c = '67890',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Business',
            OtherSourceOfIncome__c = 'Stocks',
            EIDNumber__c ='784-1234-1234567-1',
            TradeLicenseExpiryDate__c = null,
            UAE_Resident_Status__c = 'Non-Resident',
            UAEVATRegisterNumber__c = 'VAT67890',
            UnifiedNumber__c = 'UN67890',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'None',
            EmiratesIDExpiryDate__c = Date.today(),
            Service_Request__c = testServiceRequest.Id,
            RelationshipSubType__c='Friend',
            IsTheBusinessEntityRealBeneficiary__c = false,
            NoOfPropertyPurchasedWithModon__c = 2,
            Prospect_Account__c = p1.Id
    );

    insert new List<Prospect_Account__c>{ p1, p2 };

    Test.startTest();
    PropertyTransferProcessController.insertJointOwnersFromProspects(
        so.Id,
        opp.Id,
        new List<Prospect_Account__c>{ p1, p2 }
    );
    PropertyTransferProcessController.insertJointOwnersFromProspects(
        so.Id,
        opp.Id,
        new List<Prospect_Account__c>()
    );
    PropertyTransferProcessController.insertJointOwnersFromProspects(
        so.Id,
        opp.Id,
        null
    );
    Test.stopTest();
}
    
    @isTest
static void testCancelInProcessReceipts() {

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

    Receipt__c r1 = new Receipt__c(
        Account__c = acc.Id,
        SalesOrder__c = so.Id,
        Status__c = 'In Progress',
        ChequeDate__c = Date.today().addDays(1)
    );

    Receipt__c r2 = new Receipt__c(
        Account__c = acc.Id,
        SalesOrder__c = so.Id,
        Status__c = 'Confirmed',
        ChequeDate__c = Date.today()
    );

    Receipt__c r3 = new Receipt__c(
        Account__c = acc.Id,
        SalesOrder__c = so.Id,
        Status__c = 'Cleared',
        EBS_Clearing_Date__c = Date.today(),
        ChequeDate__c = Date.today().addDays(1)
    );

    insert new List<Receipt__c>{ r1, r2, r3 };

    Test.startTest();
    PropertyTransferProcessController.cancelInProcessReceipts(so.Id);
    PropertyTransferProcessController.cancelInProcessReceipts(null);
    Test.stopTest();
}
    
    @isTest
static void testUpdateFutureInstallmentInvoicesAccount() {

    Account acc1 = new Account(Name = 'Old Account');
    Account acc2 = new Account(Name = 'New Account');
    List<Account> lstAccounts = new List<Account>{ acc1, acc2 };
    insert lstAccounts;

    Opportunity opp = new Opportunity(
        Name = 'Test Opp',
        StageName = 'Qualification',
        CloseDate = Date.today()
    );
    insert opp;

    SalesOrder__c so = new SalesOrder__c(
        Opportunity__c = opp.Id,
        CustomerAccount__c = acc1.Id,
        Status__c = 'Completed'
    );
    insert so;

    SalesOrderInstallments__c futureSoi = new SalesOrderInstallments__c(
        SalesOrder__c = so.Id,
        MilestoneDate__c = Date.today().addDays(5)
    );

    SalesOrderInstallments__c pastSoi = new SalesOrderInstallments__c(
        SalesOrder__c = so.Id,
        MilestoneDate__c = Date.today().addDays(-5)
    );

    insert new List<SalesOrderInstallments__c>{ futureSoi, pastSoi };

    Invoice__c inv1 = new Invoice__c(
        Account__c = acc1.Id,
        SalesOrderInstallment__c = futureSoi.Id
    );

    Invoice__c inv2 = new Invoice__c(
        Account__c = acc1.Id,
        SalesOrderInstallment__c = pastSoi.Id
    );

    insert new List<Invoice__c>{ inv1, inv2 };

    Test.startTest();
    PropertyTransferProcessController.updateFutureInstallmentInvoicesAccount(
        so.Id,
        acc2.Id
    );
    PropertyTransferProcessController.updateDocumentsWithNewAccounts(lstAccounts);
    Test.stopTest();
}
    
 @isTest
static void testUpdateChargeSo() {

    Account acc = new Account(Name = 'Test Account');
    insert acc;

    Opportunity opp = new Opportunity(
        Name = 'Test Opp',
        StageName = 'Qualification',
        CloseDate = Date.today(),
        AccountId = acc.Id
    );
    insert opp;

    SalesOrder__c so = new SalesOrder__c(
        Opportunity__c = opp.Id,
        CustomerAccount__c = acc.Id,
        Status__c = 'Completed'
    );
    insert so;

    Id srRt = Schema.SObjectType.ServiceRequest__c
        .getRecordTypeInfosByName()
        .get('Property Transfer OffPlan')
        .getRecordTypeId();

    ServiceRequest__c sr = new ServiceRequest__c(
        SalesOrder__c = so.Id,
        RecordTypeId = srRt
    );
    insert sr;

    Charge__c ch1 = new Charge__c(
        Service_Request__c = sr.Id
    );
    Charge__c ch2 = new Charge__c(
        Service_Request__c = sr.Id
    );
    insert new List<Charge__c>{ ch1, ch2 };

    Invoice__c inv1 = new Invoice__c(
        Account__c = acc.Id,
        Charge__c = ch1.Id
    );
    Invoice__c inv2 = new Invoice__c(
        Account__c = acc.Id,
        Charge__c = ch2.Id
    );
    insert new List<Invoice__c>{ inv1, inv2 };

    Test.startTest();
    PropertyTransferProcessController.updateChargeSo(so.Id, sr.Id);
    PropertyTransferProcessController.updateJointOwnerDetailsForDeletion(sr);
    Test.stopTest();
}  
        @isTest
static void testPtTitleDeedProcessServiceRequest1() {
    Account oldAcc = new Account(Name = 'Old Account');
Id personAccRtId = Schema.SObjectType.Account
    .getRecordTypeInfosByName()
    .get('Person Account')
    .getRecordTypeId();

// Create Person Account
Account newAcc = new Account(
    RecordTypeId = personAccRtId,
    FirstName = 'New',
    LastName = 'Primary Account',
    PersonEmail = 'test@example.com'
);
    Account joAcc  = new Account(LastName = 'Joint Owner Account',RecordTypeId = personAccRtId);
    insert new List<Account>{ oldAcc, newAcc, joAcc };

    

    Opportunity opp = new Opportunity(
        Name = 'Test Opp',
        StageName = 'Qualification',
        CloseDate = Date.today(),
        AccountId = oldAcc.Id
    );
    insert opp;

    SalesOrder__c so = new SalesOrder__c(
        CustomerAccount__c = oldAcc.Id,
        Opportunity__c = opp.Id,
        Status__c = 'Completed'
    );
    insert so;

    Id srRtId = Schema.SObjectType.ServiceRequest__c
        .getRecordTypeInfosByName()
        .get(Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED)
        .getRecordTypeId();

    ServiceRequest__c sr = new ServiceRequest__c(
        SalesOrder__c = so.Id,
        RecordTypeId = srRtId,
        Type__c = 'Normal'
    );
    insert sr;

    Id prospectAccRtId = Schema.SObjectType.Prospect_Account__c
        .getRecordTypeInfosByDeveloperName()
        .get('Account')
        .getRecordTypeId();

    Id prospectConRtId = Schema.SObjectType.Prospect_Account__c
        .getRecordTypeInfosByDeveloperName()
        .get('Contact')
        .getRecordTypeId();

    Prospect_Account__c orgProspect = new Prospect_Account__c(
        RecordTypeId = prospectConRtId,
        Account__c = newAcc.Id,
        Service_Request__c = sr.Id,
        IsPersonAccount__c = true,
        Is_Primary__c = true
    );
insert orgProspect;
    Prospect_Account__c primaryProspect = new Prospect_Account__c(
        RecordTypeId = prospectConRtId,
        Account__c = joAcc.Id,
        Is_Primary__c = false,
        IsPersonAccount__c = true,
        Service_Request__c = sr.Id,
        OwnershipPercentage__c =50,
        RelationshipSubType__c ='Friend'
    );
insert primaryProspect;

    Invoice__c inv = new Invoice__c(
        Sales_Order__c = so.Id,
        Account__c = oldAcc.Id,
        InvoiceDate__c = Date.today()
    );
    insert inv;

    Test.startTest();
    String result = PropertyTransferProcessController.ptTitleDeedprocessServiceRequest(sr.Id);
    Test.stopTest();

    
}

    @isTest
static void testPtTitleDeedProcessServiceRequest() {
    Account oldAcc = new Account(Name = 'Old Account');
    Account newAcc = new Account(Name = 'New Primary Account');
    Account joAcc  = new Account(Name = 'Joint Owner Account');
    insert new List<Account>{ oldAcc, newAcc, joAcc };

    Contact primaryCon = new Contact(
        LastName = 'Primary Contact',
        AccountId = newAcc.Id,
        UAE_Resident_Status__c = 'Resident',
        Nationality__c = 'United Arab Emirates',
        EIDNumber__c = '784-1234-1234567-1',
        EID_Expiry_Date__c = Date.today().addYears(1)
    );
    insert primaryCon;

    Opportunity opp = new Opportunity(
        Name = 'Test Opp',
        StageName = 'Qualification',
        CloseDate = Date.today(),
        AccountId = oldAcc.Id
    );
    insert opp;

    SalesOrder__c so = new SalesOrder__c(
        CustomerAccount__c = oldAcc.Id,
        PrimaryContact__c = primaryCon.Id,
        Opportunity__c = opp.Id,
        Status__c = 'Completed'
    );
    insert so;

    Id srRtId = Schema.SObjectType.ServiceRequest__c
        .getRecordTypeInfosByName()
        .get(Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED)
        .getRecordTypeId();

    ServiceRequest__c sr = new ServiceRequest__c(
        SalesOrder__c = so.Id,
        RecordTypeId = srRtId,
        Type__c = 'Normal'
    );
    insert sr;

    Id prospectAccRtId = Schema.SObjectType.Prospect_Account__c
        .getRecordTypeInfosByDeveloperName()
        .get('Account')
        .getRecordTypeId();

    Id prospectConRtId = Schema.SObjectType.Prospect_Account__c
        .getRecordTypeInfosByDeveloperName()
        .get('Contact')
        .getRecordTypeId();

    Prospect_Account__c orgProspect = new Prospect_Account__c(
        RecordTypeId = prospectAccRtId,
        Account__c = newAcc.Id,
        Account_Name__c = 'New Primary Account',
        Service_Request__c = sr.Id
    );
insert orgProspect;
    Prospect_Account__c primaryProspect = new Prospect_Account__c(
        RecordTypeId = prospectConRtId,
        Contact__c = primaryCon.Id,
        Is_Primary__c = true,
        IsPersonAccount__c = false,
        Prospect_Account__c= orgProspect.Id,
        Service_Request__c = sr.Id
    );
insert primaryProspect;

    Invoice__c inv = new Invoice__c(
        Sales_Order__c = so.Id,
        Account__c = oldAcc.Id,
        InvoiceDate__c = Date.today()
    );
    insert inv;

    Test.startTest();
    String result = PropertyTransferProcessController.ptTitleDeedprocessServiceRequest(sr.Id);
    Test.stopTest();
    
}
}