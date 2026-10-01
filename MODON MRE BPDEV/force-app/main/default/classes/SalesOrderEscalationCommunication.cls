/**********************************************************************************************************************
* Name               : SalesOrderEscalationCommunication                                                        
* Description        : This class is used to send the escalation email to managers
* Usage              : apex class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    13 01 2026     Initial Draft       
******************************************************************************************************************/
public without sharing class SalesOrderEscalationCommunication {

    public class EscalationRequest {
        @InvocableVariable(required=true)
        public String recordId;
        @InvocableVariable(required=true)
        public String emailIds;
        @InvocableVariable(required=true)
        public String templateName;
    }
    
    @InvocableMethod(label='SalesOrder Execution' description='SalesOrder Execution')
    public static void execute(List<EscalationRequest> requestId) {
        String emailTemplateName = requestId[0].templateName;
        String custEmail = requestId[0].emailIds; 
        System.debug('>>>>>>>>>>>>>>> emailTemplateName  custEmail >>  '+emailTemplateName+'    '+custEmail); 
        if(!String.isBlank(custEmail) && requestId != null && requestId.size() > 0){
            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,emailTemplateName,custEmail,'noreply@modon.com',
                                                           				  'MODON Sales Team',null,null,'SalesOrder','Customer Management',
                                                                           null,null,requestId[0].recordId));
        } 
    }     
}