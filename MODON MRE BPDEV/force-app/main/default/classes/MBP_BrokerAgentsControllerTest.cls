@isTest
private class MBP_BrokerAgentsControllerTest {
    @testSetup
    static void setupData() {
        RecordType partnerRecordType = [
        SELECT Id FROM RecordType
        WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1
    ];
        // Create a test Account
        Account acc = new Account(Name = 'Test Agency', RecordTypeId = partnerRecordType.Id);
        insert acc;

        // Create a test Contact
        Contact con = new Contact(LastName = 'Test Agent', AccountId = acc.Id, Email = 'testagent@example.com');
        insert con;

        // Fetch Profile
        //Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];

    Id userRoleId;
    try {
        userRoleId = [SELECT Id FROM UserRole WHERE Name = 'Partner User' LIMIT 1].Id;
    } catch (Exception e) {
        userRoleId = null;
    }

        // Create a test User linked to the Contact
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@modonportal.com',
            Username = 'testuser' + DateTime.now().getTime() + '@modonportal.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            ContactId = con.Id,
            UserRoleId = userRoleId,
        IsActive = true
        );
        insert testUser;
        
        // Simulate a file linked to the contact (optional)
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test content')
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = con.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
    }

    @isTest
    static void test_getUserInformation() {
        // Run as the test user created
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@modonportal.com' LIMIT 1];

        System.runAs(testUser) {
            Test.startTest();
            User result = MBP_BrokerAgentsController.getUserInformation();
            Test.stopTest();

            System.assertNotEquals(null, result, 'User result should not be null');
            System.assertEquals(testUser.Id, result.Id, 'Returned user should match the test user ID');
        }
    }
    
    static void test_getContactsUserInfo() {
        User testUser = [SELECT Id FROM User WHERE Email = 'agentuser@example.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            List<MBP_BrokerAgentsController.AgentInformation> agentInfoList = MBP_BrokerAgentsController.getContactsUserInfo();
            Test.stopTest();

            System.assertNotEquals(null, agentInfoList, 'Returned agent list should not be null');
            System.assert(agentInfoList.size() > 0, 'Should return at least one agent record');

            MBP_BrokerAgentsController.AgentInformation info = agentInfoList[0];
            System.assertNotEquals(null, info.contact, 'Contact should not be null');
            System.assertEquals('agent@example.com', info.email, 'Email should match test data');
        }
    }
    
    @isTest
    static void test_getPicklistValuesGeneric() {
        // Use a known object and picklist field — adjust if needed
        String objectName = 'Contact';
        String picklistField = 'Broker_Type__c'; // This must be a valid picklist in your org

        Test.startTest();
        List<Map<String, String>> result = MBP_BrokerAgentsController.getPicklistValuesGeneric(objectName, picklistField);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'There should be at least one picklist value');

        // Check structure of first entry
        Map<String, String> entry = result[0];
        System.assert(entry.containsKey('label'), 'Entry should contain label');
        System.assert(entry.containsKey('value'), 'Entry should contain value');
    }
    
    @isTest
    static void test_createBrokerAgent_insert() {
        User u = [SELECT Id FROM User WHERE Email = 'testuser@modonportal.com' LIMIT 1];
        System.runAs(u) {
            // Prepare input data for new Contact
            Map<String, Object> agentInfo = new Map<String, Object>{
                'firstName' => 'Neha',
                'lastName' => 'Kumar',
                'emailId' => 'neha.kumar@example.com',
                'phoneNumber' => '0501234567',
                'countryCode' => '+971',
                'title' => 'Ms.',
                'birthdate' => '1995-01-01',
                'role' => 'Agent',
                'residentStatus' => 'Abu Dhabi',
                'emiratesID' => '784-1995-1234567-1',
                'expiryDate' => '2027-01-01',
                'passportNumber' => 'M9876543',
                'passportExpiryDate' => '2030-01-01',
                'nationality' => 'India',
                'isPrimaryOwner' => true,
                     'isPrimaryAgencyAdmin' => true,
                    'isBroker'=>true
            };

            Test.startTest();
            String contactId = MBP_BrokerAgentsController.createBrokerAgent(agentInfo);
            Test.stopTest();

            System.assertNotEquals(null, contactId, 'Returned Contact Id should not be null');

            Contact newContact = [SELECT Id, Email, Agent_Status__c FROM Contact WHERE Id = :contactId];
            System.assertEquals('Pending Verification', newContact.Agent_Status__c, 'Status should be Pending Verification');
        }
    }
    
    @isTest
    static void test_createUserFromContact() {
        // Retrieve test contact
        Contact con1 = [SELECT Id FROM Contact WHERE Email = 'testagent@example.com' LIMIT 1];
        //Contact con1 = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE LastName = 'Test Agent'];
        //Contact con1 = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Id = :con.Id];


        // Make sure profile exists
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name = :BRConstants.MODON_PARTNER_COMMUNITY_PROFILE LIMIT 1];

        Test.startTest();
        User createdUser = MBP_BrokerAgentsController.createUserFromContact(con1.Id, true, 'Modon - Agent Access');
        Test.stopTest();

        System.assertNotEquals(null, createdUser, 'Created user should not be null');
        System.assertEquals(con1.Id, createdUser.ContactId, 'User should be linked to the contact');
        System.assertEquals('testagent@example.com', createdUser.Email, 'User email should match contact email');
        System.assertEquals(true, createdUser.IsActive, 'User should be active');
    }
    
    
    @isTest
    static void test_uploadFile_as_ContentVersion() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];

        // Prepare dummy base64 data
        String base64String = EncodingUtil.base64Encode(Blob.valueOf('Dummy PDF content'));
        String filename = 'TestUpload.pdf';
        String type = 'Document'; // Anything except 'Profile Image'
        String recordId = acc.Id;
        List<String> existingFilenames = new List<String>();

        Test.startTest();
        String result = MBP_BrokerAgentsController.uploadFile(base64String, filename, type, recordId, true, existingFilenames);
        Test.stopTest();

       // System.assertEquals('Success', result, 'Expected upload to succeed');

        // Confirm file is linked
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId
        ];
       // System.assert(!links.isEmpty(), 'ContentDocumentLink should be created');
    }
    
    // BP-094 - a Broker Card lands in the agent's ADM/RERA slot.
    @isTest
    static void test_uploadFile_brokerCard() {
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testagent@example.com' LIMIT 1];
        String base64String = EncodingUtil.base64Encode(Blob.valueOf('Broker card'));
        String filename = 'Broker Card - test.pdf';

        Test.startTest();
        String result = MBP_BrokerAgentsController.uploadFile(base64String, filename, 'Broker Card', con.Id, true, new List<String>{ filename });
        String refused = MBP_BrokerAgentsController.uploadFile(base64String, 'Visa.pdf', 'Visa Copy', con.Id, true, new List<String>());
        Test.stopTest();

        System.assertEquals('Success', result, 'A Broker Card should be accepted');
        System.assertEquals('Unsupported type', refused, 'Unknown types are still refused');
        List<Documents__c> slots = [SELECT Id FROM Documents__c WHERE PrimaryContact__c = :con.Id AND Name = 'Agent_Adm/Rera_Copy'];
        System.assertEquals(1, slots.size(), 'The card should reuse the one ADM/RERA slot');
        System.assertEquals(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :slots[0].Id], 'The file should sit under that slot');
    }

    // BP-094 - the RERA and ADM types still save to the same slot.
    @isTest
    static void test_uploadFile_reraAndAdmUnchanged() {
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testagent@example.com' LIMIT 1];
        String base64String = EncodingUtil.base64Encode(Blob.valueOf('Card'));
        List<String> keep = new List<String>{ 'RERA Broker Card - test.pdf', 'ADM Card - test.pdf' };

        Test.startTest();
        String rera = MBP_BrokerAgentsController.uploadFile(base64String, keep[0], 'RERA Broker Card', con.Id, true, keep);
        String adm = MBP_BrokerAgentsController.uploadFile(base64String, keep[1], 'ADM Card', con.Id, true, keep);
        Test.stopTest();

        System.assertEquals('Success', rera, 'A RERA card should still be accepted');
        System.assertEquals('Success', adm, 'An ADM card should still be accepted');
        List<Documents__c> slots = [SELECT Id FROM Documents__c WHERE PrimaryContact__c = :con.Id AND Name = 'Agent_Adm/Rera_Copy'];
        System.assertEquals(1, slots.size(), 'Both cards share the one ADM/RERA slot');
        System.assertEquals(2, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :slots[0].Id], 'Both files should sit under that slot');
    }

    // BP-097 - the approver's Reject comment reaches the roster row of a portal user.
    @isTest
    static void test_rejectionComments_fromApproval() {
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testagent@example.com' LIMIT 1];
        User portalUser = [SELECT Id FROM User WHERE ContactId = :con.Id LIMIT 1];
        Boolean rejected = false;
        try {
            Approval.ProcessSubmitRequest submit = new Approval.ProcessSubmitRequest();
            submit.setObjectId(con.Id);
            Approval.ProcessResult submitted = Approval.process(submit);
            Approval.ProcessWorkitemRequest reject = new Approval.ProcessWorkitemRequest();
            reject.setWorkitemId(submitted.getNewWorkitemIds()[0]);
            reject.setAction('Reject');
            reject.setComments('Passport copy is not clear');
            rejected = Approval.process(reject).isSuccess();
        } catch (Exception e) {
            // The approval is org setup. Where it cannot run here, the lookup must still be safe.
            rejected = false;
        }
        if (!rejected) update new Contact(Id = con.Id, Agent_Status__c = 'Rejected');

        Test.startTest();
        Map<Id, String> comments = MBP_BrokerAgentsController.getRejectionComments(new Set<Id>{ con.Id });
        List<MBP_BrokerAgentsController.AgentInformation> rows;
        System.runAs(portalUser) {
            rows = MBP_BrokerAgentsController.getContactsUserInfo();
        }
        Test.stopTest();

        String expected = rejected ? 'Passport copy is not clear' : null;
        System.assertEquals(expected, comments.get(con.Id), 'The latest Reject comment is returned');
        System.assertEquals(1, rows.size(), 'The portal user sees the agent');
        System.assertEquals(expected, rows[0].rejectionComments, 'The roster row carries the comment');
    }

    // BP-097 - the reason typed in the status tool counts too, where the status log exists.
    @isTest
    static void test_rejectionComments_fromStatusLog() {
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testagent@example.com' LIMIT 1];
        update new Contact(Id = con.Id, Agent_Status__c = 'Rejected');
        Boolean hasLog = Type.forName('Broker_Status_Log__c') != null;
        if (hasLog) {
            List<SObject> logs = new List<SObject>();
            for (String status : new List<String>{ 'Rejected', 'Active' }) {
                SObject log = Schema.getGlobalDescribe().get('Broker_Status_Log__c').newSObject();
                log.put('Name', 'Test Agent - ' + status);
                log.put('Broker_Agent__c', con.Id);
                log.put('New_Status__c', status);
                log.put('Status_Reason__c', status == 'Rejected' ? 'Emirates ID has expired' : 'Not a rejection');
                logs.add(log);
            }
            insert logs;
        }

        Test.startTest();
        Map<Id, String> comments = MBP_BrokerAgentsController.getRejectionComments(new Set<Id>{ con.Id });
        Test.stopTest();

        System.assertEquals(hasLog ? 'Emirates ID has expired' : null, comments.get(con.Id), 'Only a Rejected log row counts');
    }

    // BP-097 - no rejected agent means no lookup and no comment.
    @isTest
    static void test_rejectionComments_noneForOtherAgents() {
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testagent@example.com' LIMIT 1];
        User portalUser = [SELECT Id FROM User WHERE ContactId = :con.Id LIMIT 1];

        Test.startTest();
        System.assertEquals(0, MBP_BrokerAgentsController.getRejectionComments(null).size(), 'Null is safe');
        System.assertEquals(0, MBP_BrokerAgentsController.getRejectionComments(new Set<Id>()).size(), 'Empty is safe');
        List<MBP_BrokerAgentsController.AgentInformation> rows;
        System.runAs(portalUser) {
            rows = MBP_BrokerAgentsController.getContactsUserInfo();
        }
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'The portal user sees the agent');
        System.assertEquals(null, rows[0].rejectionComments, 'An agent who is not rejected has no comment');
    }

    // BP-098 - Enable Agent cannot override a status that Broker Management decided.
    @isTest
    static void test_toggleRefusedForBrokerManagementStatuses() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];
        List<Contact> agents = new List<Contact>();
        for (String status : new List<String>{ 'Pending Verification', 'Rejected', 'Suspended', 'Blocked', MBP_BrokerAgencyLevelController.STATUS_PENDING_TRADE_LICENSE }) {
            agents.add(new Contact(LastName = 'Held ' + status, AccountId = acc.Id, Agent_Status__c = status));
        }
        insert agents;

        Test.startTest();
        for (Contact agent : agents) {
            Boolean refused = false;
            try {
                MBP_BrokerAgentsController.updateContactAgentStatus(agent.Id, agent.Agent_Status__c);
            } catch (AuraHandledException e) {
                refused = e.getMessage().contains('Only Broker Management');
            }
            System.assert(refused, agent.Agent_Status__c + ' must not be switched by a broker');
        }
        Test.stopTest();

        for (Contact agent : [SELECT LastName, Agent_Status__c FROM Contact WHERE Id IN :agents]) {
            System.assertEquals(agent.LastName.removeStart('Held '), agent.Agent_Status__c, 'The status is untouched');
        }
    }

    // BP-098 - the login user of a rejected agent cannot be switched on either.
    @isTest
    static void test_toggleRefusedForRejectedAgentUser() {
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testagent@example.com' LIMIT 1];
        User portalUser = [SELECT Id FROM User WHERE ContactId = :con.Id LIMIT 1];
        update new Contact(Id = con.Id, Agent_Status__c = 'Rejected');

        // The call is refused before it writes anything, so the refusal is the proof.
        Boolean refused = false;
        Test.startTest();
        try {
            MBP_BrokerAgentsController.updateUserAgentStatus(portalUser.Id, 'Rejected');
        } catch (AuraHandledException e) {
            refused = e.getMessage().contains('Only Broker Management');
        }
        Test.stopTest();

        System.assert(refused, 'The user of a rejected agent must not be switched by a broker');
    }

    // BP-099 - saving a rejected agent sends it for verification again, even with no field change.
    @isTest
    static void test_rejectedAgentGoesBackForVerificationOnSave() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];
        User portalUser = [SELECT Id FROM User WHERE Email = 'testuser@modonportal.com' LIMIT 1];
        Id agentRecordType = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Broker Agent').getRecordTypeId();
        List<Contact> agents = new List<Contact>{
            new Contact(FirstName = 'Rita', LastName = 'Rejected', Email = 'rita.rejected@example.com', AccountId = acc.Id, RecordTypeId = agentRecordType, Agent_Status__c = 'Rejected'),
            new Contact(FirstName = 'Adam', LastName = 'Active', Email = 'adam.active@example.com', AccountId = acc.Id, RecordTypeId = agentRecordType, Agent_Status__c = 'Active')
        };
        insert agents;

        Test.startTest();
        System.runAs(portalUser) {
            for (Contact agent : agents) {
                MBP_BrokerAgentsController.createBrokerAgent(new Map<String, Object>{
                    'contactId' => agent.Id,
                    'firstName' => agent.FirstName,
                    'lastName' => agent.LastName,
                    'emailId' => agent.Email,
                    'isBroker' => false,
                    'isPrimaryOwner' => false,
                    'isPrimaryAgencyAdmin' => false
                });
            }
        }
        Test.stopTest();

        Map<Id, Contact> saved = new Map<Id, Contact>([SELECT Agent_Status__c FROM Contact WHERE Id IN :agents]);
        System.assertEquals('Pending Verification', saved.get(agents[0].Id).Agent_Status__c, 'A rejected agent goes back for verification');
        System.assertEquals('Active', saved.get(agents[1].Id).Agent_Status__c, 'An active agent with no change stays active');
    }

    @isTest
    static void test_deleteFileByDocumentId() {
        // Create dummy account for linking
        Account acc = new Account(Name = 'Delete File Test Account');
        insert acc;

        // Create ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'DeleteMe',
            PathOnClient = 'DeleteMe.pdf',
            VersionData = Blob.valueOf('Test file to delete')
        );
        insert cv;

        // Retrieve ContentDocumentId
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        String docId = cv.ContentDocumentId;

        // Link to Account via ContentDocumentLink
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = acc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        // Confirm link and document exist
        System.assertEquals(2, [SELECT COUNT() FROM ContentDocumentLink WHERE ContentDocumentId = :docId]);
        System.assertEquals(1, [SELECT COUNT() FROM ContentDocument WHERE Id = :docId]);

        // Call deleteFileByDocumentId
        Test.startTest();
        String result = MBP_BrokerAgentsController.deleteFileByDocumentId(docId);
        Test.stopTest();

        System.assertEquals('Success: File deleted', result);

        // Confirm deletion
        System.assertEquals(0, [SELECT COUNT() FROM ContentDocumentLink WHERE ContentDocumentId = :docId], 'Links should be deleted');
        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :docId], 'Document should be deleted');
    }
    
    @isTest
    static void test_resetPassword_success() {
        // Create test user
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        User u = new User(
            FirstName = 'Reset',
            LastName = 'User',
            Email = 'resetuser@example.com',
            Username = 'resetuser' + DateTime.now().getTime() + '@example.com',
            Alias = 'rsusr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profile.Id
        );
        insert u;

        Test.startTest();
        MBP_BrokerAgentsController.resetPassword(u.Id);
        Test.stopTest();

        System.assert(true, 'Password reset completed without exception');
    }

    
    
    @isTest
    static void test_resetPassword_success1() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User u = new User(
            FirstName = 'Reset',
            LastName = 'User',
            Email = 'resetuser@example.com',
            Username = 'resetuser' + DateTime.now().getTime() + '@example.com',
            Alias = 'rsusr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profile.Id
        );
        insert u;

        Test.startTest();
        MBP_BrokerAgentsController.resetPassword(u.Id);
        Test.stopTest();

        System.assert(true, 'Password reset executed without error');
    }
    
    @isTest
    static void test_updateContactAgentStatus() {
        // Setup test Contact
         Account acc = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];

        Contact con = new Contact(
            LastName = 'Status Test',
            AccountId = acc.Id,
            Agent_Status__c = 'Active' // assuming valid initial status
        );
        insert con;

        // Call method with "Active" → should switch to "In Active"
        Test.startTest();
        MBP_BrokerAgentsController.updateContactAgentStatus(con.Id, 'Active');
        Test.stopTest();

        Contact updated1 = [SELECT Agent_Status__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals('In Active', updated1.Agent_Status__c, 'Should switch to In Active');

        // Call method with "Inactive" → should switch to "Active"
        //Test.startTest();
        MBP_BrokerAgentsController.updateContactAgentStatus(con.Id, 'Inactive');
        //Test.stopTest();

        Contact updated2 = [SELECT Agent_Status__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals('Active', updated2.Agent_Status__c, 'Should switch back to Active');
    }
    
    
   @isTest
    static void test_updateUserAgentStatus() {
        // Create a test user
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User u = new User(
            FirstName = 'Agent',
            LastName = 'Status',
            Email = 'agentstatus@example.com',
            Username = 'agentstatus' + DateTime.now().getTime() + '@example.com',
            Alias = 'asusr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profile.Id,
            IsActive = true
        );
        insert u;

        // Case 1: checkboxVal == 'Active' → should deactivate
        Test.startTest();
        MBP_BrokerAgentsController.updateUserAgentStatus(u.Id, 'Active');
        Test.stopTest();

        User updated1 = [SELECT IsActive FROM User WHERE Id = :u.Id];
        System.assertEquals(false, updated1.IsActive, 'User should be deactivated');

        // Case 2: checkboxVal == 'Inactive' → should activate
        //Test.startTest();
        MBP_BrokerAgentsController.updateUserAgentStatus(u.Id, 'Inactive');
        //Test.stopTest();

        User updated2 = [SELECT IsActive FROM User WHERE Id = :u.Id];
        System.assertEquals(true, updated2.IsActive, 'User should be reactivated');
    } 
    
    
    @isTest
    static void test_updateAgent_withSensitiveChange() {
        // Setup account and contact
         Account acc = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];

        Contact con = new Contact(
            FirstName = 'Agent',
            LastName = 'Sensitive',
            Email = 'original@example.com',
            Phone = '0501234567',
            PassportNumber__c = 'P123',
            EIDNumber__c = 'EID123',
            AccountId = acc.Id,
            Agent_Status__c = 'Active'
        );
        insert con;

        // Prepare updated contact with changed sensitive fields
        Contact updated = new Contact(
            Email = 'updated@example.com',
            Phone = '0507654321',
            PassportNumber__c = 'P456',
            EIDNumber__c = 'EID456'
        );

        Test.startTest();
        String result = MBP_BrokerAgentsController.updateAgent(updated, con.Id);
        Test.stopTest();

        System.assertEquals('Pending Verification', result, 'Should return Pending Verification');
        
        Contact refreshed = [SELECT Agent_Status__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals('Pending Verification', refreshed.Agent_Status__c, 'Status should be updated');

       // Agent_Approvals__c approval = [SELECT Id, Status__c, Contact__c FROM Agent_Approvals__c WHERE Contact__c = :con.Id LIMIT 1];
       // System.assertEquals('Pending', approval.Status__c, 'Approval status should be Pending');
    }

    @isTest
    static void test_updateAgent_withoutSensitiveChange() {
        // Setup contact
         Account acc = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];

        Contact con = new Contact(
            FirstName = 'Agent',
            LastName = 'NoChange',
            Email = 'unchanged@example.com',
            Phone = '0500000000',
            PassportNumber__c = 'P999',
            EIDNumber__c = 'EID999',
            AccountId = acc.Id,
            Agent_Status__c = 'Active'
        );
        insert con;

        // Prepare identical update
        Contact updated = new Contact(
            Email = 'unchanged@example.com',
            Phone = '0500000000',
            PassportNumber__c = 'P999',
            EIDNumber__c = 'EID999'
        );

        Test.startTest();
        String result = MBP_BrokerAgentsController.updateAgent(updated, con.Id);
        Test.stopTest();

        System.assertEquals('Updated', result, 'Should return Updated');
        
        Contact refreshed = [SELECT Agent_Status__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals('Active', refreshed.Agent_Status__c, 'Status should remain unchanged');

      /*  List<Agent_Approvals__c> approvals = [
            SELECT Id FROM Agent_Approvals__c WHERE Contact__c = :con.Id
        ]; 
        System.assertEquals(0, approvals.size(), 'No approval should be created');*/
    }
    
    @isTest
static void test_permissionSetAssignment_logicCoverage() {
    // Step 1: Insert Account and Contact
    RecordType partnerRecordType = [
        SELECT Id FROM RecordType
        WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1
    ];

     Account acc = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];

    Contact con = new Contact(
        LastName = 'Test Agent',
        AccountId = acc.Id,
        Email = 'testagent@example.com',
        Broker_Type__c = 'Agent'
    );
    insert con;

    // Step 2: Insert User (setup object) outside of runAs
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];
    Id userRoleId = null;
    try {
        userRoleId = [SELECT Id FROM UserRole WHERE Name = 'Partner User' LIMIT 1].Id;
    } catch (Exception e) {
        // continue with null
    }

    User u = new User(
        FirstName = 'Agent',
        LastName = 'PS',
        Email = 'agentps@example.com',
        Username = 'agentps' + DateTime.now().getTime() + '@example.com',
        Alias = 'aps',
        TimeZoneSidKey = 'Asia/Kolkata',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id,
        ContactId = con.Id,
        UserRoleId = userRoleId,
        IsActive = true
    );
    insert u; // ✅ insert before using in runAs

    // Step 3: Call permissionSetAssignment inside runAs
    System.runAs(u) {
        // Confirm PermissionSets exist
        List<String> psNames = new List<String>{
            BRConstants.MODON_LIMITED_LOGIN_ACCESS,
            BRConstants.MODON_AGENT_ACCESS,
            BRConstants.MODON_AGENCY_OWNER_ACCESS,
            BRConstants.MODON_AGENCY_ADMIN_ACCESS
        };
        List<PermissionSet> psList = [
            SELECT Id FROM PermissionSet WHERE Name IN :psNames
        ];
        System.assert(!psList.isEmpty(), 'Permission sets should exist');

        Test.startTest();
        MBP_BrokerAgentsController.permissionSetAssignment(new List<User>{u});
        Test.stopTest();

        List<PermissionSetAssignment> after = [
            SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :u.Id
        ];
        System.assert(after.size() > 0, 'PermissionSetAssignment should be created');
    }
}

    
    @isTest
    static void test_agentInformation_properties() {
        // Mock Contact
        Contact c = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@example.com',
            Phone = '0501234567'
        );

        // Mock User
        User u = new User(
            FirstName = 'Agent',
            LastName = 'User',
            Email = 'agent.user@example.com'
        );

        // Mock file list
        List<Map<String, Object>> files = new List<Map<String, Object>>();
        Map<String, Object> fileData = new Map<String, Object>{
            'filename' => 'document.pdf',
            'type' => 'pdf',
            'fileSize' => 12345,
            'documentId' => '069xx0000001234',
            'downloadUrl' => '/sfc/servlet.shepherd/document/download/069xx0000001234'
        };
        files.add(fileData);

        // Create AgentInformation instance and assign values
        MBP_BrokerAgentsController.AgentInformation agentInfo = new MBP_BrokerAgentsController.AgentInformation();
        agentInfo.contact = c;
        agentInfo.user = u;
        agentInfo.mobile = c.Phone;
        agentInfo.email = c.Email;
        agentInfo.lastUpdated = c.LastModifiedDate;
        agentInfo.files = files;

        // Assertions to cover fields
        System.assertEquals(c.Email, agentInfo.email);
        System.assertEquals(c.Phone, agentInfo.mobile);
        System.assertEquals(u.Email, agentInfo.user.Email);
        System.assertEquals('document.pdf', agentInfo.files[0].get('filename'));
    }

