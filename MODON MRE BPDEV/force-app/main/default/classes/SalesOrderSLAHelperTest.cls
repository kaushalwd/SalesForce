@isTest
public class SalesOrderSLAHelperTest {

    private static User createTestUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = alias,
            Email = alias + '@test.com',
            Username = alias + '@test.com.' + System.currentTimeMillis(),
            Alias = alias,
            CommunityNickname = alias,
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    @testSetup
    static void setupData() {
        

        // Master SLA records
        insert new List<Master_SLA__c>{
            new Master_SLA__c(Name='Sales Resident', Category__c='Sales', Sub_Category__c='Resident Sales', SLA_Hrs__c=1, GroupName__c='Sales Queue', IsActive__c=true, ObjectName__c='Sales Order'),
            new Master_SLA__c(Name='Sales Non-Resident', Category__c='Sales', Sub_Category__c='Non-Resident Sales', SLA_Hrs__c=2, GroupName__c='Sales Queue', IsActive__c=true, ObjectName__c='Sales Order'),
            new Master_SLA__c(Name='Sales Operation', Category__c='Sales Operation', SLA_Hrs__c=4, GroupName__c='Sales Ops Queue', IsActive__c=true, ObjectName__c='Sales Order'),
            new Master_SLA__c(Name='Finance', Category__c='Finance', SLA_Hrs__c=8, GroupName__c='Finance Queue', IsActive__c=true, ObjectName__c='Sales Order')
        };

        // Round Robin users
        for (String alias : new List<String>{'srr', 'forr', 'oprr', 'cmrr'}) {
            User u = createTestUser(alias);
            insert new RoundRobinAssignmentMatrix__c(
                User__c = u.Id,
                User_Queue__c = alias == 'srr' ? 'Sales Ops Queue' :
                                alias == 'forr' ? 'Finance Queue' :
                                alias == 'oprr' ? 'Sales Ops Queue' :
                                'Customer Management Team',
                Threshold__c = 3,
                CurrentLoad__c = 0,
                Application_Type__c = 'Sales Cloud',
                Status__c = 'Available'
            );
        }

        // Insert default Business Hours if not present
        
    }

@isTest static void testAllSalesOrderTeamAssignmentsAndSLAs() {
    // Create test users
    User salesUserResident = createTestUser('salesres');
    User salesUserNResident = createTestUser('salenres');
    User salesOpsUser = createTestUser('salesops');
    User financeUser = createTestUser('finance');
    User cmUser = createTestUser('custmgmt');

    // Insert Round Robin records for each queue
    insert new List<RoundRobinAssignmentMatrix__c>{
        new RoundRobinAssignmentMatrix__c(
            User__c = salesUserResident.Id,
            User_Queue__c = 'Sales Ops Queue',
            Threshold__c = 3,
            CurrentLoad__c = 0,
            Application_Type__c = 'Sales Cloud',
            Status__c = 'Available'
        ),
        new RoundRobinAssignmentMatrix__c(
            User__c = salesUserNResident.Id,
            User_Queue__c = 'Sales Ops Queue',
            Threshold__c = 3,
            CurrentLoad__c = 0,
            Application_Type__c = 'Sales Cloud',
            Status__c = 'Available'
        ),
        new RoundRobinAssignmentMatrix__c(
            User__c = salesOpsUser.Id,
            User_Queue__c = 'Sales Ops Queue',
            Threshold__c = 3,
            CurrentLoad__c = 0,
            Application_Type__c = 'Sales Cloud',
            Status__c = 'Available'
        ),
        new RoundRobinAssignmentMatrix__c(
            User__c = financeUser.Id,
            User_Queue__c = 'Finance Queue',
            Threshold__c = 3,
            CurrentLoad__c = 0,
            Application_Type__c = 'Sales Cloud',
            Status__c = 'Available'
        ),
        new RoundRobinAssignmentMatrix__c(
            User__c = cmUser.Id,
            User_Queue__c = 'Customer Management Team',
            Threshold__c = 3,
            CurrentLoad__c = 0,
            Application_Type__c = 'Sales Cloud',
            Status__c = 'Available'
        )
    };

    Datetime now = System.now();
    Datetime slaStart = now;
    Datetime slaEnd = now.addHours(4);

    // Insert Sales Orders with all required fields populated
    List<SalesOrder__c> orders = new List<SalesOrder__c>{
        // SALES - Resident
        new SalesOrder__c(
            Status__c = 'New',
            Sub_Status__c = 'Pending with Sales',
            UAE_Resident_Status__c = 'Resident',
            SalesAssociate__c = salesUserResident.Id,
            SLA_Start_Date_Time__c = slaStart,
            SLA_End_Date_Time__c = slaEnd
        ),

        // SALES - Non-Resident
        new SalesOrder__c(
            Status__c = 'New',
            Sub_Status__c = 'Pending with Sales',
            UAE_Resident_Status__c = 'Non-Resident',
            SalesAssociate__c = salesUserNResident.Id,
            SLA_Start_Date_Time__c = slaStart,
            SLA_End_Date_Time__c = slaEnd
        ),

        // SALES OPERATION
        new SalesOrder__c(
            Status__c = 'In Progress',
            Sub_Status__c = 'Pending With Sales Operation',
            SalesAssociate__c = salesOpsUser.Id,
            SLA_Start_Date_Time__c = slaStart,
            SLA_End_Date_Time__c = slaEnd
        ),

        // FINANCE
        new SalesOrder__c(
            Status__c = 'In Progress',
            Sub_Status__c = 'Under Finance Verification',
            SalesAssociate__c = financeUser.Id,
            SLA_Start_Date_Time__c = slaStart,
            SLA_End_Date_Time__c = slaEnd
        ),

        /*CUSTOMER MANAGEMENT
        new SalesOrder__c(
            Status__c = 'In Progress',
            Sub_Status__c = 'Pending with CM',
            Customer_Management_Associate__c = cmUser.Id
        ),*/

        // CLOSED (valid sub-status, valid SalesAssociate)
        new SalesOrder__c(
            Status__c = 'Cancelled',
            Sub_Status__c = 'Cancelled',
            SalesAssociate__c = salesUserResident.Id,
            SLA_Start_Date_Time__c = slaStart,
            SLA_End_Date_Time__c = slaEnd
        )
    };

    insert orders;

    // Create a clone map for oldMap simulation
    Map<Id, SObject> oldMap = new Map<Id, SObject>();
    for (SalesOrder__c so : orders) {
        oldMap.put(so.Id, so.clone(false, true, false, false));
    }

    Test.startTest();
    SalesOrderSLAHelper.assignToQueueMembers(orders, oldMap, 'after insert');
    SalesOrderSLAHelper.createOrderSLAs(orders, oldMap, false);
  //  SalesOrderSLAHelper.updateRRMatrix(orders, oldMap);
    SalesOrderSLAHelper.orderClosedCloseSLA(orders, oldMap);
    SalesOrderSLAHelper.closeSLAOnTeamChange(orders, oldMap);
    SalesOrderSLAHelper.createOrderCMSLA(orders, oldMap);
    Test.stopTest();

    // Assertions (basic checks)
    for (SalesOrder__c so : [SELECT Id, SLA_Start_Date_Time__c, SLA_End_Date_Time__c FROM SalesOrder__c WHERE Id IN :orders]) {
 
        // Call getSLAConfig and getBusinessTimeDiff safely
        Map<String, Object> config = SalesOrderSLAHelper.getSLAConfig(so.Id);
        Long diff = SalesOrderSLAHelper.getBusinessTimeDiff(so.Id);

        System.assert(config.containsKey('Team'), 'getSLAConfig should return a team');
    }
}

