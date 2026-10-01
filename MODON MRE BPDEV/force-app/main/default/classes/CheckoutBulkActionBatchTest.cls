/**********************************************************************************************************************
* Name               : CheckoutBulkActionBatchTest
* Description        : Test class for CheckoutBulkActionBatch
* Usage              : Apex unit test
* Created By         : Rushi Patel - Horizontal Digital
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Rushi Patel                 10 Sep 2026     Initial draft
******************************************************************************************************************/
@IsTest
private class CheckoutBulkActionBatchTest {

    private class BulkActionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"action_id":"act_test_123"}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        Checkout_Payment__c cpCapture = new Checkout_Payment__c(
            Reference__c = 'CKO-BATCH-CAP',
            Payment_Id__c = 'pay_test_cap',
            Status__c = 'Authorized',
            Amount__c = 100,
            Currency_Code__c = 'AED',
            Bulk_Action__c = 'Capture'
        );
        Checkout_Payment__c cpVoid = new Checkout_Payment__c(
            Reference__c = 'CKO-BATCH-VOID',
            Payment_Id__c = 'pay_test_void',
            Status__c = 'Authorized',
            Amount__c = 50,
            Currency_Code__c = 'AED',
            Bulk_Action__c = 'Void'
        );
        insert new List<Checkout_Payment__c>{ cpCapture, cpVoid };
    }

    @IsTest
    static void testBulkActionBatchCapture() {
        Test.setMock(HttpCalloutMock.class, new BulkActionMock());

        Test.startTest();
        // Since test methods only allow 1 batch chunk to run, we test Capture with batch size 1
        // by deleting the Void record so only 1 record is processed.
        delete [SELECT Id FROM Checkout_Payment__c WHERE Bulk_Action__c = 'Void'];
        
        CheckoutBulkActionBatch batch = new CheckoutBulkActionBatch();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // Verify Capture
        Checkout_Payment__c cpCap = [SELECT Status__c, Bulk_Action__c FROM Checkout_Payment__c WHERE Payment_Id__c = 'pay_test_cap'];
        System.assertEquals('Captured', cpCap.Status__c, 'Payment should be captured');
        System.assertEquals('Capture', cpCap.Bulk_Action__c, 'Bulk action field should not be cleared');
    }

    @IsTest
    static void testBulkActionBatchVoid() {
        Test.setMock(HttpCalloutMock.class, new BulkActionMock());

        Test.startTest();
        // Test Void in its own method to ensure only 1 batch chunk runs.
        delete [SELECT Id FROM Checkout_Payment__c WHERE Bulk_Action__c = 'Capture'];
        
        CheckoutBulkActionBatch batch = new CheckoutBulkActionBatch();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // Verify Void
        Checkout_Payment__c cpVoid = [SELECT Status__c, Bulk_Action__c FROM Checkout_Payment__c WHERE Payment_Id__c = 'pay_test_void'];
        System.assertEquals('Voided', cpVoid.Status__c, 'Payment should be voided');
        System.assertEquals('Void', cpVoid.Bulk_Action__c, 'Bulk action field should not be cleared');
    }
}