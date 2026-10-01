@istest
public class PassforStatusUpdateTest{

 static testMethod void  test1(){
   PassforStatusUpdate reqst=new PassforStatusUpdate();

    String JsonMsg=JSON.serialize(reqst);

    Test.startTest();
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/DemoUrl';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response= res;
        PassforStatusUpdate.doPost();
    Test.stopTest();

   } 
   static testMethod void  test2(){
   
    /*Account acc = new Account(Name='Test',ProfileId__c='01234567'); 
    insert*/ 
    Contact Testcon =new Contact();
    Testcon.FirstName = 'Test';
    Testcon.LastName = 'Test 2'; 
    Testcon.PassfortRiskStatus__c='Low';
    Testcon.PassfortApprovalStatus__c='Approved';
    Testcon.ProfileId__c='01234567';
    insert Testcon;

        String JsonMsg=JSON.serialize('{   "event": "PRODUCT_STATUS_CHANGED",   "data": {     "apikey": {       "name": "MASTER_KEY"     },     "application_id": "01234567-89ab-cdef-0123-456789abcdef",     "customer_ref": "1234567",     "new_status": "APPLIED",     "product": {       "alias": "forexo_basic",       "id": "b0ce7c17-2cab-86e7-9a83-ebee0d4d5dc8",       "name": "Forexo Basic Account"     },     "profile_id": "01234567",     "user": {       "email": "morgan.rose@forexo.com",       "id": "01234567-89ab-cdef-0123-456789abcdef",       "name": "Morgan Rose"     }   },   "id": "01234567-89ab-cdef-0123-456789abcdef",   "secret": "yourSecret",   "timestamp": "1568997222" }');
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/DemoUrl';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueof('{   "event": "PRODUCT_STATUS_CHANGED",   "data": {     "apikey": {       "name": "MASTER_KEY"     },     "application_id": "01234567-89ab-cdef-0123-456789abcdef",     "customer_ref": "1234567",     "new_status": "APPLIED",     "product": {       "alias": "forexo_basic",       "id": "b0ce7c17-2cab-86e7-9a83-ebee0d4d5dc8",       "name": "Forexo Basic Account"     },     "profile_id": "01234567",     "user": {       "email": "morgan.rose@forexo.com",       "id": "01234567-89ab-cdef-0123-456789abcdef",       "name": "Morgan Rose"     }   },   "id": "01234567-89ab-cdef-0123-456789abcdef",   "secret": "yourSecret",   "timestamp": "1568997222" }');
        RestContext.request = req;
        RestContext.response= res;
        Test.startTest();
            PassforStatusUpdate reqst=new PassforStatusUpdate();
            PassforStatusUpdate.doPost();
        Test.stopTest();

   }
   static testMethod void  test3(){
   
    Account acc = new Account(Name='Test',ProfileId__c='01234567'); 
    insert acc;
    

        String JsonMsg=JSON.serialize('{   "event": "PRODUCT_STATUS_CHANGED",   "data": {     "apikey": {       "name": "MASTER_KEY"     },     "application_id": "01234567-89ab-cdef-0123-456789abcdef",     "customer_ref": "1234567",     "new_status": "APPLIED",     "product": {       "alias": "forexo_basic",       "id": "b0ce7c17-2cab-86e7-9a83-ebee0d4d5dc8",       "name": "Forexo Basic Account"     },     "profile_id": "01234567",     "user": {       "email": "morgan.rose@forexo.com",       "id": "01234567-89ab-cdef-0123-456789abcdef",       "name": "Morgan Rose"     }   },   "id": "01234567-89ab-cdef-0123-456789abcdef",   "secret": "yourSecret",   "timestamp": "1568997222" }');
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/DemoUrl';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueof('{   "event": "PRODUCT_STATUS_CHANGED",   "data": {     "apikey": {       "name": "MASTER_KEY"     },     "application_id": "01234567-89ab-cdef-0123-456789abcdef",     "customer_ref": "1234567",     "new_status": "APPLIED",     "product": {       "alias": "forexo_basic",       "id": "b0ce7c17-2cab-86e7-9a83-ebee0d4d5dc8",       "name": "Forexo Basic Account"     },     "profile_id": "01234567",     "user": {       "email": "morgan.rose@forexo.com",       "id": "01234567-89ab-cdef-0123-456789abcdef",       "name": "Morgan Rose"     }   },   "id": "01234567-89ab-cdef-0123-456789abcdef",   "secret": "yourSecret",   "timestamp": "1568997222" }');
        RestContext.request = req;
        RestContext.response= res;
        Test.startTest();
            PassforStatusUpdate reqst=new PassforStatusUpdate();
            PassforStatusUpdate.doPost();
        Test.stopTest();

   }

}