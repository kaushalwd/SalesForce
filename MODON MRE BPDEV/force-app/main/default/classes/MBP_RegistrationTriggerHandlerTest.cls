@isTest
class MBP_RegistrationTriggerHandlerTest {
    static Registration__c reg(String status) {
        Registration__c r = new Registration__c(Status__c=status, Company_Name_as_per_Trade_License__c='Test', Company_Email_Address__c='r@t.com', Trade_License_Number__c=String.valueOf(Math.random()));
        insert r; return r;
    }
    static Registration_Agent__c agent(Id regId) {
        Registration_Agent__c a = new Registration_Agent__c(Registration_Name__c=regId, Agent_Email__c='a@t.com', Type__c='Agency Admin');
        insert a; return a;
    }
    @isTest static void test_createServiceRequest() {
        Registration__c r = reg('Draft');
        Registration__c oldReg = r.clone(false,false,false,false); oldReg.Status__c = 'Draft';
        r.Status__c = 'Submitted'; update r;
        Map<Id,Registration__c> oldMap = new Map<Id,Registration__c>{r.Id=>oldReg};
        List<Registration__c> newList = new List<Registration__c>{r};
        MBP_RegistrationTriggerHandler.createServiceRequest(newList, oldMap);
    }
    @isTest static void test_createDocumentRecords() {
        Registration__c r = reg('Draft');
        Documents__c d = new Documents__c(Name='Doc', Status__c='Pending Upload'); insert d;
        List<SObject> l = new List<SObject>{r};
        MBP_RegistrationTriggerHandler.createDocumentRecords(l);
    }
   
}