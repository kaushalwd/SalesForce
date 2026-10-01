@isTest
public class DirectDebitTransactionBatchJobTest {

    @isTest
    static void testBatchJob_createsTransactions() {
        // --- Setup Required Data ---

        // Create Account (Person Account)
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John', LastName = 'Doe', RecordTypeId = personRtId);
        insert acc;

        // Create Project and Phase
        Project__c project = new Project__c(Name = 'Test Project');
        insert project;

        Phase__c phase = new Phase__c(Name = 'Phase 1', Project__c = project.Id);
        insert phase;

        // Create Unit
        Unit__c unit = new Unit__c(Name = 'Unit 101', Phase__c = phase.Id, PlotNo__c = 'P101', UnitClassification__c ='Apartment', Number_of_Bedrooms__c ='2');
        insert unit;

        // Create Sales Order
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Unit__c = unit.Id);
        insert so;

        // Create Direct Debit Request → Approve__c = true
        DirectDebitRequest__c ddRequest = new DirectDebitRequest__c(
            SalesOrder__c = so.Id,
            Approve__c = true
        );
        insert ddRequest;

        // Link DDR to SalesOrder
        so.Direct_Debit_Request__c = ddRequest.Id;
        update so;

        // Create Installment matching batch query
        SalesOrderInstallments__c installment = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1,
            MilestoneDate__c = Date.today().addDays(1),  // inside batch query window
            PaymentStatus__c = 'Not Paid',  // required
            InstallmentAmount__c = 1000
        );
        insert installment;

        // --- Run the Batch ---
        Test.startTest();
        DirectDebitTransactionBatchJob batch = new DirectDebitTransactionBatchJob();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // --- Verify ---
        List<DirectDebit_Transactions__c> txns = [
            SELECT Id, Direct_Debit_Request__c, Collection_Amount__c, Currency__c, Request_Type__c, SOInstallment__c
            FROM DirectDebit_Transactions__c
            WHERE SOInstallment__c = :installment.Id
        ];

        System.assertEquals(1, txns.size(), 'One transaction should be created');
        System.assertEquals(ddRequest.Id, txns[0].Direct_Debit_Request__c, 'Correct DDR linked');
        System.assertEquals('Collection', txns[0].Request_Type__c, 'Correct request type');
        System.assertEquals(1000, txns[0].Collection_Amount__c, 'Correct amount');
        System.assertEquals('AED', txns[0].Currency__c, 'Correct currency');
    }
}