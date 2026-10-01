@IsTest
public class BusinessProcessCloser_Test {

    @testSetup
    static void setupData() {

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Default And Termination',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'DEFAULT_TERM'
        );
        insert pf;

        Process_Flow_Step__c pfs = new Process_Flow_Step__c(
            Step_Name__c = 'Test Step',
            Process_Flow__c = pf.Id,
            Section_Number__c = 1,
            section_Name__c = 'SEC1'
        );
        insert pfs;

        Business_Process_Step__c bpStep =
            new Business_Process_Step__c(
                Name = 'Current Step',
                Status__c = 'Open',
                 Process_Flow_Step__c=pfs.Id,
                Is_Process_End__c = false,
                Section_Number__c = 1,
                section_Name__c = 'SEC1',
                Business_Process_Steps_Name_Custom__c = 'Current Step'
            );
        insert bpStep;
        
        SalesOrder__c soUAE = new SalesOrder__c(
            TotalAmount__c   = 200,
            Source_Entity__c = 'Modon - UAE'
        );
        insert soUAE;
        SalesOrderInstallments__c soi =
            new SalesOrderInstallments__c(
             SalesOrder__c=soUAE.Id  
            );
        insert soi;

        Business_Process__c bp =
            new Business_Process__c(
                Process_Flow__c = pf.Id,
                Status__c = 'In Progress',
                Sales_Order_Installment__c = soi.Id,
                Current_Business_Process_Step__c = bpStep.Id
            );
        insert bp;
        
        Id personRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Account personAcc = new Account(
            RecordTypeId  = personRTId,
            PersonEmail   = 'test@example.com',
            FirstName     = 'Test',
            LastName      = 'User',
            Swift_Code__c = '123456'
        );
        insert personAcc;

        Invoice__c inv =
            new Invoice__c(
                SalesOrderInstallment__c = soi.Id,
                Account__c=personAcc.Id
            );
        insert inv;
    }

    @IsTest
    static void testCloseOnInvoicePaid() {

        List<Invoice__c> invoices = [

            SELECT
                Id,
                InvoiceStatus__c,
                SalesOrderInstallment__c
            FROM Invoice__c
            WHERE InvoiceStatus__c = 'Paid'
        ];

        Test.startTest();

        BusinessProcessCloser.closeOnInvoicePaid(
            invoices
        );

        Test.stopTest();

        Business_Process_Step__c updatedStep = [

            SELECT
                Id,
                Status__c,
                Is_Process_End__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

    }

  
   

  
}