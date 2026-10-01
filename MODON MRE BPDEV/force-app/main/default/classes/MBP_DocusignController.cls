public class MBP_DocusignController {

    // ===================================================================================
    // NEW — enqueueSendForSignatureFromTasks
    //
    // Moved here from TaskTriggerHandler.afterInsertMethod (was inline there, tagged "1.4
    // start"/"1.4 end"). This is DocuSign-related logic, so it belongs in the DocuSign
    // controller, not scattered inline in the task trigger handler — TaskTriggerHandler now
    // just calls this one method.
    //
    // What it does, unchanged from the original inline version: scans the newly-inserted
    // Tasks for ones with Subject == 'Send for Signature' whose WhatId points at a
    // ServiceRequest__c, collects those SR Ids, and — if any were found — enqueues a single
    // DocuSignQueueable for all of them (DocuSignQueueable itself just delegates to
    // MBP_SendForSignatureController.sendEnvelopeBulk(), which is already bulk-safe).
    // ===================================================================================
    public static void enqueueSendForSignatureFromTasks(List<Task> newTasks){
        if (newTasks == null || newTasks.isEmpty()) return;

        Set<Id> srIds = new Set<Id>();

        for (Task t : newTasks) {
            if (
                t.Subject == 'Send for Signature' &&
                t.WhatId != null &&
                t.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c'
            ) {
                srIds.add(t.WhatId);
            }
        }

        if (!srIds.isEmpty()) {
            System.enqueueJob(new DocuSignQueueable(new List<Id>(srIds)));
        }
    }

  public static void updateSRDocuSignStatus(List<SObject> newList, Map<Id, SObject> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        String srPrefix = ServiceRequest__c.SObjectType.getDescribe().getKeyPrefix();

        // DocuSign's raw envelope status -> the picklist value on ServiceRequest__c.
        // Update the right-hand values here if the actual picklist API values differ.
        Map<String, String> STATUS_TO_PICKLIST = new Map<String, String>{
            'Sent'      => 'Envelope Sent',
            'Delivered' => 'Envelope Delivered',
            'Completed' => 'Envelope Completed',
            'Declined'  => 'Envelope Declined',
            'Voided'    => 'Envelope Voided'
        };

        // Record types already fully handled by markLatestUnifiedFileSignedForSR — skip those
        // here entirely so the two methods never touch the same SR.
        Set<String> ALREADY_HANDLED_RECORD_TYPES = new Set<String>{
            Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER,
            Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION,
            Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED,
            Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED,
            Constants.SERVICE_REQUEST_RT_DEV_NAME_PE,
            Constants.SERVICE_REQUEST_LPC
        };

        Map<Id, String> srIdToPicklistValue = new Map<Id, String>();

        for (SObject sObj : newList) {
            dfsle__EnvelopeStatus__c env = (dfsle__EnvelopeStatus__c) sObj;
            if (env == null || env.dfsle__SourceId__c == null || env.dfsle__Status__c == null) continue;
            if (!String.valueOf(env.dfsle__SourceId__c).startsWith(srPrefix)) continue;

            String picklistValue = STATUS_TO_PICKLIST.get(env.dfsle__Status__c);
            if (picklistValue == null) {
                System.debug('⚠️ [updateSRDocuSignStatus] Unmapped dfsle__Status__c value "' + env.dfsle__Status__c
                    + '" on EnvelopeStatus ' + env.Id + ' — skipping rather than guessing a picklist value.');
                continue;
            }

            srIdToPicklistValue.put((Id) env.dfsle__SourceId__c, picklistValue);
        }

        if (srIdToPicklistValue.isEmpty()) return;

        // Exclude SRs whose RecordType is already owned by markLatestUnifiedFileSignedForSR.
        Map<Id, ServiceRequest__c> srById = new Map<Id, ServiceRequest__c>([
            SELECT Id, RecordType.DeveloperName
            FROM ServiceRequest__c
            WHERE Id IN :srIdToPicklistValue.keySet()
        ]);

        List<ServiceRequest__c> srsToUpdate = new List<ServiceRequest__c>();
        for (ServiceRequest__c sr : srById.values()) {
            String rtDevName = sr.RecordType != null ? sr.RecordType.DeveloperName : null;
            if (rtDevName != null && ALREADY_HANDLED_RECORD_TYPES.contains(rtDevName)) {
                continue; // markLatestUnifiedFileSignedForSR already owns this one
            }
            srsToUpdate.add(new ServiceRequest__c(
                Id = sr.Id,
                Docusign_Envelope_Status__c = srIdToPicklistValue.get(sr.Id)
            ));
        }

        if (srsToUpdate.isEmpty()) return;

        try {
            update srsToUpdate;
            System.debug('✅ [updateSRDocuSignStatus] Updated Docusign_Envelope_Status__c on ' + srsToUpdate.size() + ' SR(s).');
        } catch (DMLException e) {
            System.debug(LoggingLevel.ERROR, '❌ [updateSRDocuSignStatus] Failed updating SR status: ' + e.getMessage());
        }
    }

    // ===================================================================================
    // v6.0 — updateAccountDocuSignStatus (NEW METHOD — only addition this round)
    //
    // Mirrors updateSRDocuSignStatus() exactly, but for Account: Account carries the SAME
    // Docusign_Envelope_Status__c field with the same picklist values ('Envelope Sent',
    // 'Envelope Delivered', 'Envelope Completed', 'Envelope Declined', 'Envelope Voided'),
    // confirmed. This is what keeps that field in sync for envelopes sent straight off an
    // Account (agencies with no Service Request yet — see MBP_SendForSignatureController's
    // sendForAccount()/sendEnvelopeBulkForAccounts()).
    //
    // No RecordType-based exclusion is needed here the way updateSRDocuSignStatus() excludes
    // markLatestUnifiedFileSignedForSR's ABC/DE buckets — nothing else in this class writes to
    // Docusign_Envelope_Status__c on Account, so there's nothing to avoid colliding with.
    // ===================================================================================
    public static void updateAccountDocuSignStatus(List<SObject> newList, Map<Id, SObject> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        String accountPrefix = Account.SObjectType.getDescribe().getKeyPrefix();

        // Same DocuSign status -> picklist value mapping as updateSRDocuSignStatus(). Update
        // the right-hand values here too if the real picklist API values ever differ.
        Map<String, String> STATUS_TO_PICKLIST = new Map<String, String>{
            'Sent'      => 'Envelope Sent',
            'Delivered' => 'Envelope Delivered',
            'Completed' => 'Envelope Completed',
            'Declined'  => 'Envelope Declined',
            'Voided'    => 'Envelope Voided'
        };

        Map<Id, String> accountIdToPicklistValue = new Map<Id, String>();

        for (SObject sObj : newList) {
            dfsle__EnvelopeStatus__c env = (dfsle__EnvelopeStatus__c) sObj;
            if (env == null || env.dfsle__SourceId__c == null || env.dfsle__Status__c == null) continue;
            if (!String.valueOf(env.dfsle__SourceId__c).startsWith(accountPrefix)) continue;

            String picklistValue = STATUS_TO_PICKLIST.get(env.dfsle__Status__c);
            if (picklistValue == null) {
                System.debug('⚠️ [updateAccountDocuSignStatus] Unmapped dfsle__Status__c value "' + env.dfsle__Status__c
                    + '" on EnvelopeStatus ' + env.Id + ' — skipping rather than guessing a picklist value.');
                continue;
            }

            accountIdToPicklistValue.put((Id) env.dfsle__SourceId__c, picklistValue);
        }

        if (accountIdToPicklistValue.isEmpty()) return;

        List<Account> accountsToUpdate = new List<Account>();
        for (Id accId : accountIdToPicklistValue.keySet()) {
            accountsToUpdate.add(new Account(
                Id = accId,
                Docusign_Envelope_Status__c = accountIdToPicklistValue.get(accId)
            ));
        }

        try {
            update accountsToUpdate;
            System.debug('✅ [updateAccountDocuSignStatus] Updated Docusign_Envelope_Status__c on ' + accountsToUpdate.size() + ' Account(s).');
        } catch (DMLException e) {
            System.debug(LoggingLevel.ERROR, '❌ [updateAccountDocuSignStatus] Failed updating Account status: ' + e.getMessage());
        }
    }
// ===================================================================================
// populateBrokerOwnerEmail — UPDATED
//
// Change: the Owner fallback (used when no agent has a POA_Email__c) now specifically
// requires Primary_Owner__c = true on top of Type__c == 'Owner'. Previously ANY agent
// with Type__c == 'Owner' would win the fallback (effectively "last Owner-type agent
// seen in the loop" if there happened to be more than one) — now it only picks the
// agent that's actually flagged as the Primary Owner, which is what should represent
// the agency's real owner-of-record when there's no POA on file.
//
// Priority order is otherwise unchanged:
//   1) Any agent with a non-blank POA_Email__c (first one found wins, loop breaks).
//   2) The agent with Type__c == 'Owner' AND Primary_Owner__c = true, if that agent
//      also has a non-blank Agent_Email__c.
//   3) Neither found -> the SR's Broker_Agency_Owner_Name__c/Email__c are left as-is.
// ===================================================================================
public static void populateBrokerOwnerEmail(List<ServiceRequest__c> newList){

    Set<Id> regIds = new Set<Id>();

    for(ServiceRequest__c sr : newList){
        if(sr.Registration__c != null){
            regIds.add(sr.Registration__c);
        }
    }

    if(regIds.isEmpty()){
        return;
    }

    Map<Id, Registration__c> regMap = new Map<Id, Registration__c>(
        [
            SELECT Id,
                   (
                       SELECT Id,
                              Name,
                              Type__c,
                              Agent_First_Name__c,
                              Agent_Last_Name__c,
                              Agent_Email__c,
                              POA_Email__c,
                              POA__c,
                              Primary_Owner__c
                       FROM Registration_Agents__r
                   )
            FROM Registration__c
            WHERE Id IN :regIds
        ]
    );

    for(ServiceRequest__c sr : newList){

        if(sr.Registration__c == null){
            continue;
        }

        Registration__c reg = regMap.get(sr.Registration__c);

        if(reg == null || reg.Registration_Agents__r == null){
            continue;
        }

        Registration_Agent__c ownerAgent;
        Registration_Agent__c poaAgent;

        for(Registration_Agent__c agent : reg.Registration_Agents__r){

            // Highest priority - POA Email
            if(!String.isBlank(agent.POA_Email__c)){
                poaAgent = agent;
                break;
            }

            // Fallback - the PRIMARY Owner specifically, not just any Type__c == 'Owner' agent.
            if(agent.Type__c == 'Owner' && agent.Primary_Owner__c == true){
                ownerAgent = agent;
            }
        }

        // Priority 1 - POA
        if(poaAgent != null){

            sr.Broker_Agency_Owner_Email__c = poaAgent.POA_Email__c;
            sr.Broker_Agency_Owner_Name__c = poaAgent.POA__c;
        }
        // Priority 2 - Primary Owner
        else if(ownerAgent != null &&
                !String.isBlank(ownerAgent.Agent_Email__c)){

            sr.Broker_Agency_Owner_Email__c = ownerAgent.Agent_Email__c;

            sr.Broker_Agency_Owner_Name__c =
                (
                    (ownerAgent.Agent_First_Name__c != null
                        ? ownerAgent.Agent_First_Name__c
                        : '')
                    + ' ' +
                    (ownerAgent.Agent_Last_Name__c != null
                        ? ownerAgent.Agent_Last_Name__c
                        : '')
                ).trim();
        }
    }
}
}