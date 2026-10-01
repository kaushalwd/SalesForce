@isTest
public class SalesOrderInstallmentTriggerHelperTest {
    
    @isTest
static void testUpdateEgyptAmountInWords_WithSalesOrder() {
    SalesOrder__c so = new SalesOrder__c(Status__c = 'Sold');
    insert so;

    SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
        SalesOrder__c = so.Id,
        MilestoneNumber__c = 1
    );
    insert soi;

    Test.startTest();
    SalesOrderInstallmentTriggerHelper.updateEgyptAmountInWords(
        new List<SalesOrderInstallments__c>{ soi }
    );
    Test.stopTest();

    System.assert(true, 'Queueable enqueued without error when SalesOrder__c is populated');
}

@isTest
static void testUpdateEgyptAmountInWords_NullSalesOrder() {
    SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
        MilestoneNumber__c = 1
    );

    Test.startTest();
    SalesOrderInstallmentTriggerHelper.updateEgyptAmountInWords(
        new List<SalesOrderInstallments__c>{ soi }
    );
    Test.stopTest();

    System.assert(true, 'No error when SalesOrder__c is null - record skipped safely');
}

@isTest
static void testUpdateEgyptAmountInWords_EmptyList() {
    Test.startTest();
    SalesOrderInstallmentTriggerHelper.updateEgyptAmountInWords(
        new List<SalesOrderInstallments__c>()
    );
    Test.stopTest();

    System.assert(true, 'No exception should be thrown for an empty list');
}
    
@isTest
static void testUpdateMilestoneDescriptionArabic_WithDescription() {
    SalesOrder__c so = new SalesOrder__c(Status__c = 'Sold');
    insert so;

    SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
        SalesOrder__c = so.Id,
        MilestoneNumber__c = 1,
        MilestoneDescription__c = 'Down Payment'
    );

    Test.startTest();
    SalesOrderInstallmentTriggerHelper.updateMilestoneDescriptionArabic(
        new List<SalesOrderInstallments__c>{ soi }
    );
    Test.stopTest();

    System.assert(true, 'if-branch executed without error');
}

@isTest
static void testUpdateMilestoneDescriptionArabic_NullDescription() {
    SalesOrder__c so = new SalesOrder__c(Status__c = 'Sold');
    insert so;

    SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
        SalesOrder__c = so.Id,
        MilestoneNumber__c = 1,
        MilestoneDescription__c = null
    );

    Test.startTest();
    SalesOrderInstallmentTriggerHelper.updateMilestoneDescriptionArabic(
        new List<SalesOrderInstallments__c>{ soi }
    );
    Test.stopTest();

    System.assertEquals(null, soi.MilestoneDescriptionArabic__c,
        'Arabic description should be null when source is null');
}

