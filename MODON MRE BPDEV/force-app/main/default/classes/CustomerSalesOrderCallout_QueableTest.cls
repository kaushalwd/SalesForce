/**********************************************************************************************************************
* Name               : CustomerSalesOrderCallout_QueableTest
* Description        : Test Class for CustomerSalesOrderCallout_Queable
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Yazan Saeed         25 April 2024      Initial Draft
***********************************************************************************************************************/

@isTest
public with sharing class CustomerSalesOrderCallout_QueableTest
{
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
       test.starttest();
    SalesOrderCallout_Queable customerSOQableContext = new SalesOrderCallout_Queable(soIdSet);

    Id apexJobID = system.enqueueJob(customerSOQableContext);
       test.stoptest();

   }
}