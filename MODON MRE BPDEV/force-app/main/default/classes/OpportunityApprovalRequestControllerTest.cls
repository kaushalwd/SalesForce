@IsTest
public class OpportunityApprovalRequestControllerTest {

        @isTest 
    static void myTestMethod(){
        
        Opportunity opp = new Opportunity();
        opp.Name = 'Test';
        opp.StageName = 'Unit selection in progress';
        opp.CloseDate = System.Today();
        INSERT opp;

        
        Documents__c docObj = new Documents__c();
        docObj.Name = 'Test';
        docObj.Opportunity__c = opp.Id;
        INSERT docObj;
        
        OpportunityApprovalRequestController.RequestWrap reqWrap = new OpportunityApprovalRequestController.RequestWrap();
        reqWrap.oppId = opp.Id;
        test.startTest();
        	OpportunityApprovalRequestController.checkCondsAndSubmitApproval(JSON.Serialize(reqWrap));
                	OpportunityApprovalRequestController.submitForApproval(JSON.Serialize(reqWrap));

        
        test.stoptest();
    }
}