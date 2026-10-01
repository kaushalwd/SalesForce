/**********************************************************************************************************************
* Name               : ContentDocumentLinkSalesMeetingTest                                                        
* Description        : Test class for ContentDocumentLinkTrigger logic handling Sales Executive Meeting file counts
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 18 Aug 2026     Initial Draft           
******************************************************************************************************************/
@isTest
private class ContentDocumentLinkSalesMeetingTest {
    @TestSetup
    static void makeData(){
        // Get the Customer Record Type ID
        Id customerRtId = Schema.SObjectType.Sales_Executive_Meeting__c.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();

        Sales_Executive_Meeting__c meeting = new Sales_Executive_Meeting__c(
            RecordTypeId = customerRtId
        );
        insert meeting;
    }

    @isTest
    static void testInsertPresentationFile() {
        Sales_Executive_Meeting__c meeting = [SELECT Id FROM Sales_Executive_Meeting__c LIMIT 1];

        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Presentation';
        cv.PathOnClient = 'TestPresentation.pdf'; 
        cv.VersionData = Blob.valueOf('Test Content');
        cv.IsMajorVersion = true;
        insert cv;

        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.LinkedEntityId = meeting.Id;
        cdl.ContentDocumentId = conDocId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';

        Test.startTest();
        insert cdl;
        Test.stopTest();

        Sales_Executive_Meeting__c updatedMeeting = [SELECT Presentation_Files_Count__c FROM Sales_Executive_Meeting__c WHERE Id = :meeting.Id];
        System.assertEquals(1, updatedMeeting.Presentation_Files_Count__c, 'File count should be 1 after inserting a PDF file.');
    }

    @isTest
    static void testDeletePresentationFile() {
        Sales_Executive_Meeting__c meeting = [SELECT Id FROM Sales_Executive_Meeting__c LIMIT 1];

        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Presentation';
        cv.PathOnClient = 'TestPresentation.pptx';
        cv.VersionData = Blob.valueOf('Test Content');
        cv.IsMajorVersion = true;
        insert cv;

        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.LinkedEntityId = meeting.Id;
        cdl.ContentDocumentId = conDocId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;

        Test.startTest();
        // Clear processedIds so the TriggerHandler doesn't skip the after delete event
        TriggerHandler.processedIds.clear();
        delete cdl; 
        Test.stopTest();

        Sales_Executive_Meeting__c updatedMeeting = [SELECT Presentation_Files_Count__c FROM Sales_Executive_Meeting__c WHERE Id = :meeting.Id];
        System.assertEquals(0, updatedMeeting.Presentation_Files_Count__c, 'File count should be 0 after deleting the file.');
    }

    @isTest
    static void testInsertInvalidFileExtension() {
        Sales_Executive_Meeting__c meeting = [SELECT Id FROM Sales_Executive_Meeting__c LIMIT 1];

        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Image';
        cv.PathOnClient = 'TestImage.jpg';
        cv.VersionData = Blob.valueOf('Test Content');
        cv.IsMajorVersion = true;
        insert cv;

        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.LinkedEntityId = meeting.Id;
        cdl.ContentDocumentId = conDocId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';

        Test.startTest();
        insert cdl;
        Test.stopTest();

        Sales_Executive_Meeting__c updatedMeeting = [SELECT Presentation_Files_Count__c FROM Sales_Executive_Meeting__c WHERE Id = :meeting.Id];
        System.assertEquals(0, updatedMeeting.Presentation_Files_Count__c, 'File count should remain 0 for an invalid file extension.');
    }
    @isTest
    static void testDeleteContentDocument() {
        Sales_Executive_Meeting__c meeting = [SELECT Id FROM Sales_Executive_Meeting__c LIMIT 1];

        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Presentation UI Delete';
        cv.PathOnClient = 'TestPresentationUI.pdf';
        cv.VersionData = Blob.valueOf('Test Content');
        cv.IsMajorVersion = true;
        insert cv;

        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.LinkedEntityId = meeting.Id;
        cdl.ContentDocumentId = conDocId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;

        Test.startTest();
        // Clear processedIds so the framework executes the trigger handler correctly
        TriggerHandler.processedIds.clear();
        
        // Delete the ContentDocument directly (simulating UI deletion)
        ContentDocument cd = new ContentDocument(Id = conDocId);
        delete cd; 
        Test.stopTest();

        Sales_Executive_Meeting__c updatedMeeting = [SELECT Presentation_Files_Count__c, Includes_Presentation__c FROM Sales_Executive_Meeting__c WHERE Id = :meeting.Id];
        System.assertEquals(0, updatedMeeting.Presentation_Files_Count__c, 'File count should be 0 after deleting the ContentDocument.');
        System.assertEquals(false, updatedMeeting.Includes_Presentation__c, 'Includes_Presentation__c should be unchecked when file count hits 0.');
    }
}