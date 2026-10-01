/**********************************************************************************************************************
* Name               : OIC_EOIConfigurationDetailsAPI                                                        
* Description        : This class is used to fetch the EOI configuration details.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                29 05 2026      Initial Draft       
* 1.1           pprajapati@horizontal.com   02 Sep 2026     Added Amount__c (EOIAmount and EOI_Amount_AED) and project/phase filtering
* 1.2           Jay Patel                   21 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL
***********************************************************************************************************************/
@RestResource(urlMapping='/EOIConfigurationAPI/*')
global with sharing class OIC_EOIConfigurationDetailsAPI {

    @HttpGet
    global static void fetchEOIConfigurationDetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        try {
            List<EoiRanges> lst_EOIDetails = new List<EoiRanges>();
            Map<String, String> params = (req != null && req.params != null) ? req.params : new Map<String, String>();
            String projectId = params.get('projectId');
            String phaseId   = params.get('phaseId');

            String query = 'SELECT Id, Applicable_for_Broker__c, Name, UnitTypologyMRE__c, No_of_Bedrooms__c, '
                + 'Phase__c, Phase__r.Name, Project__c, Project__r.Name, Unit_Type__c, Amount__c '
                + 'FROM EOI_Range__c WHERE Is_Active__c = true';

            Map<String, Object> binds = new Map<String, Object>();
            if (String.isNotBlank(projectId)) {
                query += ' AND Project__c = :projectId';
                binds.put('projectId', projectId.trim());
            }
            if (String.isNotBlank(phaseId)) {
                query += ' AND Phase__c = :phaseId';
                binds.put('phaseId', phaseId.trim());
            }
            query += ' ORDER BY Project__r.Name, Phase__r.Name, Unit_Type__c, No_of_Bedrooms__c';

            //1.2 MCR-73: Enforce CRUD/FLS via USER_MODE on EOI_Range__c query
            List<EOI_Range__c> lst_EOI = Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);
            for(EOI_Range__c obj_EOI : lst_EOI){
                EoiRanges obj_EoiRange = new EoiRanges();
                obj_EoiRange.EOIRangeId = obj_EOI.Id;
                obj_EoiRange.Name = obj_EOI.Name;
                obj_EoiRange.ApplicableForBroker = obj_EOI.Applicable_for_Broker__c;
                obj_EoiRange.UnitTypologyMRE = obj_EOI.UnitTypologyMRE__c;
                obj_EoiRange.NumberOfBedrooms = obj_EOI.No_of_Bedrooms__c;
                obj_EoiRange.UnitType = obj_EOI.Unit_Type__c;
                obj_EoiRange.Phase = obj_EOI.Phase__r != null ? obj_EOI.Phase__r.Name : null;
                obj_EoiRange.PhaseId = obj_EOI.Phase__c;
                obj_EoiRange.Project = obj_EOI.Project__r != null ? obj_EOI.Project__r.Name : null;
                obj_EoiRange.ProjectId = obj_EOI.Project__c;
                obj_EoiRange.EOIAmount = obj_EOI.Amount__c;
                obj_EoiRange.EOI_Amount_AED = obj_EOI.Amount__c;
                lst_EOIDetails.add(obj_EoiRange);
            }
            APIResponse response = new APIResponse('success', requestId, lst_EOIDetails, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            
        } catch (Exception ex) { // Return generic server error response
            LoggerService.save(LoggerService.createApexLog(ex, 'OIC_EOIConfigurationDetailsAPI', 'OIC_EOIConfigurationDetailsAPI', 'fetchEOIConfigurationDetails'));
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200); 
        }
    }
    
    public class EoiRanges {
        public String EOIRangeId;
        public String Name;
        public Boolean ApplicableForBroker;
        public String UnitTypologyMRE;
        public String NumberOfBedrooms;
        public String UnitType;
        public String Phase;
        public String PhaseId;
        public String Project;
        public String ProjectId;
        public Decimal EOIAmount;
        public Decimal EOI_Amount_AED;
    } 
}