/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class PassfortRelatedEntitiesControllerTest {

	private class RestMock implements HttpCalloutMock {
		//Mock class
        public HTTPResponse respond(HTTPRequest req) {
            String fullJson = '{"integration_id" : "YxvkMSGkEe-RpoFwob_Iiw","status" : "Success","id" : "08aadff4-1edd-4aa8-8998-8688ef2da175","error_msg" : "","root_id" : "110873ff-3747-4482-846c-7bfe8867b5d4"}';
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'text/json');
            res.setBody(fullJson);
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }
    }    

    //@isTest
    public static testmethod void makedata() {
        // TO DO: implement unit test
        Account act= new Account();
        act.Name='Test Account';
        act.LegalStructure__c='Sole Private Establishment (UAE based)';
        act.DateOfEstablishment__c=date.newinstance(2000, 2, 17);
        act.UnifiedNumber__c='12357';
        act.TradeLicenseExpiryDate__c=date.newinstance(2040, 2, 17);
        act.UAEVATRegisterNumber__c='123456';
        act.PurposeOfTransaction__c='Flat booking';
        act.PurposeOfTransaction__c='House rent';
        act.Phone='+97154799866';
        //act.AreYouPoliticallyExposedPersonPEP__pc=true;
        act.SourceOfIncome__c='Salary';
        act.IsTheBusinessEntityRealBeneficiary__c=true;
        act.DeliveryChannel__c='Direct Sales Partner';
        act.NoOfPropertyPurchasedWithModon__c=2;
        act.Description='test Description';
        
        Account personAccount = new Account();
        personAccount.RecordTypeId= Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        personAccount.FirstName = 'Test';
        personAccount.LastName = 'PersonAccount';
        personAccount.PersonBirthdate=Date.newinstance(2000, 2, 17);
        personAccount.Nationality__pc='India';
        personAccount.UAE_Resident_Status__pc='Resident';
        personAccount.IdentityProof__pc='Emirates Id';
        personAccount.EIDNumber__pc='123456';
        personAccount.PersonMobilePhone='+97154799866';
        personAccount.Occupation__pc='Teacher';
        personAccount.EmployerBusinessName__pc='PwC';
        personAccount.PurposeOfTransaction__pc='House rent';
        personAccount.PersonEmail='abc@pwc.com';
        personAccount.AreYouPoliticallyExposedPersonPEP__pc=true;
        personAccount.SourceOfIncome__pc='Salary';
        personAccount.DeliveryChannel__pc='Face to face interaction';
        personAccount.NoOfPropertyPurchasedWithModon__pc=2;

        List<Account> lstAccount = new List<Account>();
		lstAccount.add(act);
		lstAccount.add(personAccount);        
        insert lstAccount;
        
        Contact con= new Contact();
        con.FirstName='Test';
        con.LastName='Test Contact';
        con.AccountId=lstAccount[0].id;
        con.Birthdate=Date.newinstance(2000, 2, 17);
        con.Nationality__c='India';
        con.UAE_Resident_Status__c='Resident';
        con.IdentityProof__c='Emirates Id';
        con.EIDNumber__c='123456';
        con.MobilePhone='+97154799866';
        con.Occupation__c='Teacher';
        con.EmployerBusinessName__c='PwC';
        con.PurposeOfTransaction__c='House rent';
        con.Email='abc@pwc.com';
        con.AreYouPoliticallyExposedPersonPEP__c=true;
        con.SourceOfIncome__c='Salary';
        con.DeliveryChannel__c='Direct Sales Partner';
        con.NoOfPropertyPurchasedWithModon__c=2;
        insert con;

        Opportunity opp= new Opportunity();
        opp.Name='Test Opportunity';
        opp.CloseDate=Date.today();
        opp.StageName='Closed Won';
        opp.AccountId=lstAccount[0].Id;
        opp.PrimaryContact__c=con.Id;
        opp.UAE_Resident_Status__c = 'Non-Resident';
        opp.Nationality__c = 'India';
        opp.PassportExpiryDate__c = System.today()+350;
        opp.PassportNumber__c = 'UAE12244';
        opp.PassportIssueDate__c = System.today()-100;
        
        Opportunity opp2= new Opportunity();
        opp2.Name='Test Opportunity2';
        opp2.CloseDate=Date.today();
        opp2.UAE_Resident_Status__c = 'Non-Resident';
        opp2.Nationality__c = 'India';
        opp2.StageName='Closed Won';
        opp2.AccountId=lstAccount[1].Id;
        opp2.PrimaryContact__c=personAccount.PersonContactId;
        opp2.PassportExpiryDate__c = System.today()+350;
        opp2.PassportNumber__c = 'UAE12244';
        opp2.PassportIssueDate__c = System.today()-100;
        
        List<Opportunity> lstOpp= new List<Opportunity>();
        lstOpp.add(opp);
        lstOpp.add(opp2);        
        insert lstOpp;
        
        SalesOrder__c salesOrder1 = new SalesOrder__c();
        salesOrder1.CustomerAccount__c=lstAccount[0].Id;
        salesOrder1.PrimaryContact__c=con.Id;
        
        SalesOrder__c salesOrder2 = new SalesOrder__c();
        salesOrder2.CustomerAccount__c=lstAccount[1].Id;
        salesOrder2.PrimaryContact__c=lstAccount[1].PersonContactId;
        
        List<SalesOrder__c> lstSalesOrder= new List<SalesOrder__c>();
        lstSalesOrder.add(salesOrder1);
        lstSalesOrder.add(salesOrder2);        
        insert lstSalesOrder;
        
		JointOwner__c jointOwner= new JointOwner__c();
		jointOwner.OwnershipPercentage__c=50;
        jointOwner.RelationshipType__c='Joint Owner P-P';
        jointOwner.RelationshipSubType__c='Broker';
        jointOwner.JointOwnerAccount__c=lstAccount[0].Id;
        jointOwner.Opportunity__c=lstOpp[0].Id;
        
        JointOwner__c jointOwner1= new JointOwner__c();
		jointOwner1.OwnershipPercentage__c=20;
        jointOwner1.RelationshipType__c='Joint Owner P-P';
        jointOwner1.RelationshipSubType__c='Broker';
        jointOwner1.JointOwnerAccount__c=lstAccount[0].Id;
        jointOwner1.SalesOrder__c=lstSalesOrder[0].Id;
        
        List<JointOwner__c> lstJointOwner= new List<JointOwner__c>();
        lstJointOwner.add(jointOwner);
        lstJointOwner.add(jointOwner1);
        insert lstJointOwner;
        
        Contact shareholder1 = new Contact();
        shareholder1.FirstName='Test';
        shareholder1.LastName='Shareholder 1';
        shareholder1.AccountId=act.Id;
        shareholder1.OwnershipPercentage__c=50;
        shareholder1.Birthdate=Date.newinstance(2000, 2, 17);
        shareholder1.Nationality__c='Iran';
        //shareholder1.PassfortApprovalStatus__c='In review';
        shareholder1.RecordTypeId=Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Shareholder').getRecordTypeId();
        
        Contact shareholder2 = new Contact();
        shareholder2.FirstName='Test';
        shareholder2.LastName='Shareholder 2';
        shareholder2.OwnershipPercentage__c=20;
        shareholder2.Birthdate=Date.newinstance(2000, 2, 14);
        shareholder2.AccountId=act.Id;
        shareholder2.Nationality__c='India';
        shareholder2.RecordTypeId=Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Shareholder').getRecordTypeId();
        
        List<Contact> lstShareholder = new List<Contact>();
        lstShareholder.add(shareholder1);
        lstShareholder.add(shareholder2);
        insert lstShareholder;
        
        ContentVersion cv = new ContentVersion();
        cv.Title='TestPassportDocument';
        cv.PathOnClient='TestPassportDocument.pdf';
        cv.VersionData= Blob.valueOf('test Passport component');
        cv.IsMajorVersion=true;
        
        ContentVersion cv1 = new ContentVersion();
        cv1.Title='TestCompanyDocument1';
        cv1.PathOnClient='TestCompanyDocument1.pdf';
        cv1.VersionData= Blob.valueOf('test TestCompanyDocument1 component');
        cv1.IsMajorVersion=true;

        List<ContentVersion> lstContentVersion = new List<ContentVersion>();
        lstContentVersion.add(cv);
        lstContentVersion.add(cv1);
        insert lstContentVersion;
        
        Documents__c doc = new Documents__c();
        doc.Name='Passport';
        doc.PrimaryContact__c=con.Id;
        doc.Opportunity__c=lstOpp[0].Id;
        
        Documents__c doc2 = new Documents__c();
        doc2.Name='Commercial trade License (Resident)';
        doc2.Account__c=lstAccount[0].Id;
        doc2.Opportunity__c=lstOpp[0].Id;

        List<Documents__c> lstDoc= new List<Documents__c>();
        lstDoc.add(doc);
        lstDoc.add(doc2);
        insert lstDoc;
        
        List<ContentVersion> lstCV= [select id,ContentDocumentId from ContentVersion];
        ContentDocumentLink cdLink= new ContentDocumentLink();
        cdLink.ContentDocumentId=lstCV[0].ContentDocumentId;
        cdLink.LinkedEntityId=lstDoc[0].Id;
        
        ContentDocumentLink cdLink1= new ContentDocumentLink();
        cdLink1.ContentDocumentId=lstCV[1].ContentDocumentId;
        cdLink1.LinkedEntityId=lstDoc[1].Id;
        
        List<ContentDocumentLink> lstCDLink= new List<ContentDocumentLink>();
        lstCDLink.add(cdLink);
        lstCDLink.add(cdLink1);
        insert lstCDLink;
  
    }
  
    public static testmethod void OppIdTestMethod1() {
        makedata();
        List<Opportunity> lstOpp=[select id from Opportunity];
        PassfortRelatedEntitiesController.isComplianceCleared(lstOpp[0].Id);
     	PassfortRelatedEntitiesController.getEntityRecords(lstOpp[0].Id);
        PassfortRelatedEntitiesController.isComplianceCleared(lstOpp[1].Id);
     	PassfortRelatedEntitiesController.getEntityRecords(lstOpp[1].Id);
    }
    public static testmethod void NationalityTestMethod1() {
    	PassfortRelatedEntitiesController.getNationalityOptions();
    }
    public static testmethod void ActIdTestMethod1() {
        makedata();
        List<Account> lstAct=[select id from Account];
        PassfortRelatedEntitiesController.getShareholderRecords(lstAct[0].Id);
        PassfortRelatedEntitiesController.getDocumentRecords(lstAct[0].Id);
        PassfortRelatedEntitiesController.deleteDocumentPlaceholders(lstAct[0].Id);
     	
    }
    public static testmethod void ConIdTestMethod1() {
        makedata();
        List<Contact> lstCon=[select id from Contact where recordType.DeveloperName!='Shareholder'];
        PassfortRelatedEntitiesController.getDocumentRecords(lstCon[0].Id);
        PassfortRelatedEntitiesController.deleteDocumentPlaceholders(lstCon[0].Id);	
    }
    public static testmethod void ShareholderTestMethod1() {
        makedata();
        List<Contact> lstShareholder=[select id,Nationality__c from Contact where recordType.Name='Shareholder'];
        PassfortRelatedEntitiesController.upsertShareholderRecords(lstShareholder[0]);
     	PassfortRelatedEntitiesController.deleteShareholderRecord(lstShareholder[0]);
        lstShareholder[0].Nationality__c='ABYZ';
        PassfortRelatedEntitiesController.upsertShareholderRecords(lstShareholder[0]);
        PassfortRelatedEntitiesController.deleteShareholderRecord(lstShareholder[0]);
    }
    public static testmethod void SalesOrderTestMethod1() {
        makedata();
        List<SalesOrder__c> lstSalesOrder=[select id from SalesOrder__c];
        PassfortRelatedEntitiesController.isComplianceCleared(lstSalesOrder[0].Id);
     	PassfortRelatedEntitiesController.getEntityRecords(lstSalesOrder[0].Id);
     	PassfortRelatedEntitiesController.isComplianceCleared(lstSalesOrder[0].Id);
    }

    public static testmethod void SalesOrderCreatePassfortTransactionTestMethod(){
        makedata();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        List<SalesOrder__c> lstSalesOrder=[select id,CustomerAccount__c,PrimaryContact__c from SalesOrder__c];
        
        String transactionList3='[{"EntityRecordId":"'+lstSalesOrder[0].CustomerAccount__c+'","EntityAPIName":"Account","EntityType":"Company","Name":"transactionList3","RiskStatus":"","ApprovalStatus":"In review","parentRecordId":"'+lstSalesOrder[0].Id+'","parentObjectName":"SalesOrder__c","passfortComment":"Test Comment","ParentDocumentIds":""}]';
     	PassfortRelatedEntitiesController.createPassfortTransactionRecords(transactionList3,lstSalesOrder[0].Id);
        String strFields='';
        List<String> lstAccFields =  System.Label.PassfortAccountFieldsToCheck.split(',');
        for(String str : lstAccFields)
            strFields = strFields+','+str;
        
        String accQuery ='Select id '+ strFields+', PassfortApprovalStatus__c,PassfortApprovalStatus__pc,profileId__c from Account where id=\''+lstSalesOrder[0].CustomerAccount__c+'\'';
        List<Account> lstAccUpdate=Database.query(accQuery);
        Map<Id, SObject> oldAccMap = new Map<Id, SObject>();
		oldAccMap.put(lstAccUpdate[0].id,lstAccUpdate[0]);
        
        lstAccUpdate[0].PassfortApprovalStatus__c='Approved';
        update lstAccUpdate;
        
        List<Account> lstAccUpdate1=Database.query(accQuery);
        list<SObject> newAccList = lstAccUpdate1;
        AccountTriggerHelper.updateReprocessingFlag(newAccList,oldAccMap);
        
     	String transactionList4='[{"EntityRecordId":"'+lstSalesOrder[0].PrimaryContact__c+'","EntityAPIName":"Contact","EntityType":"Individual","Name":"transactionList4","RiskStatus":"","ApprovalStatus":"In review","parentRecordId":"'+lstSalesOrder[0].Id+'","parentObjectName":"SalesOrder__c","passfortComment":"Test Comment","ParentDocumentIds":""}]';
     	PassfortRelatedEntitiesController.createPassfortTransactionRecords(transactionList4,lstSalesOrder[0].Id);
        List<String> lstConFields = System.Label.PassfortContactFieldsToCheck.split(',');
        strFields='';
        for(String str : lstConFields)
            strFields = strFields+','+str;
        
        String conQuery ='Select id '+ strFields+', PassfortApprovalStatus__c,profileId__c from Contact where id=\''+lstSalesOrder[0].PrimaryContact__c+'\'';
        List<Contact> lstPrimaryConUpdate=Database.query(conQuery);
        
        Map<Id, SObject> oldMap = new Map<Id, SObject>();
        oldMap.put(lstPrimaryConUpdate[0].id,lstPrimaryConUpdate[0]);
      
        lstPrimaryConUpdate[0].PassfortApprovalStatus__c='Approved';
        update lstPrimaryConUpdate;
        
        List<Contact> lstPrimaryConUpdate1=Database.query(conQuery);
        list<SObject> newList = lstPrimaryConUpdate1;
        ContactTriggerHelper.updateReprocessingFlag(newList,oldMap);

        //Added by Arvind-07/07/2026 - Version 1.0 - covers getKYCAndSalesOrderDetails for a Sales Order + matching Primary Contact
        PassfortRelatedEntitiesController.getKYCAndSalesOrderDetails(lstSalesOrder[0].PrimaryContact__c,'SalesOrder__c',lstSalesOrder[0].Id);
    }
   
