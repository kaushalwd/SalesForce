@isTest
private class OIC_WhatsappCustomerPropertiesTest {

    @testSetup
    static void setupTestData() {
        // Create a test User (owner of SalesOrder)
        User u = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John54454', LastName = 'Doe54454', RecordTypeId = rtId, PersonMobilePhone = '+971501234567');
        insert acc;
		List<Account> lst_Account = [SELECT Id, Name, PersonEmail, PersonContactId from Account where Id = :acc.Id];
        // Create SalesOrder
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, OwnerId = u.Id, 
                                             PrimaryContact__c = acc.PersonContactId, Status__c = 'Completed');
        
        system.debug('soId'+so.Id);
        so.JO1__c = lst_Account.get(0).PersonContactId;
        so.JO2__c = lst_Account.get(0).PersonContactId;
        so.JO3__c = lst_Account.get(0).PersonContactId;
        so.JO4__c = lst_Account.get(0).PersonContactId;
        so.JO5__c = lst_Account.get(0).PersonContactId;
        so.JO6__c = lst_Account.get(0).PersonContactId;

        insert so;
        
        String mobileNumber = '+971501234567';
        List<SalesOrder__c> lst_SalesOrder = [SELECT Id, Name, Status__c, TotalAmount__c, ProjectName__c, Unit__c, Unit__r.Name, 
                                                 Unit__r.Status__c, Unit__r.Phase__r.Name, CustomerAccount__c, JO1__c, JO1__r.Name,JO2__c, 
                                                 JO2__r.Name,JO3__c, JO3__r.Name,JO4__c, JO4__r.Name,JO5__c, JO5__r.Name,JO6__c, JO6__r.Name, 
                                                 CustomerAccount__r.Name, PrimaryContact__r.Email, PrimaryContact__r.MobilePhone, JO1__r.Email, 
                                                 JO1__r.MobilePhone, JO2__r.Email, JO2__r.MobilePhone, JO3__r.Email, JO3__r.MobilePhone, 
                                                 JO4__r.Email, JO5__r.MobilePhone, JO6__r.Email, JO6__r.MobilePhone 
                                                 From SalesOrder__c where Status__c = 'Completed' 
                                                 and (PrimaryContact__r.MobilePhone = :mobileNumber
                                                 or JO1__r.MobilePhone = :mobileNumber or JO2__r.MobilePhone = :mobileNumber
                                                 or JO3__r.MobilePhone = :mobileNumber or JO4__r.MobilePhone = :mobileNumber
                                                 or JO5__r.MobilePhone = :mobileNumber or JO6__r.MobilePhone = :mobileNumber)];
        System.debug('>>>>>>>>>>>>>>>>>>>>> lst_SalesOrder '+lst_SalesOrder.size());
        SalesOrder__c obj_SO = lst_SalesOrder.get(0);
        System.debug('>>>>>>>>>>>>>>>>>>>>> obj_SO.JO4__c '+obj_SO.JO4__c);
        System.debug('>>>>>>>>>>>>>>>>>>>>> obj_SO.JO5__c '+obj_SO.JO5__c);
        System.debug('>>>>>>>>>>>>>>>>>>>>> obj_SO.JO6__c '+obj_SO.JO6__c);
        
        // 3. Create Documents__c
        Documents__c doc = new Documents__c(
            SalesOrder__c = so.Id,
            Status__c = 'Uploaded',
            Name = 'Signed SPA (Modon)'
        );
        insert doc;
    }

    @isTest
    static void testFindPropertyDetails_Success() {
        // Setup RestContext
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/WhatsappCustomerPropertiesAPI';
        req.httpMethod = 'GET';
        req.params.put('MobileNumber', '971501234567'); // Testing '+' auto-append

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_WhatsappCustomerProperties.findPropertyDetails();
        Test.stopTest();
    }

    @isTest
    static void testFindPropertyDetails_MissingParam() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/WhatsappCustomerPropertiesAPI';
        req.httpMethod = 'GET'; // Intentionally missing params

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_WhatsappCustomerProperties.findPropertyDetails();
        Test.stopTest();
    }

    @isTest
    static void testFindPropertyDetails_NoData() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/WhatsappCustomerPropertiesAPI';
        req.httpMethod = 'GET';
        req.params.put('MobileNumber', '+971000000000'); // Unused Number

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_WhatsappCustomerProperties.findPropertyDetails();
        Test.stopTest();
    }

    @isTest
    static void testFindPropertyDetails_Exception() {
        // Passing null for RestContext to simulate a null pointer exception in the try block
        RestContext.request = null; 
        RestContext.response = new RestResponse();

        Test.startTest();
        OIC_WhatsappCustomerProperties.findPropertyDetails();
        Test.stopTest();
    }
}