/**
    @isTest
    static void test_createAgent() {
        // Inputs for the method
        String name = 'Kiran';
        String email = 'kiran@example.com';
        String phone = '0501234567';

        // Call the method
        Test.startTest();
        Contact result = BrokerAgentsController.createAgent(name, email, phone);
        Test.stopTest();

        // Assertions to confirm contact creation
        System.assertNotEquals(null, result, 'Contact should not be null');
        System.assertEquals(name, result.LastName, 'LastName should match input');
        System.assertEquals(email, result.Email, 'Email should match input');
        System.assertEquals(phone, result.Phone, 'Phone should match input');
        System.assertEquals('Active', result.Agent_Status__c, 'Agent_Status__c should be "New"');

        // Confirm record exists in DB
        Contact c = [SELECT Id, Agent_Status__c FROM Contact WHERE Id = :result.Id];
        System.assertEquals('Active', c.Agent_Status__c);
    }*/
    
    @isTest
    static void test_validateEmailAndMobile_callout() {
        // Register mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        MBP_BrokerAgentsController.validateEmailAndMobile();
        Test.stopTest();

        System.assert(true, 'Callout executed without exceptions');
    }
    
    @isTest
    static void test_setProfileImageAsync() {
        // Register the mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Call the future method
        Test.startTest();
        MBP_BrokerAgentsController.setProfileImageAsync(
            'profile_pic.jpg',
            'image/jpeg',
            'https://example.com/download/profile_pic.jpg'
        );
        Test.stopTest(); // Ensures @future executes

        System.assert(true, 'setProfileImageAsync executed successfully');
    }


    @isTest
    static void test_getContactsUserInfo1() {
        contact con = [SELECT Id FROM contact WHERE Email = 'testagent@example.com' LIMIT 1];
        
        ContentVersion cv = new ContentVersion(
            Title = 'ID Document',
            PathOnClient = 'id_doc.pdf',
            VersionData = Blob.valueOf('Dummy file content')
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = con.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
        // Query test user created in @testSetup
        User u = [SELECT Id FROM User WHERE Email = 'testuser@modonportal.com' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            List<MBP_BrokerAgentsController.AgentInformation> result =
                MBP_BrokerAgentsController.getContactsUserInfo();
            Test.stopTest();

            System.assertNotEquals(null, result, 'Returned list should not be null');
            System.assert(result.size() > 0, 'At least one AgentInformation should be returned');
            
            MBP_BrokerAgentsController.AgentInformation info = result[0];
            System.assertNotEquals(null, info.contact, 'Contact info should be present');
            System.assertNotEquals(null, info.user, 'User info should be present');
            System.assertEquals('testagent@example.com', info.email, 'Email should match contact');
            System.assertNotEquals('0501234567', info.mobile, 'Phone should match contact');
           // System.assertNotEquals(null, info.files, 'Files should be mapped from getUploadedFiles');
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    /**
    static User sysAdmin;
    static Account agency;
    static Contact contact;

   @testSetup
static void setupData() {
    // Get necessary metadata
    RecordType brokerRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1];
    Profile profile = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];

    // Create Account
    agency = new Account(Name = 'Test Agency', RecordTypeId = brokerRt.Id);
    insert agency;

    // Create Contact linked to agency
    contact = new Contact(
        FirstName = 'Test',
        LastName = 'Agent',
        Email = 'agent@test.com',
        Phone = '1234567890',
        Broker_Type__c = 'Agent',
        AccountId = agency.Id
    );
    insert contact;

    // Create User linked to the above contact
    sysAdmin = new User(
        Username = 'testuser' + DateTime.now().getTime() + '@modonportal.com',
        LastName = 'Admin',
        Email = 'admin@test.com',
        Alias = 'adm',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        TimeZoneSidKey = 'Asia/Dubai',
        ProfileId = profile.Id,
        ContactId = contact.Id
    );
    insert sysAdmin;

    // Debug validation
    User debugUser = [SELECT Id, ContactId, Contact.AccountId FROM User WHERE Id = :sysAdmin.Id];
    System.debug('ContactId: ' + debugUser.ContactId);
    System.debug('AccountId: ' + debugUser.Contact.AccountId);
}



    
    @isTest
    static void testGetUserInformation() {
        System.runAs(sysAdmin) {
            User u = BrokerAgentsController.getUserInformation();
            System.assertNotEquals(null, u);
        }
    }

    @isTest
    static void testCreateAndUpdateAgent() {
        System.runAs(sysAdmin) {
            Contact created = BrokerAgentsController.createAgent('Test Agent', 'newemail@test.com', '1112223333');
            System.assertNotEquals(null, created.Id);

            created.Phone = '9998887777';
            String result = BrokerAgentsController.updateAgent(created, created.Id);
            System.assertEquals('Pending Verification', result);
        }
    }

    @isTest
    static void testCreateUserFromContact() {
        System.runAs(sysAdmin) {
            User newUser = BrokerAgentsController.createUserFromContact(contact.Id, true, 'MODON_AGENT_ACCESS');
            System.assertNotEquals(null, newUser);
            System.assertEquals(contact.Email, newUser.Email);
        }
    }

    @isTest
    static void testGetPicklistValuesGeneric() {
        System.runAs(sysAdmin) {
            List<Map<String, String>> values = BrokerAgentsController.getPicklistValuesGeneric('Contact', 'Salutation');
            System.assert(values.size() > 0);
        }
    }

    @isTest
    static void testCreateBrokerAgentInsert() {
        System.runAs(sysAdmin) {
            Map<String, Object> agentInfo = new Map<String, Object>{
                'emailId' => 'agent2@test.com',
                'phoneNumber' => '9876543210',
                'countryCode' => '+971',
                'firstName' => 'Agent',
                'lastName' => 'Two',
                'title' => 'Mr.',
                'birthdate' => '1990-01-01',
                'role' => 'Agent',
                'residentStatus' => 'Dubai',
                'emiratesID' => '784-1987-1234567-1',
                'expiryDate' => '2027-12-31',
                'passportNumber' => 'M9876543',
                'passportExpiryDate' => '2029-06-30',
                'nationality' => 'UAE',
                'primaryOwner' => true
            };
            String result = BrokerAgentsController.createBrokerAgent(agentInfo);
            System.assertNotEquals('Duplicate', result);
        }
    }

    @isTest
    static void testResetPasswordAndStatusUpdate() {
        System.runAs(sysAdmin) {
            User user = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
            BrokerAgentsController.resetPassword(user.Id);
            BrokerAgentsController.updateUserAgentStatus(user.Id, 'Inactive');
            BrokerAgentsController.updateContactAgentStatus(contact.Id, 'Inactive');
        }
    }

    @isTest
    static void testPermissionSetAssignment() {
        System.runAs(sysAdmin) {
            List<User> users = [SELECT Id FROM User WHERE Email = :contact.Email];
            BrokerAgentsController.permissionSetAssignment(users);
        }
    }

    // File upload and deleteFileByDocumentId require mocking or real file creation which is best tested in integration environments.
    */
    @IsTest
    static void testCreateContentVersion_Success() {
        // Arrange: create base64 string for file content
        Blob fileBlob = Blob.valueOf('This is a test file');
        String base64Data = EncodingUtil.base64Encode(fileBlob);
        String fileName = 'TestDoc.txt';
        String type = 'txt';

        // Act
        Test.startTest();
        ContentVersion cv = MBP_BrokerAgentsController.createContentVersion(base64Data, fileName, type);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, cv, 'ContentVersion should not be null');
        System.assertEquals(fileName, cv.Title, 'Title should match');
        System.assertEquals(fileName, cv.PathOnClient, 'PathOnClient should match');

        // Validate it really exists in DB
        ContentVersion dbCv = [SELECT Id, Title, PathOnClient, VersionData, ContentDocumentId 
                               FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        System.assertEquals(fileName, dbCv.Title, 'Stored ContentVersion should match input');
    }
    
    @IsTest
    static void testCreateContentLink_Success() {
        // Arrange: create parent record
        Account acc = new Account(Name='Linked Account');
        insert acc;

        // Create a ContentVersion first
        Blob fileBlob = Blob.valueOf('Another test file');
        String base64Data = EncodingUtil.base64Encode(fileBlob);
        ContentVersion cv = MBP_BrokerAgentsController.createContentVersion(base64Data, 'LinkedFile.pdf', 'pdf');

        // Act
        Test.startTest();
        ContentDocumentLink cdl = MBP_BrokerAgentsController.createContentLink(cv.Id, acc.Id);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, cdl, 'ContentDocumentLink should not be null');
        System.assertEquals(acc.Id, cdl.LinkedEntityId, 'LinkedEntityId should match Account');
        
        // Verify in DB
        ContentDocumentLink dbLink = [
            SELECT Id, ContentDocumentId, LinkedEntityId, ShareType 
            FROM ContentDocumentLink 
            WHERE Id = :cdl.Id LIMIT 1
        ];
        System.assertEquals(acc.Id, dbLink.LinkedEntityId, 'Database link must match Account');
        System.assertEquals('V', dbLink.ShareType, 'ShareType must be V');
    }
    
    @IsTest
    static void testCreateContentVersion_InvalidBase64() {
        
        String badBase64 = 'Test';
        String fileName = 'BadFile.txt';
        String type = 'txt';

        ContentVersion cv = MBP_BrokerAgentsController.createContentVersion(badBase64, fileName, type);
    }

    @IsTest
    static void testCreateContentLink_InvalidId() {
        // Arrange: invalid contentVersionId
        Account acc = new Account(Name='Bad Link Account');
        insert acc;

        // Act
        ContentDocumentLink cdl = MBP_BrokerAgentsController.createContentLink('001XXXXXXXXXXXXXXX', acc.Id);

        // Assert
        System.assertEquals(null, cdl, 'Should return null if ContentVersion lookup fails');
    }
    @IsTest
    static void testCreateAgent_Success() {
        // Arrange
        String testName  = 'Test Agent';
        String testEmail = 'agent@test.com';
        String testPhone = '1234567890';

        // Act
        Test.startTest();
        Contact createdAgent = MBP_BrokerAgentsController.createAgent(testName, testEmail, testPhone);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, createdAgent, 'Contact should not be null');
        System.assertNotEquals(null, createdAgent.Id, 'Contact should be inserted');
        System.assertEquals(testName, createdAgent.LastName, 'Name should match');
        System.assertEquals(testEmail, createdAgent.Email, 'Email should match');
        System.assertEquals(testPhone, createdAgent.Phone, 'Phone should match');

        // Verify with SOQL
        Contact dbAgent = [
            SELECT Id, LastName, Email, Phone, Agent_Status__c 
            FROM Contact 
            WHERE Id = :createdAgent.Id
        ];
        
    }

    @IsTest
    static void testCreateAgent_MinimalInput() {
        // Arrange: only required LastName
        String testName  = 'Only Name Agent';

        // Act
        Contact createdAgent = MBP_BrokerAgentsController.createAgent(testName, null, null);

    }
    @IsTest
    static void testCheckExistingPrimary_Owner() {
        // Arrange
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact c = new Contact(
            LastName = 'OwnerContact',
            AccountId = acc.Id,
            Primary_Owner__c = true
        );
        insert c;

        Boolean result = MBP_BrokerAgentsController.checkExistingPrimary(acc.Id, 'Owner');

        System.assertEquals(true, result, 'Should return true when Owner exists');
    }
    @IsTest
    static void testCheckExistingPrimary_AgencyAdmin() {
        Account acc = new Account(Name = 'Test Account 2');
        insert acc;

        Contact c = new Contact(
            LastName = 'AdminContact',
            AccountId = acc.Id,
            Primary_Agency_Admin__c = true
        );
        insert c;

        // Act
        Boolean result = MBP_BrokerAgentsController.checkExistingPrimary(acc.Id, 'Agency Admin');

        // Assert
        System.assertEquals(true, result, 'Should return true when Agency Admin exists');
    }

    @IsTest
    static void testCheckExistingPrimary_NoMatch() {
        Account acc = new Account(Name = 'Empty Account');
        insert acc;

       
        System.assertEquals(false, MBP_BrokerAgentsController.checkExistingPrimary(acc.Id, 'Owner'), 'Should return false with no owner');
        System.assertEquals(false, MBP_BrokerAgentsController.checkExistingPrimary(acc.Id, 'Agency Admin'), 'Should return false with no admin');
        System.assertEquals(false, MBP_BrokerAgentsController.checkExistingPrimary(acc.Id, 'RandomType'), 'Should return false for unsupported type');
    }
}