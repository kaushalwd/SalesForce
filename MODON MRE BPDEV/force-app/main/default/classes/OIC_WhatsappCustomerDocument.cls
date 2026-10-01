/**********************************************************************************************************************
* Name               : OIC_WhatsappCustomerDocument                                                        
* Description        : This class is used for Whatsapp integration to get SPA and SOA document.
* Usage              : Called from Whatsapp.
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	            28 Mar 2026     Initial Draft
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — with sharing, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/WhatsappCustomerDocuments/*')
global with sharing class OIC_WhatsappCustomerDocument {

    @HttpGet
    global static void generateSPADocumentURL() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        GenerateDocumentResponse obj_Response = new GenerateDocumentResponse();
        try {
            String mobileNumber = req.params.get('MobileNumber');
            String unitName = req.params.get('UnitName');
            String documentType = req.params.get('DocumentType');
            if (String.isBlank(mobileNumber) || String.isBlank(unitName) || String.isBlank(documentType)) {
                returnErrorAPI.returnError(res, requestId, 'Missing Query parameters', 200);
                return;
            }
            if(!mobileNumber.startsWith('+')){
                mobileNumber = '+'+mobileNumber;
            }
            if(documentType == 'SPA'){
                obj_Response.DocumentURL = WhatsappCustomerDocumentUtil.generateSPADocument(unitName, mobileNumber);
            } else if(documentType == 'SOA'){
                obj_Response.DocumentURL = WhatsappCustomerDocumentUtil.generateSOADocument(unitName, mobileNumber);
            } else{
                returnErrorAPI.returnError(res, requestId, 'No document type found in request', 200);
                return;
            }
            
            APIResponse response = new APIResponse('success', requestId, obj_Response, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
        }catch(Exception exe){
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                exe,
                'WhatsApp Customer Document API',
                'OIC_WhatsappCustomerDocument',
                'generateSPADocumentURL'
            ));
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + exe.getMessage(), 200);
        }
    }
  public class GenerateDocumentResponse{
        public string DocumentURL;
  }    
}