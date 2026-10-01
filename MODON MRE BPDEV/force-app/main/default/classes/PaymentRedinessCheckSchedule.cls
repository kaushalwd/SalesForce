public class PaymentRedinessCheckSchedule implements Schedulable {
 

	
	 public void execute(SchedulableContext sc) {
        processSteps();
		processSteps2();
    }

	   public static void processSteps2() {

        Date today = Date.today();
		today=today.addDays(-10);

        // Step 1: Get eligible Business Processes
        List<Business_Process__c> bpList = [
            SELECT Id,Current_Business_Process_Step__c
            FROM Business_Process__c
            WHERE Type__c = 'Mile Stone Readiness Check'
            AND Status__c = 'In Progress'
            AND Current_Business_Process_Step__r.Sequence__c = 2
            AND Milestone__r.ConfirmedMilestoneDate__c  = :today
        ];

		  if(bpList.isEmpty()) return;
		  List<Business_Process_Step__c> updates = new List<Business_Process_Step__c>();

		  for(Business_Process__c bp:bpList){
			Business_Process_Step__c bstep=new Business_Process_Step__c();
			bstep.Id=bp.Current_Business_Process_Step__c;
			bstep.Status__c = 'Completed';
			updates.add(bstep);
		  }

		  if(updates.size()>0)
		  update updates;


	   }

    public static void processSteps() {

        Date today = Date.today();

        // Step 1: Get eligible Business Processes
        List<Business_Process__c> bpList = [
            SELECT Id
            FROM Business_Process__c
            WHERE Type__c = 'Mile Stone Readiness Check'
            AND Status__c = 'In Progress'
            AND Current_Business_Process_Step__r.Sequence__c = 1
            AND Milestone__r.ConfirmedMilestoneDate__c  = :today
        ];

        if(bpList.isEmpty()) return;

        Set<Id> bpIds = new Set<Id>();
        for(Business_Process__c bp : bpList){
            bpIds.add(bp.Id);
        }

        // Step 2: Fetch Step records (only step 1 & 2)
        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Business_Process__c,
                   Sequence__c,
                   Status__c
            FROM Business_Process_Step__c
            WHERE Business_Process__c IN :bpIds
            AND Sequence__c IN (1,2)
        ];

        // Step 3: Map steps by BP
        Map<Id, Business_Process_Step__c> step1Map = new Map<Id, Business_Process_Step__c>();
        Map<Id, Business_Process_Step__c> step2Map = new Map<Id, Business_Process_Step__c>();

        for(Business_Process_Step__c st : steps){
            if(st.Sequence__c == 1){
                step1Map.put(st.Business_Process__c, st);
            }
            if(st.Sequence__c == 2){
                step2Map.put(st.Business_Process__c, st);
            }
        }

        List<Business_Process_Step__c> updates = new List<Business_Process_Step__c>();

        // Step 4: Apply transitions
        for(Id bpId : bpIds){

            // STEP 1 → Completed
            if(step1Map.containsKey(bpId)){
                Business_Process_Step__c s1 = step1Map.get(bpId);
                s1.Status__c = 'Completed';
                updates.add(s1);
            }

            // STEP 2 → Open
            if(step2Map.containsKey(bpId)){
                Business_Process_Step__c s2 = step2Map.get(bpId);
                s2.Status__c = 'Open';
                updates.add(s2);
            }
        }

        // Step 5: Bulk update
        if(!updates.isEmpty()){
            update updates;
        }
    }
}