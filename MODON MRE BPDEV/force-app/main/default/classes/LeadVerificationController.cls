public with sharing class LeadVerificationController {

    @AuraEnabled(cacheable=true)
    public static Boolean isApiEnabled() {
        return LoqateService.isApiEnabled();
    }

    @AuraEnabled
    public static LoqateService.EmailResult validateEmail(String email) {
        return LoqateService.validateEmail(email);
    }

    @AuraEnabled
    public static LoqateService.PhoneResult validatePhone(String phone) {
        return LoqateService.validatePhone(phone);
    }
}