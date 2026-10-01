@isTest
public class HandleSalesOrderJunctionObjcet_Test {
    static TestMethod void runTest1(){
        Id prsnAccountRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        Account acctoinsert = New Account(RecordTypeId= prsnAccountRecTypeId,
                                        FirstName= 'Test FN-1',
                                        LastName='Test LN-1',
                                        PersonEmail= 'test-1@example.com');
        INSERT acctoinsert;
        Account acc = [SELECT Id, PersonContactId FROM Account WHERE Id=:acctoinsert.Id];
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.EIDNumber__c = '784-1996-3732188-7';
        oppObj.AccountId = acc.Id;
        oppObj.PrimaryContact__c = acc.PersonContactId;
        oppObj.BrokerAgentName__c = 'test broker';
        INSERT oppObj;
        
        PaymentInstallements__c payI = New PaymentInstallements__c (Name = 'Down Payment',
                                                                   MilestoneDate__c = System.Today(),
                                                                   MilestoneNumber__c = 1, 
                                                                   Milestone__c = 20,
                                                                   MilestoneDescription__c = 'Down Payment');
        
        SalesOrder__c so = new SalesOrder__c();
        so.Opportunity__c = oppObj.Id;
        so.Totalamountinwords__c = 'NINETEEN MILLION ONE HUNDRED SEVENTY-TWO THOUSAND SIX HUNDRED EIGHTY-TWO DIRHAMS ONLY.';
        insert so;
        
        JointOwner__c jo = New JointOwner__c();
        jo.OwnershipPercentage__c = 30.00;
        jo.RelationshipType__c = 'Joint Owner P-P';
        jo.RelationshipSubType__c = 'Friend';
        jo.JointOwnerAccount__c = acc.Id;
        jo.SalesOrder__c = so.Id;
        INSERT jo;
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        soi.PaymentInstallments__c = payI.Id;
        soi.MilestoneNumber__c = 1;
        soi.MilestoneDescription__c = 'Down Payment';
        soi.InstallmentAmount__c = 20000.00;
        insert soi;
        try{
            Test.startTest();
            HandleSalesOrderJunctionObjcet.initiatefuture(New List<Id>{so.Id});
            Test.stopTest();
        }catch(Exception ex){
            System.debug('test exception: ' + ex);
        }
    }
}