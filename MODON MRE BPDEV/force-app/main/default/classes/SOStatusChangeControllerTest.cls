/**-------------------------------------------------------------------
 * Description : Test Class for SOStatusChangeController
 * -------------------------------------------------------------------
 * History :
 * [2024-02-02] Yazan Saeed - Code Creation
 * [2026-05-14] Narendra Agrawal (Horizontal) - Refactored the test class to avoid 'Too many SOQL error' while deploying in the PROD.
 * -------------------------------------------------------------------
*/
@isTest
public class SOStatusChangeControllerTest {

    @isTest
    static void testMethod1(){

        //Create an account
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
        unitObj.UnitClassification__c = 'Apartment';
        unitObj.Number_of_Bedrooms__c = '1';
        INSERT unitObj;

        //Create a new sales order with a populated status
        SalesOrder__c salesOrderObj = new SalesOrder__c();
        salesOrderObj.Status__c = 'In Progress';
        salesOrderObj.Unit__c = unitObj.Id;
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

        //Create a new receipt 
        Receipt__c receiptObj = new Receipt__c();
        receiptObj.TotalAmount__c = 1000;
        receiptObj.Account__c = accountObj.Id;
        receiptObj.Status__c = 'Approved';
        INSERT receiptObj;

        //Create a new allocation related to the invoice so it is fully paid
        Allocation__c allocationObj = new Allocation__c();
        allocationObj.Invoice__c = invoiceObj.Id;
        allocationObj.AllocationAmount__c = 1000;
        allocationObj.Status__c = 'Applied';
        allocationObj.Receipt__c = receiptObj.Id;
        allocationObj.ApprovedReceiptAmount__c = 10000;
        INSERT allocationObj;
        
        // Changing status of Signed Reservation Form Document
        String salesOrderId = salesOrderObj.Id;
        List<Documents__c> salesOrderDocs = [SELECT Id, Name, SalesOrder__c, Status__c FROM Documents__c WHERE SalesOrder__c =: salesOrderId];
        if( !salesOrderDocs.isEmpty() ){
            for( Documents__c doc: salesOrderDocs ){
                doc.Status__c = 'Uploaded';
            }
            UPDATE salesOrderDocs;
        }
        List<Lead> leads = new List<Lead>{
            new Lead(ProjectInterest__c = 'Wadeem', FirstName = 'John', LastName = 'Doe', email='test@test.com', EIDNumber__c='784-3434-3434343-4',MobilePhone='+971343434343',TradeName__c ='Test', UnifiedNumber__c='Test')
            // Add more test lead records as needed 
        };
            
       
        test.startTest();
            //Narendra Agrawal [14/05/2026] - Moving insert lead DML inside Test.startTest and StopTest as, data created above having DMLs which is calling triggers and flows and consuming lot of
            //SOQL already. Test.startTest and stopTest reset the limits. We were getting Too Many SOQL 101 error. 
            //To fix this problem whole code repository should be refatored and make code more optimized in future.
            insert leads;
            String leadId = leads[0].Id;
            SOStatusChangeController.getCurrentSalesOrderStatus(salesOrderObj.Id);
            SOStatusChangeController.getCurrentSalesOrderStatus(salesOrderNoStatus.Id);
            SOStatusChangeController.checkReservationFormGenerated(salesOrderObj.Id);
            SOStatusChangeController.checkDownPaymentCollected(salesOrderObj.Id);
            SOStatusChangeController.checkDpPaymentConfirmed(salesOrderObj.Id);
            SOStatusChangeController.checkReservationFormSigned(salesOrderObj.Id);
            SOStatusChangeController.checkInstallementPaymentCollected(salesOrderObj.Id);
            SOStatusChangeController.checkInstallementPaymentCollectedEgypt(salesOrderObj.Id);
            SOStatusChangeController.checkSPAGenerated(salesOrderObj.Id);
            SOStatusChangeController.checkSignedSPACustomer(salesOrderObj.Id);
            SOStatusChangeController.checkSignedSPAModon(salesOrderObj.Id);
            SOStatusChangeController.checkSubmitButtonVisibility(leadId);
            SOStatusChangeController.reassignLead(leadId);
            SOStatusChangeController.reassignLeadToSA(leadId);
        test.stopTest();

    }
}