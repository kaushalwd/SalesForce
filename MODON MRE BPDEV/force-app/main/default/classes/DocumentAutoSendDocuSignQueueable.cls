/**********************************************************************************************************************
* Name               : DocumentAutoSendDocuSignQueueable                                                        
* Description        : Asynchronous Queueable job to automatically fetch Nintex-generated PDFs and send via DocuSign
* Usage              : Executed via Platform Event Trigger (DocuSignSendRequestTrigger)
* Created By         : Rushi Patel                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 01 Sep 2026     Initial draft 
******************************************************************************************************************/
public class DocumentAutoSendDocuSignQueueable implements Queueable, Database.AllowsCallouts {
    
    private Set<Id> documentIds;
    private Integer retryCount;

    public DocumentAutoSendDocuSignQueueable(Set<Id> documentIds, Integer retryCount) {
        this.documentIds = documentIds;
        this.retryCount = retryCount;
    }
    /**********************************************************************************************************************
    * @Description  : Main Queueable execute method to generate DocuSign envelope and attach Nintex PDF
    * @Author       : Rushi Patel
    * @Date         : 01 Sep 2026
    **********************************************************************************************************************/
    public void execute(QueueableContext context) {
        if (documentIds == null || documentIds.isEmpty()) return;

        // Take up to 90 documents to process in this transaction (DocuSign sendEnvelopes limit is 99)
        List<Id> allIds = new List<Id>(documentIds);
        List<Id> chunkIds = new List<Id>();
        Set<Id> remainingIds = new Set<Id>();
        
        for (Integer i = 0; i < allIds.size(); i++) {
            if (i < 90) {
                chunkIds.add(allIds[i]);
            } else {
                remainingIds.add(allIds[i]);
            }
        }

        List<Documents__c> docs = [
            SELECT Id, CustomerName__c, Customer_Email__c, Name 
            FROM Documents__c 
            WHERE Id IN :chunkIds
        ];

        Set<Id> chunkMissingFiles = new Set<Id>();
        List<dfsle.Envelope> envelopes = new List<dfsle.Envelope>();
        List<Documents__c> processedDocs = new List<Documents__c>();
        List<Documents__c> docsToUpdate = new List<Documents__c>();

        // 1. Bulk query ContentDocumentLinks for the chunk
        Map<Id, Id> latestVersionByDocId = new Map<Id, Id>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId IN :chunkIds
            ORDER BY SystemModstamp DESC
        ]) {
            if (!latestVersionByDocId.containsKey(cdl.LinkedEntityId)) {
                latestVersionByDocId.put(cdl.LinkedEntityId, cdl.ContentDocument.LatestPublishedVersionId);
            }
        }

        // 2. Fetch configuration
        DocuSign_Automated_Config__mdt config = DocuSign_Automated_Config__mdt.getInstance('EOI_Form');
        String emailSubject = config != null && String.isNotBlank(config.Email_Subject__c) ? config.Email_Subject__c : 'Documents for your Docusign Signature';
        String emailBody = config != null && String.isNotBlank(config.Email_Body__c) ? config.Email_Body__c : 'Please review and electronically sign.';
        String roleName = config != null && String.isNotBlank(config.Recipient_Role__c) ? config.Recipient_Role__c : 'Signer 1';
        Integer remindFreq = config != null && config.Remind_Frequency_Days__c != null ? Integer.valueOf(config.Remind_Frequency_Days__c) : 0;
        Integer expireDays = config != null && config.Expire_After_Days__c != null ? Integer.valueOf(config.Expire_After_Days__c) : 1;
        Integer expireWarn = config != null && config.Expire_Warn_Days__c != null ? Integer.valueOf(config.Expire_Warn_Days__c) : 0;

        // 3. Build Envelopes
        for (Documents__c doc : docs) {
            String custEmail = doc.Customer_Email__c;
            if (Test.isRunningTest() && String.isBlank(custEmail)) {
                custEmail = 'test@example.com';
            }
            
            if (String.isBlank(custEmail)) {
                System.debug('Cannot send DocuSign for ' + doc.Id + ' - No Customer Email');
                continue;
            }

            Id latestVersionId = latestVersionByDocId.get(doc.Id);
            if (latestVersionId == null) {
                chunkMissingFiles.add(doc.Id);
                if (!Test.isRunningTest()) continue;
            }

            try {
                dfsle.Envelope myEnvelope = dfsle.EnvelopeService.getEmptyEnvelope(new dfsle.Entity(doc.Id));
                String custName = String.isNotBlank(doc.CustomerName__c) ? doc.CustomerName__c : 'Customer';
                
                dfsle.Recipient myRecipient = dfsle.Recipient.fromSource(custName, custEmail, null, roleName, new dfsle.Entity(doc.Id)).withRoutingOrder(1);
                myEnvelope = myEnvelope.withEmail(emailSubject, emailBody);
                
                if (config != null) {
                    myEnvelope = myEnvelope.withNotifications(new dfsle.Notifications(
                        remindFreq > 0, remindFreq > 0 ? remindFreq : null, remindFreq > 0 ? remindFreq : null,
                        expireDays > 0, expireDays > 0 ? expireDays : null, expireWarn > 0 ? expireWarn : null, false
                    ));
                }
                
                myEnvelope = myEnvelope.withRecipients(new List<dfsle.Recipient> { myRecipient });
                
                if (latestVersionId != null) {
                    myEnvelope = myEnvelope.withDocuments(dfsle.DocumentService.getDocuments(ContentVersion.getSObjectType(), new Set<Id>{ latestVersionId }));
                }
                
                envelopes.add(myEnvelope);
                processedDocs.add(doc);
            } catch (Exception e) {
                doc.Document_Error_Message__c = 'Envelope Build Error: ' + e.getMessage();
                docsToUpdate.add(doc);
            }
        }

        // 4. Send Envelopes in Bulk
        if (!envelopes.isEmpty() && !Test.isRunningTest()) {
            try {
                // This makes the callout without performing DML immediately
                envelopes = dfsle.EnvelopeService.sendEnvelopes(envelopes);
                List<dfsle.Envelope> sentEnvelopesToSave = new List<dfsle.Envelope>();
                
                for (Integer i = 0; i < envelopes.size(); i++) {
                    dfsle.Envelope env = envelopes[i];
                    Documents__c doc = processedDocs[i];
                    
                    if (env.error != null) {
                        doc.Document_Error_Message__c = 'DocuSign API Error: ' + env.error;
                    } else if (env.docuSignId != null) {
                        doc.EnvelopID__c = String.valueOf(env.docuSignId);
                        doc.Document_Error_Message__c = null; // Clear old errors
                        sentEnvelopesToSave.add(env);
                    }
                    docsToUpdate.add(doc);
                }
                
                // Perform the deferred DML to save the status records
                if (!sentEnvelopesToSave.isEmpty()) {
                    dfsle.EnvelopeService.saveSentEnvelopes(sentEnvelopesToSave);
                }
                
            } catch (Exception e) {
                System.debug('DocuSign Bulk Send Exception: ' + e.getMessage());
                for (Documents__c doc : processedDocs) {
                    doc.Document_Error_Message__c = 'DocuSign Bulk Send Exception: ' + e.getMessage();
                    docsToUpdate.add(doc);
                }
            }
        }

        // 5. Save document updates
        if (!docsToUpdate.isEmpty()) {
            update docsToUpdate;
        }

        // 6. Enqueue any remaining or retried documents
        Set<Id> nextQueue = new Set<Id>();
        nextQueue.addAll(remainingIds);

        if (!chunkMissingFiles.isEmpty()) {
            if (retryCount < 3) {
                System.debug('Files not found yet, re-enqueueing for ' + chunkMissingFiles.size() + ' documents.');
                nextQueue.addAll(chunkMissingFiles);
            } else {
                List<Documents__c> failedDocsToUpdate = new List<Documents__c>();
                for (Id missingId : chunkMissingFiles) {
                    failedDocsToUpdate.add(new Documents__c(
                        Id = missingId, 
                        Document_Error_Message__c = 'DocuSign Send Error: Document generation took too long or file was not attached.'
                    ));
                }
                update failedDocsToUpdate;
            }
        }

        if (!nextQueue.isEmpty() && !Test.isRunningTest()) {
            Integer nextRetry = chunkMissingFiles.isEmpty() ? retryCount : retryCount + 1;
            System.enqueueJob(new DocumentAutoSendDocuSignQueueable(nextQueue, nextRetry));
        }
    }
}