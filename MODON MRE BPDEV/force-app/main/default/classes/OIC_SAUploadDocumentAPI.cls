/**********************************************************************************************************************
* Name               : OIC_SAUploadDocumentAPI                                                        
* Description        : This class is used to upload the document.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft 
* 1.1           Jay Patel                   22 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL/DML, createApexLog
* 1.2           Suresh   	                29 09 2026      Added payment notification once the payment receipt is uploaded through Modon Connect. 
***********************************************************************************************************************/
@RestResource(urlMapping='/customer/uploaddocument')
global with sharing class OIC_SAUploadDocumentAPI {

    public class DocumentUploadException extends Exception {}

    @HttpPost
    global static void getCustomerDocuments() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        String requestId = String.valueOf(UUID.randomUUID());
        res.addHeader('Content-Type', 'application/json'); 

        try {
            if (req.requestBody == null) {
                throw new DocumentUploadException('Missing Request Body Payload.');
            }

            UploadDocumentRequest obj_UploadDocumentRequest = (UploadDocumentRequest) System.JSON.deserialize(
                req.requestBody.toString(), 
                UploadDocumentRequest.class
            );
            System.debug('OIC_SAUploadDocumentAPI >>>> ' + System.JSON.serialize(obj_UploadDocumentRequest));
            
            validateIncomingPayload(obj_UploadDocumentRequest);
            
            String formattedFileName = obj_UploadDocumentRequest.FileName + '.' + obj_UploadDocumentRequest.FileType;

            ContentVersion cv = new ContentVersion(
                Title = formattedFileName,
                PathOnClient = formattedFileName,
                VersionData = EncodingUtil.base64Decode(obj_UploadDocumentRequest.FileBase64Content)
            );
            Database.insert(cv, AccessLevel.USER_MODE);
            
            Id contentDocumentId = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :cv.Id 
                LIMIT 1
            ].ContentDocumentId;
            
            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = obj_UploadDocumentRequest.DocumentId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            Database.insert(cdl, AccessLevel.USER_MODE);

            List<Documents__c> lst_Documents = [
                SELECT Id, SalesOrder__c 
                FROM Documents__c 
                WHERE Id = :obj_UploadDocumentRequest.DocumentId
                WITH USER_MODE
                LIMIT 1
            ]; 

            if (!lst_Documents.isEmpty()) {
                Documents__c obj_Doc = lst_Documents.get(0);
                
                Pattern milestonePattern = Pattern.compile('(?i)MILESTONE(\\d+)');
                Matcher milestoneMatcher = milestonePattern.matcher(obj_UploadDocumentRequest.FileName);
                String milestoneNumber = '';
                
                if (milestoneMatcher.find()) {
                    milestoneNumber = milestoneMatcher.group(1); 
                }
                
                if (String.isNotBlank(milestoneNumber)) {
                    Double dblMilestone = Double.valueOf(milestoneNumber);

                    List<SalesOrderInstallments__c> lst_SOI = [
                        SELECT Id 
                        FROM SalesOrderInstallments__c 
                        WHERE SalesOrder__c = :obj_Doc.SalesOrder__c 
                          AND MilestoneNumber__c = :dblMilestone
                        WITH USER_MODE
                        LIMIT 1
                    ];

                    if (!lst_SOI.isEmpty()) {
                        sendEmailNotification(lst_SOI.get(0).Id, cv.Id);
                    }
                }
            }
              
            UploadDocumentResponse obj_UploadDocumentResponse = new UploadDocumentResponse();
            obj_UploadDocumentResponse.Status = 'Success';

            APIResponse response = new APIResponse('success', requestId, obj_UploadDocumentResponse, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.statusCode = 200;

        } catch (DocumentUploadException due) {
            System.debug(LoggingLevel.WARN, 'Business Validation Warning: ' + due.getMessage());
            UploadDocumentResponse errorRes = new UploadDocumentResponse();
            errorRes.Status = 'Failure';
            errorRes.ErrorCode = 'FU-001';
            errorRes.ErrorMessage = due.getMessage();

            APIResponse response = new APIResponse('error', requestId, errorRes, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.statusCode = 200; 

        } catch (Exception exe) {
            System.debug(LoggingLevel.ERROR, 'Global Runtime Exception: ' + exe.getMessage() + ' at line: ' + exe.getLineNumber());
            LoggerService.save(LoggerService.createApexLog(
                exe,
                'SA Upload Document API',
                'OIC_SAUploadDocumentAPI',
                'getCustomerDocuments'
            ));
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + exe.getMessage(), 200); 
        }        
    }

    public static void sendEmailNotification(Id soiId, Id contentVersionId) {
        String emailTemplateName = 'Payment_Notification_SOI_Online';
        String custEmail = System.Label.PaymentNotificationMC;
        
        System.enqueueJob(new SendGridNotificationUtilityQueueable(
            null, null, emailTemplateName, custEmail, 'noreply@modon.com',
            'Modon Connect', null, null, 'Payment Notification', 'Collection Update',
            null, new List<Id>{contentVersionId}, soiId
        ));
    }

    private static void validateIncomingPayload(UploadDocumentRequest req) {
        if (req == null) {
            throw new DocumentUploadException('Invalid request payload structure.');
        }
        if (String.isBlank(req.FileName) || String.isBlank(req.DocumentId) || String.isBlank(req.FileBase64Content)) {
            throw new DocumentUploadException('Error while uploading the file: Missing mandatory properties (FileName, DocumentId, FileBase64Content).');
        }
    }
    
    global class UploadDocumentRequest {
        public String FileName;
        public String FileType;
        public String FileBase64Content;
        public String DocumentId;        
    }
    global class UploadDocumentResponse {
        public String Status;
        public String ErrorCode;
        public String ErrorMessage;        
    }
}