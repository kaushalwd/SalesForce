@IsTest
global class MBP_OracleCalloutMockTest implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(201);

        res.setBody(
            '[{' +
                '"SupplierId":"SUP123",' +
                '"SupplierPartyId":"PARTY123",' +
                '"SupplierNumber":"SUPNUM123",' +
                '"SupplierAddressId":"ADDR123",' +
                '"SupplierSiteId":"SITE123"' +
            '}]'
        );

        return res;
    }
}