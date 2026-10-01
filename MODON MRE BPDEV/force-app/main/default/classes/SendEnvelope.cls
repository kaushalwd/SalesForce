public class SendEnvelope {
    public static integer rountingCounter =1;
    public static string docName;
    @auraEnabled
    public static string sendEnvelopeMethod(string docID){
        //docID='a05Dw00000AOhhgIAD';
        
        Id mySourceId =docID; // The ID of the initiating Salesforce object
        Documents__c  docRecord =[select Id, Name, EnvelopID__c,Salesorder__c,Salesorder__r.Opportunity__r.PrimaryContact__r.Name,Opportunity__r.PrimaryContact__r.UAE_Resident_Status__c , Salesorder__r.Opportunity__r.PrimaryContact__r.UAE_Resident_Status__c ,Salesorder__r.Opportunity__r.PrimaryContact__r.email,Salesorder__r.Opportunity__r.PrimaryContact__c,Opportunity__c,Opportunity__r.PrimaryContact__r.Name,Opportunity__r.PrimaryContact__r.email,Opportunity__r.PrimaryContact__c from Documents__c where id=:mySourceId limit 1];
        docName = docRecord.Name;
        if(docRecord.EnvelopID__c!=null){
            return 'The docusign process is already in progress';
        }
        if((docRecord.Salesorder__c!=null && docRecord.Salesorder__r.Opportunity__r.PrimaryContact__r.UAE_Resident_Status__c == null ) || docRecord.Opportunity__r.PrimaryContact__r.UAE_Resident_Status__c == null){
            return 'Pleas update resident status for '+docRecord.Salesorder__r.Opportunity__r.PrimaryContact__r.Name+' (primary owner)';
        }
        
        String userId = label.Modon_Recipient;
        User modon_recipient = [SELECT Id, Name, Email FROM User WHERE Id =: userId];
        
        ContentDocumentLink cdl = [select id, ContentDocumentId, ContentDocument.LatestPublishedVersionId from ContentDocumentLink where LinkedEntityId = :docRecord.id order by systemmodStamp desc limit 1]; 
        list<JointOwner__c> joList = [select id, JointOwnerAccount__c  from JointOwner__c where Opportunity__c = :docRecord.id];
        List<dfsle.Recipient> recipientList = new List<dfsle.Recipient>();
        Integer residentCounter =1;
        Integer nonResidentCounter =1;
        
        if(docRecord.Salesorder__c!=null){
            Integer seqCounter =1;
            boolean isPrimaryOwnerResident = docRecord.Name != 'SPA' ? (docRecord.Salesorder__r.Opportunity__r.PrimaryContact__r.UAE_Resident_Status__c == Constants.RESIDENT):false;
            recipientList.add(createRecipientFromSobj(docRecord.Salesorder__r.Opportunity__r.PrimaryContact__r.Name,
                                                  docRecord.Salesorder__r.Opportunity__r.PrimaryContact__r.email,
                                                  docRecord.Salesorder__r.Opportunity__r.PrimaryContact__c,mySourceId,(isPrimaryOwnerResident?residentCounter:nonResidentCounter ),isPrimaryOwnerResident)); // true false must be derived based on Resident Staus
            if(isPrimaryOwnerResident){residentCounter++; }else{nonResidentCounter++;}
            system.debug(docRecord.Opportunity__r.PrimaryContact__c);
            for(JointOwner__c joRecord : [select id, JointOwnerAccount__c,JointOwnerAccount__r.PersonContactId,JointOwnerAccount__r.Name,JointOwnerAccount__r.UAE_Resident_Status__pc,JointOwnerAccount__r.Personemail  from JointOwner__c where Salesorder__c = :docRecord.Salesorder__c]){
                if(joRecord.JointOwnerAccount__r.UAE_Resident_Status__pc == null){ return 'Pleas update resident status for '+joRecord.JointOwnerAccount__r.Name+' (joint owner)'; }
                boolean isJOResident = docRecord.Name != 'SPA' ? (joRecord.JointOwnerAccount__r.UAE_Resident_Status__pc == Constants.RESIDENT):false;
                recipientList.add(createRecipientFromSobj(joRecord.JointOwnerAccount__r.Name, joRecord.JointOwnerAccount__r.Personemail, joRecord.Id,mySourceId,(isJOResident?residentCounter:nonResidentCounter),isJOResident));//true false must be derived based on Resident Staus
                if(isJOResident){residentCounter++; }else{nonResidentCounter++;}
                
            }
        }else{
            Integer seqCounter =1;
            recipientList.add(createRecipientFromSobj(docRecord.Opportunity__r.PrimaryContact__r.Name,
                                                  docRecord.Opportunity__r.PrimaryContact__r.email,
                                                  docRecord.Opportunity__r.PrimaryContact__c,mySourceId,seqCounter,true)); //true false must be derived based on Resident Staus
            system.debug(docRecord.Opportunity__r.PrimaryContact__c);
            for(JointOwner__c joRecord : [select id, JointOwnerAccount__c,JointOwnerAccount__r.PersonContactId,JointOwnerAccount__r.Name,JointOwnerAccount__r.Personemail  from JointOwner__c where Opportunity__c = :docRecord.Opportunity__c]){
                if(joRecord.JointOwnerAccount__r.UAE_Resident_Status__pc == null){ return 'Pleas update resident status for '+joRecord.JointOwnerAccount__r.Name+' (joint owner)'; }
                boolean isJOResident = docRecord.Name != 'SPA' ?(joRecord.JointOwnerAccount__r.UAE_Resident_Status__pc == Constants.RESIDENT):false;
                recipientList.add(createRecipientFromSobj(joRecord.JointOwnerAccount__r.Name, joRecord.JointOwnerAccount__r.Personemail, joRecord.Id,mySourceId,(isJOResident?residentCounter:nonResidentCounter),isJOResident));
                if(isJOResident){residentCounter++; }else{nonResidentCounter++;}
            }
        }
        if(docRecord.Name == 'SPA'){
            recipientList.add(createRecipientFromSobj(modon_recipient.Name, modon_recipient.Email, modon_recipient.Id,mySourceId,nonResidentCounter,false));
        }
        
            
        system.debug(recipientList.size());
        
        String templateId = System.label.UAEPASS_Template_ID ; // The ID of the DocuSign template
        system.debug(recipientList.size());
        dfsle.Document myDocument = dfsle.Document.fromTemplate(dfsle.UUID.parse(templateId),'dummy');
        //Contentversion ccv = [select id,FileType,Title,ContentDocumentId from contentversion where id = :cdl.ContentDocument.LatestPublishedVersionId limit 1];
        //system.debug('ccv-->'+ccv);
        if(!test.isRunningTest()) { myDocument.withReplacement( (dfsle.DocumentService.getDocuments(ContentVersion.getSObjectType(), new Set<Id>{cdl.ContentDocument.LatestPublishedVersionId}))[0] ); }
        // Create an empty envelope
        //dfsle.Envelope myEnvelope = dfsle.EnvelopeService.getEmptyEnvelope(new dfsle.Entity(mySourceId)).withRecipients(recipientList).withDocuments(dfsle.DocumentService.getDocuments(ContentVersion.getSObjectType(), new Set<Id>{cdl.ContentDocument.LatestPublishedVersionId}));
        dfsle.Envelope myEnvelope = dfsle.EnvelopeService.getEmptyEnvelope(new dfsle.Entity(mySourceId)).withRecipients(recipientList).withDocuments(new list<dfsle.Document>{myDocument});
        // The initiating Salesforce entity
        myEnvelope = test.isRunningTest() ? null : dfsle.EnvelopeService.sendEnvelope(myEnvelope, true);

        //Docusign Envelop Id
        String DocuSignId = test.isRunningTest() ? 'Test' : String.valueOf(myEnvelope.docuSignId);
        docRecord.EnvelopID__c=DocuSignId;
        update docRecord;
        return 'success';
        //system.debug(DocuSignId);
    }
    
    public static dfsle.Recipient createRecipientFromSobj(string recepientName, string recepientEmail, string stacticAchorTab,string docID,integer sequenceNumber,boolean isUAEres) {
            Integer seq = docName != 'SPA' ? 1:sequenceNumber;                                                     
            string recepientNameTruncated = recepientName.length() < 80 ? recepientName : recepientName.substring(0,79);
            string anchorString = stacticAchorTab;
            dfsle.Tab signatureTab = createEnvTab(anchorString + 'SignatureHolder'); 
            dfsle.Tab dateTab = createEnvTab(anchorString + 'DateHolder');
            dfsle.Tab initialHereTab = createEnvTab(anchorString + 'InitialsHolder');
            dfsle.Tab stampTab = createEnvTab(anchorString + 'StampHolder');
            system.debug('isUAEres --' +isUAEres);                                                      
            dfsle.Recipient envRecipient = dfsle.Recipient.fromSource(recepientName, recepientEmail, null, 
                                                                    ((isUAEres?'UAE':'')+'SignatureHolder'+sequenceNumber), new dfsle.Entity(docID))
                .withTabs(new List<dfsle.Tab> {signatureTab,dateTab,initialHereTab,stampTab})
                .withRoutingOrder(seq);
            //rountingCounter++;
            return envRecipient;                                                            
        }
    
    public static dfsle.Tab createEnvTab(string anchorString ) {
            dfsle.Tab envTab;
            dfsle.Tab.Anchor anchor = new dfsle.Tab.Anchor(
                anchorString, // Anchor string
                false, // Do not allow white space in anchor string
                false, // Anchor string is not case sensitive
                'left', // Horizontal alignment in relation to the anchor text
                true, // Ignore if the anchor text is not present in the document
                true, // Must match the value of the anchor string in its entirety
                'pixels', // Unit of the x and y offset properties
                30, // X offset
                10);
            
            dfsle.SignHereTab.StampImage img = new dfsle.SignHereTab.StampImage('signature_image',null,null,null,true);
            dfsle.SignHereTab.Stamp Stamp = new dfsle.SignHereTab.Stamp('stamp',null,'NameHanko','test','test',img,null,null);
            System.debug('anchorString: ' + anchorString);
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