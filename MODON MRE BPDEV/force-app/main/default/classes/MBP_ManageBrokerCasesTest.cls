@isTest
private class MBP_ManageBrokerCasesTest {
    
    static User createUser(String brokerType, String uniqueKey) {
        String timestamp = String.valueOf(System.now().getTime());
        String randomSuffix = String.valueOf(Math.random()).replace('.', '').substring(0, 8);
        String trulyUniqueKey = uniqueKey + timestamp + randomSuffix;
        
        Account acc = new Account(Name = 'Test Acc ' + trulyUniqueKey);
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'F' + trulyUniqueKey,
            LastName = 'L' + trulyUniqueKey,
            Email = trulyUniqueKey + '@test.com',
            Phone = '1234567890',
            AccountId = acc.Id,
            Broker_Type__c = brokerType
        );
        insert con;
        
        User u = new User(
            Username = 'user' + trulyUniqueKey + '@test.com',
            LastName = 'Last' + trulyUniqueKey,
            Email = trulyUniqueKey + '@test.com',
            Alias = 'a' + trulyUniqueKey.substring(0, 5),
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ContactId = con.Id
        );
        insert u;
        return u;
    }
    
    static Unit__c createUnit(String uniqueKey) {
        Project__c proj = new Project__c(Name = 'Test Project ' + uniqueKey);
        insert proj;
        
        Phase__c phase = new Phase__c(Name = 'Phase ' + uniqueKey, Project__c = proj.Id);
        insert phase;
        
        Unit__c unit = new Unit__c(
            Name = 'Unit-' + uniqueKey,
            Phase__c = phase.Id,
            Status__c = 'Sold',
            Number_of_Bedrooms__c = '2',
            PlotNo__c = uniqueKey,
            UnitClassification__c = 'Apartment'
        );
        insert unit;
        return unit;
    }
    
    static void testGetCasesFor(String brokerType, String suffix) {
        User u = createUser(brokerType, suffix);
        
        System.runAs(u) {
            MBP_ManageBrokerCases.getCases(false, null, null);
            MBP_ManageBrokerCases.getCases(false, '2024-01-01', null);
            MBP_ManageBrokerCases.getCases(false, null, '2024-12-31');
            MBP_ManageBrokerCases.getCases(false, '2024-01-01', '2024-12-31');
        }
    }
    
    static testMethod void testAllPaths() {
        String uniqueId = String.valueOf(System.now().getTime()) + String.valueOf(Math.random()).replace('.', '').substring(0, 8);
        
        Account acc = new Account(Name = 'Main Test Account ' + uniqueId);
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'Main',
            LastName = 'Contact' + uniqueId,
            Email = 'main' + uniqueId + '@test.com',
            Phone = '9999999999',
            AccountId = acc.Id,
            Broker_Type__c = 'Owner'
        );
        insert con;
        
        User u = new User(
            Username = 'mainuser' + uniqueId + '@test.com',
            LastName = 'MainUser' + uniqueId,
            Email = 'main' + uniqueId + '@test.com',
            Alias = 'main' + uniqueId.substring(0, 3),
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ContactId = con.Id
        );
        insert u;
        
        Id rtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = 'Broker_Cases' LIMIT 1].Id;
        Id queueId = [SELECT Id FROM Group WHERE DeveloperName = 'Brokers_Queue' AND Type = 'Queue' LIMIT 1].Id;
        Unit__c unit = createUnit(uniqueId);
        
        Case c1 = new Case(
            Subject = 'Test Subject 1',
            Description = 'Test Description 1',
            CaseCategory__c = 'Broker Enquiry',
            CaseType__c = 'Non VIP Case',
            Customer_Type__c = 'Visitor',
            Visitor_First_Name__c = 'first',
            Visitor_Last_Name__c = 'last',
            Visitor_Phone__c = '+919885370070',
            Visitor_Email__c = 'test@test.com',
            Requestor_Email__c = 'test@test.com',
            ContactId = con.Id,
            AccountId = acc.Id,
            Status = 'New',
            RecordTypeId = rtId,
            Unit__c = unit.Id,
            CreatedDate = DateTime.newInstance(2024, 6, 15, 10, 0, 0)
        );
        insert c1;
        
        Case c2 = new Case(
            Subject = 'Test Subject 2',
            Description = 'Test Description 2',
            CaseCategory__c = 'Broker Enquiry',
            CaseType__c = 'Non VIP Case',
            Customer_Type__c = 'Visitor',
            Visitor_First_Name__c = 'first',
            Visitor_Last_Name__c = 'last',
            Visitor_Phone__c = '+919885370070',
            Visitor_Email__c = 'test@test.com',
            Requestor_Email__c = 'test@test.com',
            ContactId = con.Id,
            AccountId = acc.Id,
            Status = 'new',
            RecordTypeId = rtId,
            Unit__c = unit.Id,
            CreatedDate = DateTime.newInstance(2024, 12, 15, 10, 0, 0)
        );
        insert c2;
        
        System.runAs(u) {
            MBP_ManageBrokerCases.getUserRelatedData();
            //MBP_ManageBrokerCases.getCaseSubcategories();
            MBP_ManageBrokerCases.upsertCase(c1, true);
            
            Case c3 = new Case(
                Subject = 'Second Case',
                Description = 'Another Desc',
                CaseCategory__c = 'Broker Enquiry',
                ContactId = con.Id,
                AccountId = acc.Id,
                Status = 'New',
                Unit__c = unit.Id
            );
            MBP_ManageBrokerCases.upsertCase(c3, false);
            
            MBP_ManageBrokerCases.getCases(false, null, null);
            MBP_ManageBrokerCases.getCases(false, '2024-07-01', null);
            MBP_ManageBrokerCases.getCases(false, null, '2024-06-30');
            MBP_ManageBrokerCases.getCases(false, '2024-01-01', '2024-06-30');
            
            MBP_ManageBrokerCases.getCasesCSVData(null, null);
            MBP_ManageBrokerCases.getCasesCSVData('2024-01-01', '2024-12-31');
            
            try { MBP_ManageBrokerCases.handleFileOperation('upload', null, null, null, null); } catch (Exception e) {}
            try { MBP_ManageBrokerCases.handleFileOperation('delete', null, null, null, null); } catch (Exception e) {}
            try { MBP_ManageBrokerCases.handleFileOperation('download', null, null, null, null); } catch (Exception e) {}
            try { MBP_ManageBrokerCases.handleFileOperation('invalid', null, null, null, null); } catch (Exception e) {}
        }
        
        User sysAdmin = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        System.runAs(sysAdmin) {
            Blob fileBody = Blob.valueOf('Sample Content');
            String base64Data = EncodingUtil.base64Encode(fileBody);
            
            ContentVersion cv = (ContentVersion)MBP_ManageBrokerCases.handleFileOperation('upload', base64Data, 'file.txt', c1.Id, null);
            Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            
            MBP_ManageBrokerCases.handleFileOperation('download', null, null, null, docId);
            MBP_ManageBrokerCases.handleFileOperation('delete', null, null, null, docId);
        }
        
        testGetCasesFor('Agency Admin', 'agency');
    }
    
    static testMethod void testUncoveredScenarios() {
        String uniqueId = String.valueOf(System.now().getTime()) + String.valueOf(Math.random()).replace('.', '').substring(0, 8);
        
        Account acc = new Account(Name = 'Edge Case Account ' + uniqueId);
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'Edge',
            LastName = 'Case' + uniqueId,
            Email = 'edge' + uniqueId + '@test.com',
            Phone = '0000000000',
            AccountId = acc.Id
        );
        insert con;
        
        User u = new User(
            Username = 'edgeuser' + uniqueId + '@test.com',
            LastName = 'EdgeUser' + uniqueId,
            Email = 'edge' + uniqueId + '@test.com',
            Alias = 'edg' + uniqueId.substring(0, 3),
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ContactId = con.Id
        );
        insert u;
        
        System.runAs(u) {
            MBP_ManageBrokerCases.getCases(false, null, null);
            MBP_ManageBrokerCases.getCases(false, '2024-01-01', '2024-12-31');
            
            try {
                MBP_ManageBrokerCases.upsertCase(new Case(), false);
            } catch (Exception e) {}
            
            MBP_ManageBrokerCases.getCasesCSVData(null, null);
            MBP_ManageBrokerCases.getCasesCSVData('2024-01-01', '2024-12-31');
            
            try {
                MBP_ManageBrokerCases.handleFileOperation('upload', null, null, null, null);
            } catch (Exception e) {}
            
            try {
                MBP_ManageBrokerCases.handleFileOperation('delete', null, null, null, null);
            } catch (Exception e) {}
            
            try {
                MBP_ManageBrokerCases.handleFileOperation('download', null, null, null, null);
            } catch (Exception e) {}
        }
    }
    
    static testMethod void testDateFilterEdgeCases() {
        String uniqueId = String.valueOf(System.now().getTime()) + String.valueOf(Math.random()).replace('.', '').substring(0, 8);
        
        Account acc = new Account(Name = 'Date Filter Test Account ' + uniqueId);
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'Date',
            LastName = 'Filter' + uniqueId,
            Email = 'date' + uniqueId + '@test.com',
            Phone = '1111111111',
            AccountId = acc.Id,
            Broker_Type__c = 'Owner'
        );
        insert con;
        
        User u = new User(
            Username = 'dateuser' + uniqueId + '@test.com',
            LastName = 'DateUser' + uniqueId,
            Email = 'date' + uniqueId + '@test.com',
            Alias = 'dat' + uniqueId.substring(0, 3),
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ContactId = con.Id
        );
        insert u;
        
        Id rtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = 'Broker_Cases' LIMIT 1].Id;
        Id queueId = [SELECT Id FROM Group WHERE DeveloperName = 'Brokers_Queue' AND Type = 'Queue' LIMIT 1].Id;
        Unit__c unit = createUnit(uniqueId);
        
        Case caseJan = new Case(
            Subject = 'January Case',
            Description = 'Case from January',
            CaseCategory__c = 'Broker Enquiry',
            ContactId = con.Id,
            AccountId = acc.Id,
            Status = 'New',
            RecordTypeId = rtId,
            Unit__c = unit.Id,
            CreatedDate = DateTime.newInstance(2024, 1, 15, 10, 0, 0)
        );
        insert caseJan;
        
        Case caseJun = new Case(
            Subject = 'June Case',
            Description = 'Case from June',
            CaseCategory__c = 'Broker Enquiry',
            ContactId = con.Id,
            AccountId = acc.Id,
            Status = 'new',
            RecordTypeId = rtId,
            Unit__c = unit.Id,
            CreatedDate = DateTime.newInstance(2024, 6, 15, 10, 0, 0)
        );
        insert caseJun;
        
        Case caseDec = new Case(
            Subject = 'December Case',
            Description = 'Case from December',
            CaseCategory__c = 'Broker Enquiry',
            ContactId = con.Id,
            AccountId = acc.Id,
            Status = 'New',
            RecordTypeId = rtId,
            Unit__c = unit.Id,
            CreatedDate = DateTime.newInstance(2024, 12, 15, 10, 0, 0),
            Resolution_Comments__c = 'yyuu'
        );
        insert caseDec;
        
        System.runAs(u) {
            MBP_ManageBrokerCases.getCases(false, '2024-06-01', null);
            MBP_ManageBrokerCases.getCases(false, null, '2024-06-30');
            MBP_ManageBrokerCases.getCases(false, '2024-06-01', '2024-06-30');
            MBP_ManageBrokerCases.getCases(false, '2024-06-15', '2024-06-15');
            MBP_ManageBrokerCases.getCases(false, '2025-01-01', '2025-12-31');
        }
    }
    
    static testMethod void testCSVExportWithDateFilters() {
        String uniqueId = String.valueOf(System.now().getTime()) + String.valueOf(Math.random()).replace('.', '').substring(0, 8);
        
        Account acc = new Account(Name = 'CSV Export Test Account ' + uniqueId);
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'CSV',
            LastName = 'Export' + uniqueId,
            Email = 'csv' + uniqueId + '@test.com',
            Phone = '2222222222',
            AccountId = acc.Id,
            Broker_Type__c = 'Owner'
        );
        insert con;
        
        User u = new User(
            Username = 'csvuser' + uniqueId + '@test.com',
            LastName = 'CsvUser' + uniqueId,
            Email = 'csv' + uniqueId + '@test.com',
            Alias = 'csv' + uniqueId.substring(0, 3),
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ContactId = con.Id
        );
        insert u;
        
        Id rtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = 'Broker_Cases' LIMIT 1].Id;
        Id queueId = [SELECT Id FROM Group WHERE DeveloperName = 'Brokers_Queue' AND Type = 'Queue' LIMIT 1].Id;
        Unit__c unit = createUnit(uniqueId);
        
        Case testCase = new Case(
            Subject = 'CSV Test Case',
            Description = 'Case for CSV export testing',
            CaseCategory__c = 'Broker Enquiry',
            ContactId = con.Id,
            AccountId = acc.Id,
            Status = 'New',
            RecordTypeId = rtId,
            Unit__c = unit.Id,
            Resolution_Comments__c = 'Test resolution comments',
            CreatedDate = DateTime.newInstance(2024, 6, 15, 10, 0, 0)
        );
        insert testCase;
        
        System.runAs(u) {
            MBP_ManageBrokerCases.getCasesCSVData('2024-01-01', '2024-12-31');
            MBP_ManageBrokerCases.getCasesCSVData('2025-01-01', '2025-12-31');
            MBP_ManageBrokerCases.getCasesCSVData(null, null);
        }
    }
}