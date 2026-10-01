public class HandoverQAInspectionValidaor  implements StepValidator {
    
     public void ValidateSteps(Business_Process_Step__c bpStep){
        
    AuraHandledException e = new AuraHandledException('exception');
        switch on bpStep.Name {
            when 'DLD Registration Process Initiation' {
                
            }
             when else {
                //throw new AuraHandledException('Input cannot be blank.');
            }  
                
        }
            
            
      }

}