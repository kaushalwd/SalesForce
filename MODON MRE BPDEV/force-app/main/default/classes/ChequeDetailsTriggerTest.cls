@isTest
public class ChequeDetailsTriggerTest {

    /**
     * Dynamically resolves a valid active picklist value for a field.
     * Tries preferred values first, falls back to any active value.
     */
    private static String getPicklistValue(
        Schema.SObjectField fieldToken,
        List<String> preferredValues,
        Set<String> excludedValues
    ) {
        List<Schema.PicklistEntry> entries = fieldToken.getDescribe().getPicklistValues();
        for (String preferred : preferredValues) {
            for (Schema.PicklistEntry pe : entries) {
                if (pe.isActive() && pe.getValue() == preferred) {
                    return pe.getValue();
                }
            }
        }
        for (Schema.PicklistEntry pe : entries) {
            if (pe.isActive() && !excludedValues.contains(pe.getValue())) {
                return pe.getValue();
            }
        }
        return null;
    }

    @isTest
    static void test_addDefaultLookups() {
        Project__c project = new Project__c();
        INSERT project;
         
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        INSERT phase;

        // Create Unit — resolve Status__c dynamically to avoid restricted picklist error
        Unit__c unitRec = new Unit__c();
        unitRec.Phase__c = phase.Id;
        unitRec.PlotAreasqm__c = 1.0;
        unitRec.PlotNo__c = '1';
        unitRec.UnitClassification__c = 'Plot';
        unitRec.Number_of_Bedrooms__c = '2';
        unitRec.Name = 'TestUnit';

        // Dynamically get a valid Status__c value — 'Available' is preferred, fallback to any active value
        String unitStatus = getPicklistValue(
            Unit__c.Status__c,
            new List<String>{ 'Available', 'Blocked', 'Sold' },
            new Set<String>()
        );
        if (unitStatus != null) {
            unitRec.Status__c = unitStatus;
        }
        INSERT unitRec;
        
        // Create Account (Customer)
        Account acc = new Account(Name = 'TestCustomer');
        INSERT acc;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.AccountId = acc.id;
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.TODAY();
        oppObj.EIDNumber__c = '784-1990-1234567-8';
        INSERT oppObj;
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unitRec.Id;
        INSERT paymentPlan;

        // Create Sales Order
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unitRec.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'In Progress';
        so.CustomerAccount__c = acc.id;
        INSERT so;
        
        // Prepare Cheque Details (should match SO by Cheque_Issuer__c and UnitName__c)
        Cheque_Details__c cheque = new Cheque_Details__c(
            UnitName__c = 'TestUnit',
            Cheque_Issuer__c = 'TestCustomer',
            Cheque_Date__c = Date.today()
        );
        
        // Prepare Cheque Details without UnitName (to test mapping from SO)
        Cheque_Details__c cheque2 = new Cheque_Details__c(
            Cheque_Issuer__c = 'TestCustomer',
            Cheque_Date__c = Date.today()
        );
        
        List<Cheque_Details__c> chequeList = new List<Cheque_Details__c>{ cheque, cheque2 };
        
        Test.startTest(); 
        insert cheque;
        cheque.Bank__c = 'ADB Bank';
        update cheque;
        ChequeDetailsTriggerHelper.addDefaultLookups(chequeList, null);
        Test.stopTest();
    }

    @isTest
    static void test_addDefaultLookups_UpdatePath() {
        Project__c project = new Project__c();
        INSERT project;
         
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        INSERT phase;

        Unit__c unitRec = new Unit__c();
        unitRec.Phase__c = phase.Id;
        unitRec.PlotAreasqm__c = 1.0;
        unitRec.PlotNo__c = '2';
        unitRec.UnitClassification__c = 'Plot';
        unitRec.Number_of_Bedrooms__c = '3';
        unitRec.Name = 'TestUnit2';

        String unitStatus = getPicklistValue(
            Unit__c.Status__c,
            new List<String>{ 'Available', 'Blocked', 'Sold' },
            new Set<String>()
        );
        if (unitStatus != null) {
            unitRec.Status__c = unitStatus;
        }
        INSERT unitRec;

        Account acc = new Account(Name = 'TestCustomer2');
        INSERT acc;

        Cheque_Details__c cheque = new Cheque_Details__c(
            UnitName__c = 'TestUnit2',
            Cheque_Issuer__c = 'TestCustomer2',
            Cheque_Date__c = Date.today()
        );
        INSERT cheque;

        // Simulate update path — pass oldMap (non-null)
        Map<Id, SObject> oldMap = new Map<Id, SObject>{
            cheque.Id => cheque
        };

        Cheque_Details__c updatedCheque = cheque.clone(true, true, false, false);
        updatedCheque.Sales_Order__c = null;

        Test.startTest();
        ChequeDetailsTriggerHelper.addDefaultLookups(
            new List<Cheque_Details__c>{ updatedCheque },
            oldMap
        );
        Test.stopTest();
    }

    @isTest
    static void test_addDefaultLookups_NoUnitName() {
        Cheque_Details__c cheque = new Cheque_Details__c(
            Cheque_Issuer__c = 'NonExistentCustomer',
            Cheque_Date__c = Date.today()
        );

        Test.startTest();
        ChequeDetailsTriggerHelper.addDefaultLookups(
            new List<Cheque_Details__c>{ cheque },
            null
        );
        Test.stopTest();

        System.assertEquals(null, cheque.Unit__c, 'Unit should remain null when no match found');
    }
}