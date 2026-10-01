/**********************************************************************************************************************
* Name               : OIC_EventoLeadEventCreate                                                        
* Description        : This class is used to create leads for sales launch.
* Usage              : Used to Integrate with Evento.
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                18 06 2025      Initial Draft       

***********************************************************************************************************************/
@RestResource(urlMapping='/createleadevent/*')
global class OIC_EventoLeadEventCreate {
    
    @HttpPost
    global static void createLeadEvent() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        LeadEventRequest obj_LeadEventRequest = new LeadEventRequest();
        LeadEventResponse obj_LeadEventResponse = new LeadEventResponse();
        restRequest.addHeader('Content-Type', 'application/json');
        obj_LeadEventRequest = (LeadEventRequest)System.JSON.deserialize(restRequest.requestBody.toString(), LeadEventRequest.class);
        System.debug('OIC_EventoLeadEventCreate >>>> createLeadEvent >> '+System.JSON.serialize(obj_LeadEventRequest));
        
        if(!String.isBlank(obj_LeadEventRequest.FirstName) && !String.isBlank(obj_LeadEventRequest.LastName)
           && !String.isBlank(obj_LeadEventRequest.Email) && !String.isBlank(obj_LeadEventRequest.PrimaryMobile)){
               List<Lead> lst_Lead = new List<Lead>();
                   Lead newLead = new Lead(
                       FirstName = obj_LeadEventRequest.FirstName,
                       LastName = obj_LeadEventRequest.LastName,
                       Email = obj_LeadEventRequest.Email,
                       MobilePhone = obj_LeadEventRequest.PrimaryMobile,
                       LeadSource = obj_LeadEventRequest.LeadSource,
                       CustomerBudget__c = obj_LeadEventRequest.CustomerBudget,
                       Nationality__c = obj_LeadEventRequest.Nationality,
                       Status = 'New');    
               Database.SaveResult result = Database.insert(newLead, false);
               if (result.isSuccess()) {
                   System.debug('Record inserted with ID: ' + result.getId());
                   Id LeadId = result.getId();
                   lst_Lead = [select Id, LeadNumber__c from Lead where Id = :LeadId] ;
               } else {
                   for (Database.Error err : result.getErrors()) {
                       System.debug('Error: ' + err.getMessage());
                   }
               }
               if(lst_Lead.size() > 0){
                  Lead obj_Lead = lst_Lead.get(0); 
                 	CampaignMember cm = new CampaignMember();
                    cm.CampaignId = obj_LeadEventRequest.CampaignId; // Replace with your Campaign Id
                    cm.LeadId = obj_Lead.Id;     // Replace with your Lead Id
                    cm.Status = 'Sent';                // Optional: depends on your campaign member statuses
                    insert cm; 
                  obj_LeadEventResponse.Status = 'Success'; 
                  obj_LeadEventResponse.LeadEventId = obj_Lead.LeadNumber__c;  
                  obj_LeadEventResponse.ErrorCode = '';
                  obj_LeadEventResponse.ErrorMessage = '';  
               } else{
                  obj_LeadEventResponse.Status = 'Failure'; 
                  obj_LeadEventResponse.LeadEventId = ''; 
                  obj_LeadEventResponse.ErrorCode = 'Evento-002';
                  obj_LeadEventResponse.ErrorMessage = 'No Lead Id';  
               }  
           }else {
               obj_LeadEventResponse.Status = 'Failure';
               obj_LeadEventResponse.ErrorCode = 'Evento-001';
               obj_LeadEventResponse.ErrorMessage = 'Please provide mandatory fields'; 
           }
        
        if(obj_LeadEventResponse != null && obj_LeadEventResponse.Status == 'Success'){
            restResponse.statusCode = 200;
        } else {
            restResponse.statusCode = 400;
        }   
        
        restResponse.addHeader('Content-Type', 'application/json');
        restResponse.responseBody = Blob.valueOf(JSON.serialize(obj_LeadEventResponse));
    }
    global class LeadEventRequest{
        public String CampaignId;
        public String Email;
        public String FirstName;
        public String LastName;
        public String PrimaryMobile;
        public String LeadSource;
        public String CustomerBudget;
        public String Nationality;
        public LeadEventRequest(){}
    } 
    global class LeadEventResponse {
        public String LeadEventId;
        public String Status;	
        public String ErrorCode;	
        public String ErrorMessage;	
    }    
}