public class HandoverQAInspectionAutomator implements BusinessProcessAutomation {
    
     public void executeAutomation( BusinessProcessAutomationInput input){
        
       for(Business_Process_Step__c step:input.steps){
            switch on step.Name {
                when 'DLD Completion with Payment' {
                    if(step.Status__c=='Completed'){
                        
                }
                }
                when else {
                    //throw new AuraHandledException('Input cannot be blank.');
                }
            }
        }
        
           
       }

}