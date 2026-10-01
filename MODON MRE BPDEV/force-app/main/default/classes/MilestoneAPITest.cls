@isTest
private class MilestoneAPITest {

    @testSetup
    static void setupData() {
        // 1. Create Project
        Project__c proj = new Project__c(Name = 'Test Project');
        insert proj;

        // 2. Create Phase
        Phase__c phase = new Phase__c(
            Name = 'Phase 1',
            Project__c = proj.Id
        );
        insert phase;

        // 3. Create Milestones
        List<Milestone__c> milestones = new List<Milestone__c>();
        milestones.add(new Milestone__c(
            Name = 'Foundation Work',
            Phase__c = phase.Id,
            Project__c = proj.Id,
            Milestone_Order__c = '1',
            Milestone_Due_Date__c = Date.today().addMonths(1),
            Construction_Progress__c = 10.0
        ));
        milestones.add(new Milestone__c(
            Name = 'Superstructure',
            Phase__c = phase.Id,
            Project__c = proj.Id,
            Milestone_Order__c = '2',
            Milestone_Due_Date__c = Date.today().addMonths(6),
            Construction_Progress__c = 40.0
        ));
        insert milestones;
    }

    @isTest
    static void testFindMilestoneDetailsSuccess() {
        Phase__c phase = [SELECT Id, Project__c FROM Phase__c LIMIT 1];
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestUri = '/services/apexrest/Milestone/';
        request.httpMethod = 'GET';
        request.params.put('PhaseId', phase.Id);
        request.params.put('ProjectId', phase.Project__c);
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        MilestoneAPI.findMilestoneDetails();
        Test.stopTest();
    }

    @isTest
    static void testMissingPhaseId() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.httpMethod = 'GET';
        // Missing PhaseId parameter
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        MilestoneAPI.findMilestoneDetails();
        Test.stopTest();
    }

    @isTest
    static void testNoDataFound() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        // Use a dummy Id for PhaseId
        request.params.put('PhaseId', 'a00000000000000AAA'); 
        request.httpMethod = 'GET';
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        MilestoneAPI.findMilestoneDetails();
        Test.stopTest();
    }

}