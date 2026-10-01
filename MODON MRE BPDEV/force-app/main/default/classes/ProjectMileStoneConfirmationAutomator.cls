/**********************************************************************************************************************
* Name               :  ProjectMileStoneConfirmationAutomator                                                       
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class ProjectMileStoneConfirmationAutomator implements BusinessProcessAutomation {

    public void executeAutomation(BusinessProcessAutomationInput input) {
       Set<Id> bpIds=new Set<Id>();
       Map<Id,Id> stepIdByBpId=new Map<Id,Id>();
         for (Business_Process_Step__c step : input.steps) {
            switch on step.Name {
                when 'CM Execute Milestone Update', 'Execute Milestone Update' {
					 if (step.Status__c == 'Completed') {
                      bpIds.add(step.business_Process__c);
                      stepIdByBpId.put(step.business_Process__c, step.Id);

					 }

				}
			}
	      }

	if(bpIds.size()>0){
	   List<Milestone__c> miles=new List<Milestone__c>();
	   Set<Id> milesIds=new Set<Id>();
	   Map<Id,Id> milestoneIdByBpId=new Map<Id,Id>();
	   List<Id> mileStoneIdsToReadniess=new List<Id>();
	   List<Business_Process_Step__c> stepsToEnd=new List<Business_Process_Step__c>();
	 for(Business_Process__c bp:[Select Id, Milestone__c, MileStone_Confirmation_Date__c,MileStone_Extension_Date__c from Business_Process__c where Id IN: bpIds]){
          Milestone__c mil=new Milestone__c();
		  milesIds.add(bp.Milestone__c);
		  milestoneIdByBpId.put(bp.Id, bp.Milestone__c);
		  mil.Id=bp.Milestone__c;
		  if(bp.MileStone_Confirmation_Date__c!=null){
              mil.ConfirmedMilestoneDate__c=bp.MileStone_Confirmation_Date__c;
              mileStoneIdsToReadniess.add(mil.Id);
          } else  {
              mil.Milestone_Due_Date__c =bp.MileStone_Extension_Date__c;
          }
		  miles.add(mil);

		  // Milestone Extension Date present: "CM Execute Milestone Update" is the final action
		  // for this Business Process, so end this step here (same approach as
		  // UnitCancellationReleaseAutomator / DefaultAndTerminationAutomater). The framework
		  // (DefaultActivator / BusinessProcessStepTriggerHandler) then skips opening the next
		  // step and closes the Business Process automatically.
		  if(bp.MileStone_Extension_Date__c!=null && stepIdByBpId.containsKey(bp.Id)){
              stepsToEnd.add(new Business_Process_Step__c(Id=stepIdByBpId.get(bp.Id), Is_Process_End__c=true));
          }
	 }

      if(miles.size()>0)
     {
       update miles;
     }

	 // One batch per Business Process so the batch can filter installments
	 // by that Business Process's Phase.
	 for(Id bpId : milestoneIdByBpId.keySet()){
	   Database.executeBatch( new UpdateMilestoneWithDatesBatch(new Set<Id>{ milestoneIdByBpId.get(bpId) }, bpId),1);
	 }

	 if(stepsToEnd.size()>0){
	   update stepsToEnd;
	 }
	// List<Process_Flow__c> pf=[Select Id from Process_Flow__c where Name='MileStone Payment Readiness' LIMIT 1];
    
	// if(mileStoneIdsToReadniess.size()>0 && pf.size()>0 && !Test.isRunningTest())
        //CreateBusinessProcess.createPreRegistration(mileStoneIdsToReadniess[0], pf[0].Id);
	 }
	
	}

}