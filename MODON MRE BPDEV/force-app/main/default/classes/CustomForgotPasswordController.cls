public without sharing class CustomForgotPasswordController {
@AuraEnabled
    public static void forgotPassword(String email) {
        // You must implement logic to find user and initiate reset
        User u = [SELECT Id FROM User WHERE Username = :email LIMIT 1];
        if (u != null) {
            System.resetPassword(u.Id, true);
        } else {
            throw new AuraHandledException('Email not found.');
        }
    }
}