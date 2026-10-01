/**
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Suresh   	       05 March 2026        Initial Draft
* 1.1			Suresh			   31 July  2026		Datetime updated	
**/
@RestResource(urlMapping='/CustomerNotificaionAPI/*')
global class CustomerNotificaionAPI {
    
    @HttpGet
    global static void getNotificaion() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        list<CustomerNotification> notifMessage=new list<CustomerNotification>();
        try {
            String userName = req.params.get('CustomerEmail'); 
            if (String.isBlank(userName) ) {
                returnError(res, requestId, 'Missing User Email Parameter', 200);
                return;
            }else{  
                    notifMessage =getThisMonthsNotifications(userName);
                    if (notifMessage.size() ==0) {
                        returnError(res, requestId, 'There is not Notification', 200);
                        return;
                    }
            } 
            APIResponse response = new APIResponse('success', requestId, notifMessage, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(ex, 'Customer Notification API', 'CustomerNotificationAPI', 'getNotificaion'));
            returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
    private static void returnError(RestResponse res, String requestId, String msg, Integer status) {
        APIResponse error = new APIResponse('error', requestId, null, msg);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
        res.statusCode = status;
    }   
    public static List<CustomerNotification> getThisMonthsNotifications(string eamil) {
        Date startOfMonth = Date.today().toStartOfMonth();
        Date endOfMonth = startOfMonth.addMonths(1);
        list<CustomerNotification> customerNotificationWrapper =new list<CustomerNotification>();
        for(Portal_Notification__c notifications: [SELECT id,Name, Event_Date_Time__c, Event_Description__c   
                                                   FROM Portal_Notification__c WHERE Event_Date_Time__c >= :startOfMonth AND Event_Date_Time__c < :endOfMonth ORDER BY Event_Date_Time__c ASC]){
            CustomerNotification newNotWrapper=new CustomerNotification();
            newNotWrapper.NotificationNumber = notifications.Name;
            newNotWrapper.Comments =notifications.Event_Description__c;
            newNotWrapper.Status = 'Open';
            newNotWrapper.NotificationType = 'Event';
            customerNotificationWrapper.add(newNotWrapper);
        }
        for(case caseRec : [select id,CaseNumber,Status,Subject,Comments,CreatedDate,
                            CaseCategory__c, CaseSubCategory__c, New_Owner__r.Name, Unit__r.Name, ClosedDate, Description
                            from Case where Customer_Email__c=:eamil ORDER BY CreatedDate DESC]){
             CustomerNotification newCaseNotiy=new CustomerNotification();
             newCaseNotiy.NotificationNumber = caseRec.CaseNumber;
             newCaseNotiy.Comments =caseRec.Description;
             newCaseNotiy.Status = caseRec.Status;
             newCaseNotiy.Subject = caseRec.Subject;
             newCaseNotiy.NotificationType ='Case';
             //1.1 changes                   
             //DateTime createdDate = caseRec.CreatedDate; 
             //String caseDate = createdDate.format('dd MMM yyyy');
             //System.debug('caseDate---- ' + caseDate);
             newCaseNotiy.CreatedDate=caseRec.CreatedDate!=null?String.valueOf(caseRec.CreatedDate):'';
             //DateTime completedDate = caseRec.ClosedDate; 
             //String caseCompleteDate = completedDate!=null?completedDate.format('dd MMM yyyy'):'';
             //System.debug('>>>>   ' + caseCompleteDate);
             newCaseNotiy.CompletedDate=caseRec.ClosedDate!=null?String.valueOf(caseRec.ClosedDate):'';
             newCaseNotiy.Category = caseRec.CaseCategory__c;
             newCaseNotiy.Subcategory = caseRec.CaseSubCategory__c;
             newCaseNotiy.Property = caseRec.Unit__c!=null?caseRec.Unit__r.Name:'';
             newCaseNotiy.Owner = caseRec.New_Owner__r.Name; 
             newCaseNotiy.ExpectedResponseDate = '';                       
             customerNotificationWrapper.add(newCaseNotiy);
        }
        for(ServiceRequest__c obj_SR : [SELECT Id, Comments__c, Name,Status__c, CreatedDate, UnitId__r.Name, 
                            			 Owner.Name, CloseDate__c, RecordType.Name, SalesOrder__r.Name, SalesOrder__r.Unit__r.Name, 
                                         SalesOrder__r.ProjectName__c 
                                         from ServiceRequest__c 
                                         where AccountId__r.PersonEmail = :eamil ORDER BY CreatedDate DESC]){
             CustomerNotification newCaseNotiy=new CustomerNotification();
             String serviceName =  obj_SR.Name;                               
             if(String.isNotBlank(obj_SR.SalesOrder__r.Name)){
                serviceName = serviceName + ' '+ obj_SR.SalesOrder__r.Name;                                 
             } 
             if(String.isNotBlank(obj_SR.SalesOrder__r.Unit__r.Name)){
                serviceName = serviceName + ' '+ obj_SR.SalesOrder__r.Unit__r.Name;                                 
             }
             if(String.isNotBlank(obj_SR.SalesOrder__r.ProjectName__c)){
                serviceName = serviceName + ' '+ obj_SR.SalesOrder__r.ProjectName__c;                                 
             }                                
             newCaseNotiy.NotificationNumber = serviceName;
             newCaseNotiy.Comments =obj_SR.Comments__c;
             newCaseNotiy.Status = obj_SR.Status__c;
             newCaseNotiy.Subject = obj_SR.RecordType.Name;
             newCaseNotiy.NotificationType ='Support Requests';
             //1.1 changes                                  
             //DateTime createdDate = obj_SR.CreatedDate; 
             //String srDate = createdDate.format('dd MMM yyyy');
             //System.debug('>>>>   ' + srDate);
             newCaseNotiy.CreatedDate=obj_SR.CreatedDate!=null?String.valueOf(obj_SR.CreatedDate):'';
             //DateTime completedDate = obj_SR.CloseDate__c; 
             //String srCompleteDate = completedDate!=null?completedDate.format('dd MMM yyyy'):'';
             //System.debug('>>>>   ' + srCompleteDate);
             newCaseNotiy.CompletedDate=obj_SR.CloseDate__c!=null?String.valueOf(obj_SR.CloseDate__c):''; 
             newCaseNotiy.Category = 'Service Requests';
             newCaseNotiy.Subcategory = obj_SR.Name;
             newCaseNotiy.Property = obj_SR.UnitId__c!=null?obj_SR.UnitId__r.Name:'';
             newCaseNotiy.Owner = obj_SR.Owner.Name; 
             newCaseNotiy.ExpectedResponseDate = '';                                
             customerNotificationWrapper.add(newCaseNotiy);
        }
        return customerNotificationWrapper;
    }
    public class CustomerNotification{
        public String NotificationNumber;
        public String Comments;
        public String Subject;
        public String Status;
        public String NotificationType;
        public String CreatedDate; 
        public String Category;
        public String Subcategory;
        public String Property;
        public String Owner;
        public String CompletedDate;
        public String ExpectedResponseDate;
    }   
}