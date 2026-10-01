@isTest
public class CustomForgotPasswordTest {
@isTest
    static void testForgotPassword_Success() {
        // Create a test user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser2302@example.com',
            Username = 'testuser2302@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;

        Test.startTest();
        CustomForgotPasswordController.forgotPassword('testuser2302@example.com');
        Test.stopTest();
        
        // If no exception is thrown, the test passes
        System.assert(true);
    }

    @isTest
    static void testForgotPassword_UserNotFound() {
        Test.startTest();
        try {
            CustomForgotPasswordController.forgotPassword('nonexistent@example.com');
            System.assert(false, 'Expected exception was not thrown.');
        } catch (Exception e) {
        }
        Test.stopTest();
    }
}