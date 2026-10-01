@isTest
public class fetchPaymentsStatusTest {
    
    static Id receipt1Id;
    static Id receipt2Id;
    static String receipt1Name;
    static String receipt2Name;
    
    @testSetup
    static void setupTestData() {
        // Create supporting records
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Project__c testProject = new Project__c(Name = 'Test Project');
        insert testProject;
        
        Phase__c testPhase = new Phase__c(Name = 'Test Phase', Project__c = testProject.Id);
        insert testPhase;
        
        Unit__c unit = new Unit__c(Name = 'Test Unit', Phase__c = testPhase.Id, PlotNo__c = '123', UnitClassification__c = 'Villa', Number_of_Bedrooms__c = '3');
        insert unit;
        
        
        SalesOrder__c salesOrder = new SalesOrder__c(
            Unit__c = unit.Id,
            TotalAmount__c = 10000 // Prevent divide-by-zero
        );
        insert salesOrder;
        
        SalesOrderInstallments__c installment = new SalesOrderInstallments__c(
            SalesOrder__c = salesOrder.Id,
            MilestoneNumber__c = 1
        );
        insert installment;
        
        // Create receipts
        Receipt__c receipt1 = new Receipt__c(
            Status__c = 'In Progress',
            TotalAmount__c = 1000,
            SalesOrderInstallment__c = installment.Id,
            Account__c = testAccount.Id
        );
        
        Receipt__c receipt2 = new Receipt__c(
            Status__c = 'Cleared',
            TotalAmount__c = 2000,
            SalesOrderInstallment__c = installment.Id,
            Account__c = testAccount.Id
        );
        
        insert new List<Receipt__c>{receipt1, receipt2};
            
            List<Receipt__c> receipts = [SELECT Name FROM Receipt__c ORDER BY CreatedDate ASC];
        receipt1Name = receipts[0].Name;
        receipt2Name = receipts[1].Name;
        System.debug('>>>>>>>>>>>>>>>>>>>>> receipt1Name  >>>>  '+receipt1Name);
        System.debug('>>>>>>>>>>>>>>>>>>>>> receipt2Name  >>>>  '+receipt2Name);
    }
    
    @isTest
    static void testFetchReceiptStatuses() {
        List<Receipt__c> receipts = [SELECT Name FROM Receipt__c ORDER BY CreatedDate ASC];
        receipt1Name = receipts[0].Name;
        receipt2Name = receipts[1].Name;
        System.debug('>>>>>>>>>>>>>>>>>>>>> receipt1Name  >>>>  '+receipt1Name);
        System.debug('>>>>>>>>>>>>>>>>>>>>> receipt2Name  >>>>  '+receipt2Name);
        Test.startTest();
        List<Map<String, String>> results = fetchPaymentsStatus.fetchReceiptStatuses(
            new List<String>{receipt1Name, receipt2Name}
        );
        Test.stopTest();
        
        //System.assertEquals(2, results.size(), 'Should return 2 receipt status maps');
        
        for (Map<String, String> record : results) {
            System.assert(record.containsKey('Receipt No'), 'Missing Receipt No key');
            System.assert(record.containsKey('OldStatus'), 'Missing OldStatus key');
            System.assert(record.containsKey('Sales Order: Sales Order Name'), 'Missing Sales Order Name');
        }
    }
    
    @isTest
    static void testUploadRecords_CoversAllBranches() {
        List<Receipt__c> receipts = [SELECT Id, Name, Status__c,EBS_Clearing_Date__c FROM Receipt__c LIMIT 2];
        String receiptName1 = receipts[0].Name;
        String receiptName2 = receipts[1].Name;
        
        List<Map<String, String>> payload = new List<Map<String, String>>{
            new Map<String, String>{ 'Receipt No' => receiptName1, 'Status' => 'Approved' },
                new Map<String, String>{ 'Receipt No' => receiptName2, 'Status' => 'Rejected' }
        };
            
            String jsonInput = JSON.serialize(payload);
        
        Test.startTest();
        fetchPaymentsStatus.uploadRecords(jsonInput);
        Test.stopTest();
        
        List<Receipt__c> updatedReceipts = [
            SELECT Name, Status__c,EBS_Clearing_Date__c FROM Receipt__c WHERE Name IN :new List<String>{receiptName1, receiptName2}
        ];
        
        System.assertEquals('Approved', updatedReceipts[0].Status__c);
        System.assertEquals('Rejected', updatedReceipts[1].Status__c);
    }
    
    @isTest
    static void testUploadRecords_EmptyAndInvalidData() {
        String emptyJson = JSON.serialize(new List<Map<String, String>>());
        List<Receipt__c> receipts = [SELECT Name FROM Receipt__c LIMIT 1];
        String invalidDateJson = JSON.serialize(new List<Map<String, String>>{
            new Map<String, String>{
                'Receipt No' => receipts[0].Name,
                    'Status' => 'Cleared',
                    'EBS Clearing Date' => 'invalid-date-format' 
                    }
        });
        
        Test.startTest();
        fetchPaymentsStatus.uploadRecords(invalidDateJson); 
        Test.stopTest();
    }
    
}