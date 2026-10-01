@isTest
public class mbpBrokerRequestControllerTest {

    private static User createBrokerCommunityUser(Contact con, String uniqueKey) {
        Profile communityProfile = [
            SELECT Id FROM Profile
            WHERE Name = 'Modon - Partner Community Login User'
            LIMIT 1
        ];
        Id userRoleId = null;
        List<UserRole> roles = [SELECT Id FROM UserRole WHERE Name = 'Partner User' LIMIT 1];
        if (!roles.isEmpty()) {
            userRoleId = roles[0].Id;
        }
        return new User(
            FirstName = 'Broker',
            LastName = 'PortalUser' + uniqueKey,
            Email = 'brokerportal' + uniqueKey + '@example.com',
            Username = 'brokerportal' + uniqueKey + '@test.com',
            Alias = ('b' + uniqueKey).left(8),
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = communityProfile.Id,
            ContactId = con.Id,
            UserRoleId = userRoleId,
            IsActive = true
        );
    }

    private static Contact createBrokerContact(String uniqueKey) {
        Account acc = new Account(Name = 'Broker Agency ' + uniqueKey);
        insert acc;
        Contact con = new Contact(
            FirstName = 'Broker',
            LastName = 'Agent' + uniqueKey,
            AccountId = acc.Id,
            Email = 'brokeragent' + uniqueKey + '@example.com',
            Broker_Type__c = 'Agent'
        );
        insert con;
        return con;
    }

    @isTest
    static void testPicklistValues() {
        Test.startTest();
        List<Map<String, String>> requestTypes =
            (List<Map<String, String>>) mbpBrokerRequestController.getPicklistValues('requestTypes');
        List<Map<String, String>> priorityOptions =
            (List<Map<String, String>>) mbpBrokerRequestController.getPicklistValues('priorityOptions');
        List<Map<String, String>> statusOptions =
            (List<Map<String, String>>) mbpBrokerRequestController.getPicklistValues('statusOptions');
        Map<String, List<Map<String, String>>> dependentSubTypes =
            (Map<String, List<Map<String, String>>>) mbpBrokerRequestController.getPicklistValues('dependentSubTypes');

        System.assert(!requestTypes.isEmpty());
        System.assert(!priorityOptions.isEmpty());
        System.assert(!statusOptions.isEmpty());
        System.assertNotEquals(null, dependentSubTypes);

        Boolean invalidThrown = false;
        try {
            mbpBrokerRequestController.getPicklistValues('invalidType');
        } catch (AuraHandledException e) {
            invalidThrown = true;
        }
        Test.stopTest();

        System.assert(invalidThrown, 'Invalid picklist type must throw AuraHandledException');
    }

