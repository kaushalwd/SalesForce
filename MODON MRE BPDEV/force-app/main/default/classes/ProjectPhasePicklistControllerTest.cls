@IsTest
public class ProjectPhasePicklistControllerTest {

	@testSetup
	static void setup() {

        Project__c project = new Project__c(Name = 'Test Project',Total_Units__c = 5);
        insert project;
        
        // Recreate all prerequisite data in the same standardized way
        Phase__c ph = new Phase__c(Name = 'Else Phase', Project__c=project.id,EntityName__c='Hudayriyat Development - L.L.C- O.P.C');
        insert ph;
        
        Phase__c ph1 = new Phase__c(Name = 'Else Phase1', Project__c=project.id,EntityName__c='Hudayriyat Development - L.L.C- O.P.C');
        insert ph1;
         
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        
        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name = 'Test account';
        vaObj.Status__c = 'Available';
        vaObj.EscrowAccount__c = escAccount.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c = 'AE3456789456789';
        INSERT vaObj;
        string options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Exterior","picklistApiName":"Exterior__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Interior","picklistApiName":"Interior__c"}]';
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        phase.EscrowAccount__c =escAccount.id;
        phase.PhaseOptions__c =options;
        insert phase;	
	}

    @IsTest
    static void testGetPhases() {
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        Test.startTest();
        list<Project__c> rstls = ProjectPhasePicklistController.getProjects('Hudayriyat Development - L.L.C- O.P.C');
        List<Phase__c> result = ProjectPhasePicklistController.getPhases(project.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetPhases_NoResults() {
        Project__c newProject = new Project__c(Name = 'Test Project');
        insert newProject;

        Test.startTest();
        list<Project__c> rstls = ProjectPhasePicklistController.getProjects('Hudayriyat Development - L.L.C- O.P.C');
        List<Phase__c> result = ProjectPhasePicklistController.getPhases(newProject.Id);
        Test.stopTest();

    }


}