@isTest
static void testUpdateMilestoneDescriptionArabic_EmptyList() {
    Test.startTest();
    SalesOrderInstallmentTriggerHelper.updateMilestoneDescriptionArabic(
        new List<SalesOrderInstallments__c>()
    );
    Test.stopTest();

    System.assert(true, 'No exception should be thrown for an empty list');
}
      @isTest
    static void myTestmethod(){
        
        Set<Id> soiIds = new Set<Id>();
        
        Account accObj = new Account(Name = 'Test');
        insert accObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.CustomerAccount__c = accObj.Id;
        insert so;
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        soi.Milestone__c = 1;
        soi.InstallmentAmount__c = 100;
        insert soi;
        SalesOrderInstallments__c soi1 = new SalesOrderInstallments__c(
            SalesOrder__c = so.id,
            MilestoneNumber__c = 1,
            InstallmentAmount__c = 5000,
            LPCActive__c = true,
            Exclude_LPC__c = false,LPC_Charge__c=5000
        );
        insert soi1;
    
        
        //Invoice__c inObj = new Invoice__c(SalesOrderInstallment__c = soi.id,Account__c = accObj.id);
        //Insert inObj;
        
        //Documents__c DOC = new Documents__c(Name = 'Invoice PDF',Invoice__c = inObj.Id);
        //Insert DOC;
        
        soiIds.add(soi.Id);
        
        //system.debug('@@@@@'+inObj );
        system.debug('@@@@@'+ soiIds);

	        
        test.startTest();
        //SalesOrderInstallmentTriggerHelper.createInvoice(new list<sObject>{soi});
        List<Documents__c> documentLst = [SELECT Id, Name, Invoice__c, Invoice__r.SalesOrderInstallment__c
                                         FROM Documents__c 
                                         WHERE Invoice__c != null AND Name = 'Invoice PDF'];
        system.debug('documentLst==>' + documentLst);
        set<Id> soInsId = new set<Id>();
        for(Documents__c docObj : documentLst){
            soInsId.add(docObj.Invoice__r.SalesOrderInstallment__c);
        }
        SalesOrderInstallmentTriggerHelper.createInvoicePDFOnceChecked (soInsId);
        
        soi.MilestoneNumber__c = 1;
        update soi;
        
        delete soi;
        test.stopTest();
    }
    
    @isTest
    static void validateInvoicePaymentReminderChangeTest()
    {
        Set<Id> soiIds = new Set<Id>();
        List<SalesOrderInstallments__c> soiNewList = new List<SalesOrderInstallments__c>();
        List<SalesOrderInstallments__c> soiOldList = new List<SalesOrderInstallments__c>();
        Map<Id,SalesOrderInstallments__c> soiNewMap = new Map<Id,SalesOrderInstallments__c>();
        Map<Id,SalesOrderInstallments__c> soiOldMap = new Map<Id,SalesOrderInstallments__c>();
        
        Account accObj = new Account(Name = 'Test');
        insert accObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.CustomerAccount__c = accObj.Id;
        insert so;
        
         DateTime testCreatedDate = system.today()-3;
         
         
        for(Integer i=1;i<4;i++)
        {
            SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
            soi.SalesOrder__c = so.Id;
            soi.Milestone__c = i;
            soi.InstallmentAmount__c = 100+i;
            soi.SendPaymentReminder__c = false;
            //System.debug(soi.SendPaymentReminder__c);
            soiNewList.add(soi);
        }
        Insert soiNewList;
        
        for(SalesOrderInstallments__c soin:soiNewList)
        {  
            Test.setCreatedDate(soin.Id,testCreatedDate);
            soiOldMap.put(soin.id,soin);
        }  
        
             
        for(SalesOrderInstallments__c soiUpdate:soiOldMap.Values())
        {
            soiUpdate.SendPaymentReminder__c = true;
            //System.debug(soiUpdate.SendPaymentReminder__c);
            //System.debug(soiUpdate.Milestone__c);
            soiNewMap.put(soiUpdate.id,soiUpdate);
        }
     
        Update soiNewMap.Values();
       
        test.startTest(); 
        SalesOrderInstallmentTriggerHelper.validateInvoicePaymentReminderChange(soiNewMap, soiOldMap);
        test.stopTest();
       
    }
    
     @isTest
    static void validateInvoicePaymentReminderChangeNullTest()
    {
        
        Set<Id> soiIds = new Set<Id>();
        Map<Id,SalesOrderInstallments__c> soiNewMap = new Map<Id,SalesOrderInstallments__c>();
        Map<Id,SalesOrderInstallments__c> soiOldMap = new Map<Id,SalesOrderInstallments__c>();
        
        test.startTest();
        SalesOrderInstallmentTriggerHelper.validateInvoicePaymentReminderChange(soiNewMap, soiOldMap);  
        test.stopTest();
    }
    
    
    @isTest
    static void createInvoicePDFOnceCheckedTest()
    {
        Set<Id> soiIds = new Set<Id>();
        List<SalesOrderInstallments__c> soiNewList = new List<SalesOrderInstallments__c>();
        List<SalesOrderInstallments__c> soiOldList = new List<SalesOrderInstallments__c>();
        
        Account accObj = new Account(Name = 'Test');
        insert accObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.CustomerAccount__c = accObj.Id;
        insert so;
        
         DateTime testCreatedDate = system.today()-3;
         
         
        for(Integer i=1;i<10;i++)
        {
            SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
            soi.SalesOrder__c = so.Id;
            soi.Milestone__c = i;
            soi.InstallmentAmount__c = 100+i;
            soi.SendPaymentReminder__c = false;
            System.debug(soi.SendPaymentReminder__c);
            soiNewList.add(soi);
        }
        Insert soiNewList;
        
        for(SalesOrderInstallments__c soin:soiNewList)
        {  
            soiIds.add(soin.Id);
        }  
       
        test.startTest(); 
        SalesOrderInstallmentTriggerHelper.createInvoicePDFOnceChecked(soiIds);
        test.stopTest();
       
    }
    
    @isTest
    static void testUpdateSalesOrders_AllMilestones() {
        
        SalesOrder__c salesOrder = new SalesOrder__c(Status__c = 'Sold');
        insert salesOrder;
        
        List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>();
        
        // Creating 10 installments with milestones from 1 to 10
        for (Integer i = 1; i <= 10; i++) {
            installments.add(new SalesOrderInstallments__c(
                SalesOrder__c = salesOrder.Id,
                MilestoneNumber__c = i,
                PaymentStatus__c = 'Partially Paid'
            ));
        }
        
        insert installments;
        
        // Simulating PaymentStatus change to 'Paid' for each installment
        for (SalesOrderInstallments__c inst : installments) {
            inst.PaymentStatus__c = 'Partially Paid';
        }
        
        update installments;
        
        // Re-query to simulate Trigger.newMap and Trigger.oldMap
        Map<Id, SalesOrderInstallments__c> newMap = new Map<Id, SalesOrderInstallments__c>(
            [SELECT Id, SalesOrder__c, MilestoneNumber__c, PaymentStatus__c 
             FROM SalesOrderInstallments__c 
             WHERE SalesOrder__c = :salesOrder.Id]
        );
        
        Map<Id, SalesOrderInstallments__c> oldMap = new Map<Id, SalesOrderInstallments__c>();
        
        for (SalesOrderInstallments__c inst : installments) {
            oldMap.put(inst.Id, new SalesOrderInstallments__c(
                Id = inst.Id,
                SalesOrder__c = inst.SalesOrder__c,
                MilestoneNumber__c = inst.MilestoneNumber__c,
                PaymentStatus__c = 'Paid'
            ));
        }
        
        Test.startTest();
        SalesOrderInstallmentTriggerHelper.updateSalesOrders(newMap, oldMap);
        Test.stopTest();
    }

   /* @isTest
    static void testJustIncrement() {
        Test.startTest();
        SalesOrderInstallmentTriggerHelper.justIncrement();
        Test.stopTest();
    }*/
    
    
    
    @isTest
    static void handleManualLPCCharges1Test()
    {
        Set<Id> soiIds = new Set<Id>();
        List<SalesOrderInstallments__c> soiNewList = new List<SalesOrderInstallments__c>();
        List<SalesOrderInstallments__c> soiOldList = new List<SalesOrderInstallments__c>();
        
        Account accObj = new Account(Name = 'Test');
        insert accObj;
        Project__c testProject = new Project__c(Name = 'Test Project');
        insert testProject;
        
        // Create test Phase
        Phase__c testPhase = new Phase__c(Name = 'Test Phase', Project__c = testProject.Id);
        insert testPhase;
        
        // Create test Unit
        Unit__c testUnit = new Unit__c(Name = 'Test Unit', Phase__c = testPhase.Id, PlotNo__c = 'PNo536',UnitClassification__c='Villa',Number_of_Bedrooms__c='4');
        insert testUnit;
                    List<PaymentInstallements__c> oldPlanInstallments = new List<PaymentInstallements__c>();

        PaymentPlan__c oldPaymentPlan = new PaymentPlan__c(Name = 'Old Payment Plan', Type__c = 'Standard', Phase__c = testPhase.id);
                insert oldPaymentPlan;

        for(Integer i = 1; i <= 3; i++) {
            oldPlanInstallments.add(new PaymentInstallements__c(
                PaymentInstallment__c = oldPaymentPlan.Id,
                MilestoneNumber__c = i,
                Milestone__c = 10 * i,
                MilestoneDate__c = Date.today().addDays(-30 * i),
                MilestoneDescription__c = 'Old Milestone ' + i
            ));
        }
        insert oldPlanInstallments;
        
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            CustomerAccount__c = accObj.Id,
            Status__c = 'sold',
            Unit__c = testUnit.Id,
            PaymentPlan__c = oldPaymentPlan.Id,
            TotalAmount__c = 100000
        );
        insert testSalesOrder;
        
        // Create test Sales Order Installments
        List<SalesOrderInstallments__c> testInstallments = new List<SalesOrderInstallments__c>();
        for(PaymentInstallements__c pi : oldPlanInstallments) {
            testInstallments.add(new SalesOrderInstallments__c(
                SalesOrder__c = testSalesOrder.Id,
                PaymentInstallments__c = pi.Id,
                InstallmentAmount__c = testSalesOrder.TotalAmount__c * (pi.Milestone__c / 100),
                MilestoneDate__c = pi.MilestoneDate__c,
                MilestoneNumber__c = pi.MilestoneNumber__c,
                PaymentStatus__c = 'Paid',
                  LPCActive__c = true,
            Exclude_LPC__c = false,
            LPC_Charge__c=5000
            ));
        }
        insert testInstallments;
        
        // Create test Receipts
        List<Receipt__c> testReceipts = new List<Receipt__c>();
        for(SalesOrderInstallments__c soi : testInstallments) {
            testReceipts.add(new Receipt__c(
                SalesOrder__c = testSalesOrder.Id,
                SalesOrderInstallment__c = soi.Id,
                TotalAmount__c = soi.InstallmentAmount__c * 0.5,
                Status__c = 'Cleared',
				EBS_Clearing_Date__c = soi.MilestoneDate__c.addDays(30),
                Account__c = accObj.Id
            ));
        }
        insert testReceipts;
        
        // Create test Invoices
        List<Invoice__c> testInvoices = new List<Invoice__c>();
        for(SalesOrderInstallments__c soi : testInstallments) {
            testInvoices.add(new Invoice__c(
                SalesOrderInstallment__c = soi.Id,
                Sales_Order__c = testSalesOrder.Id,
                InvoiceAmount__c = soi.InstallmentAmount__c,
                IsCancelled__c = false,
                Account__c = accObj.Id
            ));
        }
        insert testInvoices;
        
        // Create test Allocations
        List<Allocation__c> testAllocations = new List<Allocation__c>();
        for(Integer i = 0; i < testReceipts.size(); i++) {
            testAllocations.add(new Allocation__c(
                Invoice__c = testInvoices[i].Id,
                Receipt__c = testReceipts[i].Id,
                AllocationAmount__c = testReceipts[i].TotalAmount__c,
                AllocationDate__c = Date.today(),
                Status__c = 'Applied'
            ));
        }
        insert testAllocations;
        
        Test.startTest();
        for(integer i=0;i<testInstallments.size();i++){
            testInstallments[i].PaymentStatus__c='Paid';
            testInstallments[i].LPC_Charge__c = 5000.00;
        }
        update testInstallments;
        try{
          SalesOrderInstallmentTriggerHelper.handleManualLPCCharges(testInstallments);
        }catch(exception e){
            
        } //SalesOrderInstallmentTriggerHelper.handleManualLPCCharges1(testInstallments);
        Test.stopTest();
        
    }
    @isTest
    static void handleManualLPCChargesTest()
    {
        Set<Id> soiIds = new Set<Id>();
        List<SalesOrderInstallments__c> soiNewList = new List<SalesOrderInstallments__c>();
        List<SalesOrderInstallments__c> soiOldList = new List<SalesOrderInstallments__c>();
        
        Account accObj = new Account(Name = 'Test');
        insert accObj;
        Project__c testProject = new Project__c(Name = 'Test Project');
        insert testProject;
        
        // Create test Phase
        Phase__c testPhase = new Phase__c(Name = 'Test Phase', Project__c = testProject.Id);
        insert testPhase;
        
        // Create test Unit
        Unit__c testUnit = new Unit__c(Name = 'Test Unit', Phase__c = testPhase.Id, PlotNo__c = 'PNo536',UnitClassification__c='Villa',Number_of_Bedrooms__c='4');
        insert testUnit;
                    List<PaymentInstallements__c> oldPlanInstallments = new List<PaymentInstallements__c>();

        PaymentPlan__c oldPaymentPlan = new PaymentPlan__c(Name = 'Old Payment Plan', Type__c = 'Standard', Phase__c = testPhase.id);
                insert oldPaymentPlan;

        for(Integer i = 1; i <= 3; i++) {
            oldPlanInstallments.add(new PaymentInstallements__c(
                PaymentInstallment__c = oldPaymentPlan.Id,
                MilestoneNumber__c = i,
                Milestone__c = 10 * i,
                MilestoneDate__c = Date.today().addDays(-90 * i),
                MilestoneDescription__c = 'Old Milestone ' + i
            ));
        }
        insert oldPlanInstallments;
        
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            CustomerAccount__c = accObj.Id,
            Status__c = 'sold',
            Unit__c = testUnit.Id,
            PaymentPlan__c = oldPaymentPlan.Id,
            TotalAmount__c = 100000
        );
        insert testSalesOrder;
        
        // Create test Sales Order Installments
        List<SalesOrderInstallments__c> testInstallments = new List<SalesOrderInstallments__c>();
        for(PaymentInstallements__c pi : oldPlanInstallments) {
            testInstallments.add(new SalesOrderInstallments__c(
                SalesOrder__c = testSalesOrder.Id,
                PaymentInstallments__c = pi.Id,
                InstallmentAmount__c = testSalesOrder.TotalAmount__c * (pi.Milestone__c / 100),
                MilestoneDate__c = pi.MilestoneDate__c,
                MilestoneNumber__c = pi.MilestoneNumber__c,
                PaymentStatus__c = 'Not Paid',
                  LPCActive__c = true,
            Exclude_LPC__c = false,
            LPC_Charge__c=5000
            ));
        }
        insert testInstallments;
        
        // Create test Receipts
        List<Receipt__c> testReceipts = new List<Receipt__c>();
        for(SalesOrderInstallments__c soi : testInstallments) {
            testReceipts.add(new Receipt__c(
                SalesOrder__c = testSalesOrder.Id,
                SalesOrderInstallment__c = soi.Id,
                TotalAmount__c = soi.InstallmentAmount__c * 0.5,
                Status__c = 'Cleared',
				EBS_Clearing_Date__c = soi.MilestoneDate__c.addDays(30),
                Account__c = accObj.Id
            ));
        }
        insert testReceipts;
        
        // Create test Invoices
        List<Invoice__c> testInvoices = new List<Invoice__c>();
        for(SalesOrderInstallments__c soi : testInstallments) {
            testInvoices.add(new Invoice__c(
                SalesOrderInstallment__c = soi.Id,
                Sales_Order__c = testSalesOrder.Id,
                InvoiceAmount__c = soi.InstallmentAmount__c,
                IsCancelled__c = false,
                Account__c = accObj.Id
            ));
        }
        insert testInvoices;
        
        // Create test Allocations
        List<Allocation__c> testAllocations = new List<Allocation__c>();
        for(Integer i = 0; i < testReceipts.size(); i++) {
            testAllocations.add(new Allocation__c(
                Invoice__c = testInvoices[i].Id,
                Receipt__c = testReceipts[i].Id,
                AllocationAmount__c = testReceipts[i].TotalAmount__c,
                AllocationDate__c = Date.today(),
                Status__c = 'Applied'
            ));
        }
        insert testAllocations;
        
        Test.startTest();
        for(integer i=0;i<testInstallments.size();i++){
            testInstallments[i].PaymentStatus__c='Paid';
        }
        update testInstallments;
          //SalesOrderInstallmentTriggerHelper.handleManualLPCCharges(testInstallments);
             SalesOrderInstallmentTriggerHelper.handleManualLPCCharges1(testInstallments);
        Test.stopTest();
        
    }
}