/**********************************************************************************************************************
* Name               : OIC_DPGIntegrationHelper
* Description        : This class contains main integration methods for DPG Integration.
* Usage              : Used to create a lead from DPG.
* Created By         : Activemindsit
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Suresh   	                31 03 2025      Initial Draft
* 1.1           Arvind                      02 Jul 2026     Added NumberOfBedrooms__c, Unit__c, Price_in_AED__c
*                                                            mapping on both insert and update paths.

***********************************************************************************************************************/
global class OIC_DPGIntegrationHelper {

    //Utility Method: Sanitizes the phone number by removing non-numeric characters.
    public static String sanitizePhoneNumber(String phoneNumber) {
        phoneNumber = phoneNumber.replaceAll('[^\\d]', '');
        if(String.isNotBlank(phoneNumber)){
            return phoneNumber;            
        }else{
            return null;
        }
    }

    // Utility Method: Sanitizes the Email by checking the email pattern.
    public static String sanitizeEmail(String email) {
        String emailPattern = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
        if (String.isNotBlank(email) && Pattern.matches(emailPattern, email)) {
            return email;
        } else {
            return null;
        }
    }

    public static String normalizeBedrooms(String raw) {
        if (String.isBlank(raw)) return null;
        String val = raw.trim();
        Schema.DescribeFieldResult dfr = Schema.sObjectType.Lead.fields.NumberOfBedrooms__c;
        Set<String> validValues = new Set<String>();
        String firstActive = null;
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) {
                validValues.add(pe.getValue());
                if (firstActive == null) firstActive = pe.getValue();
                if (pe.getValue().equalsIgnoreCase(val)) return pe.getValue();
            }
        }
        if (validValues.isEmpty()) return val;

        List<String> candidates = new List<String>{
            val,
            val + ' Bedroom',
            val + ' Bedrooms',
            val + 'BHK',
            val + ' BHK'
        };
        for (String c : candidates) {
            for (String vv : validValues) {
                if (vv.equalsIgnoreCase(c)) return vv;
            }
        }
        String stripped = val.replaceAll('(?i)(Bedrooms?|BHK|\\s+)', '');
        for (String vv : validValues) {
            if (vv.startsWithIgnoreCase(val) || (String.isNotBlank(stripped) && vv.startsWithIgnoreCase(stripped))) {
                return vv;
            }
        }
        if (dfr.isRestrictedPicklist() && !validValues.contains(val)) {
            return firstActive;
        }
        return val;
    }

    public static OIC_DPGCreateLeadAPI.CreateLeadResponse createLeadDPG(OIC_DPGCreateLeadAPI.CreateLeadRequest createLeadRequest) {
        OIC_DPGCreateLeadAPI.CreateLeadResponse obj_CreateLeadResponse = new OIC_DPGCreateLeadAPI.CreateLeadResponse();
if(createLeadRequest != null){
            List<Lead> leads = new List<Lead>();
            String unitToUse = String.isNotBlank(createLeadRequest.Unit) ? createLeadRequest.Unit : createLeadRequest.UnitId;
            Id validUnitId = null;
            if (String.isNotBlank(unitToUse) && !unitToUse.equalsIgnoreCase('null') && !unitToUse.equalsIgnoreCase('undefined')) {
                try {
                    validUnitId = Id.valueOf(unitToUse.trim());
                } catch (Exception e) {}
            }
            String projToUse = createLeadRequest.Project;
            if (String.isBlank(projToUse)) {
                List<Project__c> projs = [SELECT Name FROM Project__c LIMIT 1];
                if (!projs.isEmpty()) {
                    projToUse = projs[0].Name;
                } else {
                    projToUse = 'Wadeem';
                }
            }
            String fName = String.isNotBlank(createLeadRequest.FirstName) ? createLeadRequest.FirstName : createLeadRequest.LastName;
            Lead newLead = new Lead(
                FirstName = fName,
                LastName = createLeadRequest.LastName,
                Email = createLeadRequest.Email,
                Phone = createLeadRequest.MobilePhone,
                MobilePhone = createLeadRequest.MobilePhone,
                LeadSource = String.isNotBlank(createLeadRequest.LeadSource) ? createLeadRequest.LeadSource : '3DS Interactive',
                Status = 'Lead Qualified',
                LanguagePreference__c = createLeadRequest.LanguagePreference,
                ProjectInterest__c = projToUse,
                InitiationType__c = 'DPG',
                NumberOfBedrooms__c = normalizeBedrooms(createLeadRequest.NumberOfBedrooms),
                Unit__c = validUnitId,
                Price_in_AED__c = createLeadRequest.PriceInAED,
                Click_ID__c = createLeadRequest.clickId,
                UTMCampaign__c = createLeadRequest.UTMCampaign,
                UTMMedium__c = createLeadRequest.UTMMedium,
                UTMSource__c = createLeadRequest.UTMSource,
                UTMURL__c = createLeadRequest.UTMURL,
                External_System_ID__c = createLeadRequest.ExternalSystemID
            );
        String phonePattern = '%' + createLeadRequest.MobilePhone + '%';
        if(String.isNotBlank(createLeadRequest.LeadId)){
            try {
                Id lId = Id.valueOf(createLeadRequest.LeadId.trim());
                leads = [SELECT Id FROM Lead WHERE Id = :lId LIMIT 1];
            } catch (Exception e) {}
        }
        if(leads.isEmpty()){
            if(String.isNotBlank(createLeadRequest.Project)){
                leads = [SELECT Id FROM Lead WHERE 
                                (Email = :createLeadRequest.Email OR Phone LIKE :phonePattern OR MobilePhone LIKE :phonePattern)
                                AND ProjectInterest__c LIKE :createLeadRequest.Project AND Status != 'Qualified' and Status != 'Retired' LIMIT 1];
            } else {
                leads = [SELECT Id FROM Lead WHERE 
                                (Email = :createLeadRequest.Email OR Phone LIKE :phonePattern OR MobilePhone LIKE :phonePattern) 
                                AND Status != 'Qualified' and Status != 'Retired' LIMIT 1];
            }
        }                                            
        
        try{
            if(leads.size() > 0){
                Update new Lead(Id = leads[0].Id, FirstName = fName, LastName = createLeadRequest.LastName, 
                                Email = createLeadRequest.Email, 
                                MobilePhone = createLeadRequest.MobilePhone, LeadSource = createLeadRequest.LeadSource, 
                                LanguagePreference__c = createLeadRequest.LanguagePreference, ProjectInterest__c = projToUse,
                                NumberOfBedrooms__c = normalizeBedrooms(createLeadRequest.NumberOfBedrooms), Unit__c = validUnitId,
                                Price_in_AED__c = createLeadRequest.PriceInAED); 
 obj_CreateLeadResponse.CorrelationId = leads[0].Id;
                 obj_CreateLeadResponse.LeadId = leads[0].Id;
                 obj_CreateLeadResponse.Status = 'Success';
                 obj_CreateLeadResponse.ErrorCode = '';
                 obj_CreateLeadResponse.ErrorMessage = '';
            }else{
                Database.insert(new List<Lead>{newLead}, true);
                obj_CreateLeadResponse.CorrelationId = newLead.Id;
                obj_CreateLeadResponse.LeadId = newLead.Id;
                obj_CreateLeadResponse.Status = 'Success';
                                obj_CreateLeadResponse.ErrorCode = '';
                obj_CreateLeadResponse.ErrorMessage = '';
            }
         }catch (Exception e){
                obj_CreateLeadResponse.CorrelationId = '';
                obj_CreateLeadResponse.LeadId = '';
                obj_CreateLeadResponse.Status = 'Failure';
                obj_CreateLeadResponse.ErrorCode = e.getMessage();
                obj_CreateLeadResponse.ErrorMessage = (e.getCause() != null) ? e.getCause().getMessage() : e.getMessage(); 
                return obj_CreateLeadResponse;
         }
        return obj_CreateLeadResponse;            
      } else{
                obj_CreateLeadResponse.CorrelationId = '';
                        obj_CreateLeadResponse.LeadId = '';
            obj_CreateLeadResponse.Status = 'Failure';
                obj_CreateLeadResponse.ErrorCode = 'Empty records found';
                obj_CreateLeadResponse.ErrorMessage = 'Empty records found';
return obj_CreateLeadResponse;
        }
    }
}