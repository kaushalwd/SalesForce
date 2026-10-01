@isTest
public class ReceiptAllocationServiceTest {
@isTest
    static void getReceiptAllocationsByReceiptIdsTest()
    {
        Map<String, Id> ids = TestDataFactory.createTestData();
        Id actId = ids.get('vipPersonAccount');  
        Id soid = ids.get('salesorder'); 
        //Id soid = ids.get('salesorder'); 
        
        Charge__c ch = new Charge__c(Amount__c = 2500);
        insert ch;
        Receipt__c rec = new Receipt__c (Account__c = actId,Status__c='Approved');
        insert rec;
        
        Invoice__c inv = new Invoice__c(Account__c  = actId,Charge__c = ch.Id,InvoiceAmount__C =12345);
        insert inv;
        
        Set<Id> recSet = new Set<Id>();
        recSet.add(rec.Id);
        
        Allocation__c al = new Allocation__c(Receipt__c = rec.Id,Invoice__c=inv.Id);
        insert al;
        List<Allocation__c> alList = new List<Allocation__c>();
        alList.add(al);
        
        ServiceRequest__c sr = [select id,name,DebitNoteAmount__c,salesorder__c from servicerequest__c limit 1];
                
        Test.StartTest();
		ReceiptAllocationService.getUnAppliedChargeReceiptAllocationsByReceiptIds(recSet);  
        ReceiptAllocationService.getReceiptAllocationsByReceiptIds(recSet);  
        ReceiptAllocationService.getReceiptAllocationsByReceipts(recSet); 
        ReceiptAllocationService.unapplyReceiptApplications(sr);
        ReceiptAllocationService.UnApplyChargeReceiptApplicationAndValidateSync(sr);
        ReceiptAllocationService.unapplyReceiptApplications(alList);
        ReceiptAllocationService.createLogicalReceiptAllocations(rec.Id,12345.0,soid);
        //List<Allocation__c> createLogicalReceiptAllocations(String receiptId, decimal allocateAmnt,string salesOrderId)
        Test.StopTest();
    }
}