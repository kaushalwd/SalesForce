@isTest
public class RefundTriggerTest {
    
    @testSetup
    static void setupTestData() {
        // Create a test Account with Source_Entity__c = 'Modon - Egypt'
        Account testAccount = new Account(
            Name = 'Test Account',
            Source_Entity__c = 'Modon - Egypt'
        );
        insert testAccount;
    }
    
    @isTest
    static void testCreateRefundRecords() {
        // Fetch test Account
        Account testAccount = [SELECT Id FROM Account WHERE Source_Entity__c = 'Modon - Egypt' LIMIT 1];

        // Create Refund__c record linked to Account
        Test.startTest();
        Refund__c testRefund = new Refund__c(
            Account__c = testAccount.Id,
            Refund_Amount__c = 100.00
        );
        insert testRefund;
		Test.stopTest();
        
        // Fetch document names linked to the Refund__c record
        Set<String> documentNames = new Set<String>();
        for (Documents__c doc : [SELECT Id, Name FROM Documents__c WHERE Refund__c = :testRefund.Id]) {
            documentNames.add(doc.Name);
        }
        
        // Fetch DocumentDisplayName__c from custom metadata
        Set<String> masterDocumentNames = new Set<String>();
        for (Modon_Documents_Master_Configuration__mdt metaDoc : [
                SELECT Id, DocumentDisplayName__c 
                FROM Modon_Documents_Master_Configuration__mdt 
                WHERE ObjectAPIName__c = 'Refund__c' 
                AND DocumentAPIName__c != null 
                AND DocumentDisplayName__c != null 
                AND Source_Entity__c = 'Modon - Egypt'
        ]) {
            masterDocumentNames.add(metaDoc.DocumentDisplayName__c);
        }
		System.assertEquals(masterDocumentNames, documentNames, 'All documents created should match metadata definitions.');
		
         //Update Record
        testRefund.Refund_Amount__c = 30;
        update testRefund;
    
        // Fetch updated Refund record and assert changes
        Refund__c updatedRefund = [SELECT Id, Refund_Amount__c FROM Refund__c WHERE Id = :testRefund.Id];
        System.assertEquals(30, updatedRefund.Refund_Amount__c, 'Refund amount should be updated to 30.');
    
        //Delete Record
        delete testRefund;
    
        // Check if Refund__c record is deleted (only works if querying with ALL ROWS)
        List<Refund__c> deletedRefundList = [SELECT Id,IsDeleted FROM Refund__c WHERE Id = :testRefund.Id ALL ROWS];
        System.assertEquals(1, deletedRefundList.size(), 'Deleted Refund record should still exist in ALL ROWS query.');  
    }

}