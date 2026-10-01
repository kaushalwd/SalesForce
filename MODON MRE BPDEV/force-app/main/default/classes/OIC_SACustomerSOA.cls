/**********************************************************************************************************************
* Name               : OIC_SACustomerSOA                                                        
* Description        : REST Endpoint to safely render and return Statement of Account PDFs as Base64 strings.
* Usage              : GET to /services/apexrest/SACustomerSOA/?SOId=YOUR_SALES_ORDER_ID
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft
***********************************************************************************************************************/
@RestResource(urlMapping='/SACustomerSOA/*')
global with sharing class OIC_SACustomerSOA {

    public class StatementOfAccountException extends Exception {}

    @HttpGet
    global static void getCustomerSOA() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        String requestId = String.valueOf(UUID.randomUUID());
        res.addHeader('Content-Type', 'application/json');

        try {
            String soId = req.params.get('SOId');
            if (String.isBlank(soId)) {
                throw new StatementOfAccountException('Missing mandatory query parameter: SOId');
            }

            PageReference pdfPage = Page.NewSOAPDF;
       			pdfPage.getParameters().put('Id', soId);
            
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Unit Test PDF Content');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            String base64EncodedPDF = EncodingUtil.base64Encode(pdfBlob);
            
            SOAResponseData responsePayload = new SOAResponseData();
            responsePayload.FileName = 'StatementOfAccount_' + soId + '.pdf';
            responsePayload.FileBase64Content = base64EncodedPDF;

            APIResponse response = new APIResponse('success', requestId, responsePayload, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.statusCode = 200;
            
        } catch (StatementOfAccountException sae) {
            System.debug(LoggingLevel.WARN, 'SOA Validation Exception: ' + sae.getMessage());
            returnErrorAPI.returnError(res, requestId, sae.getMessage(), 200); 
            
        } catch (Exception exe) {
            LoggerService.save(LoggerService.createApexLog(exe, 'OIC_SACustomerSOA', 'OIC_SACustomerSOA', 'getCustomerSOA'));
            System.debug(LoggingLevel.ERROR, 'Fatal failure generating statement profile data: ' + exe.getMessage());
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + exe.getMessage(), 200);
        }
    }

    global class SOAResponseData {
        public String FileName;
        public String FileBase64Content;
    }
}