@IsTest
public class InvoiceServiceHelperTest {

    @IsTest
    static void testSendInvoiceToOracle_Future() {
        // Step 1: Create mock record IDs
        Set<String> mockIds = new Set<String>{
            'a0oHp00001Bh85vIAB',
            'a0oHp00001Bh856IAB'
        };

        // Step 2: Use Test.startTest/stopTest to trigger the @future method
        Test.startTest();
        InvoiceServiceHelper.sendInvoiceToOracle_Future(mockIds);
        Test.stopTest(); // Ensures future method is executed        
    }
}