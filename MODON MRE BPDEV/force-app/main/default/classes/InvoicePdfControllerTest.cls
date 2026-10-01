@istest
public class InvoicePdfControllerTest {

    @istest
    static void mytestmethod(){
        test.starttest();
        try{
            
        
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account account = new Account(RecordTypeId = recordTypeId);
        account.PersonEmail = 'abdallahhdaib@outlook.com';
        account.FirstName = 'First';
        account.LastName = 'Last';
        insert account;
        
        Invoice__c inv = new Invoice__c();
        inv.Account__c = account.Id;
        inv.InvoiceAmount__c  =100;
        insert inv;
        
        InvoicePdfController obj = new InvoicePdfController();
        
        obj.invoice = inv;
            } catch(Exception e){}
        test.stopTest();
    }
}