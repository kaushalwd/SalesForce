/**
 * @description  : Helper for sending DocuSign envelopes via dfsle toolkit
 * @author       : Krishna Chaitanya
 * @last updated : 2025-09-08
 */
public with sharing class DocusignSRSendEnvelopStatus {

    public static String sendFromServiceRequest(Id serviceRequestId) {
        String titleLike= '%Unified%';
        ServiceRequest__c sr = [
            SELECT Id, Name
            FROM ServiceRequest__c
            WHERE Id = :serviceRequestId
            LIMIT 1
        ];

        // Build recipients from Prospect_Account__c
        List<dfsle.Recipient> recipientList = new List<dfsle.Recipient>();
        Integer routingOrder = 1;
        for (Prospect_Account__c pa : [
            SELECT Id, Name, Email__c, Is_Primary__c,AccName__c
            FROM Prospect_Account__c
            WHERE Service_Request__c = :sr.Id AND Email__c != NULL AND IsOrgAccount__c=false
            ORDER BY Is_Primary__c DESC, Name ASC
        ]) {
            dfsle.Recipient rec = createRecipientFromSobj(
                pa.AccName__c,
                pa.Email__c,
                pa.Name,     // anchor seed for <Sign - Name> and <Date - Name>
                routingOrder,
                sr.Id,
                'Signer'
            );
            recipientList.add(rec);
            routingOrder++;
        }

        // Collect latest file versions linked to SR
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :sr.Id
        ]) docIds.add(l.ContentDocumentId);

        String soql = 'SELECT Id, Title, VersionData, ContentDocumentId ' +
                      'FROM ContentVersion ' +
                      'WHERE IsLatest = true AND ContentDocumentId IN :docIds';
        if (!String.isBlank(titleLike)) {
            soql += ' AND Title LIKE :titleLike';
        }
        List<ContentVersion> versions = Database.query(soql);

        Set<Id> versionIds = new Set<Id>();
        for (ContentVersion cv : versions) versionIds.add(cv.Id);

        // Build & send envelope (your pattern)
        dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(new dfsle.Entity(sr.Id)).withRecipients(recipientList).withDocuments(dfsle.DocumentService.getDocuments(ContentVersion.getSObjectType(), versionIds));

        try {
            envelope = Test.isRunningTest() ? null : dfsle.EnvelopeService.sendEnvelope(envelope, true);
        } catch (Exception ex) {
            throw new AuraHandledException('DocuSign send failed: ' + ex.getMessage());
        }

        String docuSignId = Test.isRunningTest() ? 'Test' : (envelope != null ? String.valueOf(envelope.docuSignId) : null);
        return docuSignId;
    }

    // -----------------------
    // Recipient builders
    // -----------------------
    public static dfsle.Recipient createRecipientFromSobj(
        String recepientName,
        String recepientEmail,
        String anchorSeed,   // Prospect Name for <Sign - Name>, <Date - Name>
        Integer routingOrder,
        String srId,
        String signerType
    ){
        String truncatedName = String.isBlank(recepientName)
            ? ''
            : (recepientName.length() < 80 ? recepientName : recepientName.substring(0,79));

        String normalized = normalizeAnchorName(anchorSeed);

        // Name-based anchors
        String signAnchor = '<S-' + normalized+'>';
        String dateAnchor = '<D-'+ normalized+'>';

        // Old scheme anchors (still supported)
      //  String sigHolderAnchor   = anchorSeed + 'SignatureHolder';
      //  String dateHolderAnchor  = anchorSeed + 'DateHolder';
        String initHolderAnchor  = '<In-' + normalized+'>';
        String stampHolderAnchor = '<ST-' + normalized+'>';

        dfsle.Tab sigTab   = createEnvTab(signAnchor);
        dfsle.Tab dateTab  = createEnvTab(dateAnchor);
        dfsle.Tab initTab  = createEnvTab(initHolderAnchor);
        dfsle.Tab stampTab = createEnvTab(stampHolderAnchor);

        dfsle.Recipient rec = dfsle.Recipient.fromSource(truncatedName, recepientEmail, null, null, new dfsle.Entity(srId)).withTabs(new List<dfsle.Tab>{ sigTab, dateTab, initTab, stampTab }).withRoutingOrder(routingOrder);

        return rec;
    }

    // -----------------------
    // Tab creation
    // -----------------------
    public static dfsle.Tab createEnvTab(String anchorString) {
        dfsle.Tab.Anchor anchor = new dfsle.Tab.Anchor(
            anchorString,
            false,  // no whitespace inside token
            false,  // case-insensitive
            'right',
            true,   // ignore if not present
            true,   // must match entirety
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
        if (anchorString.startsWith('ST-') && anchorString.endsWith('>')) {
            dfsle.SignHereTab.StampImage img = new dfsle.SignHereTab.StampImage('signature_image', null, null, null, true);
            dfsle.SignHereTab.Stamp stamp = new dfsle.SignHereTab.Stamp('stamp', null, 'NameHanko', 'test', 'test', img, null, null);
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
        while (n.contains('  ')) n = n.replace('  ', ' ');
        return n;
    }
}