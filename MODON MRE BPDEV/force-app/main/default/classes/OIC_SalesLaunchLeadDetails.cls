/**********************************************************************************************************************
* Name               : OIC_SalesLaunchLeadDetails                                                        
* Description        : This class is used to fetch leads for sales launch.
* Usage              : Used to Integrate with Evento.
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                18 06 2025      Initial Draft       
* 1.1           Suresh   	                15 12 2025      Customer Type added
* 1.2           Suresh   	                11 03 2026      New Fields are added for Tara Saleslaunch
* 1.3           Jay Patel                   21 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/saleslaunch/leaddetails/*')
global with sharing class OIC_SalesLaunchLeadDetails {

    @HttpGet
    global static void getLeadDetails() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        LeadDetailsResponse obj_LeadDetailsResponse = new LeadDetailsResponse();
        restRequest.addHeader('Content-Type', 'application/json');
        try {
        String campaignId = restRequest.params.get('CampaignId'); 
        String modifiedDateTime = restRequest.params.get('ModifiedDateTime');
        Datetime cutoff = (Datetime)JSON.deserialize('"' + modifiedDateTime + '"', Datetime.class);
        System.debug('OIC_SalesLaunchLeadDetails >>>> getLeadDetails >> '+campaignId);
        if(!String.isBlank(campaignId)){
            List<LeadRecord> lst_LeadRecord = new List<LeadRecord>();
            List<CampaignMember> lst_CampaignMember = new List<CampaignMember>();
            //1.2 added
            if(cutoff != null){
                //1.3 MCR-73: Enforce CRUD/FLS via USER_MODE on CampaignMember query
                lst_CampaignMember = [select CampaignId, Campaign.Name, Lead.Id, Lead.Name, Lead.UAEResidentStatus__c, 
                                         Lead.FirstName, Lead.LastName, Lead.Phone, Lead.MobilePhone, Lead.Email, Lead.BrokerAgency__r.Name, 
                                         Lead.BrokerAgency__r.UnifiedNumber__c, Lead.BrokerAgency__r.UAEVATRegisterNumber__c, 
                                         Lead.BrokerAgency__r.Phone, Lead.BrokerAgency__r.PersonEmail, Lead.BrokerAgent__r.Name, 
                                         Lead.BrokerAgent__r.MobilePhone, Lead.BrokerAgent__r.Email, Lead.LeadNumber__c, Lead.CustomerType__c,
                                         Lead.LeadSource, Lead.Owner.Name, Lead.Status 
                                         from CampaignMember where CampaignId = :campaignId and createddate >= :cutoff
                                         WITH USER_MODE];
            } else {
                //1.2 added
                //1.3 MCR-73: Enforce CRUD/FLS via USER_MODE on CampaignMember query
                lst_CampaignMember = [select CampaignId, Campaign.Name, Lead.Id, Lead.Name, Lead.UAEResidentStatus__c, 
                                         Lead.FirstName, Lead.LastName, Lead.Phone, Lead.MobilePhone, Lead.Email, Lead.BrokerAgency__r.Name, 
                                         Lead.BrokerAgency__r.UnifiedNumber__c, Lead.BrokerAgency__r.UAEVATRegisterNumber__c, 
                                         Lead.BrokerAgency__r.Phone, Lead.BrokerAgency__r.PersonEmail, Lead.BrokerAgent__r.Name, 
                                         Lead.BrokerAgent__r.MobilePhone, Lead.BrokerAgent__r.Email, Lead.LeadNumber__c, Lead.CustomerType__c,
                                         Lead.LeadSource, Lead.Owner.Name, Lead.Status
                                         from CampaignMember where CampaignId = :campaignId
                                         WITH USER_MODE];
            }
            
            for(CampaignMember obj_CampaignMem : lst_CampaignMember) {
                LeadRecord obj_LeadRecord = new LeadRecord();
                obj_LeadRecord.CampaignId = obj_CampaignMem.CampaignId;
                obj_LeadRecord.CampaignName = obj_CampaignMem.Campaign.Name;
                obj_LeadRecord.LeadId = obj_CampaignMem.Lead.Id;
                obj_LeadRecord.LeadName = obj_CampaignMem.Lead.Name;
                obj_LeadRecord.UAEResidentStatus = obj_CampaignMem.Lead.UAEResidentStatus__c;
                obj_LeadRecord.FirstName = obj_CampaignMem.Lead.FirstName;
                obj_LeadRecord.LastName = obj_CampaignMem.Lead.LastName;
                obj_LeadRecord.Phone = obj_CampaignMem.Lead.Phone;
                obj_LeadRecord.MobilePhone = obj_CampaignMem.Lead.MobilePhone;
                obj_LeadRecord.Email = obj_CampaignMem.Lead.Email;
                obj_LeadRecord.BrokerAgencyName = obj_CampaignMem.Lead.BrokerAgency__r.Name;
                obj_LeadRecord.BrokerAgencyUnifiedNumber = obj_CampaignMem.Lead.BrokerAgency__r.UnifiedNumber__c;
                obj_LeadRecord.BrokerAgencyUAEVATRegisterNumber = obj_CampaignMem.Lead.BrokerAgency__r.UAEVATRegisterNumber__c;
                obj_LeadRecord.BrokerAgencyPhone = obj_CampaignMem.Lead.BrokerAgency__r.Phone;
                obj_LeadRecord.BrokerAgencyPersonEmail = obj_CampaignMem.Lead.BrokerAgency__r.PersonEmail;
                obj_LeadRecord.BrokerAgentName = obj_CampaignMem.Lead.BrokerAgent__r.Name;
                obj_LeadRecord.BrokerAgentMobilePhone = obj_CampaignMem.Lead.BrokerAgent__r.MobilePhone;
                obj_LeadRecord.BrokerAgentEmail = obj_CampaignMem.Lead.BrokerAgent__r.Email;
                obj_LeadRecord.LeadNumber = obj_CampaignMem.Lead.LeadNumber__c;
                //V1.1 added
                obj_LeadRecord.CustomerType = obj_CampaignMem.Lead.CustomerType__c;
                obj_LeadRecord.Status = obj_CampaignMem.Lead.Status;
                obj_LeadRecord.LeadOwnerName = obj_CampaignMem.Lead.Owner.Name;
                obj_LeadRecord.LeadSource = obj_CampaignMem.Lead.LeadSource;
                
                lst_LeadRecord.add(obj_LeadRecord);
            }
            obj_LeadDetailsResponse.LeadRecords = lst_LeadRecord;
            obj_LeadDetailsResponse.Status = 'Success';
            obj_LeadDetailsResponse.ErrorCode = '';
            obj_LeadDetailsResponse.ErrorMessage = '';
        } else {
            obj_LeadDetailsResponse.Status = 'Failure';
            obj_LeadDetailsResponse.ErrorCode = 'Evento-001';
            obj_LeadDetailsResponse.ErrorMessage = 'Campaign Id should not be empty';
        }
        System.debug('OIC_SalesLaunchLeadDetails >>>> Response >>  '+System.JSON.serialize(obj_LeadDetailsResponse));
        if(obj_LeadDetailsResponse != null && obj_LeadDetailsResponse.Status == 'Success'){
                restResponse.statusCode = 200;
        } else {
                restResponse.statusCode = 400;
        }   
            
            restResponse.addHeader('Content-Type', 'application/json');
            restResponse.responseBody = Blob.valueOf(JSON.serialize(obj_LeadDetailsResponse));
        } catch (Exception ex) {
            //1.3 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'Sales Launch Lead Details',
                'OIC_SalesLaunchLeadDetails',
                'getLeadDetails'
            ));
            obj_LeadDetailsResponse.Status = 'Failure';
            obj_LeadDetailsResponse.ErrorCode = 'Evento-500';
            obj_LeadDetailsResponse.ErrorMessage = 'Internal Server Error: ' + ex.getMessage();
            restResponse.statusCode = 400;
            restResponse.addHeader('Content-Type', 'application/json');
            restResponse.responseBody = Blob.valueOf(JSON.serialize(obj_LeadDetailsResponse));
        }
    }
    global class LeadDetailsResponse {
        public List<LeadRecord> LeadRecords;
        public String Status;	
        public String ErrorCode;	
        public String ErrorMessage;	
    } 
    global class LeadRecord {
        public String CampaignId;	
        public String CampaignName;	
        public String LeadId;	
        public String LeadName;
        public String UAEResidentStatus;
        public String FirstName;	
        public String LastName;
        public String Phone;
        public String MobilePhone;
        public String Email;
        public String BrokerAgencyName;
        public String BrokerAgencyUnifiedNumber;
        public String BrokerAgencyUAEVATRegisterNumber;
        public String BrokerAgencyPhone;
        public String BrokerAgencyPersonEmail;
        public String BrokerAgentName;
        public String BrokerAgentMobilePhone;
        public String BrokerAgentEmail;
        public String LeadNumber;
        public String CustomerType;
        public String LeadOwnerName;
        public String Status;
        public String LeadSource;
    }    
}