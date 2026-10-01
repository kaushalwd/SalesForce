@isTest
public class ManageReceiptAllocationControllerTest {

      @isTest
    static void myTestmethod(){
        
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account testAccount = new Account();
        testAccount.RecordTypeId = recordTypeId;
        testAccount.PersonEmail = 'abdallahhdaib@outlook.com';
        testAccount.FirstName = 'Test Account';
        testAccount.LastName = 'test';
        insert testAccount;
        
        Contact conObj = new Contact();
        conObj.LastName = 'Test contact';
        conObj.Email = 'test@test.com';
        INSERT conObj;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.PrimaryContact__c = conObj.Id;
        insert oppObj;
        
        Expressionofinterest__c eoi = new Expressionofinterest__c();
        eoi.Opportunity__c = oppObj.Id;
        insert eoi;
        
        SalesOrder__c so = new SalesOrder__c();
        insert so;
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        insert soi;
        
        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = testAccount.Id;
        recObj.ExpressionOfInterest__c = eoi.Id;
        //recObj.SalesOrderInstallment__c = soi.Id;
        insert recObj;
        
        Invoice__c invoice = new Invoice__c();
        invoice.Expressionofinterest__c = eoi.Id;
        invoice.InvoiceAmount__c = 100;
        //invoice.AppliedAmount__c = 50;
        invoice.Account__c = testAccount.Id;
        insert invoice;
        
        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = invoice.Id;
        alloc.Receipt__c = recObj.Id;
        insert alloc;
        
        test.startTest();
        	ReceiptTriggerHelper.createAllocationRecord(new Map<Id, sObject>{recObj.Id => recObj});
            ManageReceiptAllocationController.getAvailableReceiptsInvoices(testAccount.Id);
        ManageReceiptAllocationController.getAllAllocations(testAccount.Id);
        ManageReceiptAllocationController.unapplyAllocationRecord(alloc.id);        
        test.stopTest();
    }
    
    @isTest
    static void myTestmethod2(){
        
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account testAccount = new Account();
        testAccount.RecordTypeId = recordTypeId;
        testAccount.PersonEmail = 'abdallahhdaib@outlook.com';
        testAccount.FirstName = 'Test Account';
        testAccount.LastName = 'test';
        insert testAccount;
        
        Contact conObj = new Contact();
        conObj.LastName = 'Test contact';
        conObj.Email = 'test@test.com';
        INSERT conObj;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.PrimaryContact__c = conObj.Id;
        insert oppObj;
        
        Expressionofinterest__c eoi = new Expressionofinterest__c();
        eoi.Opportunity__c = oppObj.Id;
        insert eoi;
        
        SalesOrder__c so = new SalesOrder__c();
        insert so;
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        insert soi;
        
        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = testAccount.Id;
        //recObj.ExpressionOfInterest__c = eoi.Id;
        recObj.SalesOrderInstallment__c = soi.Id;
        insert recObj;
        
        Invoice__c invoice = new Invoice__c();
        invoice.SalesOrderInstallment__c = soi.Id;
        invoice.InvoiceAmount__c = 100;
        //invoice.AppliedAmount__c = 50;
        invoice.Account__c = testAccount.Id;
        insert invoice;
        
        test.startTest();
        	ReceiptTriggerHelper.createAllocationRecord(new Map<Id, sObject>{recObj.Id => recObj});
            ManageReceiptAllocationController.getAvailableReceiptsInvoices(so.Id);
        	
        	ManageReceiptAllocationController.saveAllocationRecord(invoice.Id,recObj.Id, 10);
        	ManageReceiptAllocationController.ResponseWrapper rp = ManageReceiptAllocationController.getAllAllocations(so.Id);
        	//ManageReceiptAllocationController.unapplyAllocationRecord(rp.allLst[0].Id);
        test.stopTest();
    }
}