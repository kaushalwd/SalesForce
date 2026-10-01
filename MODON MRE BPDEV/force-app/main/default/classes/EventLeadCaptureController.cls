/**
 * ============================================================================
 * Class Name  : EventLeadCaptureController
 * Author      : Prateek
 * Created On  : 2025-01-16
 * Description :
 * Controller used for public Experience Cloud event lead capture.
 *
 * ----------------------------------------------------------------------------
 * Version History
 * ----------------------------------------------------------------------------
 * Version | Date       | Author   | Description
 * ----------------------------------------------------------------------------
 * 1.0     | 2025-01-16 | Prateek  | Initial version
 * ----------------------------------------------------------------------------
 * 1.1     | 2026-02-12 | Sami  | Added Project Interest Dynamically
 * ============================================================================
 */
public without sharing class EventLeadCaptureController {
    public class LeadInput {
        @AuraEnabled public String eventName;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String phone;
        @AuraEnabled public String email;
        @AuraEnabled public String projectInterest; // added project interest
        @AuraEnabled public String propertyType;
        @AuraEnabled public String modonRepresentative;
        @AuraEnabled public String kioskName;
        @AuraEnabled public String customerBudget;
        @AuraEnabled public Boolean isSalesPerson;
    }

    /**
     * Creates a Lead for any event/landing page without relying on custom fields.
     * Non-core fields are stored in Description so the form can be reused across events.
     */
    @AuraEnabled
    public static Id createLead(String inputJson) {
        if (String.isBlank(inputJson)) {
            throw new AuraHandledException('No data received.');
        }

        LeadInput input;
        try {
            input = (LeadInput) JSON.deserialize(inputJson, LeadInput.class);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid form payload.');
        }

        System.debug('Input received: ' + inputJson);
        validate(input);

        String eventLabel = String.isNotBlank(input.eventName) ? input.eventName.trim() : 'Event Lead';

        Lead record = new Lead();
        record.FirstName = input.firstName.trim();
        record.LastName = input.lastName.trim();
        record.Email = input.email.trim();
        record.MobilePhone = input.phone.trim();
        record.LeadSource = eventLabel;
        record.SubSource__c = 'Kiosk';
        record.UTMSource__c = input.kioskName.trim();
        //record.ProjectInterest__c = 'Al Naseem'; removing hard coded Al Naseem
        //adding project name values 2026-02-12
        if (String.isNotBlank(input.projectInterest)) {
            record.ProjectInterest__c = input.projectInterest.trim();
        }
        if(input.isSalesPerson){
            record.Sales_Executive__c = input.modonRepresentative.trim();
        }else{
            record.Sales_Hostess__c = input.modonRepresentative.trim();
        }
        
        record.Status = 'New';

        List<String> notes = new List<String>();
        notes.add('Event: ' + eventLabel);
        if (String.isNotBlank(input.kioskName)) {
            notes.add('Kiosk: ' + input.kioskName.trim());
        }
        if (String.isNotBlank(input.propertyType)) {
            notes.add('Property Type: ' + input.propertyType.trim());
        }
        if (String.isNotBlank(input.customerBudget)) {
            notes.add('Budget: ' + input.customerBudget.trim());
        }
        if (String.isNotBlank(input.modonRepresentative)) {
            notes.add('Modon Representative: ' + input.modonRepresentative.trim());
        }
        record.Description = String.join(notes, ' | ');

        insert record;
        return record.Id;
    }

    private static void validate(LeadInput input) {
        if (input == null) {
            throw new AuraHandledException('No data received.');
        }
        if (String.isBlank(input.firstName)) {
            throw new AuraHandledException('First Name is required.');
        }
        if (String.isBlank(input.lastName)) {
            throw new AuraHandledException('Last Name is required.');
        }
        if (String.isBlank(input.phone)) {
            throw new AuraHandledException('Phone number is required.');
        }
        if (String.isBlank(input.email)) {
            throw new AuraHandledException('Email Address is required.');
        }
        if (!isValidEmail(input.email)) {
            throw new AuraHandledException('Enter a valid email address.');
        }
    }

    private static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) {
            return false;
        }
        // (?i) flag makes the pattern case-insensitive in Apex.
        Pattern p = Pattern.compile('(?i)^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$');
        Matcher m = p.matcher(email.trim());
        return m.matches();
    }
}