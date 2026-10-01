/**
 * @File Name        : FileService.cls
 * @Description      : Loads the latest uploaded files (passport, Emirates ID, visa, POA) for
 *                     Registration_Agent__c records and returns them keyed by file type.
 *                     Used only by MBP_RegistrationFormController.getRegistrationAgents,
 *                     which feeds the Owners and Admins steps of the broker registration form.
 * @Author           : Prateek Bansal
 * @Modification Log :
 *==============================================================================
 * Ver | Date       | Author         | Modification
 *------------------------------------------------------------------------------
 * 1.0 | 13-11-2025 | Prateek Bansal | Initial version
 * 1.1 | 08-09-2026 | Aurelix IT     | Changed "with sharing" to "inherited sharing". Documents__c
 *     |            |                | and Registration_Agent__c are shared only with the guest user,
 *     |            |                | so a logged-in broker (Required More Information flow) could
 *     |            |                | not read back their owner / admin files. The calling controller
 *     |            |                | is "without sharing"; this class now runs in the caller's mode.
 */
public inherited sharing class FileService {

    // One map per agent: file type key (passportFront, eidFront, ...) -> latest ContentVersion.
    public class AgentFileResult {
        public Map<Id, Map<String, ContentVersion>> agentFileMap;
    }

    public static AgentFileResult fetchAgentDocuments(Set<Id> agentIdSet) {
        AgentFileResult result = new AgentFileResult();
        result.agentFileMap = new Map<Id, Map<String, ContentVersion>>();

        if (agentIdSet.isEmpty()) return result;

        Map<Id, Id> docIdToAgentId = new Map<Id, Id>();
        Set<Id> docIds = new Set<Id>();

        // Files linked directly to the agent record.
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :agentIdSet
        ]) {
            docIds.add(cdl.ContentDocumentId);
            docIdToAgentId.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
        }

        // Files linked to the agent's Documents__c placeholders (the normal upload path).
        Map<Id, Id> placeholderToAgent = new Map<Id, Id>();
        Set<Id> placeholderIds = new Set<Id>();

        for (Documents__c doc : [
            SELECT Id, Registration_Agent__c
            FROM Documents__c
            WHERE Registration_Agent__c IN :agentIdSet
        ]) {
            placeholderIds.add(doc.Id);
            placeholderToAgent.put(doc.Id, doc.Registration_Agent__c);
        }

        if (!placeholderIds.isEmpty()) {
            for (ContentDocumentLink link : [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :placeholderIds
            ]) {
                docIds.add(link.ContentDocumentId);
                Id agentId = placeholderToAgent.get(link.LinkedEntityId);
                if (agentId != null) {
                    docIdToAgentId.put(link.ContentDocumentId, agentId);
                }
            }
        }

        // Read the latest version of each file in batches of 100 to keep VersionData under the heap limit.
        Integer batchSize = 100;
        List<Id> docIdList = new List<Id>(docIds);

        for (Integer i = 0; i < docIdList.size(); i += batchSize) {
            List<Id> batchIds = new List<Id>();
            Integer endIndex = Math.min(i + batchSize, docIdList.size());
            for (Integer j = i; j < endIndex; j++) {
                batchIds.add(docIdList[j]);
            }

            for (ContentVersion ver : [
                SELECT Title, VersionData, ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId IN :batchIds
                AND IsLatest = true
            ]) {
                Id agentId = docIdToAgentId.get(ver.ContentDocumentId);
                if (agentId == null) continue;

                // Title carries the slot name (Passport_First_Page, Emirates_ID_Front, ...).
                String key = MBP_RegistrationFormController.getFileTypeKey(ver.Title);
                if (!result.agentFileMap.containsKey(agentId)) {
                    result.agentFileMap.put(agentId, new Map<String, ContentVersion>());
                }
                result.agentFileMap.get(agentId).put(key, ver);
            }
        }

        return result;
    }
}