/**--------------------------------------------------------------------------------------------------------------------
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 05-13-2025
 * @last modified by  : Krishna Chaitanya
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Krishna            13 May 2025        Initial Draft 
* 2.0       	Suresh         08 Jan 2026        Case updated while creating the record
* 3.0           Manoj         13 Jan 2026      Update creating case bug
* 4.0			Ravi				10 Feb 2-26			Do not send recordtype during case creation
*--------------------------------------------------------------------------------------------------------------------*/
public without sharing class CommunityLoginController {
    @AuraEnabled
    public static string login(String username, String password) {
        try {
            String startUrl = System.Label.Customer_Portal_URL;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/';
            ApexPages.PageReference pageRef = Site.login(username, password, startUrl);
            if(pageRef != null){
                return pageRef.getUrl();
            } else{
                throw new CalloutException();
            }
            
        } catch (Exception e) {
            system.debug('e.getMessagelogin+   '+e.getMessage());
            throw new AuraHandledException(e.getMessage());
            
            //return null;
        }
    }
    @AuraEnabled
    public static String createUserLeadMethod(String firstName, String lastName, String email, String mobile){
        try{
            Lead leadObj = new Lead();
            leadObj.FirstName = firstName;
            leadObj.lastName = lastName;
            leadObj.Email = email;
            leadObj.MobilePhone = mobile;
            leadObj.LeadSource = 'Self Generated';
            insert leadObj;
            return 'Success';
        }catch (DmlException e) {
            String rawMessage = e.getMessage();
            System.debug(' Error Message: ' + rawMessage);
            
            // Try to clean it
            String validErrorMsg = rawMessage;
            
            if (rawMessage.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION,')) {
                // Extract after the custom validation
                Integer index = rawMessage.indexOf('FIELD_CUSTOM_VALIDATION_EXCEPTION,');
                validErrorMsg = rawMessage.substring(index + 'FIELD_CUSTOM_VALIDATION_EXCEPTION,'.length());
                
                
                // Remove anything after the colon :
                if (validErrorMsg.contains(':')) {
                    validErrorMsg = validErrorMsg.substring(0, validErrorMsg.indexOf(':')).trim();
                }
            }
            
            return 'Error! ' + validErrorMsg;
        }
    }
    @AuraEnabled
    public static String handleCaseCreation(String Subject, String issueDesc, String email, String mobile,boolean isGeneralCase){
        try{
            //2.0  added by suresh
             //String webCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Web Cases').getRecordTypeId(); // 4.0
             user resetUsers = [ SELECT Id, Email, Username,FirstName, EmiratesIDNumber__c,LastName,Street, City, 
                               State, Country, PostalCode,Phone,Contact.AccountId FROM User 
                               where Username = :email AND IsActive = TRUE limit 1];
            system.debug('isGeneralCase:'+isGeneralCase);
            Case caseObj = new Case();
            caseObj.Status = 'New';
            caseObj.Origin = label.CaseOriginCustomerPortal;
            caseObj.Subject = Subject;
            caseObj.Description = issueDesc;
            caseObj.SuppliedEmail = email;
            caseObj.SuppliedPhone = mobile;           
            caseObj.Requestor_Email__c = email;
            caseObj.Requestor_Phone__c = mobile;            
            caseObj.AccountId = resetUsers.Contact.AccountId;
            //caseObj.RecordTypeId = webCaseRecordTypeId; // 4.0
            caseObj.Requestor_Name__c = resetUsers!=null?resetUsers.FirstName+' '+resetUsers.LastName:email;
            if(!isGeneralCase){ // 3.0 Remove 
                if(Subject == 'Customer Care' || Subject == 'Property Transfer' || Subject == 'Financial Services' || Subject == 'Property Handover'){
                    caseObj.CaseCategory__c = 'Department Action';
                    caseObj.CaseSubCategory__c =Subject;
                }else {
                    caseObj.CaseCategory__c = 'Contact Details Update';
                    caseObj.CaseSubCategory__c = 'Contact Details Update';
                }
                               
            }else{
                caseObj.CaseCategory__c = 'General Enquiry';
                caseObj.CaseSubCategory__c = 'General Enquiry';
            }
            insert caseObj;
            String caseNumber = [SELECT Id,CaseNumber FROM Case WHERE Id =:caseObj.Id LIMIT 1 ].CaseNumber;
            //System.debug(' caseNumber: ' + caseNumber);
            return 'Your case created successfully! Here is your reference tracking number '+caseNumber;
        }catch (DmlException e) {
            String rawMessage = e.getMessage();
            System.debug(' Error Message: ' + rawMessage);
            
            // Try to clean it
            String validErrorMsg = rawMessage;
            
            if (rawMessage.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION,')) {
                // Extract after the custom validation
                Integer index = rawMessage.indexOf('FIELD_CUSTOM_VALIDATION_EXCEPTION,');
                validErrorMsg = rawMessage.substring(index + 'FIELD_CUSTOM_VALIDATION_EXCEPTION,'.length());
                
                // Remove anything after the colon :
                if (validErrorMsg.contains(':')) {
                    validErrorMsg = validErrorMsg.substring(0, validErrorMsg.indexOf(':')).trim();
                }
            }
            
            return 'Error! ' + validErrorMsg;
        }catch(Exception e){
            system.debug(e.getMessage());
            return 'Error! '+e.getMessage();
        }
    }
}