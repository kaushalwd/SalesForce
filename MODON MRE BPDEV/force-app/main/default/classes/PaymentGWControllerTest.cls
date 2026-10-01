@isTest
public class PaymentGWControllerTest {
 
    @isTest
    static void myTestMethod(){
        PaymentGWController myClsObj = new PaymentGWController();
        
        Account acc = new Account();
        acc.name = 'Test Account';
        insert acc;
        
        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = acc.Id;
        insert recObj;
        
        Test.setCurrentPageReference(new PageReference('/apex/Receipt__c?oid=' + recObj.Id));
        test.StartTest();
            myClsObj.paymentGWURLResponseCtrl();
        test.stoptest();
    }
}