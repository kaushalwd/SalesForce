@isTest
public class OIC_InstallmentExtServiceTest {

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"items":[{"Sfid":"a01000000000001AAA","Status":"Success","Message":"Processed successfully","TransactionNumber":"TRX-001","Trx_No":"TRX-001"}]}');
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }
    }

    @isTest
    static void testProcessInstallments() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        OIC_RequestWrapperController.InstallmentWrapper wrap = new OIC_RequestWrapperController.InstallmentWrapper();
        wrap.Sfid = 'a01000000000001AAA';
        wrap.TrxnType = 'Invoice';
        wrap.Amount = '1000';

        List<OIC_RequestWrapperController.InstallmentWrapper> wrapList = new List<OIC_RequestWrapperController.InstallmentWrapper>{wrap};

        Test.startTest();
        OIC_InstallmentExtService.InstallmentCalloutResult result = OIC_InstallmentExtService.processInstallments(wrapList, new Map<Id, Id>());
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }
}