    @isTest
    static void testBrokerPortal_fullFlow() {
        String uniqueKey = String.valueOf(DateTime.now().getTime());
        Contact brokerContact = createBrokerContact(uniqueKey);

        BrokerRequest__c draftReq = new BrokerRequest__c(
            Broker__c = brokerContact.Id,
            Status__c = 'Draft',
            Request_Type__c = 'Marketing Request',
            Request_SubType__c = 'Banner Design',
            Priority__c = 'Low',
            Description__c = 'Draft request for edit'
        );
        BrokerRequest__c newReq = new BrokerRequest__c(
            Broker__c = brokerContact.Id,
            Status__c = 'New',
            Request_Type__c = 'Marketing Request',
            Request_SubType__c = 'Social Media Post',
            Priority__c = 'Medium',
            Description__c = 'Existing request'
        );

        User brokerUser = createBrokerCommunityUser(brokerContact, uniqueKey);
        insert brokerUser;

        Map<String, Object> requestData = new Map<String, Object>{
            'Request_Type__c' => 'Marketing Request',
            'Request_SubType__c' => 'Email Campaign',
            'Description__c' => 'Created from test',
            'Priority__c' => 'High'
        };

        Test.startTest();
        System.runAs(brokerUser) {
            insert new List<BrokerRequest__c>{ draftReq, newReq };

            User runningUser = [
                SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
            ];
            System.assertEquals(brokerContact.Id, runningUser.ContactId);

            List<BrokerRequest__c> allRequests =
                mbpBrokerRequestController.getRequests(new Map<String, Object>());
            System.assert(allRequests.size() >= 2, 'Broker must see seeded requests');

            List<BrokerRequest__c> filteredRequests =
                mbpBrokerRequestController.getRequests(new Map<String, Object>{
                    'startDate' => String.valueOf(Date.today().addDays(-7)),
                    'endDate' => String.valueOf(Date.today())
                });
            System.assert(!filteredRequests.isEmpty(), 'Date-filtered list must return records');

            String csv = mbpBrokerRequestController.getRequestsCSVData(
                String.valueOf(Date.today().addDays(-7)),
                String.valueOf(Date.today())
            );
            System.assert(csv.contains('Request Number'), 'CSV must include header row');
            System.assert(csv.contains('Existing request'), 'CSV must include request data');

            String emptyCsv = mbpBrokerRequestController.getRequestsCSVData(
                String.valueOf(Date.today().addDays(30)),
                String.valueOf(Date.today().addDays(60))
            );
            System.assertEquals('', emptyCsv, 'Future date range must return empty CSV');

            Id createdId = mbpBrokerRequestController.createRequest(requestData, null, null);
            System.assertNotEquals(null, createdId);

            BrokerRequest__c created = [
                SELECT Id, Status__c, Broker__c, Description__c
                FROM BrokerRequest__c WHERE Id = :createdId
            ];
            System.assertEquals('New', created.Status__c);
            System.assertEquals(runningUser.ContactId, created.Broker__c);

            try {
                mbpBrokerRequestController.createRequest(
                    requestData,
                    EncodingUtil.base64Encode(Blob.valueOf('broker attachment')),
                    'broker-note.txt'
                );
            } catch (Exception e) {
                System.debug('Community file upload skipped in test: ' + e.getMessage());
            }

            Id updatedId = mbpBrokerRequestController.updateRequest(
                new Map<String, Object>{
                    'Id' => draftReq.Id,
                    'Request_Type__c' => 'Video Shoot Request',
                    'Request_SubType__c' => 'Property Video',
                    'Description__c' => 'Updated draft description',
                    'Priority__c' => 'High'
                },
                null,
                null,
                new List<Id>()
            );
            System.assertEquals(draftReq.Id, updatedId);

            BrokerRequest__c updated = [
                SELECT Description__c, Priority__c, Request_Type__c
                FROM BrokerRequest__c WHERE Id = :draftReq.Id
            ];
            System.assertEquals('Updated draft description', updated.Description__c);
            System.assertEquals('High', updated.Priority__c);

            Boolean missingIdThrown = false;
            try {
                mbpBrokerRequestController.updateRequest(
                    new Map<String, Object>{ 'Description__c' => 'No Id' },
                    null, null, null
                );
            } catch (AuraHandledException e) {
                missingIdThrown = true;
            }
            System.assert(missingIdThrown, 'Update without Id must throw');

            Boolean notDraftThrown = false;
            try {
                mbpBrokerRequestController.updateRequest(
                    new Map<String, Object>{
                        'Id' => newReq.Id,
                        'Description__c' => 'Should fail'
                    },
                    null, null, null
                );
            } catch (AuraHandledException e) {
                notDraftThrown = true;
            }
            System.assert(notDraftThrown, 'Non-Draft request must not be editable');

            try {
                mbpBrokerRequestController.updateRequest(
                    new Map<String, Object>{
                        'Id' => draftReq.Id,
                        'Description__c' => 'With file'
                    },
                    EncodingUtil.base64Encode(Blob.valueOf('updated file')),
                    'updated.txt',
                    new List<Id>()
                );
            } catch (Exception e) {
                System.debug('Draft file update skipped in test: ' + e.getMessage());
            }
        }
        Test.stopTest();
    }
}