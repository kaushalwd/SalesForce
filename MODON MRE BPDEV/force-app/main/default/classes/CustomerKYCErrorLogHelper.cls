/**********************************************************************************************************************
* Name               : CustomerKYCErrorLogHelper                                                        
* Description        : This class is used to handle all the Signzy KYC Automation related Error Handling Logics
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0          dinesh.selvam@modon.com             28 Jan 2026     Initial Draft
* 2.0          dinesh.selvam@modon.com             08 Apr 2026     Commented code for bug fix
**********************************************************************************************************************/
public class CustomerKYCErrorLogHelper {
    public static String SUBJECT = System.label.SignzyKYCERRORSUBJECT;
    public static String TEMPLATE_NAME = System.label.SignzyKYCERRORTEMPLATENAME;
    public static String LINK = System.label.SIGNZYKYCERRORRECORDLINK;
    public static String toEmail;
    public static String ccEmail;
    public static String AccountName;
    public static String Owner ='Team';
    public static String kycrefno;
    public static String errormessage;
    public static String kycSendDate;
    public static String errorDate;
    public static String docType1;
    public static String docType2;
    public static String errorstatus;
    public static void logError(Id kycId,Id userId,string processName,string className,String methodName,Exception exc){
        logErrorHandler(kycId,userId,processName,className,methodName,exc,null);
    }
    public static void logErrorHandler(Id kycId,Id userId,string processName,string className,String methodName,Exception exc,string message){
        KYC_Response__c kyc = new KYC_Response__c();
        if(kycId <> null){ 
          kyc = [SELECT Id,Name,Customer__c,Contact__c,Contact__r.Name,Customer__r.Name,Contact__r.Owner.Name,Customer__r.Owner.Name,CreatedDate,KYC_Send_By__r.Email,KYC_Send_By__r.Name,
                 recordType.Name,Signzy_Journey_Message__c,Signzy_Journey_Status__c,Document_1_Message__c,Document_2_Message__c FROM KYC_Response__c WHERE Id =:kycId LIMIT 1];  
        }
        if(kyc <> null && kyc.KYC_Send_By__c <> null && kyc.KYC_Send_By__r.Email <> null){
            toEmail =  kyc.KYC_Send_By__r.Email; 
        }
       if(processName != 'Expiry Notification 2HR' && processName != 'Expiry Notification' && kyc.Signzy_Journey_Status__c != 'COMPLETED'){
            Logger__c newLog = new Logger__c();
            newLog.KYC_Response__c = kycId;
            if(exc <> null){
                Integer lineNumber = exc.getLineNumber();
                newLog.LineNumber__c = lineNumber;
                newLog.Message__c = exc.getMessage(); 
                newLog.ExceptionMessage__c = exc.getMessage();
                
                errormessage = 'Apex Error- ClassName:'+className+', Error Message:'+exc.getMessage()+'; Line Number: '+exc.getLineNumber();
            }else if(message <> null){
                 newLog.ExceptionMessage__c = message;
            }else{
                newLog.ExceptionMessage__c = kyc.Signzy_Journey_Message__c;
            }
            newLog.ExecutingProcessName__c = processName;
            newLog.ClassName__c = className;
            newLog.MethodName__c = methodName;
            insert newLog;
       }
        if(userId <> null){
           toEmail = [SELECT Id,Email FROM User WHERE Id=:userId].Email; 
        }
        if(kyc.Signzy_Journey_Status__c == 'COMPLETED'){
              TEMPLATE_NAME = System.label.SIGNZY_COMPLETED_KYCERRORTEMPLATENAME;
              SUBJECT = System.label.SIGNZY_COMPLETED_KYCERRORSUBJECT;
        }
        if(processName == 'Expiry Notification 2HR'){
            TEMPLATE_NAME = System.label.SIGNZY_EXPIRY_REMINDER_KYCERRORTEMPLATENAME; 
            SUBJECT = System.label.SIGNZY_EXPIRY_REMINDER_KYCERRORSUBJECT;
        }if(processName == 'Expiry Notification'){
            TEMPLATE_NAME = System.label.SIGNZY_EXPIRIED_REMINDER_KYCERRORTEMPLATENAME;  
            SUBJECT = System.label.SIGNZY_EXPIRIED_REMINDER_KYCERRORSUBJECT;
        }
         // Load the email template
            EmailTemplate template = [
                SELECT Id, HtmlValue
                FROM EmailTemplate
                WHERE DeveloperName =: TEMPLATE_NAME
                LIMIT 1
            ];
            if(kyc <> null && kyc.RecordType.Name == 'Corporate KYC'){
                AccountName = kyc.Contact__r.Name;
               // Owner = kyc.KYC_Send_By__r.Name;
                LINK +='Contact/'+kyc.Contact__c+'/view';
            }else if(kyc <> null){
               AccountName = kyc.Customer__r.Name;
             //  Owner = kyc.KYC_Send_By__r.Name; 
               LINK +='Account/'+kyc.Customer__c+'/view';
            }
            
            kycrefno =  kyc<>null? kyc.Name : 'Error';
            if(errormessage == null){
                errormessage = kyc<>null && kyc.Signzy_Journey_Message__c <> null ? kyc.Signzy_Journey_Message__c : '';
            }
            if(errormessage <> null && errormessage.containsIgnoreCase('DUPLICATE')){
                errormessage = 'DUPLICATES DETECTED: an account with these details (Emirates ID or Passport) already exists in our system.';
            }
            if(errormessage <> null && errormessage.containsIgnoreCase('APEX')){
                errormessage = 'There is an Issue, Kindly check with IT Support Team.';
            }
            kycSendDate = kyc<>null? kyc.CreatedDate.format():system.today().format();
            errorDate = System.today().format();
            errorstatus = kyc.Signzy_Journey_Status__c <> null ? kyc.Signzy_Journey_Status__c : '';
            docType1 = kyc.Document_1_Message__c <> null ? kyc.Document_1_Message__c : '';
            docType2 = kyc.Document_2_Message__c <> null ? kyc.Document_2_Message__c : '';
            String htmlValue = template.HtmlValue;
            htmlValue = htmlValue.replace('{!AccountName}', AccountName)
                    .replace('{!Owner}', Owner)
                    .replace('{!kycrefno}', kycrefno)
                    .replace('{!errorstatus}', errorstatus)
                    .replace('{!errormessage}', errormessage)
                    .replace('{!kycSendDate}', kycSendDate)
                    .replace('{!docType1}', docType1)
                    .replace('{!docType2}', docType2)
                    .replace('{detaillink}', LINK)
                    .replace('{!errorDate}', errorDate);
        
        sendEmail(SUBJECT,htmlValue,toEmail);
    }
    public static void sendEmail(String subject,String htmlValue,String toAddress){
        
        OrgWideEmailAddress owea = [
                    SELECT Id, Address, DisplayName
                    FROM OrgWideEmailAddress
                    WHERE Address = 'noreply@modon.com'
                    LIMIT 1
                ];
         Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        if(toAddress == null){
            toAddress = System.Label.SignzyErrorLogEmail; 
        }
        mail.setSaveAsActivity(false);
        mail.setCCAddresses(new String[] { System.Label.SignzyErrorLogEmail});
        mail.setToAddresses(new String[] { toAddress });
        mail.setSubject(subject);
        mail.setHtmlBody(htmlValue); 
        mail.setOrgWideEmailAddressId(owea.Id);

        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail }, false); // second param = allOrNone

        for (Messaging.SendEmailResult r : results) {
            System.debug('Email success? ' + r.isSuccess());
            if (!r.isSuccess()) {
                for (Messaging.SendEmailError e : r.getErrors()) {
                    System.debug('EMAIL ERROR: ' + e.getMessage() + ' | StatusCode: ' + e.getStatusCode());
                }
            }
        }
    }
    public class Input {
        @InvocableVariable public Id kycId;
        @InvocableVariable public Id userId;
        @InvocableVariable public String processName;
        @InvocableVariable public String className;
        @InvocableVariable public String methodName;
        @InvocableVariable public String errorMessage;
    }
    /** Error Causing Code Commented for the avoid the null pointer exception **/
    @InvocableMethod(label='KYC Log Error (Flow)')
    public static void logFromFlow(List<Input> inputs) {
       /* for (Input i : inputs) {
            CustomerKYCErrorLogHelper.logError(
                i.kycId, i.userId, i.processName, i.className, i.methodName,null
            );
        } */
    }
}