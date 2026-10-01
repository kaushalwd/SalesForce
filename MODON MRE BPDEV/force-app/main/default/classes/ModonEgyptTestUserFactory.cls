/**********************************************************************************************************************
* Name               : ModonEgyptTestUserFactory
* Description        : Creates and retrieves Egypt Sales Operations test users for Modon - Egypt test classes.
* Usage              : Call createEgyptSalesOrderTestUser from @TestSetup; getEgyptSalesOrderTestUser in test methods.
* Created By         : Milin Kapatel
**********************************************************************************************************************/
@isTest
public class ModonEgyptTestUserFactory {

    private static final Set<String> EGYPT_PERMISSION_SET_NAMES = new Set<String>{
        'Egypt_Sales_Order_Permissions',
        'Unit_Creator',
        'Unit_Editor_Egypt'
    };

    public static User createEgyptSalesOrderTestUser(String userLastName, String alias) {
        Profile profile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Modon Egypt - Sales Operations'
            LIMIT 1
        ];

        UserRole userRole = [
            SELECT Id
            FROM UserRole
            WHERE Name = 'Modon Egypt - Head of Sales Operations'
            LIMIT 1
        ];

        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        String safeAlias = alias.length() > 8 ? alias.substring(0, 8) : alias;

        User testUser = new User(
            Alias = safeAlias,
            Email = safeAlias + '.' + uniqueSuffix + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = userLastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            UserRoleId = userRole.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = safeAlias + '.' + uniqueSuffix + '@example.com'
        );
        insert testUser;

        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet ps : [
            SELECT Id
            FROM PermissionSet
            WHERE Name IN :EGYPT_PERMISSION_SET_NAMES
        ]) {
            assignments.add(new PermissionSetAssignment(
                AssigneeId = testUser.Id,
                PermissionSetId = ps.Id
            ));
        }

        if (!assignments.isEmpty()) {
            insert assignments;
        }

        return testUser;
    }

    public static User getEgyptSalesOrderTestUser(String userLastName) {
        return [
            SELECT Id
            FROM User
            WHERE LastName = :userLastName
            LIMIT 1
        ];
    }
}