@IsTest
public class ShareUnitFilesBatch_Test {

    @TestSetup
    static void setupData() {

        Project__c project = new Project__c(
            Name = 'Default Tracker Test Project'
        );
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Default Tracker Test Phase',
            Project__c = project.Id
        );
        insert phase;

        Unit__c unitRec = new Unit__c(
            Phase__c = phase.Id,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2',
            Name = 'Default Tracker Unit'
        );
        insert unitRec;

        // Create Collaboration Group
        CollaborationGroup grp = new CollaborationGroup(
            Name = 'Test Unit File Group',
            CollaborationType = 'Public'
        );
        insert grp;

        // Create a file and attach it to the Unit
        ContentVersion cv = new ContentVersion(
            Title = 'Test Unit File',
            PathOnClient = 'TestUnitFile.txt',
            VersionData = Blob.valueOf('Test file content'),
            FirstPublishLocationId = unitRec.Id
        );
        insert cv;
    }


    @IsTest
    static void testBatchWithProjectName() {

        Project__c project = [
            SELECT Id, Name
            FROM Project__c
            WHERE Name = 'Default Tracker Test Project'
            LIMIT 1
        ];

        CollaborationGroup grp = [
            SELECT Id, Name
            FROM CollaborationGroup
            WHERE Name = 'Test Unit File Group'
            LIMIT 1
        ];

        Test.startTest();

        Database.executeBatch(
            new ShareUnitFilesBatch(
                grp.Name,
                project.Name
            ),
            200
        );

        Test.stopTest();

        Unit__c unitRec = [
            SELECT Id
            FROM Unit__c
            WHERE Name = 'Default Tracker Unit'
            LIMIT 1
        ];

        ContentVersion cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Title = 'Test Unit File'
            LIMIT 1
        ];

        List<ContentDocumentLink> groupLinks = [
            SELECT Id,
                   ContentDocumentId,
                   LinkedEntityId,
                   ShareType,
                   Visibility
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :cv.ContentDocumentId
            AND LinkedEntityId = :grp.Id
        ];

        System.assertEquals(
            1,
            groupLinks.size(),
            'The file should be shared with the Collaboration Group.'
        );

        System.assertEquals(
            cv.ContentDocumentId,
            groupLinks[0].ContentDocumentId,
            'The correct ContentDocument should be shared.'
        );

        System.assertEquals(
            grp.Id,
            groupLinks[0].LinkedEntityId,
            'The file should be linked to the correct Collaboration Group.'
        );

        System.assertEquals(
            'V',
            groupLinks[0].ShareType,
            'ShareType should be Viewer.'
        );

        System.assertEquals(
            'AllUsers',
            groupLinks[0].Visibility,
            'Visibility should be AllUsers.'
        );
    }


    @IsTest
    static void testBatchWithUnitIds() {

        Unit__c unitRec = [
            SELECT Id
            FROM Unit__c
            WHERE Name = 'Default Tracker Unit'
            LIMIT 1
        ];

        CollaborationGroup grp = [
            SELECT Id, Name
            FROM CollaborationGroup
            WHERE Name = 'Test Unit File Group'
            LIMIT 1
        ];

        Set<Id> unitIds = new Set<Id>{
            unitRec.Id
        };

        Test.startTest();

        Database.executeBatch(
            new ShareUnitFilesBatch(
                grp.Name,
                unitIds
            ),
            200
        );

        Test.stopTest();

        ContentVersion cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Title = 'Test Unit File'
            LIMIT 1
        ];

        List<ContentDocumentLink> groupLinks = [
            SELECT Id,
                   ContentDocumentId,
                   LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :cv.ContentDocumentId
            AND LinkedEntityId = :grp.Id
        ];

        System.assertEquals(
            1,
            groupLinks.size(),
            'The file should be shared with the group.'
        );
    }


    @IsTest
    static void testAlreadySharedFileIsNotDuplicated() {

        Unit__c unitRec = [
            SELECT Id
            FROM Unit__c
            WHERE Name = 'Default Tracker Unit'
            LIMIT 1
        ];

        CollaborationGroup grp = [
            SELECT Id, Name
            FROM CollaborationGroup
            WHERE Name = 'Test Unit File Group'
            LIMIT 1
        ];

        ContentVersion cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Title = 'Test Unit File'
            LIMIT 1
        ];

        // Manually share the file with the group first.
        ContentDocumentLink existingLink = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = grp.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert existingLink;

        Test.startTest();

        Database.executeBatch(
            new ShareUnitFilesBatch(
                grp.Name,
                new Set<Id>{ unitRec.Id }
            ),
            200
        );

        Test.stopTest();

        List<ContentDocumentLink> groupLinks = [
            SELECT Id,
                   ContentDocumentId,
                   LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :cv.ContentDocumentId
            AND LinkedEntityId = :grp.Id
        ];

        System.assertEquals(
            1,
            groupLinks.size(),
            'The batch should not create a duplicate ContentDocumentLink.'
        );
    }


    @IsTest
    static void testGroupDoesNotExist() {

        Project__c project = [
            SELECT Id, Name
            FROM Project__c
            WHERE Name = 'Default Tracker Test Project'
            LIMIT 1
        ];

        Test.startTest();

        Database.executeBatch(
            new ShareUnitFilesBatch(
                'Group That Does Not Exist',
                project.Name
            ),
            200
        );

        Test.stopTest();

        // No exception should occur when the CollaborationGroup
        // does not exist.
        System.assert(
            true,
            'Batch should complete without exception when group does not exist.'
        );
    }


    @IsTest
    static void testNoTargetUnits() {

        CollaborationGroup grp = [
            SELECT Id, Name
            FROM CollaborationGroup
            WHERE Name = 'Test Unit File Group'
            LIMIT 1
        ];

        Set<Id> emptyUnitIds = new Set<Id>();

        Test.startTest();

        Database.executeBatch(
            new ShareUnitFilesBatch(
                grp.Name,
                emptyUnitIds
            ),
            200
        );

        Test.stopTest();

        System.assert(
            true,
            'Batch should complete successfully with no target Unit IDs.'
        );
    }
}