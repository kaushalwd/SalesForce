/**********************************************************************************************************************
* Name               : OIC_SAHandoverAuthorizedPersonDetails                                                        
* Description        : This class is used to update the authorized person details in the Handover details.
* Usage              : 
* Created By         : Modon                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                23 09 2026      Initial Draft       
***********************************************************************************************************************/
@RestResource(urlMapping='/superapp/handover/authorizedperson/*')
global class OIC_SAHandoverAuthorizedPersonDetails {

    public class HandoverValidationException extends Exception {}
        
    private static final String STAGE_ORIENTATION = 'Customer Home Orientation Appointment Booking';
    private static final String STAGE_KEYHANDOVER = 'Handover Document Signing';
    private static final String TYPE_AUTHORIZED   = 'Authorized Person';
    private static final String TYPE_THIRD_PARTY  = 'Third Party';
    
    @HttpPost
    global static void updateAuthorizedPersonDetails() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        restRequest.addHeader('Content-Type', 'application/json');
        
        try{
            if (restRequest.requestBody == null) {
                throw new HandoverValidationException('Missing Request Body Payload.');
            }
            
            AuthorizedPersonRequest obj_AuthRequest = (AuthorizedPersonRequest) System.JSON.deserialize(
                restRequest.requestBody.toString(), 
                AuthorizedPersonRequest.class
            );
            
            validateIncomingPayload(obj_AuthRequest);
            
            List<Handover_Details__c> hdList = [
                SELECT Id, Attended_By__c,
                       Business_Process__r.Current_Step_Name__c, 
                       HO_Authorized_Person_Name__c, HO_Authorized_Person_Phone__c, HO_Authorized_Person_Email__c, 
                       HO_Attendee_Emirates_Id__c, HO_Attendee_Passport_Number__c, 
                       HO_Attendee_Third_Party_Engineer_Name__c, HO_Attendee_Third_Party_Engineer_Mobile__c,
                       HO_Attendee_Third_Party_Engineer_Email__c, HO_Attendee_Company_Name__c, HO_Attendee_Trade_License__c,
                       HO_Attendee_Joint_Owner__c, Handover_Authorized_Person_Name__c, Handover_Authorized_Person_Phone__c, 
                       Handover_Authorized_Person_Email__c, Handover_Attendee_Emirates_Id__c, Handover_Attendee_Passport_Number__c, 
                       Handover_Third_Party_Engineer_Name__c, Handover_Third_Party_Engineer_Email__c, Handover_Third_Party_Engineer_Mobile__c, 
                       Handover_Company_Trade_License__c, Handover_Attendee_Company_Name__c, Handover_Attendee_Joint_Owner__c                
                FROM Handover_Details__c
                WHERE Id = :obj_AuthRequest.HandoverDetailsId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            
            if (hdList.isEmpty()) {
                returnErrorAPI.returnError(restResponse, requestId, 'No completed handover milestone found for the specified Unit ID.', 200);
                return;
            }
            
            Handover_Details__c obj_HD = hdList.get(0);
            String currentStep = obj_HD.Business_Process__r?.Current_Step_Name__c;
            
            if (currentStep != STAGE_ORIENTATION && currentStep != STAGE_KEYHANDOVER) {
                throw new HandoverValidationException('Update rejected: The Handover record is currently in the stage: ' + currentStep);
            }
            
            List<JointOwner__c> lst_JO = [
                SELECT Id 
                FROM JointOwner__c 
                WHERE SalesOrder__c = :obj_AuthRequest.SalesOrderId 
                AND JointOwnerAccount__r.PersonContactId = :obj_AuthRequest.ContactId 
                WITH USER_MODE
                LIMIT 1
            ];
            
            Id jointOwnerId = !lst_JO.isEmpty() ? lst_JO.get(0).Id : null;
            
            if (currentStep == STAGE_ORIENTATION) {
                mapOrientationDetails(obj_HD, obj_AuthRequest, jointOwnerId);
            } else if (currentStep == STAGE_KEYHANDOVER) {
                mapKeyOrientationDetails(obj_HD, obj_AuthRequest, jointOwnerId);
            }            
            
            update as system obj_HD;
            
            AuthorizedPersonResponse obj_AuthResponse = new AuthorizedPersonResponse();
            obj_AuthResponse.HandoverDetailsId = obj_AuthRequest.HandoverDetailsId;
            APIResponse response = new APIResponse('success', requestId, obj_AuthResponse, null);
            restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
            restResponse.statusCode = 200;
            
        }catch (HandoverValidationException ce) {
            System.debug(LoggingLevel.WARN, 'Business Validation Exception: ' + ce.getMessage());
            returnErrorAPI.returnError(restResponse, requestId, ce.getMessage(), 200);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Global Runtime Exception: ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
            returnErrorAPI.returnError(restResponse, requestId, 'Engine Processing Failure: ' + e.getMessage(), 200);
        }
    } 
    
    private static void validateIncomingPayload(AuthorizedPersonRequest req) {
        if (req == null) {
            throw new HandoverValidationException('Invalid request payload structure.');
        }
        if (String.isBlank(req.HandoverDetailsId) || String.isBlank(req.ContactId) || 
            String.isBlank(req.SalesOrderId)      || String.isBlank(req.HandoverStageName)) {
            throw new HandoverValidationException('Invalid payload: Missing required parameters (HandoverDetailsId, ContactId, SalesOrderId, HandoverStageName).');
        }
    }
    
    private static void mapOrientationDetails(Handover_Details__c record, AuthorizedPersonRequest req, Id jointOwnerId) {
        record.HO_Attendee_Joint_Owner__c     = jointOwnerId;
        record.Attended_By__c                 = req.AttendedBy;
        record.HO_Attendee_Emirates_Id__c     = req.AttendeeEmiratesId;
        record.HO_Attendee_Passport_Number__c = req.AttendeePassportNumber;
        
        if (req.AttendedBy == TYPE_AUTHORIZED) {
            record.HO_Authorized_Person_Name__c  = req.AuthorizedPersonName;
            record.HO_Authorized_Person_Phone__c = req.AuthorizedPersonPhone;
            record.HO_Authorized_Person_Email__c = req.AuthorizedPersonEmail;                    
        } else if (req.AttendedBy == TYPE_THIRD_PARTY) {
            record.HO_Attendee_Third_Party_Engineer_Name__c   = req.AuthorizedPersonName;
            record.HO_Attendee_Third_Party_Engineer_Mobile__c = req.AuthorizedPersonPhone;
            record.HO_Attendee_Third_Party_Engineer_Email__c  = req.AuthorizedPersonEmail;
            record.HO_Attendee_Company_Name__c                 = req.ThirdPartyCompanyName;
            record.HO_Attendee_Trade_License__c                = req.ThirdPartyTradeLicense;
        }
    }
    
    private static void mapKeyOrientationDetails(Handover_Details__c record, AuthorizedPersonRequest req, Id jointOwnerId) {
        record.Handover_Attendee_Joint_Owner__c     = jointOwnerId;
        record.Attended_By__c                       = req.AttendedBy;
        record.Handover_Attendee_Emirates_Id__c     = req.AttendeeEmiratesId;
        record.Handover_Attendee_Passport_Number__c = req.AttendeePassportNumber;
        
        if (req.AttendedBy == TYPE_AUTHORIZED) {
            record.Handover_Authorized_Person_Name__c  = req.AuthorizedPersonName;
            record.Handover_Authorized_Person_Phone__c = req.AuthorizedPersonPhone;
            record.Handover_Authorized_Person_Email__c = req.AuthorizedPersonEmail;                    
        } else if (req.AttendedBy == TYPE_THIRD_PARTY) {
            record.Handover_Third_Party_Engineer_Name__c   = req.AuthorizedPersonName;
            record.Handover_Third_Party_Engineer_Mobile__c = req.AuthorizedPersonPhone;
            record.Handover_Third_Party_Engineer_Email__c  = req.AuthorizedPersonEmail;
            record.Handover_Attendee_Company_Name__c       = req.ThirdPartyCompanyName;
            record.Handover_Company_Trade_License__c       = req.ThirdPartyTradeLicense;
        }
    }    
    
    global class AuthorizedPersonRequest{
        public String HandoverDetailsId;
        public String AttendedBy;
        public String AuthorizedPersonName;
        public String AuthorizedPersonPhone;
        public String AuthorizedPersonEmail;
        public String AttendeeEmiratesId;
        public String AttendeePassportNumber;
        public String ThirdPartyCompanyName;
        public String ThirdPartyTradeLicense;
        public String ContactId;
        public String SalesOrderId;
        public String HandoverStageName;
    }
    global class AuthorizedPersonResponse {
        public String HandoverDetailsId;
    }
}