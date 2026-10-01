public with sharing class CaseCategoryPromptGrounding {

    public class Request {
        @InvocableVariable(label='Case Record' description='The input Case record')
        public Case caseRecord;
    }

    public class Response {
        @InvocableVariable(label='Prompt Grounding Text' description='Formatted text passed to Prompt Builder')
        public String Prompt;
    }

    @InvocableMethod(
        label='Get Case Categories for AI'
        description='Fetches all Case_Config_Category__mdt records and formats them for AI prompt grounding'
    )
    public static List<Response> getCategoryRules(List<Request> requests) {
        List<Response> responses = new List<Response>();

        // 1. Query all Case_Config_Category__mdt records
        List<String> formattedRules = new List<String>();
        Integer count = 1;

        for (Case_Config_Category__mdt cfg : Case_Config_Category__mdt.getAll().values()) {
            // Skip rows without an AI instruction
            if (String.isBlank(cfg.AI_Instruction__c)) continue;

            String subVertical = String.isNotBlank(cfg.Sub_Vertical__c) ? cfg.Sub_Vertical__c : 'General';

            // Format: 1. ADM Fee Refund (Sub_Vertical: ADM Services): Use this category when...
            formattedRules.add(
                count + '. ' + cfg.MasterLabel + ' (Sub_Vertical: ' + subVertical + '):\n' + cfg.AI_Instruction__c
            );
            count++;
        }

        String fullInstructionsText = String.join(formattedRules, '\n\n');

        // 2. Return the formatted text to Prompt Builder
        for (Request req : requests) {
            Response res = new Response();
            res.Prompt = fullInstructionsText;
            responses.add(res);
        }

        return responses;
    }
}