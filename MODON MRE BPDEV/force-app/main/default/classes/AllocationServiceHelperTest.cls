@IsTest
public class AllocationServiceHelperTest {
    
    @IsTest
    static void testSendAllocationToOracle_Future() {
        // Prepare a test set of record IDs
        Set<String> testRecIds = new Set<String>{
            'a0fHp00000TEST1',
            'a0fHp00000TEST2'
        };
        
        // Use Test.startTest() and Test.stopTest() to execute the @future method
        Test.startTest();
        AllocationServiceHelper.sendAllocationToOracle_Future(testRecIds);
        Test.stopTest();
      
    }
}