public static testMethod void AccountCreatePassfortTransactionTestMethod() {
    makedata();
Test.setMock(HttpCalloutMock.class, new RestMock());
    // Get a business account
    Account acc = [
        SELECT Id, Name
        FROM Account
        WHERE IsPersonAccount = false
        LIMIT 1
    ];

    // Optional: get one related contact if needed
    Contact con = [
        SELECT Id, AccountId
        FROM Contact
        WHERE AccountId = :acc.Id
        LIMIT 1
    ];

    // Create Opportunity for fallback / relation
    Opportunity opp = new Opportunity();
    opp.Name = 'Account Parent Opportunity';
    opp.CloseDate = Date.today();
    opp.StageName = 'Closed Won';
    opp.AccountId = acc.Id;
    opp.PrimaryContact__c = con.Id;
    opp.UAE_Resident_Status__c = 'Non-Resident';
    opp.Nationality__c = 'India';
    opp.PassportExpiryDate__c = Date.today().addDays(300);
    opp.PassportNumber__c = 'P123456';
    opp.PassportIssueDate__c = Date.today().addDays(-100);
    insert opp;

    // Create Sales Order for this Account
    SalesOrder__c so = new SalesOrder__c();
    so.CustomerAccount__c = acc.Id;
    so.PrimaryContact__c = con.Id;
    so.Opportunity__c = opp.Id;
    
    insert so;

    // JSON for Account parent branch
    String transactionJson = '[{' +
        '"EntityRecordId":"' + acc.Id + '",' +
        '"EntityAPIName":"Account",' +
        '"EntityType":"Company",' +
        '"Name":"Account Parent Transaction",' +
        '"RiskStatus":"",' +
        '"ApprovalStatus":"In review",' +
        '"parentRecordId":"' + acc.Id + '",' +
        '"parentObjectName":"Account",' +
        '"passfortComment":"Test Comment",' +
        '"ParentDocumentIds":"",' +
        '"IsCommercialProject":false' +
    '}]';

    Test.startTest();
    String response = PassfortRelatedEntitiesController.createPassfortTransactionRecords(transactionJson, acc.Id);
    Test.stopTest();

    

    List<PassfortTransaction__c> ptList = [
        SELECT Id, Account__c, Sales_Order__c, Opportunity__c, EntityType__c
        FROM PassfortTransaction__c
        WHERE Account__c = :acc.Id
    ];

    //Added by Arvind-07/07/2026 - Version 1.0 - covers getKYCAndSalesOrderDetails for a non-Sales-Order parent (should skip the KYC/Payment lookup) and a non-matching contact
    PassfortRelatedEntitiesController.getKYCAndSalesOrderDetails(con.Id,'Account',acc.Id);
    PassfortRelatedEntitiesController.getKYCAndSalesOrderDetails(so.PrimaryContact__c,'SalesOrder__c',so.Id);
    PassfortRelatedEntitiesController.getKYCAndSalesOrderDetails(null,'SalesOrder__c',so.Id);
     
}
   public static testmethod void ContentDocumentIdTestMethod(){
        makedata();
        List<ContentVersion> lstContentVersion= [select id,ContentDocumentId from ContentVersion];
    	PassfortRelatedEntitiesController.deleteDocumentFile(lstContentVersion[0].ContentDocumentId);
     	PassfortRelatedEntitiesController.deleteDocumentFile(lstContentVersion[1].ContentDocumentId);
    } 
}