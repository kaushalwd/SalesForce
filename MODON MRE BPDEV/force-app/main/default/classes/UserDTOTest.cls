/**
* @description       : Community/Portal Profile
* @author            : Manoj
* @last modified on  : 30 May 2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       30 May 2025   		Initial Draft 
* 2.0           Manoj   	       10 Dce 2025   		Initial Draft 
**/
@IsTest
private class UserDTOTest {
    
    @IsTest
    static void testUserConstructor() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test User without Contact association
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testusr',
            Email = 'test.user@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Test',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'test.user@example.com' + System.currentTimeMillis(),
            // Removed ContactId assignment
            // Added required fields for user creation
            CommunityNickname = 'testuser' + System.currentTimeMillis(),
            IsActive = true
        );
        insert testUser;
        
        // Test the User constructor
        Test.startTest();
        UserDTO dto = new UserDTO(testUser,false,false);
        Test.stopTest();
    }   
    
}