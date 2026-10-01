/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : paymentPlanChangeValidator
 * Author          : <YourName>
 * Created Date    : Aug 3, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Aug 3, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Aug 3, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class paymentPlanChangeValidator  implements StepValidator {
    
     public void ValidateSteps(Business_Process_Step__c bpStep){



       switch on bpStep.Name {
            when 'Initiate Request' {
             Business_Process__c bproc=[Select Id,Sales_Order__c from Business_Process__c where Id=:bpStep.Business_Process__c]; 

			  List<PaymentPlanChangeRequest__c> requestRec =[SELECT Id, Sales_Order__c, Sales_Order__r.CustomerAccount__c, Revised_Payment_Plan__c, Status__c
              FROM PaymentPlanChangeRequest__c WHERE Sales_Order__c = : bproc.Sales_Order__c LIMIT 1 ];  
               

			  if(requestRec.isEmpty() || (requestRec.size()>0 && requestRec[0].Status__c !='Draft' ))
			  throw new AuraHandledException('Please submit Payment Plan Change Request');  
			  

            
            }

            
            when 'Legal Discussions' {
                 
            }

             when else {

               
            }  
                
        }
            
            
      }


	 }