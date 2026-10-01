@isTest
private class InvoiceLineViewerControllerTest {
    @isTest static void testGetInvoiceLinesAndUpdateHoldStatus() {
        // Create supporting records
       Commission_Line__c commLine = new Commission_Line__c(External_Total_Commission_Amount__c=1000);
        insert commLine;
        
        Invoice_Bundle__c masterBundle = new Invoice_Bundle__c(Hold_Status__c = 'Release',Hold_Reason__c = 'Test Reason');
        insert masterBundle;
        
        Invoice_Line__c invLine = new Invoice_Line__c(Commission_Line__c = commLine.Id,Invoice_Bundle__c = masterBundle.Id,Is_Hold__c = false);
        insert invLine;
        
        
        
        // Call the getter and assert it returns the created invoice line
            List<Invoice_Line__c> lines = InvoiceLineViewerController.getInvoiceLines(masterBundle.Id);
        
        Invoice_Line__c returned = lines[0];
        
        // Now test updateHoldStatus -> set On Hold with a reason
            InvoiceLineViewerController.updateHoldStatus(invLine.Id, true, 'Test hold reason');
        
        Invoice_Line__c afterHold = [
            SELECT Id, Is_Hold__c, Hold_Reason__c
            FROM Invoice_Line__c
            WHERE Id = :invLine.Id
            LIMIT 1
        ];
       
        // Then un-hold and ensure reason is cleared
        Test.startTest();
            InvoiceLineViewerController.updateHoldStatus(invLine.Id, false, null);
        Test.stopTest();
        
        Invoice_Line__c afterUnHold = [
            SELECT Id, Is_Hold__c, Hold_Reason__c
            FROM Invoice_Line__c
            WHERE Id = :invLine.Id
            LIMIT 1
        ];
    }
}