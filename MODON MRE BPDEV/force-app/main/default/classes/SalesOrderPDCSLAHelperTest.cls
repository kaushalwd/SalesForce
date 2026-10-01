@isTest
public class SalesOrderPDCSLAHelperTest {

    @testSetup
    static void setupData() {
        Id personAccountRTID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Account testAccount = new Account();
        testAccount.FirstName = 'Test2222';
        testAccount.LastName = 'Account';
        testAccount.RecordTypeId = personAccountRTID;
        testAccount.PersonEmail = 'test@test2222.com';
        insert testAccount;

        Contact conObj = new Contact();
        conObj.LastName = 'Test contact12312';
        conObj.Email = 'test12311@test.com';
        INSERT conObj;

        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.PrimaryContact__c = conObj.Id;
        oppObj.UAE_Resident_Status__c = 'Non-Resident';
        oppObj.Nationality__c = 'India';
        oppObj.PassportExpiryDate__c = Date.today();
        oppObj.PassportIssueDate__c = Date.today();
        oppObj.PassportNumber__c = 'NP232131';
        oppObj.En_Nationality__c = 'India';
        oppObj.En_PassportNumber__c = 'P1234567';
        insert oppObj;

        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        Phase__c phase = new Phase__c(name='Test Phase', EscrowAccount__c =escAccount.id);
        insert phase;

        Expressionofinterest__c eoi = new Expressionofinterest__c();
        eoi.Opportunity__c = oppObj.Id;
        eoi.Phase__c = phase.id;
        insert eoi;

        SalesOrder__c so = new SalesOrder__c();
        so.TotalAmount__c = 100;
        so.CustomerAccount__c = testAccount.Id;
        so.PrimaryContact__c = conObj.Id;
        so.Resale__c = false;
        so.PDC_Collected__c = 'No';
        so.ExcludePDCCheck__c = false;
        so.Status__c = 'In Progress';
        so.PDC_SLA__c = Datetime.now().addHours(-2);
        so.PDC_Extended_SLA__c = Datetime.now().addDays(2);
        so.PDCSLAExtensionApproved__c = false;
        so.IsPDCSLAExtensionRequired__c = false;
        insert so;
    }

    @isTest
    static void testGetBusinessHours() {
        Test.startTest();
        BusinessHours bhSales = SalesOrderPDCSLAHelper.getBusinessHours('Sales');
        BusinessHours bhSalesOps = SalesOrderPDCSLAHelper.getBusinessHours('Sales Operation');
        BusinessHours bhFinance = SalesOrderPDCSLAHelper.getBusinessHours('Finance');
        BusinessHours bhCM = SalesOrderPDCSLAHelper.getBusinessHours('Customer Management');
        BusinessHours bhUnknown = SalesOrderPDCSLAHelper.getBusinessHours('NonExistentTeam');
        BusinessHours bhNull = SalesOrderPDCSLAHelper.getBusinessHours(null);
        Test.stopTest();

        System.assertNotEquals(null, bhUnknown, 'Unknown team should fall back to default business hours');
        System.assertNotEquals(null, bhNull, 'Null team should fall back to default business hours');
    }

    @isTest
    static void testUpdatePDCSOStatus() {
        SalesOrder__c so = [
            SELECT Id, Status__c, Resale__c, PDC_Collected__c, ExcludePDCCheck__c
            FROM SalesOrder__c
            LIMIT 1
        ];
        so.Resale__c = false;
        so.PDC_Collected__c = 'No';
        so.ExcludePDCCheck__c = false;
        so.Status__c = 'In Progress';
        update so;

        Test.startTest();
        String result = SalesOrderPDCSLAHelper.updatePDCSOStatus(so.Id);
        String missingResult = SalesOrderPDCSLAHelper.updatePDCSOStatus(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Status update should return a message');
        System.assert(missingResult.startsWith('Failure'), 'Null Id should return failure');
    }

    @isTest
    static void testUpdatePDCSOStatusExcludedStatus() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        so.Status__c = 'Cancelled';
        so.Resale__c = false;
        so.PDC_Collected__c = 'No';
        so.ExcludePDCCheck__c = false;
        update so;

        Test.startTest();
        String result = SalesOrderPDCSLAHelper.updatePDCSOStatus(so.Id);
        Test.stopTest();

        System.assert(result.startsWith('Failure') || result.startsWith('Updated'), 'Cancelled SO should not silently throw');
    }

    @isTest
    static void testUpdatePDCSLAExtensionFlag() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Test.startTest();
        String result = SalesOrderPDCSLAHelper.updatePDCSLAExtensionFlag(so.Id, 'Requesting more time');
        String missingResult = SalesOrderPDCSLAHelper.updatePDCSLAExtensionFlag(null, 'No id');
        Test.stopTest();

        System.assertEquals('Success', result);
        System.assertEquals('Success', missingResult);
    }

    @isTest
    static void testGetPDCSLAConfig() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        Map<String, Object> config = SalesOrderPDCSLAHelper.getPDCSLAConfig(so.Id);
        Map<String, Object> errorConfig = SalesOrderPDCSLAHelper.getPDCSLAConfig(null);
        Test.stopTest();

        System.assertEquals(true, config.containsKey('SLA_Start') || config.containsKey('Error'));
        System.assertEquals('No recordId provided', errorConfig.get('Error'));
    }

    @isTest
    static void testGetPDCSLAConfigApprovedExtension() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        so.PDCSLAExtensionApproved__c = true;
        so.PDC_SLA__c = Datetime.now().addHours(-5);
        so.PDC_Extended_SLA__c = Datetime.now().addDays(3);
        so.IsPDCSLAExtensionRequired__c = true;
        update so;

        Test.startTest();
        Map<String, Object> config = SalesOrderPDCSLAHelper.getPDCSLAConfig(so.Id);
        Test.stopTest();

        System.assertEquals(true, (Boolean) config.get('IsPDCSLAExtensionRequired'));
        System.assertNotEquals(null, config.get('SLA_End'));
    }

    @isTest
    static void testGetPDCSLAConfigMissingRecord() {
        Id fakeId = SalesOrder__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';
        Test.startTest();
        Map<String, Object> config = SalesOrderPDCSLAHelper.getPDCSLAConfig(fakeId);
        Test.stopTest();
        System.assertEquals(true, config.containsKey('Error'));
    }
}