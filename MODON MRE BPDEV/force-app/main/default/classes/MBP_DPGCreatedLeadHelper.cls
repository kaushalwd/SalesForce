/**********************************************************************************************************************
* Name               : MBP_DPGCreatedLeadHelper
* Description        : Helper class for MBP DPG Lead Integration. Bridges legacy callers to the standardized
*                      MBP_DPGCreateLeadAPI / OIC_RequestContext / OIC_RestResponse engine.
* Usage              : Used by DPG integration callers.
* Created By         : Activemindsit
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Suresh                      31 03 2025      Initial Draft
* 1.1           upendra                     Updated         Added Broker lead handling based on logged in
*                                                             community user's Profile & Contact broker type.
* 1.2           upendra                     Updated         Broker and non-broker leads are now matched/updated
*                                                             separately so they never mix or overwrite each other's
*                                                             Broker fields.
* 1.3           Arvind                      02 Jul 2026     Added NumberOfBedrooms__c, Unit__c, Price_in_AED__c
*                                                             mapping on both insert and update paths.
* 1.4           Arvind                      02 Jul 2026     Added full individual/organization field set and
*                                                             immediate Lead conversion (Account match-or-create +
*                                                             Database.convertLead) after insert or match/update.
* 2.0           pprajapati@horizontal.com   19 Aug 2026     Delegated to MBP_DPGCreateLeadAPI and OIC_RequestContext.
* 2.1           pprajapati@horizontal.com   14 Sep 2026     Decoupled from OIC_RequestContext; routed sanitization and broker context directly to MBP_DPGCreateLeadAPI for standalone PROD deployment.
***********************************************************************************************************************/
global class MBP_DPGCreatedLeadHelper {

    public static String sanitizePhoneNumber(String phoneNumber) {
        return MBP_DPGCreateLeadAPI.sanitizePhoneNumber(phoneNumber);
    }

    public static String sanitizeEmail(String email) {
        return MBP_DPGCreateLeadAPI.sanitizeEmail(email);
    }

    public static Date parseDate(String dateString) {
        return MBP_DPGCreateLeadAPI.parseDate(dateString);
    }

    public static Contact getBrokerContactContext() {
        return MBP_DPGCreateLeadAPI.getBrokerContactContext();
    }

    /**
     * Legacy entry point returning CreateLeadResponse DTO for backward compatibility.
     */
    global static MBP_DPGCreateLeadAPI.CreateLeadResponse createLeadDPG(MBP_DPGCreateLeadAPI.CreateLeadRequest createLeadRequest) {
        MBP_DPGCreateLeadAPI.CreateLeadResponse obj_CreateLeadResponse = new MBP_DPGCreateLeadAPI.CreateLeadResponse();

        if (createLeadRequest == null) {
            obj_CreateLeadResponse.CorrelationId = '';
            obj_CreateLeadResponse.LeadId = '';
            obj_CreateLeadResponse.Status = 'Failure';
            obj_CreateLeadResponse.ErrorCode = 'Empty records found';
            obj_CreateLeadResponse.ErrorMessage = 'Empty records found';
            return obj_CreateLeadResponse;
        }

        try {
            OIC_RestResponse res = MBP_DPGCreateLeadAPI.processLead(createLeadRequest);
            if (res.isSuccess()) {
                obj_CreateLeadResponse.Status = 'Success';
                obj_CreateLeadResponse.LeadId = (String) res.get('LeadId');
                obj_CreateLeadResponse.CorrelationId = (String) res.get('CorrelationId');
                obj_CreateLeadResponse.ErrorCode = '';
                obj_CreateLeadResponse.ErrorMessage = '';
            } else {
                obj_CreateLeadResponse.Status = 'Failure';
                obj_CreateLeadResponse.ErrorCode = res.getErrorCode();
                obj_CreateLeadResponse.ErrorMessage = res.getErrorMessage();
                obj_CreateLeadResponse.LeadId = '';
                obj_CreateLeadResponse.CorrelationId = '';
            }
        } catch (Exception e) {
            obj_CreateLeadResponse.Status = 'Failure';
            obj_CreateLeadResponse.ErrorCode = e.getMessage();
            obj_CreateLeadResponse.ErrorMessage = (e.getCause() != null) ? e.getCause().getMessage() : e.getMessage();
            obj_CreateLeadResponse.LeadId = '';
            obj_CreateLeadResponse.CorrelationId = '';
        }

        return obj_CreateLeadResponse;
    }
}