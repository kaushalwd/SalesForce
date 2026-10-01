@isTest
public with sharing class DocumentTriggerHelperTest {
    
    @isTest
    static void myTestmethod(){
        Project__c project = new Project__c();
        insert project;
         
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '1';
        insert unit;
        
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        
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
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.PrimaryContact__c = [SELECT Id,PersonContactId FROM Account WHERE Id =:personAccount.Id LIMIT 1].PersonContactId;
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.UAE_Resident_Status__c = 'Non-Resident';
        oppObj.PassportNumber__c = 'UE123456';
        oppObj.PassportExpiryDate__c = system.today()+200;
        oppObj.PassportIssueDate__c = system.today()-200;
        oppObj.Nationality__c = 'India';
        oppObj.En_Nationality__c = 'India';
        oppObj.En_PassportNumber__c = 'P1234567';
        INSERT oppObj;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.Opportunity__c = oppObj.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'In Progress';
        so.CustomerAccount__c = acc.Id;
        INSERT so;
        
        Documents__c docObj = new Documents__c();
        docObj.Name = 'Signed SPA (Modon)';
        docObj.SalesOrder__c = so.Id;
        docObj.Status__c = 'Pending Upload';
        INSERT docObj;
        
        ContentVersion cv = new ContentVersion(
            Title = 'Signed SPA (Modon)',
            PathOnClient = 'Signed SPA (Modon).pdf',
            VersionData = Blob.valueOf('Test file content')
        );
        insert cv;

        ContentVersion insertedCV = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = insertedCV.ContentDocumentId,
            LinkedEntityId = docObj.Id,
            ShareType = 'V', // Viewer access
            Visibility = 'AllUsers'
        );
        insert link;

        Documents__c newDocObj = new Documents__c();
        newDocObj.Name = 'Signed SPA (Modon)';
        newDocObj.SalesOrder__c = so.Id;
        newDocObj.Id = docObj.Id;
        newDocObj.Status__c = 'Uploaded';
        UPDATE newDocObj;

        DocumentTriggerHelper.updateSalesOrder(new Map<Id, sObject>{docObj.Id => newDocObj}, new Map<Id, sObject>{docObj.Id => docObj});
        CommissionLineReviewController.updateSPADocId(new List<sObject>{newDocObj},new Map<Id, sObject>{docObj.Id => docObj});
    }
}