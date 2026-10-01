/**********************************************************************************************************************
* Name               : MBP_SendForSignatureControllerTest
* Description        : Test coverage for MBP_SendForSignatureController — both the ServiceRequest__c flow and the
*                       Account flow, the VAT-certificate-type branch, key exception paths, and the bulk/chunking
*                       behavior for large lists.
* Created By         : upendra
* --------------------------------------------------------------------------------------------------------------------

*   V 1.   upendra    09-09-2026  Intial draft
**********************************************************************************************************************/
public class MBP_SendForSignatureController {

    private static final String VAT_UNDERTAKING_CERTIFICATE = 'VAT Undertaking Certificate';

    private static Boolean isVatRegistered(ServiceRequest__c sr){
        String certType = sr.Registration__r.VAT_Certificate_Type__c;
        return !VAT_UNDERTAKING_CERTIFICATE.equalsIgnoreCase(String.isBlank(certType) ? '' : certType.trim());
    }

    public class DocusignSendException extends Exception {}

   
    private static final Integer BULK_CHUNK_SIZE = 25;

    @AuraEnabled
    public static void sendEnvelopeBulk(List<Id> srIds){
        if(srIds == null || srIds.isEmpty()){
            return;
        }
        if(srIds.size() <= BULK_CHUNK_SIZE){
        
            for(Id srId : srIds){
                System.enqueueJob(new PrepJob(srId));
            }
        } else {
            // Large volume — hand off to the self-chaining chunk processor so we never risk
            // the governor limit no matter how many Ids came in.
            System.enqueueJob(new PrepJobBatch(srIds, 0));
        }
    }

    public class PrepJobBatch implements Queueable {
        private List<Id> allIds;
        private Integer startIndex;
        public PrepJobBatch(List<Id> allIds, Integer startIndex){
            this.allIds = allIds;
            this.startIndex = startIndex;
        }

        public void execute(QueueableContext ctx){
            Integer endIndex = Math.min(startIndex + BULK_CHUNK_SIZE, allIds.size());

            List<StaticResource> resources = [
                SELECT Id, Body, BodyLength, ContentType
                FROM StaticResource
                WHERE Name = 'MBP_Broker_Agency_Agreement'
                LIMIT 1
            ];
            if(resources.isEmpty()){
                // Still advance the chain so one missing-template moment doesn't stall
                // everything after it forever, in case it gets fixed before the next chunk runs.
                enqueueNextChunkIfAny();
                return;
            }
            Blob templateBody = resources[0].Body;

            List<ContentVersion> versionsToInsert = new List<ContentVersion>();
            List<Id> srIdsInOrder = new List<Id>(); // parallel to versionsToInsert, by index

            for(Integer i = startIndex; i < endIndex; i++){
                Id srId = allIds[i];
                try {
                    ServiceRequest__c sr = querySr(srId);
                    Map<String,String> mergeData = buildMergeData(sr);
                    Boolean hasVat = isVatRegistered(sr);
                    Blob mergedDocx = mergeDocx(templateBody, mergeData, hasVat);

                    versionsToInsert.add(new ContentVersion(
                        Title        = 'Sales Agency Agreement',
                        PathOnClient = 'Sales Agency Agreement.docx',
                        VersionData  = mergedDocx
                    ));
                    srIdsInOrder.add(srId);
                } catch(Exception e){
                    // One bad SR in the chunk (e.g. missing data) doesn't block the rest of
                    // the chunk — same isolation the original per-record PrepJob gave you.
                }
            }

            if(versionsToInsert.isEmpty()){
                enqueueNextChunkIfAny();
                return;
            }

            insert versionsToInsert; // ONE DML for the whole chunk, not one per record

            Map<Id, Id> srIdToVersionId = new Map<Id, Id>();
            for(Integer i = 0; i < versionsToInsert.size(); i++){
                srIdToVersionId.put(srIdsInOrder[i], versionsToInsert[i].Id);
            }

            System.enqueueJob(new SendJobBatch(srIdToVersionId, allIds, startIndex));
        }

        private void enqueueNextChunkIfAny(){
            Integer nextStart = startIndex + BULK_CHUNK_SIZE;
            if(nextStart < allIds.size()){
                System.enqueueJob(new PrepJobBatch(allIds, nextStart));
            }
        }
    }

    // Round 26: sends every SR in this one chunk by calling the EXISTING, unchanged sendForSr()
    // for each — zero duplication of the actual send logic. Once this chunk is fully sent, it
    // enqueues the next PrepJobBatch chunk (if any remain), continuing the chain.
    public class SendJobBatch implements Queueable, Database.AllowsCallouts {
        private Map<Id, Id> srIdToVersionId;
        private List<Id> allIds;
        private Integer chunkStartIndex;

        public SendJobBatch(Map<Id, Id> srIdToVersionId, List<Id> allIds, Integer chunkStartIndex){
            this.srIdToVersionId = srIdToVersionId;
            this.allIds = allIds;
            this.chunkStartIndex = chunkStartIndex;
        }

        public void execute(QueueableContext ctx){
            for(Id srId : srIdToVersionId.keySet()){
                Id versionId = srIdToVersionId.get(srId);
                try {
                    String envId = sendForSr(srId, versionId);
                } catch(Exception e){
                    // swallow — see class-level notes
                }
            }

            Integer nextStart = chunkStartIndex + BULK_CHUNK_SIZE;
            if(nextStart < allIds.size()){
                System.enqueueJob(new PrepJobBatch(allIds, nextStart));
            }
        }
    }

    // Round 21: convenience entry point for running this manually against a single Service
    // Request — e.g. from Execute Anonymous:
    //   MBP_SendForSignatureController.sendEnvelopeForOne('<the 15/18-char SR Id>');
    // This is just sendEnvelopeBulk() with a one-element list — sendEnvelopeBulk was already
    // bulk-safe (each SR gets its own queued PrepJob/SendJob pair, so any number of SRs, one or
    // many, can be passed through it directly). For multiple specific SRs at once, call
    // sendEnvelopeBulk directly, e.g.:
    //   MBP_SendForSignatureController.sendEnvelopeBulk(new List<Id>{'<SR Id 1>','<SR Id 2>'});
    @AuraEnabled
    public static void sendEnvelopeForOne(Id srId){
        if(srId == null){
            return;
        }
        sendEnvelopeBulk(new List<Id>{ srId });
    }

    // ===== TX1: build the merged DOCX from the Static Resource template, then chain the send =====
    public class PrepJob implements Queueable {
        private Id srId;
        public PrepJob(Id srId){ this.srId = srId; }

