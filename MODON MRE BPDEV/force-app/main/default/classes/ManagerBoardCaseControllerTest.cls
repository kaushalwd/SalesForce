@isTest
public class ManagerBoardCaseControllerTest {
    @isTest
    static void testGetCases_WithData() {
        // Prepare test user info
        Id userId = UserInfo.getUserId();
        User u = [SELECT Name FROM User WHERE Id = :userId];
          String modonRecordTypeId =  Utility.getRecordTypeIdByDevName(Case.SObjectType, 'X800_Modon_Cases');
        List<Case> casesToInsert = new List<Case>();
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'User');
        insert testContact;
  
          Case newCase = new Case(
            Subject = 'Test Service Case',
            RecordTypeId = modonRecordTypeId,
            Origin = 'Website',
            Description = 'Test description',
            Requestor_Email__c = 'TestRequestEmail7@gmail.com',
            Requestor_Name__c = 'RequestName7',
            Requestor_Phone__c = '+971666877888',
            CaseCategory__c = 'General Enquiry',
            ContactId = [SELECT Id FROM Contact LIMIT 1].Id
        );
        casesToInsert.add(newCase);    
        // Create sample cases
  /*      List<Case> casesToInsert = new List<Case>();
        for (Integer i = 0; i < 3; i++) {
            casesToInsert.add(new Case(
                Subject             = 'Test Case ' + i,
                Status              = 'New',
                Origin              = 'Phone',
                CaseType__c         = 'Type' + i,
                Breached__c         = false,
                CaseCategory__c     = 'Category' + i,
                CaseSubCategory__c  = 'SubCategory' + i,
                Primary_Assignee__c = userId,
                SR_Number__c        = 'SR' + i,
                Requestor_Name__c   = 'Req ' + i
            ));
        }*/
        insert casesToInsert;

        // Exercise the controller
        Test.startTest();
            List<ManagerBoardCaseController.CaseWrapper> wrappers =
                ManagerBoardCaseController.getCases();
        Test.stopTest();

        // Verify correct number of wrappers returned
        System.assertNotEquals(null, wrappers, 'Wrappers list should not be null');
        System.assertEquals(
            1, wrappers.size(),
            'Expected 3 wrappers for the 1 test cases'
        );

        // Verify each wrapper’s fields
       /* for (Integer i = 0; i < wrappers.size(); i++) {
            Case inserted = casesToInsert[i];
            ManagerBoardCaseController.CaseWrapper w = wrappers[i];

            System.assertEquals(inserted.Id, w.caseId);
            System.assertEquals(inserted.CaseNumber, w.caseNumber);
            System.assertEquals('/' + inserted.Id, w.caseUrl);
            System.assertEquals(inserted.Status, w.status);
            System.assertEquals(inserted.CaseType__c, w.caseType);
            System.assertEquals(inserted.Breached__c, w.breached);
            System.assertEquals(inserted.CaseCategory__c, w.caseCategory);
            System.assertEquals(inserted.CaseSubCategory__c, w.caseSubCategory);
            System.assertEquals(u.Name, w.ownerName);
            System.assertEquals(u.Name, w.primaryAssignee);
            System.assertEquals(inserted.SR_Number__c, w.srNumber);
            System.assertEquals(inserted.Requestor_Name__c, w.requestorName);
        }*/
    }

    @isTest
    static void testGetCases_NoData() {
        // No cases inserted

        Test.startTest();
            List<ManagerBoardCaseController.CaseWrapper> wrappers =
                ManagerBoardCaseController.getCases();
        Test.stopTest();

        System.assertNotEquals(null, wrappers, 'Wrappers list should not be null');
        System.assertEquals(
            0, wrappers.size(),
            'Expected an empty list when no Case records exist'
        );
    }
}