    @isTest static void testGetSLAConfig_and_getBusinessTimeDiff() {
        SalesOrder__c so = new SalesOrder__c(
            Status__c='New',
            Sub_Status__c='Pending With Sales',
            UAE_Resident_Status__c='Resident',
            SLA_Start_Date_Time__c=System.now(),
            SLA_End_Date_Time__c=System.now().addHours(1)
        );
        insert so;

        Test.startTest();
        Map<String, Object> config = SalesOrderSLAHelper.getSLAConfig(so.Id);
        Long diff = SalesOrderSLAHelper.getBusinessTimeDiff(so.Id);
        Test.stopTest();

        System.assert(config.containsKey('Team'), 'Team should be returned');
        System.assertNotEquals(null, diff, 'Time difference should be calculated');
    }

    @isTest static void testCreateOrderSLAsWhenOwnerUpdated() {
    // Create Project
    Project__c project = new Project__c(Name = 'Test Project');
    insert project;

    // Create Phase linked to Project
    Phase__c phase = new Phase__c(Name = 'Test Phase', Project__c = project.Id);
    insert phase;

    // Create Unit linked to Phase
   Unit__c unit = new Unit__c(
    Name = 'Unit A',
    Phase__c = phase.Id,
    PlotNo__c = 'P-123',
    UnitClassification__c = 'Villa', // Use a valid picklist value
    Number_of_Bedrooms__c = '2'
);
insert unit;

    // Create Customer Account
    Account custAccount = new Account(Name = 'Test Account');
    insert custAccount;

    // Create SalesOrder__c linked to Unit + CustomerAccount
    SalesOrder__c so = new SalesOrder__c(
        Status__c = 'New',
        Sub_Status__c = 'Pending With Sales',
        Unit__c = unit.Id,
        CustomerAccount__c = custAccount.Id
        // Do not populate ProjectName__c directly; it’s read-only and derived
    );
    insert so;

    insert new CaseSLA__c(SalesOrder__c = so.Id, Category__c = 'Sales', Status__c = 'OnTrack');

    // Trigger the Flow (simulate update)
    SalesOrder__c oldSo = so.clone(false, true, false, false);
    so.SalesAssociate__c = UserInfo.getUserId();
    update so;

    Test.startTest();
    SalesOrderSLAHelper.createOrderSLAWhenOwnerUpdated(
        new List<SalesOrder__c>{so},
        new Map<Id, SObject>{so.Id => oldSo}
    );
    Test.stopTest();
}

