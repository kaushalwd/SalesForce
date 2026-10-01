/**

*Name               : LoqateMockHttpCallout                                                        
* Description        : This class is used  Mockclass for Loqate API 
* Usage              : This class is used  Mockclass for Loqate API                                                  
* Created By         :Arvind Kesharwani
 *Version       Author                          Date            Comment   
 1.0            Arvind Kesharwani              04/20/2026       Intial Dreaft

 * LoqateMockHttpCallout
 * Single mock that handles both phone and email endpoints.
 * Pass scenario in constructor: 'PHONE_VALID', 'PHONE_INVALID',
 *                               'EMAIL_VALID', 'EMAIL_INVALID', 'ERROR'
 */
@isTest
public class LoqateMockHttpCallout implements HttpCalloutMock {

    private String scenario;

    public LoqateMockHttpCallout(String scenario) {
        this.scenario = scenario;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');

        if (scenario == 'ERROR') {
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }

        if (req.getEndpoint().contains('PhoneNumberValidation')) {
            if (scenario == 'PHONE_VALID') {
                res.setBody('{"Items":[{"PhoneNumber":"+971588080914","IsValid":"Yes","NetworkName":"du (EITC)","NetworkCountry":"AE","NationalFormat":"058 808 0914","CountryPrefix":971,"NumberType":"Mobile","RequestProcessed":true}]}');
            } else {
                res.setBody('{"Items":[{"PhoneNumber":"+92588080914","IsValid":"No","NetworkName":"","NetworkCountry":"PK","NationalFormat":"","CountryPrefix":92,"NumberType":"","RequestProcessed":true}]}');
            }
        } else {
            if (scenario == 'EMAIL_VALID') {
                res.setBody('{"Items":[{"ResponseCode":"Valid","ResponseMessage":"Email is valid","EmailAddress":"test@gmail.com","Domain":"gmail.com","IsDisposableOrTemporary":false,"IsComplainerOrFraudRisk":false}]}');
            } else {
                res.setBody('{"Items":[{"ResponseCode":"Invalid","ResponseMessage":"Email Address is not valid","EmailAddress":"bad@bad.com","Domain":"bad.com","IsDisposableOrTemporary":false,"IsComplainerOrFraudRisk":false}]}');
            }
        }
        return res;
    }
}