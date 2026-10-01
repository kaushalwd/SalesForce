@isTest
public class SubmitEOIEgyptControllerTest {

    @isTest 
    static void myTestMethod(){
        
        Account acc = new Account();
        acc.name = 'test acc';
        insert acc;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        //oppObj.Account = acc.Id;
        oppObj.Source_Entity__c = 'Modon - Egypt';
        INSERT oppObj;
        
        Expressionofinterest__c eoiObj = new Expressionofinterest__c();
        eoiObj.Opportunity__c = oppObj.Id;
        INSERT eoiObj;

        Invoice__c inv = new Invoice__c();
        inv.Account__c = acc.Id;
        inv.Expressionofinterest__c = eoiObj.Id;
        inv.InvoiceAmount__c  =100;
        //inv.AppliedAmount__c = 100;
        insert inv;
        
         Allocation__c alloc = new Allocation__c();
        alloc.AllocationAmount__c = 100;
        alloc.Invoice__c = inv.Id;
        
        SubmitEOIEgyptController.RequestWrap reqWrap = new SubmitEOIEgyptController.RequestWrap();
        reqWrap.eoiId = eoiObj.Id;
        
        Test.startTest();
            // Check submission eligibility
            SubmitEOIEgyptController.RespondWrap resp = SubmitEOIEgyptController.eoiSubmissionCheck(eoiObj.Id);
            System.debug(resp.result);
            // Submit the EOI
        	SubmitEOIEgyptController.submitEoi(JSON.serialize(reqWrap));
        Test.stopTest();
        System.assertEquals('Please upload the required signed documents: KYC and Wealth Form', resp.result, 'Validation Message');
    }
}