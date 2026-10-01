/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 03-25-2025
 * @last modified by  : Krishna Chaitanya
**/
@isTest
public class ProgressKYCControllerTest {

    @isTest
    static void testCreateAccounts1(){
                        
        Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Joint Owner Addition And Deletion').getRecordTypeId();

        ServiceCatalog__c sc = new ServiceCatalog__c(); 
        sc.Name = 'Joint Owner Addition and Deletion';
        sc.Object__c = 'Service Request';
         sc.ProcessType__c = 'Sales';
            sc.Service_Request_Type__c = 'Joint Owner Addition and Deletion';
            sc.Type__c = 'Service Request';
            insert sc;
    
        ServiceAction__c sa = new ServiceAction__c();
        sa.Name = 'Initiate Request';
        sa.ServiceCatalog__c = sc.Id;
        sa.Description__c = 'Initiat Request';
        sa.Notes__c = 'Create new task';
        sa.Order__c = 1;
        sa.Task_Name__c = 'Initiate request for SR';
        sa.TaskSubject__c = 'Initiate request for SR';
        sa.TaskSubType__c = 'CRM Team Task';
        insert sa;

        ServiceAction__c sa1 = new ServiceAction__c();
        sa1.Name = 'Check KYC';
        sa1.ServiceCatalog__c = sc.Id;
        sa1.Description__c = 'Initiat Request';
        sa1.Notes__c = 'Create new task';
        sa1.Order__c = 2;
        sa1.Task_Name__c = 'KYC SR';
        sa1.TaskSubject__c = 'KYC for SR';
        sa1.TaskSubType__c = 'CRM Team Task';
        insert sa1;

        ServiceAction__c sa2 = new ServiceAction__c();
        sa2.Name = 'Initiate Request';
        sa2.ServiceCatalog__c = sc.Id;
        sa2.Description__c = 'Initiat Request';
        sa2.Notes__c = 'Create new task';
        sa2.Order__c = 3;
        sa2.Task_Name__c = 'Initiate request for SR';
        sa2.TaskSubject__c = 'Initiate request for SR';
        sa2.TaskSubType__c = 'CRM Team Task';
        insert sa2;

        ServiceAction__c sa3 = new ServiceAction__c();
        sa3.Name = 'Initiate Request';
        sa3.ServiceCatalog__c = sc.Id;
        sa3.Description__c = 'Initiat Request';
        sa3.Notes__c = 'Create new task';
        sa3.Order__c = 4;
        sa3.Task_Name__c = 'Initiate request for SR';
        sa3.TaskSubject__c = 'Initiate request for SR';
        sa3.TaskSubType__c = 'CRM Team Task';
        insert sa3;

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
        personAccount.PaymentMethod__pc='Cash';
        personAccount.PurposeOfTransaction__pc='House rent';
        personAccount.PersonEmail='abc@pwc.com';
        personAccount.AreYouPoliticallyExposedPersonPEP__pc=true;
        personAccount.SourceOfIncome__pc='Salary';
        personAccount.DeliveryChannel__pc='Face to face interaction';
        personAccount.NoOfPropertyPurchasedWithModon__pc=2;        
        insert personAccount;
        
        // Create Test Opportunity
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = Date.today(),
            StageName = 'Prospecting',
            Status__c = '	In Progress'
        );
        insert testOpportunity;
        
        
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            CustomerAccount__c = personAccount.Id,
            Opportunity__c = testOpportunity.Id,
            Status__c = 'SPA Generated'
        );
        insert testSalesOrder;
        
        ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = testSalesOrder.Id,
            type__c = 'Normal',
            recordtypeId = SRPTRecordTypeId
        );
        insert testServiceRequest;

        ProgressKYCController.getEntityRecords(testServiceRequest.Id);


    }
    
    @isTest
    static void testCreateAccounts2(){
    	
        Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Service Request Management -Property Transfer OffPlan').getRecordTypeId();

            ServiceCatalog__c sc = new ServiceCatalog__c(); 
            sc.Name = 'Property Transfer OffPlan';
               sc.Object__c = 'Service Request';
               sc.ProcessType__c = 'Sales';
               sc.Service_Request_Type__c = 'Service Request Management -Property Transfer OffPlan';
               sc.Type__c = 'Service Request';
               insert sc;


        ServiceAction__c sa = new ServiceAction__c();
        sa.Name = 'Initiate Request';
        sa.ServiceCatalog__c = sc.Id;
        sa.Description__c = 'Initiat Request';
        sa.Notes__c = 'Create new task';
        sa.Order__c = 1;
        sa.Task_Name__c = 'Initiate request for SR';
        sa.TaskSubject__c = 'Initiate request for SR';
        sa.TaskSubType__c = 'CRM Team Task';
        insert sa;

        ServiceAction__c sa1 = new ServiceAction__c();
        sa1.Name = 'Check KYC';
        sa1.ServiceCatalog__c = sc.Id;
        sa1.Description__c = 'Initiat Request';
        sa1.Notes__c = 'Create new task';
        sa1.Order__c = 2;
        sa1.Task_Name__c = 'KYC SR';
        sa1.TaskSubject__c = 'KYC for SR';
        sa1.TaskSubType__c = 'CRM Team Task';
        insert sa1;

        ServiceAction__c sa2 = new ServiceAction__c();
        sa2.Name = 'Initiate Request';
        sa2.ServiceCatalog__c = sc.Id;
        sa2.Description__c = 'Initiat Request';
        sa2.Notes__c = 'Create new task';
        sa2.Order__c = 3;
        sa2.Task_Name__c = 'Initiate request for SR';
        sa2.TaskSubject__c = 'Initiate request for SR';
        sa2.TaskSubType__c = 'CRM Team Task';
        insert sa2;

        ServiceAction__c sa3 = new ServiceAction__c();
        sa3.Name = 'Initiate Request';
        sa3.ServiceCatalog__c = sc.Id;
        sa3.Description__c = 'Initiat Request';
        sa3.Notes__c = 'Create new task';
        sa3.Order__c = 4;
        sa3.Task_Name__c = 'Initiate request for SR';
        sa3.TaskSubject__c = 'Initiate request for SR';
        sa3.TaskSubType__c = 'CRM Team Task';
        insert sa3;

        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create Test Opportunity
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = Date.today(),
            StageName = 'Prospecting',
            Status__c = '	In Progress'
        );
        insert testOpportunity;
           Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Id contactRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Contact').getRecordTypeId();
        
        
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            CustomerAccount__c = testAccount.Id,
            Opportunity__c = testOpportunity.Id,
            Status__c = 'SPA Generated'
        );
        insert testSalesOrder;
        
        ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = testSalesOrder.Id,
            type__c = 'Normal',
            recordtypeId = SRPTRecordTypeId
        );
        insert testServiceRequest;
   Prospect_Account__c prospect1 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            RecordTypeId	=  contactRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '1234567890',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'UAE',
            State__c = 'Abu Dhabi',
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            Service_Request__c = testServiceRequest.Id,
            Street__c = 'Street 1',
            IsPersonAccount__c =true,
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        insert prospect1;
        ProgressKYCController.getEntityRecords(testServiceRequest.Id);
        ProgressKYCCOntroller.isComplianceCleared(testServiceRequest.Id);
		ProgressKYCController.isAccessSubmitForCompliance();
        ProgressKYCController.getDocumentRecords(prospect1.Id);
        	String transactionList4='[{"EntityRecordId":"'+prospect1.Id+'","EntityAPIName":"Contact","EntityType":"Individual","Name":"transactionList4","RiskStatus":"","ApprovalStatus":"In review","parentRecordId":"'+testServiceRequest.Id+'","parentObjectName":"SalesOrder__c","passfortComment":"Test Comment","ParentDocumentIds":""}]';
     	ProgressKYCController.createPassfortTransactionRecords(transactionList4,prospect1.Id);
        Task tsk=[Select Id,Subject,Status from Task where WhatId=:testServiceRequest.Id limit 1];
        tsk.status= 'Closed';
        //Update tsk;
        
         Task tsk1=[Select Id,Subject,Status from Task where WhatId=:testServiceRequest.Id limit 1];
        tsk1.status= 'Closed';
        tsk1.KYC_Status__c ='Approved';
        Update tsk1;
        
       

    }
    
    
    
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
        act.PaymentMethod__c='Cash';
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
        personAccount.PaymentMethod__pc='Cash';
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
        con.PaymentMethod__c='Cash';
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
        
        Opportunity opp2= new Opportunity();
        opp2.Name='Test Opportunity2';
        opp2.CloseDate=Date.today();
        opp2.StageName='Closed Won';
        opp2.AccountId=lstAccount[1].Id;
        opp2.PrimaryContact__c=personAccount.PersonContactId;
        
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
        ProgressKYCController.isComplianceCleared(lstOpp[0].Id);
     	ProgressKYCController.getEntityRecords(lstOpp[0].Id);
        ProgressKYCController.isComplianceCleared(lstOpp[1].Id);
     	ProgressKYCController.getEntityRecords(lstOpp[1].Id);
    }
    public static testmethod void NationalityTestMethod1() {
    	ProgressKYCController.getNationalityOptions();
    }
    public static testmethod void ActIdTestMethod1() {
        makedata();
        List<Account> lstAct=[select id from Account];
        ProgressKYCController.getShareholderRecords(lstAct[0].Id);
        ProgressKYCController.getDocumentRecords(lstAct[0].Id);
        
        ProgressKYCController.deleteDocumentPlaceholders(lstAct[0].Id);
     	
    }
    public static testmethod void ConIdTestMethod1() {
        makedata();
        List<Contact> lstCon=[select id from Contact where recordType.DeveloperName!='Shareholder'];
        ProgressKYCController.getDocumentRecords(lstCon[0].Id);
        ProgressKYCController.deleteDocumentPlaceholders(lstCon[0].Id);	
    }
    
    public static testmethod void SalesOrderCreatePassfortTransactionTestMethod(){
        makedata();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        List<SalesOrder__c> lstSalesOrder=[select id,CustomerAccount__c,PrimaryContact__c from SalesOrder__c];
        
        String transactionList3='[{"EntityRecordId":"'+lstSalesOrder[0].CustomerAccount__c+'","EntityAPIName":"Account","EntityType":"Company","Name":"transactionList3","RiskStatus":"","ApprovalStatus":"In review","parentRecordId":"'+lstSalesOrder[0].Id+'","parentObjectName":"SalesOrder__c","passfortComment":"Test Comment","ParentDocumentIds":""}]';
     	ProgressKYCController.createPassfortTransactionRecords(transactionList3,lstSalesOrder[0].Id);
        String strFields='';
        List<String> lstAccFields =  System.Label.PassfortAccountFieldsToCheck.split(',');
       
     	String transactionList4='[{"EntityRecordId":"'+lstSalesOrder[0].PrimaryContact__c+'","EntityAPIName":"Contact","EntityType":"Individual","Name":"transactionList4","RiskStatus":"","ApprovalStatus":"In review","parentRecordId":"'+lstSalesOrder[0].Id+'","parentObjectName":"SalesOrder__c","passfortComment":"Test Comment","ParentDocumentIds":""}]';
     	ProgressKYCController.createPassfortTransactionRecords(transactionList4,lstSalesOrder[0].Id);
       
        
           }

}