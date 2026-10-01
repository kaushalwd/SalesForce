public with sharing class GeminiDocumentValidator {

    @AuraEnabled
    public static String createLeadFromAI(String userInput) {

        System.debug('==============================');
        System.debug('AI LEAD CREATION START');
        System.debug('USER INPUT: ' + userInput);
        System.debug('==============================');

        try {

            // ============================
            // 🔹 BASIC EXTRACTION (NO AI DEPENDENCY)
            // ============================

            String firstName = extractName(userInput);
            String lastName  = firstName;

            String email  = extractEmail(userInput);
            String mobile = extractMobile(userInput);

            String project  = extractField(userInput, 'project');
            String budget   = extractField(userInput, 'budget');
            String unitType = extractField(userInput, 'unit');

            System.debug('----- EXTRACTED VALUES -----');
            System.debug('Name: ' + firstName);
            System.debug('Email: ' + email);
            System.debug('Mobile: ' + mobile);
            System.debug('Project: [' + project + ']');
            System.debug('Budget: [' + budget + ']');
            System.debug('Unit: [' + unitType + ']');
            System.debug('----------------------------');

            if (String.isBlank(email) && String.isBlank(mobile)) {
                return 'ERROR: Email or Mobile is required';
            }

            // ============================
            // 🔥 PICKLIST MATCHING
            // ============================

            project = matchPicklistValue(Lead.ProjectInterest__c, project);
            System.debug('MATCHED PROJECT: ' + project);

            if (project == null) {
                System.debug('❌ PROJECT MATCH FAILED');
                return 'ERROR: Project not matching CRM values';
            }

            budget = matchPicklistValue(Lead.CustomerBudget__c, budget);
            System.debug('MATCHED BUDGET: ' + budget);

            if (Schema.sObjectType.Lead.fields.getMap().containsKey('UnitType__c')) {
                unitType = matchPicklistValue(Lead.UnitType__c, unitType);
                System.debug('MATCHED UNIT: ' + unitType);
            }

            // ============================
            // 🔥 CREATE LEAD
            // ============================

            Lead l = new Lead();

            l.FirstName = firstName;
            l.LastName  = lastName;
            l.Email     = email;
            l.Phone     = mobile;
            l.Company   = 'AI Generated Lead';

            l.ProjectInterest__c = project;
            if (budget != null) l.CustomerBudget__c = budget;

            if (unitType != null && Schema.sObjectType.Lead.fields.getMap().containsKey('UnitType__c')) {
                l.UnitType__c = unitType;
            }

            l.LeadSource = 'Broker Portal';

            insert l;

            System.debug('✅ LEAD CREATED: ' + l.Id);
            return 'SUCCESS';

        } catch (Exception e) {
            System.debug('❌ ERROR: ' + e.getMessage());
            return 'ERROR: ' + e.getMessage();
        }
    }

    // ============================
    // 🔥 FIELD EXTRACTOR
    // ============================
    private static String extractField(String input, String type) {

        if (String.isBlank(input)) return null;

        String lower = input.toLowerCase();

        try {
            if (type == 'project' && lower.contains('project name should be')) {
                return input.substring(lower.indexOf('project name should be') + 23)
                    .split(' and ')[0].trim();
            }

            if (type == 'budget' && lower.contains('budget should be')) {
                return input.substring(lower.indexOf('budget should be') + 17)
                    .split(' and ')[0].trim();
            }

            if (type == 'unit' && lower.contains('unit should be')) {
                return input.substring(lower.indexOf('unit should be') + 15)
                    .split(' and ')[0].trim();
            }

        } catch (Exception e) {
            System.debug('Field extraction error: ' + e.getMessage());
        }

        return null;
    }

    // ============================
    // 🔥 EMAIL EXTRACT
    // ============================
    private static String extractEmail(String input) {

        Matcher m = Pattern.compile('[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}')
            .matcher(input);

        return m.find() ? m.group(0) : null;
    }

    // ============================
    // 🔥 MOBILE EXTRACT
    // ============================
    private static String extractMobile(String input) {

        Matcher m = Pattern.compile('\\+?[0-9]{10,15}')
            .matcher(input);

        return m.find() ? m.group(0) : null;
    }

    // ============================
    // 🔥 NAME EXTRACT
    // ============================
    private static String extractName(String input) {

        for (String word : input.split(' ')) {
            if (!word.contains('@') && !Pattern.matches('.*\\d.*', word)) {
                return word;
            }
        }
        return 'Customer';
    }

    // ============================
    // 🔥 PICKLIST MATCHER
    // ============================
    private static String matchPicklistValue(
        Schema.SObjectField field,
        String input
    ) {
        if (String.isBlank(input)) return null;

        String cleanInput = input.replaceAll('[^a-zA-Z0-9]', '').toLowerCase();

        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {

            String pickVal = entry.getValue();
            String cleanPick = pickVal.replaceAll('[^a-zA-Z0-9]', '').toLowerCase();

            System.debug('Comparing → Input: ' + cleanInput + ' | Picklist: ' + cleanPick);

            if (cleanPick == cleanInput ||
                cleanPick.contains(cleanInput) ||
                cleanInput.contains(cleanPick)) {

                return pickVal;
            }
        }

        System.debug('❌ NO MATCH FOUND FOR: ' + input);
        return null;
    }
}