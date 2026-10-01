@IsTest
public class PropertyTransferCustomerHistoryTest {

    @IsTest
    static void test_getAccountHistory_constructor_and_if() {

        Account acc1 = new Account(Name = 'Old Customer');
        Account acc2 = new Account(Name = 'New Customer');
        insert new List<Account>{ acc1, acc2 };

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc1.Id,
            Resale_Transfer_Date__c = System.today()
        );
        insert so;

        Test.startTest();

        so.CustomerAccount__c = acc2.Id;
        update so;

        PropertyTransferCustomerHistory.getAccountHistory(so.Id);

        Test.stopTest();
    }

    @IsTest
    static void test_wrapper_constructor_direct() {
        PropertyTransferCustomerHistory.SalesOrderHistoryWrapper w =
            new PropertyTransferCustomerHistory.SalesOrderHistoryWrapper(
                'old',
                'new',
                System.now(),
                'tester'
            );
    }
}