    @isTest static void testCloseSLAOnTeamChange() {
    Account custAccount = new Account(Name = 'Test Account');
    insert custAccount;

    
    
    Project__c project = new Project__c(Name = 'Test Project');
    insert project;

    // Create Phase linked to Project
    Phase__c phase = new Phase__c(Name = 'Test Phase', Project__c = project.Id);
    insert phase;

    // Create Unit linked to Phase
    Unit__c unit = new Unit__c(
    Name = 'Unit A',
    Phase__c = phase.Id,
    PlotNo__c = 'P-123',
    UnitClassification__c = 'Villa', // Use a valid picklist value
    Number_of_Bedrooms__c = '2'
);
insert unit;
    SalesOrder__c so = new SalesOrder__c(
        Status__c = 'New',
        Sub_Status__c = 'Pending With Sales',
        CustomerAccount__c = custAccount.Id,
        Unit__c = unit.Id
    );
    insert so;

    insert new CaseSLA__c(SalesOrder__c = so.Id, Category__c = 'Sales', Status__c = 'OnTrack');

    SalesOrder__c oldSo = so.clone(false, true, false, false);
    so.Sub_Status__c = 'Under Finance Verification';
    update so;

    Test.startTest();
    SalesOrderSLAHelper.closeSLAOnTeamChange(
        new List<SalesOrder__c>{so},
        new Map<Id, SObject>{so.Id => oldSo}
    );
    Test.stopTest();
}

    @isTest static void testOrderClosedCloseSLA() {
        SalesOrder__c so = new SalesOrder__c(Status__c='New', Sub_Status__c='Pending With Sales');
        insert so;
        insert new CaseSLA__c(SalesOrder__c=so.Id, Category__c='Sales', Status__c='OnTrack');

        SalesOrder__c oldSo = so.clone(false, true, false, false);
        so.Status__c = 'Cancelled';
        update so;

        Test.startTest();
        SalesOrderSLAHelper.orderClosedCloseSLA(new List<SalesOrder__c>{so}, new Map<Id, SObject>{so.Id => oldSo});
        Test.stopTest();
    }

