@isTest
public class SalesOrderSOAAControllerTest {

    /* ---------- lightweight user factory ---------- */
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

    /* ---------- baseline data ---------- */
    @testSetup
    static void prepare() {
        User saActive  = makeUser('saAct');
        User saInact   = makeUser('saInAct');
        User opsUser   = makeUser('ops1');

        insert new Sales_Operations_Associate_Assignment__c(
            Sales_Associate__c           = saActive.Id,
            Sales_Operations_Associate__c= opsUser.Id,
            Is_Active__c                 = true,
            Expiry_Date__c               = System.today().addDays(30)
        );

        insert new Sales_Operations_Associate_Assignment__c(
            Sales_Associate__c           = saInact.Id,
            Sales_Operations_Associate__c= opsUser.Id,
            Is_Active__c                 = false        // used for exclusion list
        );
    }

    /* ---------- getInit() ---------- */
    @isTest
    static void exerciseGetInit() {
        Test.startTest();
        SalesOrderSOAAController.getInit('ck-1');
        Test.stopTest();
    }

    /* ---------- createRow() happy + duplicate path ---------- */
    @isTest
    static void exerciseCreateRow() {
        User freshSA   = makeUser('newSA');
        Id   opsId     = [SELECT Id FROM User WHERE Alias = 'ops1' LIMIT 1].Id;
        Id   dupSAId   = [SELECT Id FROM User WHERE Alias = 'saAct' LIMIT 1].Id;

        Test.startTest();
        // 1) insert brand-new row
        SalesOrderSOAAController.createRow(
            freshSA.Id, opsId, true, System.today().addDays(15));

        // 2) attempt duplicate – expect AuraHandledException; swallow it
        try {
            SalesOrderSOAAController.createRow(
                dupSAId, opsId, true, null);
        } catch (AuraHandledException ignore) { }

        Test.stopTest();
    }

    /* ---------- updateRows() (bulk) ---------- */
    @isTest
    static void exerciseUpdateRows() {
        Sales_Operations_Associate_Assignment__c rec =
            [SELECT Id FROM Sales_Operations_Associate_Assignment__c
             WHERE Is_Active__c = true LIMIT 1];

        SalesOrderSOAAController.UpsertRequest r =
            new SalesOrderSOAAController.UpsertRequest();
        r.id         = rec.Id;
        r.isActive   = false;
        r.expiryDate = System.today().addDays(90);

        Test.startTest();
        SalesOrderSOAAController.updateRows(new List<
            SalesOrderSOAAController.UpsertRequest>{ r });
        Test.stopTest();
    }

    /* ---------- updateRow() (single) ---------- */
    @isTest
    static void exerciseUpdateRow() {
        Id ops2 = makeUser('ops2').Id;
        Id row  = [SELECT Id FROM Sales_Operations_Associate_Assignment__c
                   LIMIT 1].Id;

        Test.startTest();
        SalesOrderSOAAController.updateRow(
            row, ops2, true, System.today().addDays(60));
        Test.stopTest();
    }

    /* ---------- deleteRow() ---------- */
    @isTest
    static void exerciseDeleteRow() {
        Sales_Operations_Associate_Assignment__c rec =
            [SELECT Id FROM Sales_Operations_Associate_Assignment__c
             LIMIT 1];

        Test.startTest();
        SalesOrderSOAAController.deleteRow(rec.Id);
        Test.stopTest();
    }
}