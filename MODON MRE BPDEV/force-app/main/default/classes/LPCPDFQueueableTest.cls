@isTest
private class LPCPDFQueueableTest {
    @isTest
    static void testQueueableExecutesSuccessfully() {
       Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Sales Order
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'sold',
            TotalAmount__c = 100000
        );
        insert so;

        // Sales Order Installment (PaymentStatus__c must NOT be 'Cancelled')
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            LPCActive__c = true,
            Exclude_LPC__c = false,
            PaymentStatus__c = 'Not Paid' // any non-'Cancelled' value per filter
        );
        insert soi;

        // Service Request must reference SAME Sales Order and SAME Installment
        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id,                 // matches filter on SR->SOI lookup
            Sales_Order_Installment__c = soi.Id,   // matches filter on SR->SOI lookup
            Waiver_Percentage__c = 50,
            LPC_Amount__c = 200
        );
        insert sr;

        // Charge on the same installment (so SR.Charge__c lookup filter passes)
        Charge__c charge = new Charge__c(
            Name = 'Test Charge',
            Amount__c = 100,
            SalesOrderInstallment__c = soi.Id, // must equal SR.Sales_Order_Installment__c
            Sales_Order__c = so.Id,
            Account__c = acc.Id,
            Service_Request__c = sr.Id
        );
        insert charge;

        // Link SR to Charge (lookup filter satisfied)
        sr.Charge__c = charge.Id;

        Test.startTest();
        System.enqueueJob(new LPCPDFQueueable(sr.Id));
        Test.stopTest();

    }
}