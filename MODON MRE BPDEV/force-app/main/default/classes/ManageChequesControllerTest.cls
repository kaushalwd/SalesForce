@isTest
public class ManageChequesControllerTest {
    
    @isTest
    static void ManageCheques() {
        Project__c project = new Project__c();
        INSERT project;
        
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        INSERT phase;
        // Create Unit
        Unit__c unitRec = new Unit__c();
        unitRec.Phase__c = phase.Id;
        unitRec.PlotAreasqm__c = 1.0;
        unitRec.PlotNo__c = '1';
        unitRec.UnitClassification__c = 'Plot';
        unitRec.Number_of_Bedrooms__c = '2';
        unitRec.Name = 'TestUnit';
        INSERT unitRec;
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Sample file content'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocumentId = [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :cv.Id
                    LIMIT 1
                ].ContentDocumentId;

        // Create a Person Account
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account')
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        
        Account acc = new Account(RecordTypeId = recordTypeId, PersonEmail = 'test@example.com', FirstName = 'Test', LastName = 'User');
        acc.UAE_Resident_Status__pc = 'Resident';
        acc.Nationality__pc = 'United Arab Emirates';
        acc.EmiratesIDExpiryDate__pc = Date.today().addDays(365);
        acc.EIDNumber__pc = '784-1232-1234567-4';
        insert acc;
        
 		Opportunity oppObj = new Opportunity(Name = 'Test Opportunity', StageName = 'Qualification', CloseDate = Date.today(),UAE_Resident_Status__c = 'Resident',Nationality__c = 'United Arab Emirates',EmiratesIDExpiryDate__c = Date.today().addDays(365),EIDNumber__c='784-1232-1234567-4');

        insert oppObj;
        
        Expressionofinterest__c eoiObj = new Expressionofinterest__c(Opportunity__c = oppObj.Id);
        insert eoiObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unitRec.Id;
        so.TotalAmount__c = 200;
        So.CustomerAccount__c = acc.Id;
        insert so;
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 1);
        insert soi;
        
        Cheque_Details__c cheque = new Cheque_Details__c(
            UnitName__c = 'TestUnit',
            Cheque_Issuer__c = 'TestCustomer',
            Cheque_Date__c = Date.today(),
            Status__c = 'New',
            Sales_order__c = so.Id,
            MileStoneNumber__c ='1',
            Cheque_No__c = '1234',
            Sales_Order_Installment__c = soi.Id
            
        );
        cheque.MileStoneNumber__c ='1';
        cheque.Payee__c = 'test';
        cheque.Account__c = acc.Id;
        cheque.Cheque_No__c = '1234';
           Cheque_Details__c cheque1 = new Cheque_Details__c(
            UnitName__c = 'TestUnit',
            Cheque_Issuer__c = 'TestCustomer',
            Cheque_Date__c = Date.today(),
            Status__c = 'New',
            Sales_order__c = so.Id,
            MileStoneNumber__c = 'ADM'
        );
            
        
        insert new List<Cheque_Details__c> {cheque, cheque1} ;
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = cheque.Id,   // Parent record Id
            ShareType = 'V',           // View permission
            Visibility = 'AllUsers'
        );
        insert cdl;

        
        // First invoice (fully paid)
        Invoice__c inv1 = new Invoice__c(Account__c = acc.Id, Expressionofinterest__c = eoiObj.Id, InvoiceAmount__c = 200,  SalesOrderInstallment__c = soi.Id);
        insert inv1;
        
        Invoice__c inv2 = new Invoice__c(Account__c = acc.Id, Expressionofinterest__c = eoiObj.Id, InvoiceAmount__c = 200,  Sales_Order__c = so.Id, Is_ADM_Fees_and_Dari_charges__c = true);
        insert inv2;
        
        Receipt__c receipt = new Receipt__c(Account__c = acc.Id, Status__c = 'Approved', TotalAmount__c = 200);
        insert receipt;
        
        Allocation__c alloc1 = new Allocation__c(Invoice__c = inv1.Id, Receipt__c = receipt.Id, AllocationAmount__c = 200);
        insert alloc1;  
        

        
        Test.startTest();
        List<Project__c> projects = ManageChequesController.getAllProjects();
        System.assertNotEquals(null, projects, 'Projects should not be null');
        
        Integer countWithSO = ManageChequesController.getChequesCount(so.Id);
        Integer countNull = ManageChequesController.getChequesCount(null);
        System.assert(countWithSO >= 0, 'Cheques count should be non-negative');
        System.assert(countNull >= 0, 'Cheques count should be non-negative');
        
        try {
            ManageChequesController.getChequesCount('invalidId');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception message should be returned');
        }

        List<Map<String, String>> options = ManageChequesController.getAllBuildings();
        ManageChequesController.SalesOrderWrapper wrap = ManageChequesController.getSalesOrderWrapper(unitRec.Id);
        System.assertNotEquals(null, wrap, 'SalesOrderWrapper should be created');
        
        try {
            ManageChequesController.getSalesOrderWrapper(null);
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception on null unitId expected');
        }

        List<ManageChequesController.ChequeWrapper> wrapper = ManageChequesController.getChequeWrappers('0', '10', '');
        List<ManageChequesController.ChequeWrapper> wrapper2 = ManageChequesController.getChequeWrappers('0', '10', so.Id);
        System.assertNotEquals(null, wrapper, 'Cheque wrappers list should not be null');
        
        ManageChequesController.getSOIfromMileStone('1', new List<SalesOrderInstallments__c> {soi});
        ManageChequesController.showChequeDetails(so.Id);
        
        List<ManageChequesController.ChequeWrapper> cwrapper = ManageChequesController.getUnitData(String.valueOf(project.Id), String.valueOf(Phase.Id), 'TestUnit', null, null, 'Test', '1234', '');
        List<ManageChequesController.ChequeWrapper> cwrappers = ManageChequesController.getUnitData(String.valueOf(project.Id), String.valueOf(Phase.Id), 'Test', Date.today(), Date.today(), 'Test', '1234', 'test');
        List<ManageChequesController.ChequeWrapper> cwrappersall = ManageChequesController.getUnitData('All', 'All', null, Date.today(), Date.today(), 'Test', '1234', 'test');
        
        List<SalesOrder__c> orders = ManageChequesController.getAllSalesOrders(project.Id, Phase.Id, unitRec.Id);
        System.assertNotEquals(null, orders, 'Sales orders list should not be null');
        
        List<Map<String, String>> results = ManageChequesController.saveChequeDetails(wrapper, 'save');
        List<Map<String, String>> result = ManageChequesController.saveChequeDetails(wrapper, 'confirm');
        
        if(!wrapper.isEmpty()) {
            ManageChequesController.unSelectCheque(wrapper[0]);
        }
        Test.stopTest();
    }
}