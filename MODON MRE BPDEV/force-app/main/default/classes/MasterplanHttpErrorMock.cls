@IsTest
public class MasterplanHttpErrorMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(500);
        res.setBody('Internal Server Error');
        return res;
    }
}