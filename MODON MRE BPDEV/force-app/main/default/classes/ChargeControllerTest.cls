@isTest
public with sharing class ChargeControllerTest {
                private static final string SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER { get { return 'Service_Request_Management_Property_Transfer_OffPlan'; } }
    private static final string SERVICE_REQUEST_RT_DEV_NAME_ADM { get { return 'Service_Request_Management_ADM'; } }

    @testSetup
    static void setupTestData() {
                Id admrRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        Id prprty = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);

               ServiceRequest__c sr = TestDataFactory.createServiceRequest('Normal',prprty);


              ServiceRequest__c sr1 = TestDataFactory.createServiceRequest('Normal',admrRecordTypeId);

      

        // Link Service Request to Parent & Sales Order
        sr1.SR_OriginID__c = sr.Id;
        update sr1;

        // Create Charges
        Charge__c charge1 = new Charge__c(Name='Charge1', Amount__c=100, Service_Request__c=sr1.Id);
        Charge__c charge2 = new Charge__c(Name='Charge2', Amount__c=200, Service_Request__c=sr.Id);
        insert new List<Charge__c>{ charge1, charge2 };
    }

    @isTest
    static void testGetCharges() {
        // Get the Service Request
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c  LIMIT 1];

        // Call the method
        Test.startTest();
        List<Charge__c> charges = ChargeController.getCharges(sr.Id);
        Test.stopTest();

    }
@isTest
    static void testDeleteCharge() {
        // Get an existing charge
        Charge__c chargeToDelete = [SELECT Id FROM Charge__c LIMIT 1];

        // Call the method
        Test.startTest();
        ChargeController.deleteCharge(chargeToDelete.Id);
        Test.stopTest();

       
    }
 

}