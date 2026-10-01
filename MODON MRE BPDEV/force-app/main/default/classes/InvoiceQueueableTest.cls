@isTest
public class InvoiceQueueableTest {

   @TestSetup
   static void makeData(){
    SalesOrder__c so = new SalesOrder__c();
    insert so;
  }

   @isTest
   static void method1(){
         Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
         String recordTypeId = recordTypeInfo.getRecordTypeId();
         Account accountObj = new Account(RecordTypeId = recordTypeId);
         accountObj.PersonEmail = 'abdallahhdaib@outlook.com';
         accountObj.FirstName = 'First';
         accountObj.LastName = 'Last';
         insert accountObj;
 
         //Create a new Unit
         Unit__c unitObj = new Unit__c();
         unitObj.Name = 'Test Unit';
         unitObj.BasePrice__c = 1000;
         unitObj.AdditionalPrice__c = 0;
         unitObj.PlotAreasqm__c = 1.0;
         unitObj.PlotNo__c = '1';
         unitObj.UnitClassification__c = 'Villa';
         unitObj.Number_of_Bedrooms__c = '2'; 
         INSERT unitObj;
 
         //Create a new sales order with a populated status
         SalesOrder__c salesOrderObj = new SalesOrder__c();
         salesOrderObj.Status__c = 'In Progress';
         salesOrderObj.Unit__c = unitObj.Id;
         SalesOrderObj.CustomerAccount__c = accountObj.Id;
         salesOrderObj.TotalAmount__c = 20000;
         INSERT salesOrderObj;
 
         //Create a new sales order with no populated status
         SalesOrder__c salesOrderNoStatus = new SalesOrder__c();
         salesOrderNoStatus.Status__c = '';
         INSERT salesOrderNoStatus;
 
         //Create a new SPA document with status as Uploaded 
         Documents__c documentObj = new Documents__c();
         documentObj.Name = 'SPA';
         documentObj.SalesOrder__c = salesOrderObj.Id;
         documentObj.Status__c = 'Uploaded';
         INSERT documentObj;
         
         //Create a new Sales Order Installment with milestone of 1
         SalesOrderInstallments__c soInstallmentObj = new SalesOrderInstallments__c();
         soInstallmentObj.SalesOrder__c = salesOrderObj.Id;
         soInstallmentObj.Milestone__c = 1;
         soInstallmentObj.MilestoneNumber__c = 1;
         INSERT soInstallmentObj;
 
         //Create a new invoice related to soInstallmentObj
         Invoice__c invoiceObj = new Invoice__c();
         invoiceObj.SalesOrderInstallment__c = soInstallmentObj.Id;
         invoiceObj.InvoiceAmount__c = 1000;
         invoiceObj.Account__c = accountObj.Id;         
         INSERT invoiceObj;

         //Create a new invoice related to charges
         Invoice__c invoiceObj1 = new Invoice__c();
         invoiceObj1.Sales_Order__c = salesOrderObj.Id;
         invoiceObj1.InvoiceAmount__c = 1000;
         invoiceObj1.Account__c = accountObj.Id;  
         invoiceObj1.Is_ADM_Fees_and_Dari_charges__c  = true;     
         INSERT invoiceObj1; 
         
    Set<String> soIdSet = new Set<String>();
    for(Salesorder__c soObj : [SELECT Id FROM SalesOrder__c where id =: salesOrderObj.id] ){
        soIdSet.add(soObj.Id);
    }
    InvoiceQueueable customerSOQableContext = new InvoiceQueueable(soIdSet);


    Id apexJobID = system.enqueueJob(customerSOQableContext);

   }


}