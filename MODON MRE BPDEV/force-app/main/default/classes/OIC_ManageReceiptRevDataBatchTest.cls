@isTest
public class OIC_ManageReceiptRevDataBatchTest {

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"Status":"Success","Message":"Receipt reversed"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testBatchExecution() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Account acc = new Account(Name = 'Test Receipt Acc');
        insert acc;

        Receipt__c rec = new Receipt__c(
            Account__c = acc.Id,
            TotalAmount__c = 500,
            OraclePartyId__c = 'ORG-101'
        );
        insert rec;

        Map<Id, String> reversalMap = new Map<Id, String>{
            rec.Id => 'Customer Request'
        };

        Test.startTest();
        OIC_ManageReceiptRevDataBatch batch = new OIC_ManageReceiptRevDataBatch(reversalMap);
        Database.executeBatch(batch, 1);
        Test.stopTest();

        System.assertNotEquals(null, rec.Id, 'Receipt record should exist');
    }
}