/**
* @description       : 
* @author            : Krishna Chaitanya
* @group             : 
* @last modified on  : 01-22-2026
* @last modified by  : Krishna Chaitanya
**/
public with sharing class DocusignSendEnvelopeBySRDeed {
    /**
* @description AuraEnabled method that sends a DocuSign envelope for a
*              ServiceRequest__c record. Builds a multi-tier recipient list:
*                1) Seller Validator (Approver) — from SR.Seller_Validation_Name__c
*                   / Seller_Validator_Email__c, with APPROVE_SELLER/DECLINE_SELLER tabs.
*                2) Buyer Validator (Approver) — from SR.Buyer_Validator_Name__c
*                   / Buyer_Validator_Email__c, with APPROVE_BUYER/DECLINE_BUYER tabs.
*                3) SO Customer (PersonAccount) or Primary Contact (Signer).
*                4) Primary Prospect_Account__c records (Signers).
*                5) Final internal recipient from Custom Labels (Signer).
*              Retrieves Documents__c linked to the SR where Name LIKE
*              '%Deed of Adherence%' OR '%Novation Agreement%', resolves
*              their latest ContentVersion files, assembles and sends the
*              envelope. On success, updates SR.Signature_Status__c to
*              'Sent for Signature'.
*
* @param serviceRequestId  The Id of the ServiceRequest__c to process.
* @return                  The DocuSign envelope Id as a String, or 'Test'
*                          when running in a test context.
* @throws AuraHandledException  If no SalesOrder is linked, no matching
*                               Documents__c or file versions are found,
*                               or if the DocuSign send fails.
*/
    
    @AuraEnabled
    public static String sendFromServiceRequest(Id serviceRequestId){
        String finalRecipientName  = System.Label.Docusign_FinalRecipient_Name;
        String finalRecipientEmail = System.Label.Docusign_FinalRecipient_Email;
        // -----------------------
        // Build recipients
        // -----------------------
        List<dfsle.Recipient> recipientList = new List<dfsle.Recipient>();
        Integer routingOrder = 1;
        
        ServiceRequest__c sr = [
            SELECT Id,
            Name,
            Buyer_Validator_Email__c,
            Buyer_Validator_Name__c,
            Seller_Validator_Email__c,
            Seller_Validation_Name__c,
            SalesOrder__c,
            SalesOrder__r.Name,
            SalesOrder__r.CustomerAccount__c,
            SalesOrder__r.CustomerAccount__r.Name,
            SalesOrder__r.CustomerAccount__r.IsPersonAccount,
            SalesOrder__r.CustomerAccount__r.PersonEmail,
            SalesOrder__r.PrimaryContact__c,
            SalesOrder__r.PrimaryContact__r.Name,
            SalesOrder__r.PrimaryContact__r.Email
            FROM ServiceRequest__c
            WHERE Id = :serviceRequestId
            LIMIT 1
        ];
        
        
        
        if (sr.SalesOrder__c == null) {
            throw new AuraHandledException('Service Request has no related Sales Order.');
        }
        System.debug('SR Loaded ---> ' + sr);
        System.debug('SalesOrder ---> ' + sr.SalesOrder__c);
        // A) Seller Validator (CC) - BEFORE SO customer
        if (!String.isBlank(sr.Seller_Validator_Email__c) && !String.isBlank(sr.Seller_Validation_Name__c)) {
            recipientList.add(createValidatorRecipient(sr.Seller_Validation_Name__c,sr.Seller_Validator_Email__c,routingOrder++,sr.Id,'<APPROVE_SELLER>','<DECLINE_SELLER>'));
            
        }
        // C) Buyer Validator (CC) - BEFORE Prospect signer(s)
        if (!String.isBlank(sr.Buyer_Validator_Email__c) && !String.isBlank(sr.Buyer_Validator_Name__c)) {
            recipientList.add(createValidatorRecipient(sr.Buyer_Validator_Name__c,sr.Buyer_Validator_Email__c,routingOrder++,sr.Id,'<APPROVE_BUYER>','<DECLINE_BUYER>'));
            
        }
        // 1) SO Customer (PersonAccount) OR Primary Contact
        String soRecipientName;
        String soRecipientEmail;
        
        if (sr.SalesOrder__r.CustomerAccount__c != null
            && sr.SalesOrder__r.CustomerAccount__r.IsPersonAccount
            && !String.isBlank(sr.SalesOrder__r.CustomerAccount__r.PersonEmail)) {
                
                soRecipientName  = sr.SalesOrder__r.CustomerAccount__r.Name;
                soRecipientEmail = sr.SalesOrder__r.CustomerAccount__r.PersonEmail;
                
            } else if (sr.SalesOrder__r.PrimaryContact__c != null
                       && !String.isBlank(sr.SalesOrder__r.PrimaryContact__r.Email)) {
                           
                           soRecipientName  = sr.SalesOrder__r.PrimaryContact__r.Name;
                           soRecipientEmail = sr.SalesOrder__r.PrimaryContact__r.Email;
                       }
        
        if (!String.isBlank(soRecipientEmail)) {
            dfsle.Recipient soRec = createRecipientFromSobj(
                soRecipientName,
                soRecipientEmail,
                soRecipientName,   // anchor seed for <S-Name>, <D-Name>, <In-Name>, <ST-Name>
                routingOrder,
                sr.Id,
                'Signer'
            );
            recipientList.add(soRec);
            routingOrder++;
        }
        
        
        // 3) Prospect_Account__c recipients
        for (Prospect_Account__c pa : [
            SELECT Id,
            Name,
            Email__c,
            Is_Primary__c,
            AccName__c
            FROM Prospect_Account__c
            WHERE Service_Request__c = :sr.Id
            AND Email__c != NULL
            AND Is_Primary__c = true
            ORDER BY Is_Primary__c DESC, Name ASC
        ]) {
            dfsle.Recipient rec = createRecipientFromSobj(
                pa.AccName__c,
                pa.Email__c,
                pa.Name,     // anchor seed for <S-Name> and <D-Name>
                routingOrder,
                sr.Id,
                'Signer'
            );
            recipientList.add(rec);
            routingOrder++;
        }
        // 3) Final internal recipient (name + email you provide)
        if (!String.isBlank(finalRecipientEmail)) {
            recipientList.add(
                dfsle.Recipient.fromSource(finalRecipientName,finalRecipientEmail,null,null,new dfsle.Entity(sr.Id)).withRoutingOrder(routingOrder++).withTabs(new List<dfsle.Tab>{createTagSignHere('\\s20\\'),createTagDateSigned('\\d20\\'),createTagStamp('\\stamp_20\\')}));
        }
        
        
        System.debug('Recipients Count ---> ' + recipientList.size());
        System.debug('Recipients Data ---> ' + recipientList);
        
        // -----------------------
        // Documents from Files on Documents__c
        // -----------------------
        
        // 1) Find Documents__c for this SR with Name LIKE '%Transfer Document%'
        List<Documents__c> docWrappers = [
            SELECT Id, Name
            FROM Documents__c
            WHERE Service_Request__c = :sr.Id AND
            (
                Name LIKE '%Deed of Adherence%'
                OR Name LIKE '%Novation Agreement%'
            )
        ];
        
        if (docWrappers.isEmpty()) {
            throw new AuraHandledException('No Documents__c records found for this SR with Name like "Transfer Document".');
        }
        
        Set<Id> documentIds = new Set<Id>();
        for (Documents__c d : docWrappers) {
            documentIds.add(d.Id);
        }
        System.debug('Documents__c Found ---> ' + docWrappers.size());
        System.debug('Documents__c Records ---> ' + docWrappers);
        
        
        // 2) Get the files linked to those Documents__c
        List<ContentDocumentLink> fileLinks = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :documentIds
        ];
        
        if (fileLinks.isEmpty()) {
            throw new AuraHandledException('No Docs Found: no files linked to Documents__c.');
        }
        
        System.debug('File Links Found ---> ' + fileLinks.size());
        System.debug('File Links ---> ' + fileLinks);
        
        Set<Id> contentDocIds = new Set<Id>();
        for (ContentDocumentLink cdl : fileLinks) {
            contentDocIds.add(cdl.ContentDocumentId);
        }
        
        // 3) Get latest versions whose Title looks like "Transfer Document"
        List<ContentVersion> transferVersions = [
            SELECT Id, Title, VersionData, ContentDocumentId, IsLatest
            FROM ContentVersion
            WHERE IsLatest = true
            AND ContentDocumentId IN :contentDocIds
            AND  (
                Title LIKE '%Deed of Adherence%'
                OR Title LIKE '%Novation Agreement%'
            )
            
        ];
        
        if (transferVersions.isEmpty()) {
            throw new AuraHandledException('No Docs Found: no latest ContentVersion with Title like "Title Deed".');
        }
        
        System.debug('Content Versions Found ---> ' + transferVersions.size());
        System.debug('Content Versions ---> ' + transferVersions);
        
        // 4) Collect version Ids to pass to DocuSign
        Set<Id> versionIds = new Set<Id>();
        for (ContentVersion cv : transferVersions) {
            versionIds.add(cv.Id);
        }
        
        // Build & send envelope
        dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(new dfsle.Entity(sr.Id)).withRecipients(recipientList).withDocuments(dfsle.DocumentService.getDocuments(ContentVersion.getSObjectType(),versionIds));
        
        System.debug('Version Ids ---> ' + versionIds);
        System.debug('Final Recipients ---> ' + recipientList);
        System.debug('Envelope Ready To Send ---> ' + envelope);
        
        
        try {
            envelope = Test.isRunningTest()
                ? null
                : dfsle.EnvelopeService.sendEnvelope(envelope, true);
        } catch (Exception ex) {
            System.debug('DocuSign Send Error ---> ' + ex.getMessage());
            System.debug('StackTrace ---> ' + ex.getStackTraceString());
            throw new AuraHandledException('DocuSign send failed: ' + ex.getMessage());
        }
        
        
        String docuSignId = Test.isRunningTest()
            ? 'Test'
            : (envelope != null ? String.valueOf(envelope.docuSignId) : null);
                
                
                if (!String.isBlank(docuSignId)) {
                    ServiceRequest__c srUpdate = new ServiceRequest__c(
                        Id = sr.Id,
                        Signature_Status__c = 'Sent for Signature'
                    );
                    update srUpdate;
                }
        
        return docuSignId;
    }
    
    /**
* @description Creates a dfsle.Tab.Anchor for simple positional token
*              anchors (e.g., \\s20\\, \\d20\\, \\stamp_20\\).
*              Left-aligned, zero pixel offsets, matchExact = true,
*              ignoreIfNotPresent = true, caseSensitive = false.
*
* @param token  The anchor token string to match in the document.
* @return       A configured dfsle.Tab.Anchor instance.
*/
    
    private static dfsle.Tab.Anchor simpleTagAnchor(String token) {
        return new dfsle.Tab.Anchor(
            token,
            false,   // allowWhiteSpaceInTag
            false,   // caseSensitive
            'left',
            true,    // ignoreIfNotPresent
            true,    // matchExact
            'pixels',
            0,
            0
        );
    }
    
    /**
* @description Creates a DocuSign SignHereTab anchored to the given
*              positional token via simpleTagAnchor.
*
* @param token  The anchor token to match in the document (e.g., '\\s20\\').
* @return       A dfsle.Tab instance representing a Sign Here tab.
*/
    
    private static dfsle.Tab createTagSignHere(String token) {
        return new dfsle.SignHereTab().withAnchor(simpleTagAnchor(token));
    }
    
    /**
* @description Builds a dfsle.Recipient of type 'Approver' for use as a
*              validator (e.g., Seller or Buyer validator) in a DocuSign
*              envelope. Attaches an ApproveTab anchored to approveToken
*              and a DeclineTab anchored to declineToken, both left-aligned
*              with zero pixel offsets. Defaults name to 'Validator' if blank.
*
* @param name           Display name of the validator recipient.
* @param email          Email address of the validator recipient.
* @param routingOrder   Routing order position in the envelope signing sequence.
* @param srId           The ServiceRequest__c Id to link as the DocuSign entity.
* @param approveToken   Anchor string for the Approve tab (e.g., '<APPROVE_SELLER>').
* @param declineToken   Anchor string for the Decline tab (e.g., '<DECLINE_SELLER>').
* @return               A dfsle.Recipient configured as type 'Approver'.
*/
    
    private static dfsle.Recipient createValidatorRecipient(String name,String email,Integer routingOrder,Id srId,String approveToken,String declineToken){
        String nm = String.isBlank(name) ? 'Validator' : name;
        dfsle.Tab.Anchor aApprove = new dfsle.Tab.Anchor(approveToken,false,false,'left',true,true,'pixels',0,0);
        dfsle.Tab.Anchor aDecline = new dfsle.Tab.Anchor(declineToken,false,false,'left',true,true,'pixels',0,0);
        return dfsle.Recipient.fromSource(nm,email,null,null,new dfsle.Entity(srId)).withType('Approver').withTabs(new List<dfsle.Tab>{new dfsle.ApproveTab().withAnchor(aApprove),new dfsle.DeclineTab().withAnchor(aDecline)}).withRoutingOrder(routingOrder);
    }
    
    /**
* @description Creates a DocuSign DateSignedTab anchored to the given
*              positional token via simpleTagAnchor.
*
* @param token  The anchor token to match in the document (e.g., '\\d20\\').
* @return       A dfsle.Tab instance representing a Date Signed tab.
*/
    
    private static dfsle.Tab createTagDateSigned(String token) {
        return new dfsle.DateSignedTab().withAnchor(simpleTagAnchor(token));
    }
    
    /**
* @description Creates a DocuSign Stamp tab (SignHereTab + NameHanko Stamp)
*              anchored to the given positional token via simpleTagAnchor.
*
* @param token  The anchor token to match in the document (e.g., '\\stamp_20\\').
* @return       A dfsle.Tab instance representing a Stamp tab.
*/
    
    private static dfsle.Tab createTagStamp(String token) {
        dfsle.Tab.Anchor a = simpleTagAnchor(token);
        
        dfsle.SignHereTab.StampImage img =
            new dfsle.SignHereTab.StampImage('signature_image', null, null, null, true);
        
        dfsle.SignHereTab.Stamp stamp =
            new dfsle.SignHereTab.Stamp('stamp', null, 'NameHanko', 'test', 'test', img, null, null);
        
        return new dfsle.SignHereTab().withStamp(stamp).withAnchor(a);
    }
    
    /**
* @description Builds a dfsle.Recipient Signer from the provided name,
*              email, and anchor seed. Normalizes the seed via
*              normalizeAnchorName, derives named anchor tags
*              (<S-seed>, <D-seed>, <In-seed>, <ST-seed>), creates
*              Sign Here, Date Signed, Initial Here, and Stamp tabs
*              via createEnvTab, and returns the recipient with the
*              specified routing order applied.
*
* @param recepientName   Display name of the recipient (truncated to 79 chars).
* @param recepientEmail  Email address of the recipient.
* @param anchorSeed      Raw string used to derive named anchor tag suffixes.
* @param routingOrder    Integer routing order in the envelope sequence.
* @param srId            ServiceRequest__c Id to link as the DocuSign entity.
* @param signerType      Signer role label — informational only.
* @return               A fully configured dfsle.Recipient instance.
*/
    
    public static dfsle.Recipient createRecipientFromSobj(
        String recepientName,
        String recepientEmail,
        String anchorSeed,
        Integer routingOrder,
        String srId,
        String signerType
    ){
        String truncatedName = String.isBlank(recepientName)
            ? ''
            : (recepientName.length() < 80
               ? recepientName
               : recepientName.substring(0,79));
                   
                   String normalized = normalizeAnchorName(anchorSeed);
        
        String signAnchor        = '<S-'  + normalized + '>';
        String dateAnchor        = '<D-'  + normalized + '>';
        String initHolderAnchor  = '<In-' + normalized + '>';
        String stampHolderAnchor = '<ST-' + normalized + '>';
        
        dfsle.Tab sigTab   = createEnvTab(signAnchor);
        dfsle.Tab dateTab  = createEnvTab(dateAnchor);
        dfsle.Tab initTab  = createEnvTab(initHolderAnchor);
        dfsle.Tab stampTab = createEnvTab(stampHolderAnchor);
        
        dfsle.Recipient rec = dfsle.Recipient.fromSource(truncatedName, recepientEmail, null, null, new dfsle.Entity(srId)).withTabs(new List<dfsle.Tab>{ sigTab, dateTab, initTab, stampTab }).withRoutingOrder(routingOrder);
        
        return rec;
    }
    
    /**
* @description Creates a DocuSign tab of the appropriate type based on
*              the prefix of the anchor string:
*                <S->  → SignHereTab
*                <D->  → DateSignedTab
*                <In-> → InitialHereTab
*                <ST-> → SignHereTab with NameHanko Stamp
*              Defaults to SignHereTab for unrecognized prefixes.
*              Anchor is right-aligned, xOffset = -60, yOffset = 15 (pixels).
*
* @param anchorString  Full named anchor string including prefix and suffix
*                      (e.g., '<S-John Smith>', '<ST-Jane Doe>').
* @return              A configured dfsle.Tab of the matching type.
*/
    
    public static dfsle.Tab createEnvTab(String anchorString) {
        dfsle.Tab.Anchor anchor = new dfsle.Tab.Anchor(
            anchorString,
            false,
            false,
            'right',
            true,
            true,
            'pixels',
            -60,
            15
        );
        
        if (anchorString.startsWith('<S-') && anchorString.endsWith('>')) {
            return new dfsle.SignHereTab().withAnchor(anchor);
        }
        if (anchorString.startsWith('<D-') && anchorString.endsWith('>')) {
            return new dfsle.DateSignedTab().withAnchor(anchor);
        }
        if (anchorString.startsWith('<In-') && anchorString.endsWith('>')) {
            return new dfsle.InitialHereTab().withAnchor(anchor);
        }
        if (anchorString.startsWith('<ST-') && anchorString.endsWith('>')) {
            dfsle.SignHereTab.StampImage img =
                new dfsle.SignHereTab.StampImage('signature_image', null, null, null, true);
            dfsle.SignHereTab.Stamp stamp =
                new dfsle.SignHereTab.Stamp('stamp', null, 'NameHanko', 'test', 'test', img, null, null);
            return new dfsle.SignHereTab().withStamp(stamp).withAnchor(anchor);
        }
        
        return new dfsle.SignHereTab().withAnchor(anchor);
    }
    
    /**
* @description Normalizes a raw name string for use as a DocuSign named
*              anchor suffix. Trims leading/trailing whitespace and
*              iteratively collapses consecutive double spaces until none
*              remain. Returns an empty string if the input is blank/null.
*
* @param name  The raw string to normalize (e.g., a contact or prospect name).
* @return      A trimmed, single-space-normalized string, or '' if blank.
*/
    
    private static String normalizeAnchorName(String name) {
        if (String.isBlank(name)) return '';
        String n = name.trim();
        while (n.contains('  ')) {
            n = n.replace('  ', ' ');
        }
        return n;
    }
}