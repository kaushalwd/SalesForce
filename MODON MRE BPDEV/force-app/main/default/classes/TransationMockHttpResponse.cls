@isTest
global class TransationMockHttpResponse implements HttpCalloutMock { 
    HttpResponse res;
    
    global TransationMockHttpResponse()   
    {
        res = new HttpResponse();
        
        res.setBody('inputString=["Rashrtrr"]');
        
    }
    
    global HTTPResponse respond (HTTPRequest req) {
        res.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        res.setHeader('Authorization', 'a3ZOdUI1ZE0yOGRqNm5mRDc0bmZkNU5XZDgzbVRjNg'); 
        res.setStatusCode(200);
        return res;
    }
}