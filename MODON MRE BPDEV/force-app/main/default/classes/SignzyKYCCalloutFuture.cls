public class SignzyKYCCalloutFuture {
    @future(Callout=true)
    public static void callWebservice(String accId,String docId,Id kycId){
       /* try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:SignzyKYCFileAccess/services/apexrest/kyc/generate');
            req.setMethod('POST');
            req.setHeader('Content-Type','application/json');
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());

            req.setBody(JSON.serialize(new Map<String,Object>{
                'accId'     => accId,
                    'docId' => docId
                    }));
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() >= 300) {
                System.debug(LoggingLevel.ERROR, 'KYC gen failed: ' + res.getStatus() + ' ' + res.getBody());
            }
            // Optionally parse response and write to a "Result" custom object keyed by correlationId
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'KYC trigger error: ' + ex.getMessage());
        }*/
        String objectName = ((Id)accId).getSObjectType().getDescribe().getName();
        if(objectName != 'Contact'){
            PageReference pdfPage = Page.SignzyKYCFormIndividual;
            pdfPage.getParameters().put('id', accId); 
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Fake PDF Content'); // mock blob
            } else {
                pdfBlob = pdfPage.getContent();
            }
            
            String ReturnUrl = System.Label.SignzyThankYouURL;
            
            System.enqueueJob(new SignzyKYCFormQueable(docId,ReturnUrl+'?id='+docId,pdfBlob,kycId));
        }else {
            PageReference pdfPage = Page.SignzyKYCFormCorporate;
            pdfPage.getParameters().put('id', accId); 
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Fake PDF Content'); // mock blob
            } else {
                pdfBlob = pdfPage.getContent();
            }
          
            String ReturnUrl = System.Label.SignzyThankYouURL;
    
            System.enqueueJob(new SignzyKYCFormQueable(docId,ReturnUrl+'?id='+docId,pdfBlob,kycId));
        }
    }
}