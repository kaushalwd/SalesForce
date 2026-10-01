/**********************************************************************************************************************
* Name               : EoiRegistrationPromotionHandler
* Description        : Back-office promotion handler for EOI_Public_Registration__c. Invoked from the
*                      EoiPublicRegistration_AutoPromote record-triggered flow (AsyncAfterCommit) to convert verified
*                      public submissions into the existing Lead -> Account -> Opportunity -> Expressionofinterest__c
*                      chain via EoiHomeJourneyController. Groups registrations by BatchId__c so multi-unit submissions
*                      share a single Opportunity, and writes the resulting status / matched records back to each row.
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    20 May 2026     Initial version
* 1.1           Prateek Bansal                    22 May 2026     UTM-aware LeadSource / SubSource derivation; UTM fields copied to Lead
**********************************************************************************************************************/
public without sharing class EoiRegistrationPromotionHandler {

    @InvocableMethod(label='Promote EOI Public Registration')
    public static void promoteFromFlow(List<Id> recordIds) {
        Set<String> batchIds = new Set<String>();
        for (EOI_Public_Registration__c r : [SELECT BatchId__c FROM EOI_Public_Registration__c WHERE Id IN :recordIds]) {
            if (String.isNotBlank(r.BatchId__c)) batchIds.add(r.BatchId__c);
        }
        if (batchIds.isEmpty()) return;

        Map<String, List<EOI_Public_Registration__c>> byBatch = new Map<String, List<EOI_Public_Registration__c>>();
        for (EOI_Public_Registration__c r : [
            SELECT Id, Name, Source__c, Visitor__c, BatchId__c, CustomerType__c, FirstName__c, LastName__c, Email__c,
                Mobile__c, Phone__c, ResidentStatus__c, EmiratesId__c, PassportNumber__c,
                CompanyName__c, TradeLicenseNumber__c, RegisteredEmail__c, RegisteredPhone__c,
                AuthorizedFirstName__c, AuthorizedLastName__c, AuthorizedEmail__c, AuthorizedPhone__c,
                Project__c, Project__r.Name, Phase__c, EOI_Range__c, UnitType__c, Bedrooms__c, UnitTypologyMRE__c,
                Amount__c, PaymentTypePreference__c,
                UTMSource__c, UTMCampaign__c, UTMMedium__c, UTMURL__c, AdName__c, AdSetName__c, UTMSubSource__c
            FROM EOI_Public_Registration__c
            WHERE BatchId__c IN :batchIds AND Status__c = 'Verified'
        ]) {
            if (!byBatch.containsKey(r.BatchId__c)) byBatch.put(r.BatchId__c, new List<EOI_Public_Registration__c>());
            byBatch.get(r.BatchId__c).add(r);
        }

        List<EOI_Public_Registration__c> toUpdate = new List<EOI_Public_Registration__c>();
        for (List<EOI_Public_Registration__c> batch : byBatch.values()) {
            promoteBatch(batch, toUpdate);
        }
        if (!toUpdate.isEmpty()) update toUpdate;
        EoiJourneyLog.flush();
    }

    private static void promoteBatch(List<EOI_Public_Registration__c> batch, List<EOI_Public_Registration__c> toUpdate) {
        try {
            EOI_Public_Registration__c first = batch[0];
            EoiHomeJourneyController.CustomerRequest req = buildCustomerRequest(first);
            EoiHomeJourneyController.CustomerSearchResult search = EoiHomeJourneyController.searchCustomer(req);
            if (search != null && search.selected != null) {
                req.accountId = search.selected.accountId;
                req.contactId = search.selected.contactId;
                req.leadId = search.selected.leadId;
            }
            EoiHomeJourneyController.OpportunityResult opp = EoiHomeJourneyController.prepareOpportunity(req);

            Map<String, Schema.SObjectField> fmap = Schema.getGlobalDescribe().get('Expressionofinterest__c').getDescribe().fields.getMap();
            List<SObject> eois = new List<SObject>();
            for (EOI_Public_Registration__c row : batch) {
                SObject eoi = Schema.getGlobalDescribe().get('Expressionofinterest__c').newSObject();
                Map<String, Object> vals = new Map<String, Object>{
                    'Opportunity__c' => opp.opportunityId, 'Project__c' => row.Project__c, 'Phase__c' => row.Phase__c,
                    'UnitType__c' => row.UnitType__c, 'NumberofBedrooms__c' => row.Bedrooms__c,
                    'UnitTypologyMRE__c' => row.UnitTypologyMRE__c, 'Number_of_Units__c' => 1,
                    'EOI_Range__c' => row.EOI_Range__c, 'EOI_Amount_AED__c' => row.Amount__c,
                    'Account__c' => opp.accountId, 'Contact__c' => opp.contactId,
                    'Payment_Type__c' => row.PaymentTypePreference__c
                };
                for (String f : vals.keySet()) {
                    if (vals.get(f) != null && fmap.containsKey(f.toLowerCase())) eoi.put(f, vals.get(f));
                }
                eois.add(eoi);
            }
            insert eois;

            List<Id> eoiIds = new List<Id>();
            for (SObject e : eois) eoiIds.add((Id) e.get('Id'));
            List<String> eoiNames = new List<String>();
            for (SObject e : Database.query('SELECT Name FROM Expressionofinterest__c WHERE Id IN :eoiIds')) eoiNames.add((String) e.get('Name'));

            Map<Id, EOI_Site_Visitor__c> visitors = new Map<Id, EOI_Site_Visitor__c>();
            for (Integer i = 0; i < batch.size(); i++) {
                EOI_Public_Registration__c row = batch[i];
                row.Status__c = 'Promoted';
                row.PromotedEOI__c = (Id) eois[i].get('Id');
                row.PromotedAt__c = System.now();
                row.MatchedAccount__c = opp.accountId;
                row.MatchedContact__c = opp.contactId;
                row.MatchedLead__c = opp.leadId;
                toUpdate.add(row);
                if (row.Visitor__c != null) {
                    visitors.put(row.Visitor__c, new EOI_Site_Visitor__c(Id = row.Visitor__c,
                        Matched_Account__c = opp.accountId, Matched_Contact__c = opp.contactId, Matched_Lead__c = opp.leadId));
                }
            }
            if (!visitors.isEmpty()) {
                update visitors.values();
                EOI_Public_Registration__c first0 = batch[0];
                EoiJourneyLog.queue(first0.Visitor__c, first0.Id, first0.Source__c, EoiJourneyLog.VISIT_CLOSED,
                    first0.Name + ' · Opportunity ' + opp.opportunityId + ' · ' + String.join(eoiNames, ', '));
                EoiSiteVisitorService.appendTrail(first0.Visitor__c, 'Visit closed  ' + String.join(eoiNames, ', '));
            }
        } catch (Exception ex) {
            for (EOI_Public_Registration__c row : batch) {
                row.Status__c = 'PromoteFailed';
                row.Promotion_Error__c = ex.getMessage() + '\n' + ex.getStackTraceString();
                toUpdate.add(row);
            }
            if (batch[0].Visitor__c != null) {
                EoiJourneyLog.queue(batch[0].Visitor__c, batch[0].Id, batch[0].Source__c, EoiJourneyLog.PROMOTION_FAILED,
                    batch[0].Name + ' · ' + ex.getMessage());
            }
        }
    }

    private static EoiHomeJourneyController.CustomerRequest buildCustomerRequest(EOI_Public_Registration__c r) {
        EoiHomeJourneyController.CustomerRequest req = new EoiHomeJourneyController.CustomerRequest();
        req.customerType = r.CustomerType__c;
        req.firstName = r.FirstName__c;
        req.lastName = r.LastName__c;
        req.email = r.Email__c;
        req.phone = String.isNotBlank(r.Mobile__c) ? r.Mobile__c : r.Phone__c;
        req.residentStatus = r.ResidentStatus__c;
        req.emiratesId = r.EmiratesId__c;
        req.passportNumber = r.PassportNumber__c;
        req.companyName = r.CompanyName__c;
        req.tradeLicenseNumber = r.TradeLicenseNumber__c;
        req.registeredEmail = r.RegisteredEmail__c;
        req.registeredPhone = r.RegisteredPhone__c;
        req.authorizedFirstName = r.AuthorizedFirstName__c;
        req.authorizedLastName = r.AuthorizedLastName__c;
        req.authorizedEmail = r.AuthorizedEmail__c;
        req.authorizedPhone = r.AuthorizedPhone__c;
        req.projectId = r.Project__c;
        req.projectInterest = r.Project__r.Name;
        req.skipFrontendValidation = true;
        Boolean hasUtm = String.isNotBlank(r.UTMSource__c);
        if (hasUtm) {
            req.leadSource = 'Social Media';
            req.subSource = String.isNotBlank(r.UTMSubSource__c) ? r.UTMSubSource__c : null;
        } else {
            req.leadSource = 'Sales Launch';
            req.subSource = 'EOI Emailer';
        }
        req.utmSource = r.UTMSource__c;
        req.utmCampaign = r.UTMCampaign__c;
        req.utmMedium = r.UTMMedium__c;
        req.utmUrl = r.UTMURL__c;
        req.adName = r.AdName__c;
        req.adSetName = r.AdSetName__c;
        return req;
    }
}