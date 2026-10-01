/******************************************************************************************************************
* Name               : RegistrationService                                                       
* Description        : This class invoked during when validation by compliance team is completed
* Usage              : 
* Created By         : AMGS                                                     
* -----------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Sanath H M              20 Jun 2025     For sending agreement via docusign
******************************************************************************************************************/
public class MBP_AgencyRegistrationDocuSignHelper {

    public static void sendUsingDocuSign(string srId, string stepId){
        List<dfsle.Recipient> recipientList 		= new List<dfsle.Recipient>();
        Task task 									= new Task();
        ServiceRequest__c serviceRequest            = new ServiceRequest__c();
        Registration_Agent__c regAgent 				= new Registration_Agent__c();
        Set<Id> documentIds 						= new Set<Id>();
        Set<id> contDocIdToSend 					= new Set<id>();
        Set<id> contVersionIdToSend 				= new Set<id>();
        
        Integer routingOrder = 1;
        dfsle.Envelope envelope;
        
        for(Task tsk: [SELECT Id, Subject,Extended_NOC_Approval_Status__c,
                       NOC_Doc_Status__c, ActivityDate, Status,Description,
                       KYC_Status__c,Priority, Broker_Registration_Status__c,Comments__c 
                       FROM Task WHERE Id =: stepId]){
            task = tsk;
        }
        ServiceRequest__c sr = [SELECT Id, Registration__c FROM ServiceRequest__c WHERE Id=:srId];
        Registration_Agent__c registrationAgent = [SELECT 
                                                   Id,
                                                   Agent_Email__c,
                                                   Agent_First_Name__c
                                                   FROM Registration_Agent__c 
                                                   WHERE Registration_Name__c =:sr.Registration__c 
                                                   AND Type__c='Owner'
                                                   AND Primary_Owner__c = true];
        
        
        List<ContentDocumentLink> links = [ SELECT ContentDocumentId  FROM ContentDocumentLink WHERE LinkedEntityId = :sr.Registration__c ];
        for(ContentDocumentLink link:links){
            documentIds.add(link.ContentDocumentId);
        }
        List<ContentVersion> latestVersions = [ SELECT Id, Title, VersionData, ContentDocumentId FROM ContentVersion
            WHERE ContentDocumentId  IN: documentIds AND isLatest = true AND Title LIKE '%Sales%'];
        
        for (ContentVersion contVer : latestVersions){
            contVersionIdToSend.add(contVer.Id);
        }
       // if(task.Subject==''){
            dfsle.Recipient brokerRecipient = createRecipientFromSobj(registrationAgent,'Agent_First_Name__c','Agent_Email__c',registrationAgent.Id,routingOrder,registrationAgent.Id,'Signer');
            recipientList.add(brokerRecipient);
       // }
        envelope = dfsle.EnvelopeService.getEmptyEnvelope(new dfsle.Entity(srId)).withRecipients(recipientList)
            .withDocuments(dfsle.DocumentService.getDocuments(ContentVersion.getSObjectType(),contVersionIdToSend));
        
        try{   
            envelope = test.isRunningTest()?null:dfsle.EnvelopeService.sendEnvelope(envelope, true);
        }catch(DMLException ex) {
            
        }
        String DocuSignID = test.isRunningTest()?'Test':String.valueOf(envelope.docuSignId);
        
        if (DocuSignID != null){
           
            dfsle__Envelope__c envelopeToUpdate = new dfsle__Envelope__c();
            dfsle__EnvelopeStatus__c envStatus = new dfsle__EnvelopeStatus__c();
            
            for (dfsle__Envelope__c envObj : [ SELECT id FROM dfsle__Envelope__c WHERE dfsle__DocuSignId__c = :DocuSignID]) {
                envelopeToUpdate = envObj;
            }
        }
    }
    public static dfsle.Recipient createRecipientFromSobj(SObject recepient, string NameField, string emailField, string stacticAchorTab, integer routingOrder, string srId, string signerType){
      
        string recepientName = string.valueof(recepient.get(NameField));
        string recepientEmail = string.valueof(recepient.get(emailField));
        return createRecipientFromSobj(recepientName, recepientEmail, stacticAchorTab, routingOrder, srId, signerType);                                                            
    
    }
    public static dfsle.Recipient createRecipientFromSobj(string recepientName, string recepientEmail, string stacticAchorTab, integer routingOrder, string srId, string signerType){
        
        string recepientNameTruncated = recepientName.length() < 80 ? recepientName : recepientName.substring(0,79);
        string anchorString = stacticAchorTab;
        dfsle.Recipient envRecipient;
        dfsle.Tab signatureTab = createEnvTab(anchorString + 'SignatureHolder');
        dfsle.Tab dateTab = createEnvTab(anchorString + 'DateHolder');
        dfsle.Tab initialHereTab = createEnvTab(anchorString + 'InitialsHolder');
        dfsle.Tab stampTab = createEnvTab(anchorString + 'StampHolder');
        
        if(signerType == 'Signer'){
            envRecipient = dfsle.Recipient.fromSource(recepientName, recepientEmail, null, 
                                                      null, new dfsle.Entity(srId))
                .withTabs(new List<dfsle.Tab> {signatureTab,dateTab,initialHereTab,stampTab})
                .withRoutingOrder(routingOrder);
        }else if(signerType == 'Approver'){
            dfsle.Tab myApproveTab = new dfsle.ApproveTab().withPosition(new dfsle.Tab.Position(
                1, // The document to use
                1, // Page number on the document
                210, // X position
                105, // Y position
                100, // 100 pixels wide
                null)); // Default height
            dfsle.Tab myDeclineTab = new dfsle.DeclineTab().withPosition(new dfsle.Tab.Position(
                1, // The document to use
                1, // Page number on the document
                210, // X position
                155, // Y position
                100, // 100 pixels wide
                null)); // Default height
            envRecipient = dfsle.Recipient.fromSource(recepientName,recepientEmail,
                                                      null, // Optional phone number
                                                      'Broker Admin', // Role Name. Specify the exact role name from template
                                                      new dfsle.Entity(srId))
                .withTabs(new List<dfsle.Tab> {signatureTab,dateTab,initialHereTab,myApproveTab,myDeclineTab}).withRoutingOrder(routingOrder); // Source object for the Recipient
        
        }
        return envRecipient;                                                           
    }
    public static dfsle.Tab createEnvTab(string anchorString){
        
        dfsle.Tab envTab;
        dfsle.Tab.Anchor anchor = new dfsle.Tab.Anchor(
            anchorString, // Anchor string
            false, // Do not allow white space in anchor string
            false, // Anchor string is not case sensitive
            'right', // Horizontal alignment in relation to the anchor text
            true, // Ignore if the anchor text is not present in the document
            true, // Must match the value of the anchor string in its entirety
            'pixels', // Unit of the x and y offset properties
            -60, // X offset
            15);
        
        dfsle.SignHereTab.StampImage img = new dfsle.SignHereTab.StampImage('signature_image',null,null,null,true);
        dfsle.SignHereTab.Stamp Stamp = new dfsle.SignHereTab.Stamp('stamp',null,'NameHanko','test','test',img,null,null);
        
        if(anchorString.contains('SignatureHolder')){
            envTab = new dfsle.SignHereTab().withAnchor(anchor);
        }else if(anchorString.contains('DateHolder')){
            envTab = new dfsle.DateSignedTab().withAnchor(anchor);
        }else if(anchorString.contains('InitialsHolder')){
            envTab = new dfsle.InitialHereTab().withAnchor(anchor);
        }else if(anchorString.contains('StampHolder')){
            envTab = new dfsle.SignHereTab().withStamp(Stamp).withAnchor(anchor);
        }
        return envTab;
    }
}