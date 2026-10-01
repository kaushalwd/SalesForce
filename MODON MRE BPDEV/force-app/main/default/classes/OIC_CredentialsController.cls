public class OIC_CredentialsController {
    public static HttpRequest getCredentials(String credentialType){

        OIC_Credential__mdt oicCredential = OIC_Credential__mdt.getInstance(credentialType);
        String username = oicCredential.Username__c;
        String password = oicCredential.Password__c;

        Blob headerValue = Blob.valueOf(username + ':' + password);
        String authorizationHeader = 'BASIC ' +
        EncodingUtil.base64Encode(headerValue);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(oicCredential.Endpoint__c);
        req.setMethod(oicCredential.Method__c);
        req.setHeader('Content-Type','application/json');
        req.setHeader('Authorization', authorizationHeader);

        return req;
    }
}