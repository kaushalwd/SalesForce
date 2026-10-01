@isTest
public class SalesOrderCMAAssignControllerTest {

    private static User makeUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Tst',
            LastName  = alias,
            Email     = alias + '@example.com',
            Username  = alias + '@example.com.' + System.currentTimeMillis(),
            Alias     = alias.left(5),
            CommunityNickname = alias,
            TimeZoneSidKey    = 'GMT',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id
        );
        insert u;
        return u;
    }

    @testSetup
    static void prepare() {

        User cmaA = makeUser('cmaA');
        User cmaB = makeUser('cmaB');


        insert new List<SalesOrder__c>{
            new SalesOrder__c(
                Status__c                   = 'In Progress',
                Sub_Status__c               = 'Pending with CM',
                Customer_Management_Associate__c = null      
            ),
            new SalesOrder__c(
                Status__c                   = 'In Progress',
                Sub_Status__c               = 'Pending with CM',
                Customer_Management_Associate__c = cmaA.Id   
            ),
            new SalesOrder__c(
                Status__c                   = 'In Progress',
                Sub_Status__c               = 'Under Finance Verification',    
                Customer_Management_Associate__c = null
            )
        };
    }

    @isTest
    static void exerciseGetSalesOrders() {

        Test.startTest();

        Map<String,Object> resUnassigned =
            SalesOrderCMAAssignController.getSalesOrders('Unassigned', null);
        Map<String,Object> resAssigned   =
            SalesOrderCMAAssignController.getSalesOrders('Assigned',   null);
        Map<String,Object> resFiltered   =
            SalesOrderCMAAssignController.getSalesOrders('Unassigned', 'FOO');

        Test.stopTest();

        System.assertEquals(1,
            ((List<SObject>)resUnassigned.get('rows')).size(),
            'Exactly one unassigned SO expected');

        System.assertEquals(1,
            ((List<SObject>)resAssigned.get('rows')).size(),
            'Exactly one assigned SO expected');

        System.assertEquals(0,
            ((List<SObject>)resFiltered.get('rows')).size(),
            'Search key should filter everything out');

        System.assert(
            ((Map<String,Set<String>>)resUnassigned.get('filterValues')).size() > 0,
            'filterValues map should be populated');
    }

    @isTest
    static void exerciseAssignCMAssociate() {

        Id soUnassignedId = [
            SELECT Id
            FROM   SalesOrder__c
            WHERE  Sub_Status__c = 'Pending with CM'
            AND    Customer_Management_Associate__c = null
            LIMIT  1
        ].Id;

        Id soAssignedId = [
            SELECT Id
            FROM   SalesOrder__c
            WHERE  Sub_Status__c = 'Pending with CM'
            AND    Customer_Management_Associate__c != null
            LIMIT  1
        ].Id;

        Id cmaB = [SELECT Id FROM User WHERE Alias = 'cmaB' LIMIT 1].Id;

        Test.startTest();

        SalesOrderCMAAssignController.assignCMAssociate(
            new List<Id>{ soUnassignedId, soAssignedId },
            cmaB,
            false
        );

        Map<Id,SalesOrder__c> after1 = new Map<Id,SalesOrder__c>(
            [SELECT Id, Customer_Management_Associate__c
             FROM   SalesOrder__c
             WHERE  Id IN :new List<Id>{ soUnassignedId, soAssignedId }]);

        System.assertEquals(cmaB,
            after1.get(soUnassignedId).Customer_Management_Associate__c,
            'Unassigned SO should now have CMA');
        System.assertNotEquals(cmaB,
            after1.get(soAssignedId).Customer_Management_Associate__c,
            'Assigned SO must stay unchanged');

        SalesOrderCMAAssignController.assignCMAssociate(
            new List<Id>{ soUnassignedId, soAssignedId },
            cmaB,
             true
        );

        Test.stopTest();

        Map<Id,SalesOrder__c> after2 = new Map<Id,SalesOrder__c>(
            [SELECT Id, Customer_Management_Associate__c
             FROM   SalesOrder__c
             WHERE  Id IN :new List<Id>{ soUnassignedId, soAssignedId }]);

        System.assertEquals(cmaB,
            after2.get(soAssignedId).Customer_Management_Associate__c,
            'overrideExisting=true should update the previously-assigned record as well');

        SalesOrderCMAAssignController.assignCMAssociate(
            new List<Id>(), cmaB, true);
    }
}