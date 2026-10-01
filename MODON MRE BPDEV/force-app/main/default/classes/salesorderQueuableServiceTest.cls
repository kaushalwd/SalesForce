@istest
public class salesorderQueuableServiceTest {
   @TestSetup
   static void makeData(){
    SalesOrder__c so = new SalesOrder__c();
    insert so;
  }

   @isTest
   static void method1(){

    Set<String> soIdSet = new Set<String>();
    for(Salesorder__c soObj : [SELECT Id FROM SalesOrder__c] ){
        soIdSet.add(soObj.Id);
    }
    salesorderQueuableService customerSOQableContext = new salesorderQueuableService(soIdSet);

    Id apexJobID = system.enqueueJob(customerSOQableContext);

   }
}