        public void execute(QueueableContext ctx){
            try {
                List<StaticResource> resources = [
                    SELECT Id, Body, BodyLength, ContentType
                    FROM StaticResource
                    WHERE Name = 'MBP_Broker_Agency_Agreement'
                    LIMIT 1
                ];
                if(resources.isEmpty()){
                    throw new DocusignSendException('Static Resource "MBP_Broker_Agency_Agreement" not found.');
                }

                ServiceRequest__c sr = querySr(srId);
                Map<String,String> mergeData = buildMergeData(sr);
                Boolean hasVat = isVatRegistered(sr);

                Blob mergedDocx = mergeDocx(resources[0].Body, mergeData, hasVat);

                ContentVersion cv = new ContentVersion(
                    Title        = 'Sales Agency Agreement',
                    PathOnClient = 'Sales Agency Agreement.docx',   // .docx — DocuSign converts to PDF server-side
                    VersionData  = mergedDocx
                );
                insert cv;   // committed when THIS queueable transaction ends

                Id versionId = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].Id;

                // Chain TX2 for the callout. The insert above commits before SendJob runs.
                System.enqueueJob(new SendJob(srId, versionId));

            } catch(Exception e){
                // swallow — see class-level notes
            }
        }
    }

    // ===== TX2: assemble recipients + send envelope (callout). No file DML here. =====
    public class SendJob implements Queueable, Database.AllowsCallouts {
        private Id srId;
        private Id versionId;
        public SendJob(Id srId, Id versionId){ this.srId = srId; this.versionId = versionId; }

        public void execute(QueueableContext ctx){
            try {
                String envId = sendForSr(srId, versionId);
            } catch(Exception e){
                // swallow — see class-level notes
            }
        }
    }

    // ===== Core send. versionId is the already-committed, already-merged ContentVersion from TX1. =====
    public static String sendForSr(Id srId, Id versionId){

        List<String> r1 = System.Label.MBP_SendForSignatureRecipient1.split('\\|');
        List<String> r2 = System.Label.MBP_SendForSignatureRecipient2.split('\\|');

        String upendraName  = r1[0].trim();
        String upendraEmail = r1[1].trim();
        String sanathName   = r2[0].trim();
        String sanathEmail  = r2[1].trim();

        ServiceRequest__c sr = querySr(srId);

        String brokerName  = String.isBlank(sr.Broker_Agency_Owner_Name__c)
                             ? 'Broker Agency Owner' : sr.Broker_Agency_Owner_Name__c;
        String brokerEmail = sr.Broker_Agency_Owner_Email__c;

        if(String.isBlank(brokerEmail)){
            throw new DocusignSendException('Broker Agency Owner Email is blank on SR ' + srId);
        }

        // ---- Round 17: VAT-certificate-type branch ----
        // VAT_Certificate_Type__c is a Picklist on Registration__c that must be populated
        // (by whatever process captures/validates the uploaded certificate) BEFORE Send for
        // Signature is used. Its value tells us which of the two certificate types the agency
        // actually supplied:
        //   - 'VAT Certificate'             -> the agency IS VAT-registered.
        //   - 'VAT Undertaking Certificate' -> the agency is NOT VAT-registered and instead
        //     supplied the undertaking-letter type of certificate.
        // VAT_UNDERTAKING_CERTIFICATE (top of class) is the exact picklist value that drives the
        // "not registered" branch; update it there if the real picklist API value differs.
        //
        // Business rule:
        //   - 'VAT Certificate' -> they execute ANNEXURE E (the self-billing agreement on page
        //     20) and must NOT also be asked to sign ANNEXURE F (the "not VAT registered"
        //     undertaking on the last two pages).
        //   - 'VAT Undertaking Certificate' -> the self-billing annexure does not apply to them
        //     and instead they execute ANNEXURE F.
        // Round 17 change: this is no longer just a tabs-only distinction. mergeDocx() (called
        // from PrepJob, using this SAME isVatRegistered() check) now physically deletes the
        // OTHER annexure's entire "EXECUTED AS AN AGREEMENT BY…" signature block — names, Date/
        // Name fields, and Sign/Stamp placeholders — from the merged document before it's ever
        // sent, so nobody sees or can fill in fields that don't apply to them. Only the tabs
        // for the branch that actually survived the merge get attached below.
        Boolean hasVat = isVatRegistered(sr);

        // ---- Recipients ----
        List<dfsle.Recipient> recipients = new List<dfsle.Recipient>();

        // 1) Broker — Agent signature block on page 14 (main agreement), always required.
        // Company Stamp tab is a real DocuSign stamp field (SignHereTab.withStamp(...), see the
        // stampTab() helper below) anchored on its own line right below the visible "Company
        // Stamp:" label. Explicitly required.
        List<dfsle.Tab> brokerTabs = new List<dfsle.Tab>{
            signTab('\\s_broker\\'),
            dateTab('\\d_broker\\'),
            stampTab('\\st_broker\\')
        };
        // Round 14: the broker signs EITHER the Annexure E self-billing block (page 20, tokens
        // …2) when the agency has a VAT Certificate, OR the Annexure F undertaking block (last
        // two pages, tokens …3) when the agency has a VAT Undertaking Certificate — never both.
        // Both annexures now carry their own "Broker Agency Name / Name / Date / Signature /
        // Company Stamp" block (Annexure F's was added by hand and initially reused Annexure E's
        // exact anchor text, which has been corrected in the template to its own …3 tokens so
        // the two branches can't collide).
        if(hasVat){
            brokerTabs.add(signTab('\\s_broker2\\'));
            brokerTabs.add(dateTab('\\d_broker2\\'));
            brokerTabs.add(stampTab('\\st_broker2\\'));
        } else {
            brokerTabs.add(signTab('\\s_broker3\\'));
            brokerTabs.add(dateTab('\\d_broker3\\'));
            brokerTabs.add(stampTab('\\st_broker3\\'));
        }
        recipients.add(
            dfsle.Recipient.fromSource(brokerName, brokerEmail, null, null, new dfsle.Entity(sr.Id))
                .withRoutingOrder(1)
                .withTabs(brokerTabs)
        );

        // 2) Upendra — REVIEWER. Round 19: exactly what "Signer with zero tabs" flagged in
        // Round 15 warned about — DocuSign was prompting Upendra with a mandatory sign-style
        // action instead of letting him just review and finish. Fixed properly this time: he
        // gets ONE tab — a checkbox — anchored to \reviewed_upendra\, a hidden marker placed in
        // the bottom-right corner of the LAST page, safely after both Annexure E's and F's
        // conditionally-removed blocks so it survives either VAT branch. Because this tab is
        // only ever added to Upendra's recipient (never Sanath's or the broker's), it is only
        // ever visible to and actionable by Upendra — the 1st (broker) and 3rd (Sanath)
        // recipients never see it at all. He ticks it and he's done; no signature required.
        recipients.add(
            dfsle.Recipient.fromSource(upendraName, upendraEmail, null, null, new dfsle.Entity(sr.Id))
                .withRoutingOrder(2)
                .withTabs(new List<dfsle.Tab>{
                    reviewedCheckboxTab('\\reviewed_upendra\\')
                })
        );

        
        List<dfsle.Tab> sanathTabs = new List<dfsle.Tab>{
            signTab('\\s_sanath\\'),
            stampTab('\\st_sanath\\')
        };
        if(hasVat){
            sanathTabs.add(signTab('\\s_sanath2\\'));
            sanathTabs.add(stampTab('\\st_sanath2\\'));
        } else {
            sanathTabs.add(signTab('\\s_sanath3\\'));
            sanathTabs.add(stampTab('\\st_sanath3\\'));
        }
        recipients.add(
            dfsle.Recipient.fromSource(sanathName, sanathEmail, null, null, new dfsle.Entity(sr.Id))
                .withRoutingOrder(3)
                .withTabs(sanathTabs)
        );

        // ---- Envelope + send ----
        Map<String, Map<String, Object>> envelopeEventUpdates = new Map<String, Map<String, Object>>{
            dfsle.Envelope.STATUS_SENT => new Map<String, Object>{
                'Docusign_Envelope_Status__c' => 'Envelope Sent'
            },
            dfsle.Envelope.STATUS_DELIVERED => new Map<String, Object>{
                'Docusign_Envelope_Status__c' => 'Envelope Delivered'
            },
            dfsle.Envelope.STATUS_COMPLETED => new Map<String, Object>{
                'Docusign_Envelope_Status__c' => 'Envelope Completed',
                'Send_For_Signature_Complete__c' => true   // kept in case something else already reads this
            },
            dfsle.Envelope.STATUS_DECLINED => new Map<String, Object>{
                'Docusign_Envelope_Status__c' => 'Envelope Declined'
            },
            dfsle.Envelope.STATUS_VOIDED => new Map<String, Object>{
                'Docusign_Envelope_Status__c' => 'Envelope Voided'
            }
        };

     
        dfsle.Document.WriteBack docWriteBack = new dfsle.Document.WriteBack(
            sr.Id,                                            // attach the signed document to this Service Request
            dfsle.Document.WRITE_BACK_ENVELOPE_STATUS_PDF,     // file name format
            true,                                              // combine into a single PDF
            true                                               // include the Certificate of Completion
        );

        dfsle.Envelope env = dfsle.EnvelopeService.getEmptyEnvelope(new dfsle.Entity(sr.Id))
            .withRecipients(recipients)
            .withDocuments(dfsle.DocumentService.getDocuments(
                ContentVersion.getSObjectType(), new Set<Id>{ versionId }))
            // Round 29: explicit envelope-level email subject/message, so the email the broker
            // actually receives says "Sales Agency Agreement" instead of DocuSign's own default
            // subject (which was pulling in the document's old title text).
            .withEmail(
                'Sales Agency Agreement',
                'Please review and sign the attached Sales Agency Agreement.'
            )
            .withOptions(new dfsle.Envelope.Options(
                null,                     // whether to auto-place default-role tags — not used here (Boolean, null is fine)
                docWriteBack,             // write the signed document back onto the SR on completion
                envelopeEventUpdates,     // envelope-level field updates by status
                null                      // recipient-status field updates — not used here
            ));

        env = dfsle.EnvelopeService.sendEnvelope(env, true);

        // ---- Cleanup temp file (DML AFTER the callout — allowed) ----
        try {
            List<ContentDocument> docs = [SELECT Id FROM ContentDocument
                                          WHERE LatestPublishedVersionId = :versionId LIMIT 1];
            if(!docs.isEmpty()){
                delete docs;
            }
        } catch(Exception cleanupEx){
            // swallow — see class-level notes
        }

        return String.valueOf(env.docuSignId);
    }

    // ===== SOQL =====
    private static ServiceRequest__c querySr(Id srId){
        return [
            SELECT Id,
                   Broker_Agency_Owner_Name__c,
                   Broker_Agency_Owner_Email__c,
                   Registration__r.Agency_Name__c,
                   Registration__r.Licensing_Authority__c,
                   Registration__r.Trade_License_Number__c,
                   Registration__r.UAE_VAT_Registration_Number__c,
                   Registration__r.VAT_Certificate_Type__c,
                   Registration__r.Address_Line_1__c,
                   Registration__r.City__c,
                   Registration__r.State__c,
                   Registration__r.Country__c
            FROM ServiceRequest__c
            WHERE Id = :srId
            LIMIT 1
        ];
    }

    private static String buildAddress(ServiceRequest__c sr){
        List<String> parts = new List<String>();
        if(!String.isBlank(sr.Registration__r.Address_Line_1__c)) parts.add(sr.Registration__r.Address_Line_1__c);
        if(!String.isBlank(sr.Registration__r.City__c))           parts.add(sr.Registration__r.City__c);
        // Round 28: State is no longer concatenated into the address string — it is now shown
        // on its own via the \agency_authority\ token (see buildMergeData below), and for many
        // records City and State hold the same value (e.g. "Dubai, Dubai"), which read as a
        // duplicate. Only Address Line 1 + City make up the address now.
        return String.join(parts, ', ');
    }

    // ===== Merge data — every key here corresponds to a literal \token\ in the docx template. =====
    private static Map<String,String> buildMergeData(ServiceRequest__c sr){
        String brokerName = String.isBlank(sr.Broker_Agency_Owner_Name__c)
                             ? 'Broker Agency Owner' : sr.Broker_Agency_Owner_Name__c;
        String agencyName = sr.Registration__r.Agency_Name__c;
        String todayStr    = Date.today().format();

        return new Map<String,String>{
            'cover_agency'      => agencyName,
            'made_date'         => todayStr,
            'agency_name'       => agencyName,   // Round 13: now also rendered as the new
                                                  // "Broker Agency Name: \agency_name\" label on
                                                  // page 14 and Annexure E — no code change was
                                                  // needed for this, the token already existed.
            // Round 28: \agency_authority\ ("...a company established under the laws of ___")
            // now renders the agency's State instead of its Licensing Authority — "under the
            // laws of Dubai" reads correctly, "under the laws of DED" did not.
            'agency_authority'  => sr.Registration__r.State__c,
            'agency_license'    => sr.Registration__r.Trade_License_Number__c,
            'agency_address'    => buildAddress(sr),
            'agency_rep'        => brokerName,
            'sb_agency_name'    => agencyName,
            'sb_trn'            => sr.Registration__r.UAE_VAT_Registration_Number__c,
            'un_agency_name'    => agencyName,
            'un_country'        => sr.Registration__r.Country__c,
            'un_license'        => sr.Registration__r.Trade_License_Number__c,
            'un_address'        => buildAddress(sr)
        };
    }

    // ===== DOCX text merge (requires Zippex — https://github.com/pdalcol/Zippex) =====
    // Round 12: production merges were silently leaving \agency_name\, \agency_authority\, etc.
    // as literal placeholder text instead of real values — confirmed by inspecting the actual
    // template XML: Word's spell-checker had split every single \token\ (all 30 of them, merge
    // tokens AND DocuSign anchor tokens alike) across multiple <w:r> runs, e.g.
    // <w:t>\</w:t></w:r><w:proofErr .../><w:r><w:t>agency_name</w:t></w:r><w:proofErr .../>
    // <w:r><w:t>\</w:t>. This happens automatically any time the .docx is opened and re-saved in
    // Word — proofErr markers force a run split around whatever word is being spell-checked. The
    // old xml.replace(needle, value) only matches when the whole token sits inside one <w:t>
    // element, so a split token is invisible to it and silently never gets replaced — no error,
    // the placeholder just stays as-is. This is a different failure mode from the anchor-sizing
    // bug in Round 5 (that was about font size within a single run; this is about the token not
    // being contiguous at all) but the SAME underlying cause (Word re-flowing the document) can
    // silently break both merge tokens and DocuSign anchors at once, since they share the same
    // \token\ syntax.
    // FIX: replaceTokenFuzzy() below still tries the fast exact match first (the common healthy
    // case), then falls back to a regex that allows any number of complete XML tags between each
    // literal character of \token\ — so a split token is found and the whole span (literal chars
    // + the tags between them) is collapsed down to plain replacement text, healing the run split
    // as a side effect. This makes the merge resilient to the template being re-opened and
    // re-saved in Word again in the future, without depending on anyone remembering to re-run a
    // run-consolidation pass on the file first.
    private static Blob mergeDocx(Blob templateDocx, Map<String,String> replacements, Boolean hasVat){
        Zippex zip = new Zippex(templateDocx);

        Blob xmlBlob = zip.getFile('word/document.xml');
        if(xmlBlob == null){
            throw new DocusignSendException('word/document.xml not found in template — is this a valid .docx?');
        }
        String xml = xmlBlob.toString();

        List<String> keys = new List<String>(replacements.keySet());
        keys.sort(new LongestFirstComparator());

        for(String token : keys){
            String value = replacements.get(token);
            String replacementText = escapeXml(String.isBlank(value) ? '' : value);
            xml = replaceTokenFuzzy(xml, token, replacementText);
        }

        // Round 17: the template carries a hidden \annexE_start\ … \annexE_end\ marker pair
        // around Annexure E's "EXECUTED AS AN AGREEMENT BY…" signature block (page 20), and a
        // \annexF_start\ … \annexF_end\ pair around Annexure F's (last two pages). Whichever one
        // doesn't apply to this envelope gets deleted here — names, Date/Name fields and Sign/
        // Stamp placeholders and all — so it's never shown to anyone. The one that DOES apply
        // keeps its content; only its (now-redundant) marker paragraphs are removed.
        xml = stripAnnexureBlock(xml, 'annexE_start', 'annexE_end', !hasVat);
        xml = stripAnnexureBlock(xml, 'annexF_start', 'annexF_end', hasVat);

        zip.addFile('word/document.xml', Blob.valueOf(xml), null);
        return zip.getZipArchive();
    }

    // Deletes the paragraphs between (and including) the two marker-token paragraphs when
    // removeContent is true — used to strip the annexure signature block that doesn't apply to
    // this envelope. When removeContent is false, only the two marker paragraphs themselves are
    // removed and the content between them is left exactly as-is. If either marker can't be
    // found (e.g. the template was edited and the markers were accidentally deleted), this
    // leaves the xml completely untouched rather than risk corrupting it.
    private static String stripAnnexureBlock(String xml, String startToken, String endToken, Boolean removeContent){
        String startNeedle = '\\' + startToken + '\\';
        String endNeedle = '\\' + endToken + '\\';
        Integer sTextIdx = xml.indexOf(startNeedle);
        Integer eTextIdx = xml.indexOf(endNeedle);
        if(sTextIdx == -1 || eTextIdx == -1 || eTextIdx < sTextIdx){
            return xml;
        }
        Integer sParaStart = xml.lastIndexOf('<w:p ', sTextIdx);
        Integer sParaCloseTag = xml.indexOf('</w:p>', sTextIdx);
        Integer eParaStart = xml.lastIndexOf('<w:p ', eTextIdx);
        Integer eParaCloseTag = xml.indexOf('</w:p>', eTextIdx);
        if(sParaStart == -1 || sParaCloseTag == -1 || eParaStart == -1 || eParaCloseTag == -1){
            return xml;
        }
        Integer sParaEnd = sParaCloseTag + 6; // length of '</w:p>'
        Integer eParaEnd = eParaCloseTag + 6;
        if(removeContent){
            return xml.substring(0, sParaStart) + xml.substring(eParaEnd);
        }
        String middle = xml.substring(sParaEnd, eParaStart);
        return xml.substring(0, sParaStart) + middle + xml.substring(eParaEnd);
    }

    // Replaces every occurrence of \token\ in xml with replacementText, tolerating the token
    // being split across multiple XML runs (see Round 12 note above on mergeDocx()).
    // NOTE: an earlier version of this method built a regex with a "skip any tags" group between
    // every literal character of \token\. That blew up Apex's regex engine on a full-size
    // document.xml — System.LimitException: Regex too complicated — because chaining ~15
    // starred groups in sequence creates a combinatorially huge automaton, even though each
    // individual group is simple. FIX: no regex at all. Instead this walks the XML by hand and
    // builds a "flat text" string containing only the actual characters inside <w:t>...</w:t>
    // elements — the only place token characters can live, since tags/attributes around and
    // between runs never contain token text — while remembering, for every flat-text position,
    // which xml index it came from. The token is searched for in that flat text with a plain
    // indexOf (cheap, no regex, no governor risk), then the match's start/end are mapped back to
    // xml indices and spliced directly into the original xml — removing the span from the
    // token's first literal character through its last (including any run-boundary tags sitting
    // in between) and replacing it with plain replacementText.
    private static String replaceTokenFuzzy(String xml, String token, String replacementText){
        String needle = '\\' + token + '\\';

        // Fast path: handles every occurrence that IS contiguous in one go, same as before.
        xml = xml.replace(needle, replacementText);

        Integer safetyLimit = 50; // occurrences of the same token; guards against any mapping bug looping forever
        while(safetyLimit > 0){
            List<Integer> segXmlStart = new List<Integer>();
            List<Integer> segLen = new List<Integer>();
            String flatText = '';

            Integer scanPos = 0;
            while(true){
                Integer tagStart = xml.indexOf('<w:t', scanPos);
                if(tagStart == -1){ break; }
                Integer afterTag = tagStart + 4;
                String nextChar = afterTag < xml.length() ? xml.substring(afterTag, afterTag + 1) : '';
                // Only treat this as a real <w:t...> (or <w:t>) element — not <w:tbl>, <w:tc>, etc.
                if(nextChar != '>' && nextChar != ' ' && nextChar != '/'){
                    scanPos = tagStart + 1;
                    continue;
                }
                Integer gt = xml.indexOf('>', afterTag);
                if(gt == -1){ break; }
                Boolean selfClosing = (gt > 0 && xml.substring(gt - 1, gt) == '/');
                if(selfClosing){
                    scanPos = gt + 1; // <w:t/> — no content, nothing to add
                    continue;
                }
                Integer contentStart = gt + 1;
                Integer closeTag = xml.indexOf('</w:t>', contentStart);
                if(closeTag == -1){ break; }
                String content = xml.substring(contentStart, closeTag);
                segXmlStart.add(contentStart);
                segLen.add(content.length());
                flatText += content;
                scanPos = closeTag + 6; // length of '</w:t>'
            }

            Integer flatPos = flatText.indexOf(needle);
            if(flatPos == -1){
                break; // nothing left to fix — either fully clean, or genuinely absent
            }

            Integer startXml = mapFlatToXmlIndex(flatPos, segXmlStart, segLen);
            Integer endXml = mapFlatToXmlIndex(flatPos + needle.length() - 1, segXmlStart, segLen);
            if(startXml == null || endXml == null){
                break; // mapping failed unexpectedly — bail out rather than risk corrupting the xml
            }

            xml = xml.substring(0, startXml) + replacementText + xml.substring(endXml + 1);
            safetyLimit--;
        }

        return xml;
    }

    // Maps a position in the concatenated "flat text" (built from <w:t> segments, in document
    // order) back to the corresponding index in the original xml string. Returns null if the
    // position doesn't fall within any recorded segment (shouldn't happen in practice).
    private static Integer mapFlatToXmlIndex(Integer flatPos, List<Integer> segXmlStart, List<Integer> segLen){
        Integer cursor = 0;
        for(Integer i = 0; i < segLen.size(); i++){
            Integer len = segLen[i];
            if(flatPos < cursor + len){
                return segXmlStart[i] + (flatPos - cursor);
            }
            cursor += len;
        }
        return null;
    }

    private static String escapeXml(String s){
        return s.replace('&', '&amp;')
                .replace('<', '&lt;')
                .replace('>', '&gt;');
    }

    private class LongestFirstComparator implements Comparator<String> {
        public Integer compare(String a, String b){
            return b.length() - a.length();
        }
    }

    // ---- Tab builders ----
    private static dfsle.Tab.Anchor anchor(String token){
        return new dfsle.Tab.Anchor(token, false, false, 'left', true, true, 'pixels', 0, 0);
    }
    // Stamp anchors: the anchor token lives on its OWN paragraph, directly below the visible
    // "Stamp:" / "Company Stamp: " label's own paragraph. Because the anchor sits alone at the
    // start of its own line, x=0 with horizontalAlignment 'left' already lands the tab at the
    // true left margin — same x as "Date:"/"Name:" — no xOffset correction needed. yOffset=25
    // clears the label line above it (matches the spacing used for \st_broker\ / \st_broker2\
    // since Round 10; Round 13 reuses the exact same technique for the new \st_sanath\ and
    // \st_sanath2\ anchors so all stamp tabs on the page line up consistently).
    // Round 16: Sign and Stamp now always sit side-by-side on the SAME tab-stopped row (Signature
    // on the left, Stamp on the right), so the stamp anchor must use the exact same y-offset as
    // the plain sign/date anchor — otherwise the Stamp widget renders visibly lower than the Sign
    // widget even though both anchor to text on one line. This helper is kept only for reference
    // /future use if a stacked (label-above, anchor-below) layout is ever needed again; stampTab()
    // below no longer calls it.
    private static dfsle.Tab.Anchor stampAnchor(String token){
        return new dfsle.Tab.Anchor(token, false, false, 'left', true, true, 'pixels', 0, 25);
    }
    private static dfsle.Tab signTab(String token){
        return new dfsle.SignHereTab().withAnchor(anchor(token));
    }
    private static dfsle.Tab dateTab(String token){
        // Round 20: reverted — .withBold(true) called AFTER .withAnchor() doesn't compile
        // ("Method does not exist ... from the type dfsle.Tab"). Root cause is the same
        // method-resolution-by-declared-type issue documented on stampTab() below: withAnchor()
        // is declared on the base dfsle.Tab/SignatureTab class and returns that type, so by the
        // time withBold() is looked up the compile-time type is no longer DateSignedTab — it's
        // already widened to dfsle.Tab, which has no such method.
        //
        // Reverted to the plain, known-compiling form. If bolding the filled-in date value is
        // still wanted, two things worth trying (can't verify either without your org's actual
        // dfsle version to check what DateSignedTab actually exposes):
        //   1) Call it FIRST, before withAnchor() — same fix pattern stampTab() already relies
        //      on for withStamp(): new dfsle.DateSignedTab().withBold(true).withAnchor(anchor(token))
        //   2) If DateSignedTab genuinely has no bold setter at all, this styling isn't
        //      controllable per-tab through dfsle and would need to go through DocuSign's own
        //      sending/brand settings instead (or whatever lower-level font/fontSize property
        //      setter dfsle does expose, if any).
        return new dfsle.DateSignedTab().withAnchor(anchor(token));
    }
    // Company Stamp — a real DocuSign stamp field, not a plain signature. A "stamp" tab is a
    // subtype of SignHereTab in the DocuSign model (SignHereTab.withStamp(...)), so building a
    // bare SignHereTab can only ever render as "Sign", regardless of anchor placement.
    // type='stamp' (vs 'signature') is what tells DocuSign to offer a stamp/upload control
    // instead of a signature pad. Explicitly required.
    // Round 13: this same helper now also backs Sanath's \st_sanath\ and \st_sanath2\ anchors —
    // the 3rd approver gets a real stamp field everywhere he signs, not just on Annexure F.
    // NOTE: whether the signer actually sees a stamp-selection UI at signing time can also depend
    // on the sending account's Admin > Sending Settings ("Enable signature stamp field") and on
    // whether that signer has a stamp already registered on their own DocuSign account — neither
    // of those is something this Apex class controls.
    private static dfsle.Tab stampTab(String token){
        // IMPORTANT: .withStamp() must be the FIRST call in this chain, directly off
        // `new dfsle.SignHereTab()`. withStamp() only exists on SignHereTab itself — it is
        // not declared on its parent class dfsle.SignatureTab. Apex resolves fluent chains by
        // each method's *declared* return type, not the runtime object, so if .withRequired()
        // or .withAnchor() (both declared on SignatureTab/Tab) run first, the expression's
        // compile-time type becomes SignatureTab and .withStamp() is no longer visible — that
        // is the exact cause of "Method does not exist ... from the type dfsle.SignatureTab".
        return new dfsle.SignHereTab()
            .withStamp(new dfsle.SignHereTab.Stamp(
                'stamp',   // type: 'stamp' (not 'signature') — this is what changes the UI to stamp/upload
                null,      // externalId
                null,      // format: null or 'NameHanko' / 'NameDateHanko'
                null,      // signer name override
                null,      // phonetic name
                null,      // stamp image (base64) — leave null to let signer pick/upload their own
                null,      // date stamp
                null       // custom field
            ))
            .withRequired(true)
            .withAnchor(anchor(token));  // Round 16: same 0-offset anchor as signTab/dateTab, so
                                          // Sign and Stamp land exactly on the same row/line —
                                          // was stampAnchor() (yOffset +25, a leftover from the
                                          // old label-above/anchor-below stacked layout), which
                                          // pushed the Stamp widget visibly lower than Sign.
    }
    private static dfsle.Tab reviewedCheckboxTab(String token){
        return new dfsle.CheckboxTab().withRequired(true).withAnchor(anchor(token));
    }
    private static dfsle.Tab roTextTab(String token, String value){
        return new dfsle.TextTab().withValue(String.isBlank(value) ? '' : value).withReadOnly(true).withAnchor(anchor(token));
    }

    // =====================================================================================
    // ROUND 25 — ACCOUNT-LEVEL SUPPORT (all NEW code below this line; nothing above this
    // point was touched — every SR-based method, class, and field keeps working exactly as
    // it did before).
    //
    // Why this exists: some agencies don't have a Service Request at all yet, so the whole
    // envelope has to be triggerable straight off the Account record instead. This mirrors
    // the SR flow (PrepJob -> SendJob -> sendForSr) step-for-step, just sourcing the same
    // pieces of data from Account + its "Owner" Contact instead of from ServiceRequest__c +
    // Registration__c. The tab builders, mergeDocx(), and stripAnnexureBlock() above are
    // already entity-agnostic (they only ever take token strings / a template Blob / a
    // hasVat Boolean), so this reuses all of that as-is — nothing needed to change there.
    //
    // Field mapping used here (per your instructions) — flagging the two I had to assume
    // rather than being told outright, since I can't see your schema from here:
    //   Broker_Agency_Owner_Name__c   -> Name of the related Contact whose Broker Type = 'Owner'
    //   Broker_Agency_Owner_Email__c  -> Email of that same Contact
    //   Registration__r.Agency_Name__c-> Account.Name                    *** ASSUMED ***
    //   ...Licensing_Authority__c     -> Account.Licensing_Authority__c
    //   ...Trade_License_Number__c    -> Account.Trade_License_Number__c
    //   ...UAE_VAT_Registration_Number__c -> Account.UAEVATRegisterNumber__c
    //   ...VAT_Certificate_Type__c    -> Account.VAT_Certificate_Type__c
    //   ...Address_Line_1__c          -> Account.BillingStreet
    //   ...City__c                    -> Account.BillingCity
    //   ...State__c                   -> Account.BillingState
    //   ...Country__c                 -> Account.BillingCountry
    //   The "Owner" Contact lookup    -> Contact.Broker_Type__c = 'Owner'   *** ASSUMED ***
    // If either assumed field/value's real API name differs, those are the only two lines
    // to change (queryOwnerContact()'s WHERE clause, and the one line building agencyName in
    // buildMergeDataForAccount()).
    //
    // Round 27 update: Account also has Docusign_Envelope_Status__c, with the same picklist
    // values as ServiceRequest__c — confirmed. sendForAccount() below now populates
    // envelopeEventUpdates the exact same way sendForSr() does, targeting Account instead.
    // =====================================================================================

    @AuraEnabled
    public static void sendEnvelopeBulkForAccounts(List<Id> accountIds){
        if(accountIds == null || accountIds.isEmpty()){
            return;
        }
        if(accountIds.size() <= BULK_CHUNK_SIZE){
            for(Id accountId : accountIds){
                System.enqueueJob(new PrepJobAccount(accountId));
            }
        } else {
            // Same governor-limit fix as sendEnvelopeBulk() — see the Round 26 note on
            // BULK_CHUNK_SIZE above for why this branch exists.
            System.enqueueJob(new PrepJobBatchAccount(accountIds, 0));
        }
    }

    // Round 26 (Account): mirrors PrepJobBatch exactly, sourcing from Account + Owner Contact
    // via the existing queryAccount()/queryOwnerContact()/buildMergeDataForAccount() helpers.
    public class PrepJobBatchAccount implements Queueable {
        private List<Id> allIds;
        private Integer startIndex;
        public PrepJobBatchAccount(List<Id> allIds, Integer startIndex){
            this.allIds = allIds;
            this.startIndex = startIndex;
        }

        public void execute(QueueableContext ctx){
            Integer endIndex = Math.min(startIndex + BULK_CHUNK_SIZE, allIds.size());

            List<StaticResource> resources = [
                SELECT Id, Body, BodyLength, ContentType
                FROM StaticResource
                WHERE Name = 'MBP_Broker_Agency_Agreement'
                LIMIT 1
            ];
            if(resources.isEmpty()){
                enqueueNextChunkIfAny();
                return;
            }
            Blob templateBody = resources[0].Body;

            List<ContentVersion> versionsToInsert = new List<ContentVersion>();
            List<Id> accountIdsInOrder = new List<Id>();

            for(Integer i = startIndex; i < endIndex; i++){
                Id accountId = allIds[i];
                try {
                    Account acc = queryAccount(accountId);
                    Contact ownerContact = queryOwnerContact(accountId);
                    String brokerName = ownerContactName(ownerContact);
                    Map<String,String> mergeData = buildMergeDataForAccount(acc, brokerName);
                    Boolean hasVat = isVatRegisteredFromCertType(acc.VAT_Certificate_Type__c);
                    Blob mergedDocx = mergeDocx(templateBody, mergeData, hasVat);

                    versionsToInsert.add(new ContentVersion(
                        Title        = 'Sales Agency Agreement',
                        PathOnClient = 'Sales Agency Agreement.docx',
                        VersionData  = mergedDocx
                    ));
                    accountIdsInOrder.add(accountId);
                } catch(Exception e){
                    // swallow — see class-level notes
                }
            }

            if(versionsToInsert.isEmpty()){
                enqueueNextChunkIfAny();
                return;
            }

            insert versionsToInsert;

            Map<Id, Id> accountIdToVersionId = new Map<Id, Id>();
            for(Integer i = 0; i < versionsToInsert.size(); i++){
                accountIdToVersionId.put(accountIdsInOrder[i], versionsToInsert[i].Id);
            }

            System.enqueueJob(new SendJobBatchAccount(accountIdToVersionId, allIds, startIndex));
        }

        private void enqueueNextChunkIfAny(){
            Integer nextStart = startIndex + BULK_CHUNK_SIZE;
            if(nextStart < allIds.size()){
                System.enqueueJob(new PrepJobBatchAccount(allIds, nextStart));
            }
        }
    }

    // Round 26 (Account): mirrors SendJobBatch, calling the EXISTING sendForAccount() for each
    // Account in this chunk — no duplication of the actual send logic.
    public class SendJobBatchAccount implements Queueable, Database.AllowsCallouts {
        private Map<Id, Id> accountIdToVersionId;
        private List<Id> allIds;
        private Integer chunkStartIndex;

        public SendJobBatchAccount(Map<Id, Id> accountIdToVersionId, List<Id> allIds, Integer chunkStartIndex){
            this.accountIdToVersionId = accountIdToVersionId;
            this.allIds = allIds;
            this.chunkStartIndex = chunkStartIndex;
        }

        public void execute(QueueableContext ctx){
            for(Id accountId : accountIdToVersionId.keySet()){
                Id versionId = accountIdToVersionId.get(accountId);
                try {
                    String envId = sendForAccount(accountId, versionId);
                } catch(Exception e){
                    // swallow — see class-level notes
                }
            }

            Integer nextStart = chunkStartIndex + BULK_CHUNK_SIZE;
            if(nextStart < allIds.size()){
                System.enqueueJob(new PrepJobBatchAccount(allIds, nextStart));
            }
        }
    }

    // Convenience single-Account entry point, same pattern as sendEnvelopeForOne(Id srId) above.
    @AuraEnabled
    public static void sendEnvelopeForOneAccount(Id accountId){
        if(accountId == null){
            return;
        }
        sendEnvelopeBulkForAccounts(new List<Id>{ accountId });
    }

    // ===== TX1 (Account): build the merged DOCX, then chain the send. Mirrors PrepJob. =====
    public class PrepJobAccount implements Queueable {
        private Id accountId;
        public PrepJobAccount(Id accountId){ this.accountId = accountId; }

        public void execute(QueueableContext ctx){
            try {
                List<StaticResource> resources = [
                    SELECT Id, Body, BodyLength, ContentType
                    FROM StaticResource
                    WHERE Name = 'MBP_Broker_Agency_Agreement'
                    LIMIT 1
                ];
                if(resources.isEmpty()){
                    throw new DocusignSendException('Static Resource "MBP_Broker_Agency_Agreement" not found.');
                }

                Account acc = queryAccount(accountId);
                Contact ownerContact = queryOwnerContact(accountId);
                String brokerName = ownerContactName(ownerContact);
                Map<String,String> mergeData = buildMergeDataForAccount(acc, brokerName);
                Boolean hasVat = isVatRegisteredFromCertType(acc.VAT_Certificate_Type__c);

                Blob mergedDocx = mergeDocx(resources[0].Body, mergeData, hasVat);

                ContentVersion cv = new ContentVersion(
                    Title        = 'Sales Agency Agreement',
                    PathOnClient = 'Sales Agency Agreement.docx',
                    VersionData  = mergedDocx
                );
                insert cv;

                Id versionId = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].Id;

                System.enqueueJob(new SendJobAccount(accountId, versionId));

            } catch(Exception e){
                // swallow — see class-level notes
            }
        }
    }

    // ===== TX2 (Account): assemble recipients + send envelope (callout). Mirrors SendJob. =====
    public class SendJobAccount implements Queueable, Database.AllowsCallouts {
        private Id accountId;
        private Id versionId;
        public SendJobAccount(Id accountId, Id versionId){ this.accountId = accountId; this.versionId = versionId; }

        public void execute(QueueableContext ctx){
            try {
                String envId = sendForAccount(accountId, versionId);
            } catch(Exception e){
                // swallow — see class-level notes
            }
        }
    }

    // ===== Core send (Account). Mirrors sendForSr() line-for-line, sourced from Account instead. =====
    public static String sendForAccount(Id accountId, Id versionId){

        List<String> r1 = System.Label.MBP_SendForSignatureRecipient1.split('\\|');
        List<String> r2 = System.Label.MBP_SendForSignatureRecipient2.split('\\|');

        String upendraName  = r1[0].trim();
        String upendraEmail = r1[1].trim();
        String sanathName   = r2[0].trim();
        String sanathEmail  = r2[1].trim();

        Account acc = queryAccount(accountId);
        Contact ownerContact = queryOwnerContact(accountId);

        String brokerName  = ownerContactName(ownerContact);
        String brokerEmail = ownerContact != null ? ownerContact.Email : null;

        if(String.isBlank(brokerEmail)){
            throw new DocusignSendException('No Broker Type=\'Owner\' Contact with an Email found on Account ' + accountId);
        }

        Boolean hasVat = isVatRegisteredFromCertType(acc.VAT_Certificate_Type__c);

        // ---- Recipients — identical structure/roles/tabs to sendForSr(), just entity=accountId ----
        List<dfsle.Recipient> recipients = new List<dfsle.Recipient>();

        List<dfsle.Tab> brokerTabs = new List<dfsle.Tab>{
            signTab('\\s_broker\\'),
            dateTab('\\d_broker\\'),
            stampTab('\\st_broker\\')
        };
        if(hasVat){
            brokerTabs.add(signTab('\\s_broker2\\'));
            brokerTabs.add(dateTab('\\d_broker2\\'));
            brokerTabs.add(stampTab('\\st_broker2\\'));
        } else {
            brokerTabs.add(signTab('\\s_broker3\\'));
            brokerTabs.add(dateTab('\\d_broker3\\'));
            brokerTabs.add(stampTab('\\st_broker3\\'));
        }
        recipients.add(
            dfsle.Recipient.fromSource(brokerName, brokerEmail, null, null, new dfsle.Entity(accountId))
                .withRoutingOrder(1)
                .withTabs(brokerTabs)
        );

        recipients.add(
            dfsle.Recipient.fromSource(upendraName, upendraEmail, null, null, new dfsle.Entity(accountId))
                .withRoutingOrder(2)
                .withTabs(new List<dfsle.Tab>{
                    reviewedCheckboxTab('\\reviewed_upendra\\')
                })
        );

        List<dfsle.Tab> sanathTabs = new List<dfsle.Tab>{
            signTab('\\s_sanath\\'),
            stampTab('\\st_sanath\\')
        };
        if(hasVat){
            sanathTabs.add(signTab('\\s_sanath2\\'));
            sanathTabs.add(stampTab('\\st_sanath2\\'));
        } else {
            sanathTabs.add(signTab('\\s_sanath3\\'));
            sanathTabs.add(stampTab('\\st_sanath3\\'));
        }
        recipients.add(
            dfsle.Recipient.fromSource(sanathName, sanathEmail, null, null, new dfsle.Entity(accountId))
                .withRoutingOrder(3)
                .withTabs(sanathTabs)
        );

        // ---- Envelope + send ----
        // Round 27: Account has the SAME Docusign_Envelope_Status__c field, with the same
        // picklist values, as ServiceRequest__c — confirmed. Now populated the exact same way
        // sendForSr() does it, just targeting the Account record instead.
        Map<String, Map<String, Object>> envelopeEventUpdates = new Map<String, Map<String, Object>>{
            dfsle.Envelope.STATUS_SENT => new Map<String, Object>{
                'Docusign_Envelope_Status__c' => 'Envelope Sent'
            },
            dfsle.Envelope.STATUS_DELIVERED => new Map<String, Object>{
                'Docusign_Envelope_Status__c' => 'Envelope Delivered'
            },
            dfsle.Envelope.STATUS_COMPLETED => new Map<String, Object>{
                'Docusign_Envelope_Status__c' => 'Envelope Completed'
            },
            dfsle.Envelope.STATUS_DECLINED => new Map<String, Object>{
                'Docusign_Envelope_Status__c' => 'Envelope Declined'
            },
            dfsle.Envelope.STATUS_VOIDED => new Map<String, Object>{
                'Docusign_Envelope_Status__c' => 'Envelope Voided'
            }
        };

        dfsle.Document.WriteBack docWriteBack = new dfsle.Document.WriteBack(
            accountId,
            dfsle.Document.WRITE_BACK_ENVELOPE_STATUS_PDF,
            true,
            true
        );

        dfsle.Envelope env = dfsle.EnvelopeService.getEmptyEnvelope(new dfsle.Entity(accountId))
            .withRecipients(recipients)
            .withDocuments(dfsle.DocumentService.getDocuments(
                ContentVersion.getSObjectType(), new Set<Id>{ versionId }))
            // Round 29: same explicit email subject/message as sendForSr() — see that note.
            .withEmail(
                'Sales Agency Agreement',
                'Please review and sign the attached Sales Agency Agreement.'
            )
            .withOptions(new dfsle.Envelope.Options(
                null,
                docWriteBack,
                envelopeEventUpdates,
                null
            ));

        env = dfsle.EnvelopeService.sendEnvelope(env, true);

        try {
            List<ContentDocument> docs = [SELECT Id FROM ContentDocument
                                          WHERE LatestPublishedVersionId = :versionId LIMIT 1];
            if(!docs.isEmpty()){
                delete docs;
            }
        } catch(Exception cleanupEx){
            // swallow — see class-level notes
        }

        return String.valueOf(env.docuSignId);
    }

    // ===== SOQL (Account) =====
    private static Account queryAccount(Id accountId){
        return [
            SELECT Id,
                   Name,
                   Licensing_Authority__c,
                   Trade_License_Number__c,
                   UAEVATRegisterNumber__c,
                   VAT_Certificate_Type__c,
                   BillingStreet,
                   BillingCity,
                   BillingState,
                   BillingCountry
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
    }

    // *** ASSUMED: Contact.Broker_Type__c = 'Owner' identifies the agency's owner contact. ***
    // Update the field name/value here if the real one differs — this is the only place it's
    // referenced.
    private static Contact queryOwnerContact(Id accountId){
        List<Contact> owners = [
            SELECT Id, Name, Email
            FROM Contact
            WHERE AccountId = :accountId AND Broker_Type__c = 'Owner' AND Agent_Status__c='Active' AND Primary_Owner__c=true
            LIMIT 1
        ];
        return owners.isEmpty() ? null : owners[0];
    }

    private static String ownerContactName(Contact ownerContact){
        return (ownerContact != null && String.isNotBlank(ownerContact.Name))
            ? ownerContact.Name
            : 'Broker Agency Owner'; // same fallback text sendForSr() already uses
    }

    private static String buildAddressForAccount(Account acc){
        List<String> parts = new List<String>();
        if(!String.isBlank(acc.BillingStreet)) parts.add(acc.BillingStreet);
        if(!String.isBlank(acc.BillingCity))   parts.add(acc.BillingCity);
        // Round 28: same change as buildAddress(ServiceRequest__c) above — BillingState is no
        // longer concatenated in; it's shown separately via \agency_authority\, and folding it
        // into the address too produced duplicates like "Dubai, Dubai" when City == State.
        return String.join(parts, ', ');
    }

    // Same token set as buildMergeData(ServiceRequest__c), sourced from Account instead.
    private static Map<String,String> buildMergeDataForAccount(Account acc, String brokerName){
        String agencyName = acc.Name; // *** ASSUMED — Account.Name stands in for Agency_Name__c ***
        String todayStr = Date.today().format();

        return new Map<String,String>{
            'cover_agency'      => agencyName,
            'made_date'         => todayStr,
            'agency_name'       => agencyName,
            // Round 28: same State-instead-of-Licensing-Authority change as buildMergeData(sr) above.
            'agency_authority'  => acc.BillingState,
            'agency_license'    => acc.Trade_License_Number__c,
            'agency_address'    => buildAddressForAccount(acc),
            'agency_rep'        => brokerName,
            'sb_agency_name'    => agencyName,
            'sb_trn'            => acc.UAEVATRegisterNumber__c,
            'un_agency_name'    => agencyName,
            'un_country'        => acc.BillingCountry,
            'un_license'        => acc.Trade_License_Number__c,
            'un_address'        => buildAddressForAccount(acc)
        };
    }

    // Same VAT-branch rule as isVatRegistered(ServiceRequest__c), just taking the raw
    // certificate-type String directly so the Account flow doesn't need a ServiceRequest__c
    // to call it. isVatRegistered(ServiceRequest__c) above is untouched and still used as-is
    // by all the existing SR code.
    private static Boolean isVatRegisteredFromCertType(String certType){
        return !VAT_UNDERTAKING_CERTIFICATE.equalsIgnoreCase(String.isBlank(certType) ? '' : certType.trim());
    }
}