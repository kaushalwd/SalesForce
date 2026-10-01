/**********************************************************************************************************************
* Name               : OIC_DPGCreateLeadAPI
* Description        : This class contains main integration methods for DPG Integration.
* Usage              : Used to create a lead from DPG.
* Created By         : Activemindsit
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Suresh   	                31 03 2025      Initial Draft
* 1.1           MODON CRM TEAM              02 Jul 2026     Added NumberOfBedrooms, Unit, PriceInAED to request
*                                                            extraction and CreateLeadRequest wrapper.
* 1.2           Jay Patel                   17 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL, try-catch, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/createlead/*')
//1.2 MCR-73: Enforce record-level sharing on inbound DPG REST API
global with sharing class OIC_DPGCreateLeadAPI {

    @HttpPost
    global static void createLeadDPG() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        CreateLeadRequest obj_CreateLeadRequest = new CreateLeadRequest();
        CreateLeadResponse obj_CreateLeadResponse = new CreateLeadResponse();
        restRequest.addHeader('Content-Type', 'application/json');

        //1.2 MCR-73: Wrap request handling; log unexpected failures via LoggerService.createApexLog
        try {
            String body = (restRequest.requestBody != null) ? restRequest.requestBody.toString() : '';
            System.debug('createLeadDPG >>>> call initiated >> ' + body);
            if(!String.isBlank(body)){
                Map<String, Object> inputMap = (Map<String, Object>) JSON.deserializeUntyped(body);
                String leadId = (String) (inputMap.containsKey('LeadId') ? inputMap.get('LeadId') : (inputMap.containsKey('leadId') ? inputMap.get('leadId') : (inputMap.containsKey('Id') ? inputMap.get('Id') : inputMap.get('id'))));
                String firstName = (String) inputMap.get('FirstName');
                String lastName = (String) inputMap.get('LastName');
                String email = (String) inputMap.get('Email');
                String mobilePhone = (String) inputMap.get('MobilePhone');
                String leadSource = (String) inputMap.get('LeadSource');
                String preferLanguage = (String) inputMap.get('LanguagePreference');
                String project = (String) inputMap.get('Project');
                String numberOfBedrooms = (String) inputMap.get('NumberOfBedrooms');
                String unitId = (String) (inputMap.containsKey('Unit') ? inputMap.get('Unit') : (inputMap.containsKey('UnitId') ? inputMap.get('UnitId') : (inputMap.containsKey('unitId') ? inputMap.get('unitId') : (inputMap.containsKey('unit_id') ? inputMap.get('unit_id') : inputMap.get('unit')))));
                String clickId = (String) inputMap.get('ClickId');
                String UTMCampaign = (String) inputMap.get('UTMCampaign');
                String UTMMedium = (String) inputMap.get('UTMMedium');
                String UTMSource = (String) inputMap.get('UTMSource');
                String UTMURL = (String) inputMap.get('UTMURL');
                String ExternalSystemID = (String) inputMap.get('ExternalSystemID');
                if (String.isNotBlank(unitId) && (unitId.equalsIgnoreCase('null') || unitId.equalsIgnoreCase('undefined'))) {
                    unitId = null;
                }
                Decimal priceInAED = inputMap.get('PriceInAED') != null
                    ? Decimal.valueOf(String.valueOf(inputMap.get('PriceInAED')))
                    : null;
                email = OIC_DPGIntegrationHelper.sanitizeEmail(email);
                if (String.isBlank(leadSource)) {
                    leadSource = '3DS Interactive';
                }
                if(!String.isBlank(lastName) && !String.isBlank(email) && !String.isBlank(mobilePhone)){
                     if (String.isNotBlank(unitId)) {
                         Id validUnitId = null;
                         try { validUnitId = Id.valueOf(unitId.trim()); } catch (Exception e) {}
                         if (validUnitId != null) {
                             //1.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Unit__c query
                             List<Unit__c> units = [
                                 SELECT Id
                                 FROM Unit__c
                                 WHERE Id = :validUnitId
                                 WITH USER_MODE
                                 LIMIT 1
                             ];
                             if (units.isEmpty()) {
                                 obj_CreateLeadResponse.Status = 'Failure';
                                 obj_CreateLeadResponse.ErrorCode = 'DPG-009';
                                 obj_CreateLeadResponse.ErrorMessage = 'No Unit record found for the supplied Unit Id: ' + unitId;
                             }
                         } else {
                             obj_CreateLeadResponse.Status = 'Failure';
                             obj_CreateLeadResponse.ErrorCode = 'DPG-009';
                             obj_CreateLeadResponse.ErrorMessage = 'Invalid Unit Id format: ' + unitId;
                         }
                     }
                     if (String.isBlank(obj_CreateLeadResponse.ErrorCode)) {
                         obj_CreateLeadRequest = new CreateLeadRequest(firstName, lastName, email, mobilePhone,
                                                                       leadSource, preferLanguage, project,
                                                                       numberOfBedrooms, unitId, priceInAED, 
                                                                       clickId, UTMCampaign, UTMMedium, UTMSource,
                                                                       UTMURL, ExternalSystemID);
                         obj_CreateLeadRequest.LeadId = leadId;
                         obj_CreateLeadRequest.UnitId = unitId;
                         System.debug('createLeadDPG >>>> Request >> ' + System.JSON.serialize(obj_CreateLeadRequest));
                         obj_CreateLeadResponse = OIC_DPGIntegrationHelper.createLeadDPG(obj_CreateLeadRequest);
                     }
                } else if(String.isBlank(lastName)){
                     obj_CreateLeadResponse.Status = 'Failure';
                     obj_CreateLeadResponse.ErrorCode = 'DPG-001';
                     obj_CreateLeadResponse.ErrorMessage = 'Last Name should not be empty';
                } else if(String.isBlank(email)){
                     obj_CreateLeadResponse.Status = 'Failure';
                     obj_CreateLeadResponse.ErrorCode = 'DPG-002';
                     obj_CreateLeadResponse.ErrorMessage = 'Email should not be empty';
                } else if(String.isBlank(mobilePhone)){
                     obj_CreateLeadResponse.Status = 'Failure';
                     obj_CreateLeadResponse.ErrorCode = 'DPG-003';
                     obj_CreateLeadResponse.ErrorMessage = 'Mobile Phone should not be empty';
                }
                System.debug('createLeadDPG >>>> Response >> ' + System.JSON.serialize(obj_CreateLeadResponse));
                if(obj_CreateLeadResponse != null && obj_CreateLeadResponse.Status == 'Success'){
                    restResponse.statusCode = 200;
                } else {
                    restResponse.statusCode = 400;
                }
                restResponse.addHeader('Content-Type', 'application/json');
                restResponse.responseBody = Blob.valueOf(JSON.serialize(obj_CreateLeadResponse));
            } else {
                restResponse.statusCode = 400;
                obj_CreateLeadResponse.Status = 'Failure';
                obj_CreateLeadResponse.ErrorCode = 'DPG-000';
                obj_CreateLeadResponse.ErrorMessage = 'Empty records found';
                restResponse.addHeader('Content-Type', 'application/json');
                restResponse.responseBody = Blob.valueOf(JSON.serialize(obj_CreateLeadResponse));
            }
        } catch (Exception ex) {
            //1.2 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'DPG Create Lead API',
                'OIC_DPGCreateLeadAPI',
                'createLeadDPG'
            ));
            restResponse.statusCode = 400;
            obj_CreateLeadResponse.Status = 'Failure';
            obj_CreateLeadResponse.ErrorCode = 'DPG-999';
            obj_CreateLeadResponse.ErrorMessage = ex.getMessage();
            restResponse.addHeader('Content-Type', 'application/json');
            restResponse.responseBody = Blob.valueOf(JSON.serialize(obj_CreateLeadResponse));
        }
    }
    
    global class CreateLeadRequest{
        public String LeadId;
        public String FirstName;
        public String LastName;
        public String Email;
        public String MobilePhone;	//+971555555555
        public String LanguagePreference;	//English
        public String LeadSource;	//3DS Interactive
        public String Project;
        public String NumberOfBedrooms;
        public String Unit;
        public String UnitId;
        public Decimal PriceInAED;
        public String clickId;
        public String UTMCampaign;
        public String UTMMedium;
        public String UTMSource;
        public String UTMURL;
        public String ExternalSystemID;
        public CreateLeadRequest(){}
        public CreateLeadRequest(String FirstName, String LastName, String Email, String MobilePhone,
                                 String LeadSource, String LanguagePreference, String Project){
            this.FirstName = FirstName;
            this.LastName = LastName;
            this.Email = Email;
            this.MobilePhone = MobilePhone;
            this.LanguagePreference = LanguagePreference;
            this.LeadSource = LeadSource;
            this.Project = Project;
        }
        public CreateLeadRequest(String FirstName, String LastName, String Email, String MobilePhone,
                                 String LeadSource, String LanguagePreference, String Project,
                                 String NumberOfBedrooms, String Unit, Decimal PriceInAED, 
                                 String clickId, String UTMCampaign, String UTMMedium, String UTMSource, String UTMURL, String ExternalSystemID){
            this.FirstName = FirstName;
            this.LastName = LastName;
            this.Email = Email;
            this.MobilePhone = MobilePhone;
            this.LanguagePreference = LanguagePreference;
            this.LeadSource = LeadSource;
            this.Project = Project;
            this.NumberOfBedrooms = NumberOfBedrooms;
            this.Unit = Unit;
            this.UnitId = Unit;
            this.PriceInAED = PriceInAED;
            this.clickId = clickId;
            this.UTMCampaign = UTMCampaign;
            this.UTMMedium = UTMMedium;
            this.UTMSource = UTMSource;
            this.UTMURL = UTMURL; 
            this.ExternalSystemID = ExternalSystemID;
        }
    }

    global class CreateLeadResponse {
        public String CorrelationId;
        public String LeadId;	
        public String Status;	
        public String ErrorCode;	
        public String ErrorMessage;	
    }
}