/**
* @description       : Community/Portal Get Notificaion
* @author            : Manoj
* @last modified on  : 29-05-2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       29 May 2025    		Initial Draft 
* 2.0 			Manoj			   13 Oct 2025    		Update Responce
* 3.0           Manoj              11 Nov 2025          Token-based request validation implemented.
*                                                       The token is included in the request and validated during processing.
*                                                       If the token is valid, the request is authorized and a successful
*                                                       response is returned; otherwise, the request is rejected with
*                                                       an appropriate error response. Error Code
*4.0           Manoj               10 Jan 2026          Add Case Notification.
*5.0		   Manoj			   12 Jan 2026			Add the Case Created Date.
*6.0		   Manoj			   13 Jan 2026			Add/Remove the Case status in Soql.
**/
@RestResource(urlMapping='/CustomerPortalNotificaionAPI/*')
global class CustomerPortalNotificaionAPI {
    
    @HttpGet
    global static void getNotificaion() {
        // Get REST request and response context
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        list<PortalNotification> notifMessage=new list<PortalNotification>();
        try {
            String userName = req.params.get('userName'); 
            String Access_token = req.params.get('token'); // 3.0 Token passed in request parameters
            if (String.isBlank(userName) ) {
                returnError(res, requestId, 'Missing user creds parameter', 200);
                return;
            }else{  // 3.0 Validate token presence
                Boolean isValidtoken = false;
                if(String.isBlank(Access_token)){
                    returnError(res, requestId, 'Missing Toke parameter', 200);
                    return;
                }else{ // Validate token using TokenValidator utility
                    isValidtoken =TokenValidator.isTokenValid(Access_token,null);
                }
                // Process request only if token is valid
                if(isValidtoken){ 
                    notifMessage =getThisMonthsNotifications(userName);
                    // Return error if no notifications found
                    if (notifMessage.size() ==0) {
                        returnError(res, requestId, 'There is not Notification', 200);
                        return;
                    }
                }else{   // Return error response if token validation fails
                    returnErrorAPI.returnError(res, requestId, 'Token validation failed. Please log in again.', 200);
                    return;
                }
            } // Build success response
            APIResponse response = new APIResponse('success', requestId, notifMessage, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            
        } catch (Exception ex) {
            // Return generic server error response
            LoggerService.save(LoggerService.createApexLog(ex, 'Customer Portal API', 'CustomerPortalUserAPI', 'findUser'));
            returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
    // Fetch generic server error response
    private static void returnError(RestResponse res, String requestId, String msg, Integer status) {
        APIResponse error = new APIResponse('error', requestId, null, msg);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
        res.statusCode = status;
    }   
    // Fetch portal notifications for the current month
    public static List<PortalNotification> getThisMonthsNotifications(string eamil) {
        Date startOfMonth = Date.today().toStartOfMonth();
        Date endOfMonth = startOfMonth.addMonths(1);
        // 4.0 Strt add Notification Wrapper and logic
        list<PortalNotification> portalNotificationWrapper =new list<PortalNotification>();
        for(Portal_Notification__c notifications: [SELECT id,Name, Event_Date_Time__c, Event_Description__c   FROM Portal_Notification__c WHERE Event_Date_Time__c >= :startOfMonth AND Event_Date_Time__c < :endOfMonth ORDER BY Event_Date_Time__c ASC]){
            PortalNotification newNotWrapper=new PortalNotification();
            newNotWrapper.notificationNumber = notifications.Name;
            newNotWrapper.comments =notifications.Event_Description__c;
            newNotWrapper.status = 'Open';
            newNotWrapper.notificationType = 'Event';
            portalNotificationWrapper.add(newNotWrapper);
        }
          // Case Notifications // 6.0 Add Status
        for(case caseRec : [select id,CaseNumber,Status,Subject,Comments,CreatedDate  from Case where Customer_Email__c=:eamil and Origin ='Customer Portal' ORDER BY CreatedDate DESC]){
             PortalNotification newCaseNotiy=new PortalNotification();
             newCaseNotiy.notificationNumber = caseRec.CaseNumber;
             newCaseNotiy.comments =caseRec.Comments;
             newCaseNotiy.status = caseRec.Status;
             newCaseNotiy.subject = caseRec.Subject;
             newCaseNotiy.notificationType ='Case';
             // 5.0 start Add the createdDate
             DateTime createdDate = caseRec.CreatedDate; 
             String caseDate = createdDate.format('dd MMM yyyy');
             System.debug('caseDate---- ' + caseDate);
             newCaseNotiy.createdDate=caseDate;
             //5.0 End
             portalNotificationWrapper.add(newCaseNotiy);
        } //4.0 End
        return portalNotificationWrapper;
    }
     //4.0 Response Wrapper for Notification
    public class PortalNotification{
        public String notificationNumber;
        public String comments;
        public String subject;
        public String status;
        public string notificationType;
        public string createdDate; // 5.0 Add the createdDate
    }   
}