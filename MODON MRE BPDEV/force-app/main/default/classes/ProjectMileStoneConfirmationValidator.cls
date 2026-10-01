/**********************************************************************************************************************
* Name               :   ProjectMileStoneConfirmationValidator                                                      
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class ProjectMileStoneConfirmationValidator implements StepValidator {
    
     public void ValidateSteps(Business_Process_Step__c bpStep){
        
    AuraHandledException e = new AuraHandledException('exception');
        switch on bpStep.Name {
            when 'Project Team to Confirm Date' {
             Business_Process__c businessProcess=[Select Id,MileStone_Confirmation_Date__c,Milestone__r.Milestone_Due_Date__c,MileStone_Extension_Date__c  from Business_Process__c where
                                  Id =:bpStep.Business_Process__c ];
                if(businessProcess.MileStone_Confirmation_Date__c==null && businessProcess.MileStone_Extension_Date__c==null ){
                   throw new AuraHandledException('Please provide Confirm Date or Extension Date!!');  
                }
				if(businessProcess.MileStone_Confirmation_Date__c!=null && businessProcess.MileStone_Extension_Date__c!=null ){
                   throw new AuraHandledException('Please provide Confirm Date or Extension Date Only!!');  
                }
                if(businessProcess.Milestone__r.Milestone_Due_Date__c!=null && businessProcess.MileStone_Confirmation_Date__c!=null && 
                businessProcess.Milestone__r.Milestone_Due_Date__c!=businessProcess.MileStone_Confirmation_Date__c){
                   throw new AuraHandledException('Confirmation should be always equal to MileStone Date');   
                }

                if(businessProcess.MileStone_Extension_Date__c!=null && businessProcess.MileStone_Extension_Date__c > businessProcess.Milestone__r.Milestone_Due_Date__c
                  ){
                   throw new AuraHandledException('Extension Date is always greater than Milestone Due date!!');   
                }

		    List<Business_Process_Documents__c> bpExtensionList=[  SELECT Id, Name, Business_Process__c, (Select Id from ContentDocumentLinks)
            FROM Business_Process_Documents__c where Business_Process__c=:bpStep.Business_Process__c  and Name='Extension Memo']	;
			List<Business_Process_Documents__c> bpCertList=[  SELECT Id, Name, Business_Process__c, (Select Id from ContentDocumentLinks)
            FROM Business_Process_Documents__c where Business_Process__c=:bpStep.Business_Process__c  and Name='Milestone confirmation Certificate']	;
			if(businessProcess.MileStone_Confirmation_Date__c!=null && bpCertList.size()>0 && bpCertList[0].ContentDocumentLinks.size()==0 )
			throw new AuraHandledException('Please add the MileStone Certificate Document'); 

			if(businessProcess.MileStone_Extension_Date__c!=null && bpExtensionList.size()>0 && bpExtensionList[0].ContentDocumentLinks.size()==0 )
			throw new AuraHandledException('Please add the MileStone Extension Document'); 	
			
			}
			
			
             when else {
                //throw new AuraHandledException('Input cannot be blank.');
            }  
                
        }
            
            
      }

}