    @isTest static void testGetSLAConfig_NullId() {
        Test.startTest();
        Map<String, Object> result = SalesOrderSLAHelper.getSLAConfig(null);
        Test.stopTest();
        System.assert(result.containsKey('Error'), 'Should return error for null input');
    }
    @isTest static void testCreateOrderSLAsWithNoMatchedSLA_UsesFallbackRR() {
    // Clean existing SLA config to force fallback logic
    delete [SELECT Id FROM Master_SLA__c];

    // Create necessary data
    Account acc = new Account(Name = 'Fallback Acc');
    insert acc;

    Project__c proj = new Project__c(Name = 'Fallback Project');
    insert proj;

    Phase__c phase = new Phase__c(Name = 'Fallback Phase', Project__c = proj.Id);
    insert phase;

    Unit__c unit = new Unit__c(
        Name = 'Fallback Unit',
        Phase__c = phase.Id,
        PlotNo__c = 'P-999',
        UnitClassification__c = 'Villa',
        Number_of_Bedrooms__c = '2'
    );
    insert unit;

    // Add one RR user with capacity 0
    User fallbackRRUser = createTestUser('fallbkRR');
    insert new RoundRobinAssignmentMatrix__c(
        User__c = fallbackRRUser.Id,
        User_Queue__c = 'Finance Queue',
        Threshold__c = 0, // No capacity
        CurrentLoad__c = 0,
        Application_Type__c = 'Sales Cloud',
        Status__c = 'Available'
    );

    // Create SalesOrder to simulate Finance team path (triggers fallback)
    SalesOrder__c so = new SalesOrder__c(
        Status__c = 'In Progress',
        Sub_Status__c = 'Under Finance Verification',
        Unit__c = unit.Id,
        CustomerAccount__c = acc.Id
    );
    insert so;

    // Clear hasAlreadyUpdated flag manually if needed
    Test.startTest();
    SalesOrderSLAHelper.createOrderSLAs(new List<SalesOrder__c>{so}, null, false);
    Test.stopTest();

    // Assert that SLA fields were cleared since fallback user has 0 capacity
    so = [SELECT SLA_Hours__c, SLA_Start_Date_Time__c, SLA_End_Date_Time__c FROM SalesOrder__c WHERE Id = :so.Id];
    System.assertEquals(null, so.SLA_Hours__c, 'SLA_Hours__c should be null due to fallback logic');
}
@isTest static void testCreateOrderSLAsWithUnknownTeamClearsFields() {
    Account acc = new Account(Name = 'Unknown Team Acc');
    insert acc;

    Project__c proj = new Project__c(Name = 'Unknown Team Project');
    insert proj;

    Phase__c phase = new Phase__c(Name = 'Unknown Team Phase', Project__c = proj.Id);
    insert phase;

    Unit__c unit = new Unit__c(
        Name = 'Unknown Team Unit',
        Phase__c = phase.Id,
        PlotNo__c = 'P-888',
        UnitClassification__c = 'Apartment',
        Number_of_Bedrooms__c = '1'
    );
    insert unit;

    SalesOrder__c so = new SalesOrder__c(
        Status__c = 'In Progress',
        Sub_Status__c = '', // This will trigger 'Unknown' team
        Unit__c = unit.Id,
        CustomerAccount__c = acc.Id,
        SLA_Hours__c = 5,
        SLA_Start_Date_Time__c = System.now(),
        SLA_End_Date_Time__c = System.now().addHours(5)
    );
    insert so;

    Test.startTest();
    SalesOrderSLAHelper.createOrderSLAs(new List<SalesOrder__c>{so}, null, false);
    Test.stopTest();

    SalesOrder__c updated = [SELECT SLA_Hours__c, SLA_Start_Date_Time__c, SLA_End_Date_Time__c FROM SalesOrder__c WHERE Id = :so.Id];
    System.assertEquals(null, updated.SLA_Hours__c, 'SLA_Hours__c should be cleared');
}


@isTest static void testAssignToQueue_UsesRecordCreatorAsFallback() {
    insert new Master_SLA__c(
        Name = 'Record Creator SLA',
        Category__c = 'Finance',
        SLA_Hrs__c = 8,
        GroupName__c = 'Record_Creator',
        IsActive__c = true,
        ObjectName__c = 'Sales Order'
    );

    Project__c project = new Project__c(Name = 'Project RC');
    insert project;
    Phase__c phase = new Phase__c(Name = 'Phase RC', Project__c = project.Id);
    insert phase;

    Unit__c unit = new Unit__c(
        Name = 'Unit RC',
        Phase__c = phase.Id,
        PlotNo__c = 'PR-001',
        UnitClassification__c = 'Villa',
        Number_of_Bedrooms__c = '2'
    );
    insert unit;

    Account acc = new Account(Name = 'RC Account');
    insert acc;

    SalesOrder__c so = new SalesOrder__c(
        Status__c = 'In Progress',
        Sub_Status__c = 'Under Finance Verification',
        Unit__c = unit.Id,
        CustomerAccount__c = acc.Id
    );
    insert so;

    Test.startTest();
    SalesOrderSLAHelper.assignToQueueMembers(new List<SalesOrder__c>{so}, null, 'after insert');
    Test.stopTest();

    so = [SELECT Finance_Associate__c FROM SalesOrder__c WHERE Id = :so.Id];
}
@isTest static void testAssignToQueue_FallbackRR_NoUser_UsesLoggedInUser() {
    // Remove all Master SLA entries
    delete [SELECT Id FROM Master_SLA__c];

    // Insert RR user with 0 capacity
    User rrUser = createTestUser('nocap');
    insert new RoundRobinAssignmentMatrix__c(
        User__c = rrUser.Id,
        User_Queue__c = 'Finance Queue',
        Threshold__c = 0,
        CurrentLoad__c = 0,
        Application_Type__c = 'Sales Cloud',
        Status__c = 'Available'
    );

    Project__c project = new Project__c(Name = 'Project RR');
    insert project;
    Phase__c phase = new Phase__c(Name = 'Phase RR', Project__c = project.Id);
    insert phase;

    Unit__c unit = new Unit__c(
        Name = 'Unit RR',
        Phase__c = phase.Id,
        PlotNo__c = 'PR-002',
        UnitClassification__c = 'Villa',
        Number_of_Bedrooms__c = '2'
    );
    insert unit;

    Account acc = new Account(Name = 'RR Fallback Acc');
    insert acc;

    SalesOrder__c so = new SalesOrder__c(
        Status__c = 'In Progress',
        Sub_Status__c = 'Under Finance Verification',
        Unit__c = unit.Id,
        CustomerAccount__c = acc.Id
    );
    insert so;

    Test.startTest();
    SalesOrderSLAHelper.assignToQueueMembers(new List<SalesOrder__c>{so}, null, 'after insert');
    Test.stopTest();

    so = [SELECT Finance_Associate__c FROM SalesOrder__c WHERE Id = :so.Id];
}

}