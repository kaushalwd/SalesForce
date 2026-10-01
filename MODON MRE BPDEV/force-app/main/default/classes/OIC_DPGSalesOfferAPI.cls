/**********************************************************************************************************************
* Name               : OIC_DPGSalesOfferAPI                                                        
* Description        : This class contains main integration methods for Sales Offer generation.
* Usage              : Used to generate sales offer for DPG.
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                08 04 2025      Initial Draft
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — with sharing, createApexLog

***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/generatesalesoffer/*')
global with sharing class OIC_DPGSalesOfferAPI {

    @HttpPost
    global static void generateSalesOfferDPG() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        SalesOfferRequest obj_SalesOfferRequest = new SalesOfferRequest();
        restRequest.addHeader('Content-Type', 'application/json');
        try {
            obj_SalesOfferRequest = (SalesOfferRequest)System.JSON.deserialize(restRequest.requestBody.toString(), SalesOfferRequest.class);
            System.debug('OIC_DPGSalesOfferAPI >>>> generateSalesOfferDPG >> '+System.JSON.serialize(obj_SalesOfferRequest));
            /*Blob salesOfferAttachment = OIC_DPGSalesOfferAPIHelper.readyPDF('a01Dw00000OFV97IAH', 'a03Dw00000BbYyPIAV', 
                                                							'', 'a09Dw00000AVnqqIAD', 'Test', 'Test@gmail.com', '');*/
            Blob salesOfferAttachment = OIC_DPGSalesOfferAPIHelper.readyPDF(obj_SalesOfferRequest.Project,obj_SalesOfferRequest.Unit,
                                                                            obj_SalesOfferRequest.UnitType,obj_SalesOfferRequest.PaymentPlan,
                                                                            obj_SalesOfferRequest.CustomerName,obj_SalesOfferRequest.CustomerEmail,obj_SalesOfferRequest.Exterior,
                                                                            obj_SalesOfferRequest.DPGInteractiveURL);
            //System.debug('OIC_DPGSalesOfferAPI >>>> generateSalesOfferDPG response >> '+System.JSON.serialize(salesOfferAttachment));
            String fileName = 'SalesOffer_' + DateTime.now().getTime() + '.pdf';
            Id contentVersionId = OIC_DPGSalesOfferAPIHelper.savePDFToSalesforce(salesOfferAttachment, 'SalesOffer.pdf',obj_SalesOfferRequest.Unit);
            String publicLink = OIC_DPGSalesOfferAPIHelper.generatePublicLink(contentVersionId,fileName);
            System.debug('publicLink: '+publicLink);
            JSONGenerator gen = JSON.createGenerator(true);
            gen.writeStartObject();
            gen.writeStringField('FileName', 'SalesOffer.pdf');
            gen.writeStringField('ContentType', 'application/pdf');
            gen.writeStringField('PublicLink', publicLink); //gen.writeStringField('Base64Data', EncodingUtil.base64Encode(salesOfferAttachment));
            gen.writeStringField('Status', 'Success');
            
            gen.writeEndObject();

            // Convert to string
            String jsonOutput = gen.getAsString();
            restResponse.responseBody = Blob.valueOf(jsonOutput);
            restResponse.addHeader('Content-Type', 'application/json');
            //restResponse.addHeader('Content-Disposition', 'attachment; filename="SalesOffer.pdf"');
            restResponse.statusCode = 200;
        } catch (Exception ex) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'DPG Sales Offer API',
                'OIC_DPGSalesOfferAPI',
                'generateSalesOfferDPG'
            ));
            throw ex;
        }
    }  
    
    global class SalesOfferRequest{
        public String CustomerName;	
        public String CustomerEmail;	
        public String Project;	
        public String Unit;
        public String UnitType;
        public String Exterior;	
        public String PaymentPlan;
        public String DPGInteractiveURL;
        public SalesOfferRequest(){}
    } 
    global class SalesOfferResponse {
        public String FileName;
        public String ContentType;
        public String Base64Data;
        public String Status;	
        public String ErrorCode;	
        public String ErrorMessage;
        public String PublicLink;
    }
}