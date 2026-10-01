/**
 * @description  : Helper for sending DocuSign envelopes via dfsle toolkit
 *                 Order: SO Customer (PersonAcc or PrimaryContact) -> Joint Owners -> Prospects -> Final custom recipient
 *                 Documents chosen from Files on Documents__c for the SR, Title LIKE '%Transfer Document%'
 * @author       : Krishna Chaitanya
 * @last updated : 2025-12-11
---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 2.0			Ravi Kumar Pasumarthi			 			04 Apr 2026 	Added code to send communication to Org account
* 2.1			Krishna Chaitanya			 			    14 Apr 2026 	Added code to send communication to Org account
* 2.2           Krishna Chaitanya                           24 Apr 2026     Added code to fix PA signature issues
***********************************************************************************************************************/
public with sharing class DocusignSRSendEnvelopeWithAccount {

    /**
     * Sends an envelope for a given ServiceRequest__c in this order:
     *  1) SR.SalesOrder__r.CustomerAccount__r (if PersonAccount) else PrimaryContact__r
     *  2) All JointOwner__c (via JointOwnerAccount__c on SalesOrder)
     *  3) All Prospect_Account__c (non-org)
     *  4) Final explicit recipient (name + email passed in)
     *
     * Documents are taken from:
     *  - Documents__c WHERE Service_Request__c = SR Id AND Name LIKE '%Transfer Document%'
     *  - Files (ContentDocument/ContentVersion) linked to that Documents__c
     */
public class DocusignSendException extends Exception {}
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
            throw new DocusignSendException('Service Request has no related Sales Order.');
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
            system.debug('debug: soRecipientEmail ' + soRecipientEmail); //2.0
            routingOrder++;
            system.debug('debug: routingOrder ' + routingOrder);//2.0
        }

        // 2.a) Joint Owners (JointOwner__c where JointOwnerAccount__c lookup to Account) 
        //    Only Person Accounts with PersonEmail are considered here
        List<JointOwner__c> jointOwners = [
            SELECT Id,
                   JointOwnerAccount__c,
                   JointOwnerAccount__r.Name,
                   JointOwnerAccount__r.IsPersonAccount,
                   JointOwnerAccount__r.PersonEmail
            FROM JointOwner__c
            WHERE SalesOrder__c = :sr.SalesOrder__c
              AND JointOwnerAccount__c != null
              AND JointOwnerAccount__r.IsPersonAccount = true
              AND JointOwnerAccount__r.PersonEmail != null
        ];

        for (JointOwner__c jo : jointOwners) {
            String joName  = jo.JointOwnerAccount__r.Name;
            String joEmail = jo.JointOwnerAccount__r.PersonEmail;

            if (String.isBlank(joEmail)) continue;

            dfsle.Recipient joRec = createRecipientFromSobj(
                joName,
                joEmail,
                joName,       // anchor seed for <S-Name>, <D-Name>, etc.
                routingOrder,
                sr.Id,
                'Signer'
            );
            recipientList.add(joRec);
            system.debug('debug: joEmail1 ' + joEmail); //2.0
            routingOrder++;
            system.debug('debug: routingOrder ' + routingOrder); //2.0
        }
   

         // 3) Prospect_Account__c recipients
        List<Prospect_Account__c> paList = [
            SELECT Id,
                   Name,
                   Is_Primary__c,
                   Account__c,
                   Account__r.Name,
                   Account__r.PersonEmail,
                   Account__r.PersonMobilePhone,
                   Contact__c,
                   Contact__r.Name,
                   Contact__r.Email,
                   Contact__r.MobilePhone
            FROM Prospect_Account__c
            WHERE Service_Request__c = :sr.Id
              AND IsOrgAccount__c = false
            ORDER BY Is_Primary__c DESC, Name ASC
        ];

        if (paList.isEmpty()) {
            throw new DocusignSendException('No Prospect Account found for this Service Request.');
        }

        Boolean hasValidEmail = false;

        for (Prospect_Account__c pa : paList) {
            String recipientName;
            String recipientEmail;
            String anchorSeed;

            if (pa.Account__c != null) {
                recipientName  = pa.Name != null ? pa.Name : null;//2.2
                recipientEmail = pa.Account__r != null ? pa.Account__r.PersonEmail : null;
            } else if (pa.Contact__c != null) {
                recipientName  = pa.Name != null ? pa.Name : null;//2.2
                recipientEmail = pa.Contact__r != null ? pa.Contact__r.Email : null;
            } else {
                throw new DocusignSendException(
                    'Prospect Account has neither Account nor Contact populated. Prospect Id: ' + pa.Id
                );
            }

            anchorSeed = recipientName;

            if (String.isBlank(recipientEmail)) {
                throw new DocusignSendException(
                    'Missing email for Prospect Account: ' + recipientName
                );
            }

            hasValidEmail = true;

            dfsle.Recipient rec = createRecipientFromSobj(
                recipientName,
                recipientEmail,
                anchorSeed,
                routingOrder,
                sr.Id,
                'Signer'
            );

            recipientList.add(rec);
            System.debug('debug: recipientEmail ' + recipientEmail);
            routingOrder++;
        }

        if (!hasValidEmail) {
            throw new DocusignSendException('No valid recipient emails found for Prospect Accounts.');
        }


        // 4) Final internal recipient (name + email you provide)
        if (!String.isBlank(finalRecipientEmail)) {
            system.debug('debug: finalRecipientEmail6: ' + finalRecipientEmail);//2.0
            system.debug('debug: recipientList6: ' + recipientList);//2.0
            recipientList.add(
                dfsle.Recipient.fromSource(finalRecipientName,finalRecipientEmail,null,null,new dfsle.Entity(sr.Id)).withRoutingOrder(routingOrder++).withTabs(new List<dfsle.Tab>{createTagSignHere('\\s20\\'),createTagDateSigned('\\d20\\'),createTagStamp('\\stamp_20\\')}));
        }
       
        // -----------------------
        // Documents from Files on Documents__c
        // -----------------------

        // 1) Find Documents__c for this SR with Name LIKE '%Transfer Document%'
        List<Documents__c> docWrappers = [
            SELECT Id, Name
            FROM Documents__c
            WHERE Service_Request__c = :sr.Id
              AND Name LIKE '%Transfer Document%'
            LIMIT 1
        ];

        if (docWrappers.isEmpty()) {
            throw new DocusignSendException('No Documents__c records found for this SR with Name like "Transfer Document".');
        }

        Set<Id> documentIds = new Set<Id>();
        for (Documents__c d : docWrappers) {
            documentIds.add(d.Id);
        }

        // 2) Get the files linked to those Documents__c
        List<ContentDocumentLink> fileLinks = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :documentIds
        ];

        if (fileLinks.isEmpty()) {
            throw new DocusignSendException('No Docs Found: no files linked to Documents__c.');
        }

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
              AND Title LIKE '%Transfer Document%'
        ];

        if (transferVersions.isEmpty()) {
            throw new DocusignSendException('No Docs Found: no latest ContentVersion with Title like "Transfer Document".');
        }

        // 4) Collect version Ids to pass to DocuSign
        Set<Id> versionIds = new Set<Id>();
        for (ContentVersion cv : transferVersions) {
            versionIds.add(cv.Id);
        }

        // Build & send envelope
        dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(new dfsle.Entity(sr.Id)).withRecipients(recipientList).withDocuments(dfsle.DocumentService.getDocuments(ContentVersion.getSObjectType(),versionIds));

        try {
            envelope = Test.isRunningTest()? null: dfsle.EnvelopeService.sendEnvelope(envelope, true);
        } catch (Exception ex) {
            throw new DocusignSendException('DocuSign send failed: ' + ex.getMessage());
        }

        String docuSignId = Test.isRunningTest()? 'Test': (envelope != null ? String.valueOf(envelope.docuSignId) : null);

        return docuSignId;
    }

    // -----------------------
    // Simple tag anchors (\s20\ etc.)
    // -----------------------
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

    private static dfsle.Tab createTagSignHere(String token) {
        return new dfsle.SignHereTab().withAnchor(simpleTagAnchor(token));
    }

    private static dfsle.Tab createTagDateSigned(String token) {
        return new dfsle.DateSignedTab().withAnchor(simpleTagAnchor(token));
    }
private static dfsle.Tab createTagStamp(String token) {
    dfsle.Tab.Anchor a = simpleTagAnchor(token);

    dfsle.SignHereTab.StampImage img =
        new dfsle.SignHereTab.StampImage('signature_image', null, null, null, true);

    dfsle.SignHereTab.Stamp stamp =
        new dfsle.SignHereTab.Stamp('stamp', null, 'NameHanko', 'test', 'test', img, null, null);

    return new dfsle.SignHereTab().withStamp(stamp).withAnchor(a);
}

    // -----------------------
    // Recipient builders
    // -----------------------
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

    // -----------------------
    // Tab creation for name-based anchors
    // -----------------------
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

    // -----------------------
    // Utility
    // -----------------------
    private static String normalizeAnchorName(String name) {
        if (String.isBlank(name)) return '';
        String n = name.trim();
        while (n.contains('  ')) {
            n = n.replace('  ', ' ');
        }
        return n;
    }
}