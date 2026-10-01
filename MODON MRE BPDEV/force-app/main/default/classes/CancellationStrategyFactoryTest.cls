@IsTest
public class CancellationStrategyFactoryTest {

    @IsTest
    static void testGetStrategy_WithRefund() {
        Test.startTest();
        ICancellationStrategy strategy =
            CancellationStrategyFactory.getStrategy(
                CancellationStrategyFactory.TYPE_WITH_REFUND
            );
        Test.stopTest();

        System.assertNotEquals(null, strategy, 'Strategy should not be null');
        System.assert(
            strategy instanceof CancellationWithRefundStrategy,
            'Expected CancellationWithRefundStrategy'
        );
    }

    @IsTest
    static void testGetStrategy_Consolidation() {
        Test.startTest();
        ICancellationStrategy strategy =
            CancellationStrategyFactory.getStrategy(
                CancellationStrategyFactory.TYPE_CONSOLIDATION
            );
        Test.stopTest();

        System.assertNotEquals(null, strategy, 'Strategy should not be null');
        System.assert(
            strategy instanceof ConsolidationCancellationStrategy,
            'Expected ConsolidationCancellationStrategy'
        );
    }

    @IsTest
    static void testGetStrategy_WithoutRefund() {
        Test.startTest();
        ICancellationStrategy strategy =
            CancellationStrategyFactory.getStrategy(
                CancellationStrategyFactory.TYPE_WITHOUT_REFUND
            );
        Test.stopTest();

        System.assertNotEquals(null, strategy, 'Strategy should not be null');
        System.assert(
            strategy instanceof CancellationWithoutRefundStrategy,
            'Expected CancellationWithoutRefundStrategy'
        );
    }

    @IsTest
    static void testGetStrategy_BlankValue() {
        Test.startTest();

        try {
            CancellationStrategyFactory.getStrategy('');
            System.assert(false, 'Expected AuraHandledException for blank cancellation type');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }

        Test.stopTest();
    }

    @IsTest
    static void testGetStrategy_NullValue() {
        Test.startTest();

        try {
            CancellationStrategyFactory.getStrategy(null);
            System.assert(false, 'Expected AuraHandledException for null cancellation type');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }

        Test.stopTest();
    }

    @IsTest
    static void testGetStrategy_InvalidValue() {
        Test.startTest();

        try {
            CancellationStrategyFactory.getStrategy('Invalid Cancellation Type');
            System.assert(false, 'Expected AuraHandledException for invalid cancellation type');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }

        Test.stopTest();
    }
}