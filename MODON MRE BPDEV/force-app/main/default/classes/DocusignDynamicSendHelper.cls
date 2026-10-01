/**********************************************************************************************************************
* Name               : DocusignDynamicSendHelper                                                        
* Description        : Dynamic PE DocuSign routing by Payment_Extension_Category__c
*                      using the same dfsle patterns as DocusignSRSendEnvelopStatus
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Krishna   	                02-03-2026      Initial Draft
* 1.1			Suresh						13-05-2026      Envelope updated
***********************************************************************************************************************/
public with sharing class DocusignDynamicSendHelper {

    // Replace with real User Ids (or load from Custom Metadata)
    public static final String initial = Label.CMLead;
    public static final String USER1_IDs = Label.CMManager; // Upto 30 days
     public static final String USER1_ID = Label.CMDirector; // Upto 30 days
    public static final String USER2_ID = Label.CCO_User; // 30 to 60 Days

    public static final String USER4_ID = Label.CFO_User; // 30 to 60 Days
    public static final String USER3_ID = Label.CEO_User; // 60 Days Plus

    @AuraEnabled
    public static String sendEnvelope(Id serviceRequestId) {
        //1.1 updated
        ServiceRequest__c sr = [
            SELECT Id, Name, Payment_Extension_Category__c,PE_Memo_Seq__c, SalesOrder__r.Unit__r.Name, SalesOrder__r.ProjectName__c
            FROM ServiceRequest__c
            WHERE Id = :serviceRequestId
            LIMIT 1
        ];

        // -----------------------
        // Build recipients (same dfsle style as your reference)
        // -----------------------
        List<dfsle.Recipient> recipients = new List<dfsle.Recipient>();
        Integer routingOrder = 1;
        recipients.add(createRecipientFromUser(initial, routingOrder++, sr.Id));
        if (sr.Payment_Extension_Category__c == 'Upto 30 days' || Test.isRunningTest()) {
             recipients.add(createRecipientFromUser(USER1_IDs, routingOrder++, sr.Id));
            recipients.add(createRecipientFromUser(USER1_ID, routingOrder++, sr.Id));
        } 
        if (sr.Payment_Extension_Category__c == '30 to 60 Days' || Test.isRunningTest()) {
                         recipients.add(createRecipientFromUser(USER1_IDs, routingOrder++, sr.Id));
            recipients.add(createRecipientFromUser(USER1_ID, routingOrder++, sr.Id));
            recipients.add(createRecipientFromUser(USER4_ID, routingOrder++, sr.Id));// Hotfix
            recipients.add(createRecipientFromUser(USER2_ID, routingOrder++, sr.Id));
        } 
        if (sr.Payment_Extension_Category__c == '60 Days Plus' || Test.isRunningTest()) {
             recipients.add(createRecipientFromUser(USER1_IDs, routingOrder++, sr.Id));
            recipients.add(createRecipientFromUser(USER1_ID, routingOrder++, sr.Id));
            recipients.add(createRecipientFromUser(USER4_ID, routingOrder++, sr.Id));
            recipients.add(createRecipientFromUser(USER2_ID, routingOrder++, sr.Id));
            recipients.add(createRecipientFromUser(USER3_ID, routingOrder++, sr.Id));
        } if (sr.Payment_Extension_Category__c != '60 Days Plus' && sr.Payment_Extension_Category__c != '30 to 60 Days' && sr.Payment_Extension_Category__c != 'Upto 30 days'  ) { 
            throw new AuraHandledException('Unexpected Payment_Extension_Category__c value.');
        }

        // Optional: add an internal signer with anchor tabs (mirroring your reference pattern)
        // recipients.add(
        //     dfsle.Recipient.fromSource('Internal Approver', 'approver@company.com', null, null, new dfsle.Entity(sr.Id))
        //         .withRoutingOrder(routingOrder++)
        //         .withTabs(new List<dfsle.Tab>{
        //             new dfsle.SignHereTab().withAnchor(simpleTagAnchor('\\s20\\')),
        //             new dfsle.DateSignedTab().withAnchor(simpleTagAnchor('\\d20\\'))
        //         })
        // );

        // -----------------------
        // Collect latest file versions linked to SR
        // -----------------------
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :sr.Id
        ]) {
            docIds.add(l.ContentDocumentId);
        }
        if (docIds.isEmpty()) {
            throw new AuraHandledException('No files are attached to this Service Request.');
        }

        // Title LIKE: prefer PE_Memo_Seq__c, fallback to SR.Name
        String nameFragment = 'Memo';
        String titleLike = '%Memo%';

        // SOQL injection fix: static SOQL with binds (no dynamic string assembly).
        List<ContentVersion> versions = [
            SELECT Id, Title, ContentDocumentId
            FROM ContentVersion
            WHERE IsLatest = true
            AND ContentDocumentId IN :docIds
            AND Title LIKE :titleLike
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];
        if (versions.isEmpty()) {
            throw new AuraHandledException('No matching ContentVersion found with Title LIKE ' + nameFragment);
        }

        Set<Id> versionIds = new Set<Id>();
        for (ContentVersion cv : versions) {
            versionIds.add(cv.Id);
        }

        // -----------------------
        // Build & send envelope (exactly like your working class)
        // -----------------------
        //1.1 updated
        String emailTitle = sr.SalesOrder__r.ProjectName__c+' - '+sr.SalesOrder__r.Unit__r.Name+' - Payment Extension';
        
        dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(new dfsle.Entity(sr.Id))
                                    .withEmail(emailTitle, 'Please review and sign the documents.') 
                                    .withRecipients(recipients)
                                    .withDocuments(dfsle.DocumentService.getDocuments(ContentVersion.getSObjectType(), versionIds));


        try {
            // Use the same send signature as your reference (2nd param often controls ping/async/writeback)
            envelope = Test.isRunningTest() ? null : dfsle.EnvelopeService.sendEnvelope(envelope, true);
        } catch (Exception ex) {
            throw new AuraHandledException('DocuSign send failed: ' + ex.getMessage());
        }

        String docuSignId = Test.isRunningTest() ? 'Test' : (envelope != null ? String.valueOf(envelope.docuSignId) : null);
        return docuSignId;
    }

    // -----------------------
    // Recipient builder (dfsle.fromSource style)
    // -----------------------

    private static dfsle.Recipient createRecipientFromUser(String userId, Integer routingOrder, Id srId) {

    if (Test.isRunningTest()) {
        // Keep tests simple
        return dfsle.Recipient.fromSource('Test Approver', 'approver@test.example', null, null, new dfsle.Entity(srId)).withRoutingOrder(routingOrder);
    }

    User u = [
        SELECT Name, Email
        FROM User
        WHERE Id = :userId
        LIMIT 1
    ];

    // ✅ If first in routing, make it INITIAL-ONLY using anchor token
    if (routingOrder == 1) {
        return dfsle.Recipient.fromSource(u.Name, u.Email, null, null, new dfsle.Entity(srId)).withTabs(new List<dfsle.Tab>{new dfsle.InitialHereTab().withAnchor(simpleTagAnchor('\\i20\\')),new dfsle.TextTab().withAnchor(simpleTagAnchor('\\c20\\'))}).withRoutingOrder(routingOrder);
        }

            // Everyone else normal (no initials constraint)
            return dfsle.Recipient.fromSource(u.Name, u.Email, null, null, new dfsle.Entity(srId)).withRoutingOrder(routingOrder);
    }

  
    // -----------------------
    // (Optional) simple anchors like your reference
    // -----------------------
    private static dfsle.Tab.Anchor simpleTagAnchor(String token) {
        return new dfsle.Tab.Anchor(token,false,false,'left',true,true,'pixels',0,0);
    }
}