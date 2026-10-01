@isTest
public class ArabicTranslaitonUtils_Test {
    static TestMethod void runTest1(){
        Id prsnAccountRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        Account acctoinsert = New Account(RecordTypeId= prsnAccountRecTypeId,
                                        FirstName= 'Test FN-1',
                                        LastName='Test LN-1',
                                        PersonEmail= 'test-1@example.com',
                                        PersonMobilePhone = '+9711234422',
                                        EIDNumber__pc = '784-1232-1326457-9',
                                        PassportNumber__pc = '12344321',
                                        Nationality__pc = 'Japan');
        INSERT acctoinsert;
        
        acctoinsert.PassportIssuancePlace__pc= 'Japan';
        acctoinsert.Nationality__pc = 'United States';
        acctoinsert.FirstName= 'Test FN-2';
        update acctoinsert;

        Account acc = [SELECT Id, PersonContactId FROM Account WHERE Id=:acctoinsert.Id];
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.EIDNumber__c = '784-1996-3732188-7';
        oppObj.AccountId = acc.Id;
        oppObj.PrimaryContact__c = acc.PersonContactId;
        oppObj.BrokerAgentName__c = 'test broker';
        oppObj.Nationality__c = 'Japan';
        INSERT oppObj;
        
        PaymentInstallements__c payI = New PaymentInstallements__c (Name = 'Down Payment',
                                                                   MilestoneDate__c = System.Today(),
                                                                   MilestoneNumber__c = 1, 
                                                                   Milestone__c = 20,
                                                                   MilestoneDescription__c = 'Down Payment');
        
        SalesOrder__c so = new SalesOrder__c();
        so.Opportunity__c = oppObj.Id;
        so.CustomerAccount__c = acc.Id;
        so.Totalamountinwords__c = 'NINETEEN MILLION ONE HUNDRED SEVENTY-TWO THOUSAND SIX HUNDRED EIGHTY-TWO DIRHAMS ONLY.';
        so.TotalAmount__c = 13246354.50;
        insert so;
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        soi.PaymentInstallments__c = payI.Id;
        soi.MilestoneNumber__c = 1;
        soi.MilestoneDescription__c = 'Down Payment';
        insert soi;
        try{
            Test.startTest();
            Test.setMock(HttpcalloutMock.class, New TransationMockHttpResponse());
            ArabicTranslaitonUtils.initiateCallout(New List<Id>{so.Id});
            Test.stopTest();
        }catch(Exception ex){
            System.debug('test exception: ' + ex);
        }
    }
}