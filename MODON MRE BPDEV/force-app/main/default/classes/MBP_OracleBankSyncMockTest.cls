@IsTest
public class MBP_OracleBankSyncMockTest implements HttpCalloutMock {

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');
        res.setBody(
            '[{"BankPartyId":"BP-12345","BranchPartyId":"BR-67890"}]'
        );
        return res;
    }
}