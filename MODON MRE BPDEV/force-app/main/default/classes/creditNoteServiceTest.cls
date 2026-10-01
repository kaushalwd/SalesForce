@isTest
public class creditNoteServiceTest {
@isTest
static void createCreditNotesTest() {
    
        Map<String, Id> ids = TestDataFactory.createTestData();
        Id soid = ids.get('SalesOrder');  
        Id actId = ids.get('vipPersonAccount');  
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = soid;
        insert soi; 
        
        List<Invoice__c> invList = new List<Invoice__c>();
        Invoice__c inv = new Invoice__c();
        inv.InvoiceAmount__c = 12345;
        inv.SalesOrderInstallment__c = soi.Id;
        inv.Account__c = actId;
        insert inv;
        
        invList.add(inv);
        
        creditNoteService.createCreditNotes(invList,soi.Id); // The second parameter is not in user in actual class. So sending random SF id.
    }
}