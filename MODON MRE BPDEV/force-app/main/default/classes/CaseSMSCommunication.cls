/***************************************************************************************************************
* Name               : CaseSmsCommunication
* Description        : Sends SMS notifications to customers (Owner or Visitor) when a Case is closed.
* Usage              : Called from CaseTriggerHelper.caseClosed()
* Created By         : Active Minds Global Solutions Pvt Ltd
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment
* 1.0           raghu.chilukuri@activemindsit.com    12 May 2026     Initial Draft - Case closure SMS notification
****************************************************************************************************************/
public without sharing class CaseSMSCommunication implements Queueable, Database.AllowsCallouts {
    
    private List<Case> casesToNotify;
    
    /**
* description : constructor for List of cases closed
*/
    public CaseSmsCommunication(List<Case> cases) {
        this.casesToNotify = cases;
    }
    
    /**
* description:
* for bulk callouts of sms
*/
    public void execute(QueueableContext context) {
        System.debug('debug: in CaseSmsCommunication.execute method');
        
        if (casesToNotify == null || casesToNotify.isEmpty()) {
            return;
        }
        
        HttpRequest req = new HttpRequest();
        req.setTimeout(120000);
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        
        if (!Test.isRunningTest()) {
            req = OIC_CredentialsController.getCredentials('CaseCommunicationApi');
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');
        }
        
        List<SmsApiRequest> payloadList = new List<SmsApiRequest>();
        
        for (Case cs : casesToNotify) {
            String phone = null;
            String customerName = null;
            
            if (cs.Customer_Type__c == ServiceConstants.CASE_CUSTOMER_TYPE_OWNER) {
                phone = cs.Customer_Phone__c;
                customerName = cs.Customer_Name__c;
            } else {
                phone = cs.Visitor_Phone__c;
                customerName = cs.Visitor_First_Name__c;
            }
            
            if (String.isBlank(phone)) {
                System.debug('debug: CaseSmsCommunication - skipping case ' + cs.CaseNumber + ', no phone found');
                continue;
            }
            string smsMessage = buildSmsMessage(cs);
            if(smsMessage != null)
            {
                SmsApiRequest reqObj = new SmsApiRequest();
                reqObj.CustomerName = String.isBlank(customerName) ? '' : customerName;
                reqObj.MobileNumber = phone;
                reqObj.TextMessage = smsMessage;
                reqObj.SendWhatsapp = false;
                reqObj.SendSMS = true;
                
                payloadList.add(reqObj);
                System.debug('debug: CaseSmsCommunication - prepared SMS for case ' + cs.CaseNumber);
            }
            else
            {
                System.debug('debug: CaseSmsCommunication - no SMS sent for case ' + cs.CaseNumber);
            }
        }
        
        if (payloadList.isEmpty()) {
            System.debug('debug: CaseSmsCommunication - no valid phone numbers found, skipping callout');
            return;
        }
        
        req.setBody(JSON.serialize(payloadList));
        
        if (!Test.isRunningTest()) {
            Http http   = new Http();
            HttpResponse response = http.send(req);
            System.debug('debug: CaseSmsCommunication response statusCode >>> ' + response.getStatusCode());
            System.debug('debug: CaseSmsCommunication response body    >>> ' + response.getBody());
        }
    }
    
    /**
* description : This is used to Build Sms Body
*/
    private String buildSmsMessage(Case cs) {
        string strMsg = '';
        strMsg = Label.Case_Closure_SMS_Message;
        strMsg = strMsg.replace('{!CaseNumber}',cs.CaseNumber.ToString());
        System.debug('debug: SMS Message >>> ' + strMsg);
        return strMsg;
        //return 'Dear Customer, your case ' + cs.CaseNumber + ' has been closed. '
        //   + 'Thank you for contacting us. If you have further queries, please reach out to us again.';
    }
    
    /**
* description : Wrapper for Sms request
*/
    
    public class SmsApiRequest {
        public String  CustomerName;
        public String  MobileNumber;
        public String  TextMessage;
        public Boolean SendWhatsapp;
        public Boolean SendSMS;
    }
    
}