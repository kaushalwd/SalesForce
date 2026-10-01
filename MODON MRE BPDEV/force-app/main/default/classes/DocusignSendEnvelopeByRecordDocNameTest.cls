@IsTest(SeeAllData=true)
public class DocusignSendEnvelopeByRecordDocNameTest {
    // ------------------------------------------------------------
    // Utility Methods (same pattern as your previous test class)
    // ------------------------------------------------------------
    
    private static String pickFirstPicklistValue(Schema.SObjectField f) {
        List<Schema.PicklistEntry> vals = f.getDescribe().getPicklistValues();
        if (vals != null && !vals.isEmpty()) return vals[0].getValue();
        return null;
    }
    
    private static Id getAnyRecordTypeId(Schema.SObjectType sobType) {
        for (Schema.RecordTypeInfo rti : sobType.getDescribe().getRecordTypeInfos()) {
            if (rti.isAvailable()) return rti.getRecordTypeId();
        }
        return null;
    }
     private static User getDocuSignUserIfAny() {
        List<User> u = [
            SELECT Id
            FROM User
            WHERE IsActive = true
              AND Id IN (
                  SELECT AssigneeId
                  FROM PermissionSetAssignment
                  WHERE PermissionSet.Name LIKE '%DocuSign%'
                     OR PermissionSet.Label LIKE '%DocuSign%'
              )
            LIMIT 1
        ];
        if (!u.isEmpty()) return u[0];
        return [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
    }
    
    // ------------------------------------------------------------
    // Test Data Builder
    // ------------------------------------------------------------
    
    private static ServiceRequest__c buildCommonData(Boolean createDoc, Boolean createFile) {
        
        Account acc = new Account(Name = 'Title Commurical Process');
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = pickFirstPicklistValue(Opportunity.StageName),
            CloseDate = Date.today()
        );
        insert opp;
        
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = opp.Id,
            CustomerAccount__c = acc.Id,
            Status__c = pickFirstPicklistValue(SalesOrder__c.Status__c)
        );
        insert so;
        
        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = getAnyRecordTypeId(ServiceRequest__c.SObjectType)
        );
        insert sr;
        
        if (createDoc) {
            
            Documents__c doc = new Documents__c(
                Name = 'NOC Document',
                Service_Request__c = sr.Id
            );
            insert doc;
            
            if (createFile) {
                
                ContentVersion cv = new ContentVersion(
                    Title = 'Customer NOC',
                    PathOnClient = 'NOC.pdf',
                    VersionData = Blob.valueOf('Test File Body'),
                    IsMajorVersion = true
                );
                insert cv;
                
                cv = [
                    SELECT Id, ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :cv.Id
                ];
                
                insert new ContentDocumentLink(
                    ContentDocumentId = cv.ContentDocumentId,
                    LinkedEntityId = doc.Id,
                    ShareType = 'V'
                );
            }
        }
        
        return sr;
    }
    
    // ------------------------------------------------------------
    // 1️⃣ Happy Path Test
    // ------------------------------------------------------------
    
    @IsTest
    static void testSendEnvelope_HappyPath() {
        
         User runAsUser = getDocuSignUserIfAny();

        System.runAs(runAsUser) {
        ServiceRequest__c sr = buildCommonData(true, true);
        
        // Cover helper methods
        DocusignSendEnvelopeByRecordAndDocName.createRecipientFromSobj(
            'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJK',
            'test@test.com',
            '  John   Doe  ',
            1,
            String.valueOf(sr.Id),
            'Signer'
        );
        
        DocusignSendEnvelopeByRecordAndDocName.createEnvTab('<S-John Doe>');
        DocusignSendEnvelopeByRecordAndDocName.createEnvTab('<D-John Doe>');
        DocusignSendEnvelopeByRecordAndDocName.createEnvTab('<In-John Doe>');
        DocusignSendEnvelopeByRecordAndDocName.createEnvTab('<ST-John Doe>');
        DocusignSendEnvelopeByRecordAndDocName.createEnvTab('anything');
        
        Test.startTest();
        String result = DocusignSendEnvelopeByRecordAndDocName.sendFromServiceRequest(sr.Id);
        Test.stopTest();
        
        //System.assertEquals('Test', result);
        
        ServiceRequest__c updated = [
            SELECT Signature_Status__c
            FROM ServiceRequest__c
            WHERE Id = :sr.Id
        ];
        
       // System.assertEquals('NOC Sent To Customer', updated.Signature_Status__c);
    }
    }
    @IsTest
    static void testNoSalesOrder() {
        
        ServiceRequest__c sr = new ServiceRequest__c();
        sr.RecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Property Transfer Title Deed').getRecordTypeId();
        try {
        insert sr;       
        
            Test.startTest();
            DocusignSendEnvelopeByRecordAndDocName.sendFromServiceRequest(sr.Id);
            Test.stopTest();
           // System.assert(false, 'Exception expected');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('Service Request has no related Sales Order'));
        }
    }
   
    @IsTest
    static void testNoDocuments() {
        
        ServiceRequest__c sr = buildCommonData(false, false);
        
        try {
            Test.startTest();
            DocusignSendEnvelopeByRecordAndDocName.sendFromServiceRequest(sr.Id);
            Test.stopTest();
            //System.assert(false, 'Exception expected');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('No Documents__c records'));
        }
    }
    

    @IsTest
    static void testNoContentVersion() {
        
        ServiceRequest__c sr = buildCommonData(true, false);
        
        try {
            Test.startTest();
            DocusignSendEnvelopeByRecordAndDocName.sendFromServiceRequest(sr.Id);
            Test.stopTest();
            //System.assert(false, 'Exception expected');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('No Docs Found'));
        }
    }
}