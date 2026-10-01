/**********************************************************************************************************************
* Name               : OIC_WhatsappCustomerProperties                                                        
* Description        : This class is used for Whatsapp integration to get SPA and SOA document.
* Usage              : Called from Whatsapp.
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	            28 Mar 2026     Initial Draft 
***********************************************************************************************************************/
@RestResource(urlMapping='/WhatsappCustomerPropertiesAPI/*')
global class OIC_WhatsappCustomerProperties {
    @HttpGet
    global static void findPropertyDetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        try {
            String mobileNumber = req.params.get('MobileNumber');
            if (String.isBlank(mobileNumber)) {
                returnErrorAPI.returnError(res, requestId, 'Missing Customer Mobile Number parameter', 200);
                return;
            } 
            if(!mobileNumber.startsWith('+')){
                mobileNumber = '+'+mobileNumber;
            }
            System.debug('>>>>>>>>>>>>>>>>>>>>> MobileNumber >>>> '+mobileNumber);
            List<PropertyDetails> lst_PropertyDetails = new List<PropertyDetails>();
            Set<String> set_SOId = new Set<String>();
            List<Documents__c> lst_Docs = new List<Documents__c>();
            Map<String, String> map_SPA = new Map<String, String>();
            List<SalesOrder__c> lst_SalesOrder = [SELECT Id, Name, Status__c, TotalAmount__c, ProjectName__c, Unit__c, Unit__r.Name, 
                                                 Unit__r.Status__c, Unit__r.Phase__r.Name, CustomerAccount__c, JO1__c, JO1__r.Name,JO2__c, 
                                                 JO2__r.Name,JO3__c, JO3__r.Name,JO4__c, JO4__r.Name,JO5__c, JO5__r.Name,JO6__c, JO6__r.Name, 
                                                 CustomerAccount__r.Name, PrimaryContact__r.Email, PrimaryContact__r.MobilePhone, JO1__r.Email, 
                                                 JO1__r.MobilePhone, JO2__r.Email, JO2__r.MobilePhone, JO3__r.Email, JO3__r.MobilePhone, 
                                                 JO4__r.Email, JO5__r.MobilePhone, JO6__r.Email, JO6__r.MobilePhone 
                                                 From SalesOrder__c where Status__c = 'Completed' 
                                                 and (PrimaryContact__r.MobilePhone = :mobileNumber
                                                 or JO1__r.MobilePhone = :mobileNumber or JO2__r.MobilePhone = :mobileNumber
                                                 or JO3__r.MobilePhone = :mobileNumber or JO4__r.MobilePhone = :mobileNumber
                                                 or JO5__r.MobilePhone = :mobileNumber or JO6__r.MobilePhone = :mobileNumber)];  
            for(SalesOrder__c obj_SO : lst_SalesOrder){
                set_SOId.add(obj_SO.Id);
            } 
            if(set_SOId.size() > 0){
                lst_Docs = [SELECT Id, SalesOrder__c from Documents__c where SalesOrder__r.Status__c = 'Completed'
                                                                   and Status__c = 'Uploaded' and Name = 'Signed SPA (Modon)' 
                                                                   and SalesOrder__c IN :set_SOId];
            }
            for(Documents__c obj_Docs : lst_Docs){
                if(!map_SPA.containsKey(obj_Docs.SalesOrder__c)){
                    map_SPA.put(obj_Docs.SalesOrder__c, obj_Docs.Id);
                }
            }
            if(lst_SalesOrder.size() > 0){
                for(SalesOrder__c obj_SO : lst_SalesOrder){
                    PropertyDetails obj_Property = new PropertyDetails();
                    List<JointOwner> jointOwnerDetails = new List<JointOwner>();
                    obj_Property.SalesOrderName = obj_SO.Name;
                    obj_Property.SalesOrderId = obj_SO.Id;
                    obj_Property.Status = obj_SO.Status__c;
                    obj_Property.TotalAmount = obj_SO.TotalAmount__c;
                    obj_Property.UnitName = obj_SO.Unit__r.Name;
                    obj_Property.UnitId = obj_SO.Unit__c;
                    obj_Property.UnitStatus = obj_SO.Unit__r.Status__c;
                    obj_Property.ProjectName = obj_SO.ProjectName__c;
                    obj_Property.PhaseName = obj_SO.Unit__r.Phase__r.Name;
                    obj_Property.CustomerName = obj_SO.CustomerAccount__r.Name;
                    obj_Property.CustomerAccountId = obj_SO.CustomerAccount__c;
                    obj_Property.MobilePhone = obj_SO.PrimaryContact__r.MobilePhone;
                    obj_Property.Email = obj_SO.PrimaryContact__r.Email;
                    if(map_SPA.containsKey(obj_SO.Id)){
                       obj_Property.IsSPAGenerated = true; 
                    } else {
                       obj_Property.IsSPAGenerated = false;  
                    }
                    if(!String.isBlank(obj_SO.JO1__c)){
                        JointOwner obj_JO = new JointOwner();
                        obj_JO.CustomerAccountId = obj_SO.JO1__c;
                        obj_JO.CustomerName = obj_SO.JO1__r.Name;
                        obj_JO.CustomerEmail = obj_SO.JO1__r.Email;
                        obj_JO.MobilePhone = obj_SO.JO1__r.MobilePhone;
                        jointOwnerDetails.add(obj_JO);
                    }
                    if(!String.isBlank(obj_SO.JO2__c)){
                        JointOwner obj_JO = new JointOwner();
                        obj_JO.CustomerAccountId = obj_SO.JO2__c;
                        obj_JO.CustomerName = obj_SO.JO2__r.Name;
                        obj_JO.CustomerEmail = obj_SO.JO2__r.Email;
                        obj_JO.MobilePhone = obj_SO.JO2__r.MobilePhone;
                        jointOwnerDetails.add(obj_JO);
                    }
                    if(!String.isBlank(obj_SO.JO3__c)){
                        JointOwner obj_JO = new JointOwner();
                        obj_JO.CustomerAccountId = obj_SO.JO3__c;
                        obj_JO.CustomerName = obj_SO.JO3__r.Name;
                        obj_JO.CustomerEmail = obj_SO.JO3__r.Email;
                        obj_JO.MobilePhone = obj_SO.JO3__r.MobilePhone;
                        jointOwnerDetails.add(obj_JO);
                    }
                    if(!String.isBlank(obj_SO.JO4__c)){
                        JointOwner obj_JO = new JointOwner();
                        obj_JO.CustomerAccountId = obj_SO.JO4__c;
                        obj_JO.CustomerName = obj_SO.JO4__r.Name;
                        obj_JO.CustomerEmail = obj_SO.JO4__r.Email;
                        obj_JO.MobilePhone = obj_SO.JO4__r.MobilePhone;
                        jointOwnerDetails.add(obj_JO);
                    }
                    if(!String.isBlank(obj_SO.JO5__c)){
                        JointOwner obj_JO = new JointOwner();
                        obj_JO.CustomerAccountId = obj_SO.JO5__c;
                        obj_JO.CustomerName = obj_SO.JO5__r.Name;
                        obj_JO.CustomerEmail = obj_SO.JO5__r.Email;
                        obj_JO.MobilePhone = obj_SO.JO5__r.MobilePhone;
                        jointOwnerDetails.add(obj_JO);
                    }
                    if(!String.isBlank(obj_SO.JO6__c)){
                        JointOwner obj_JO = new JointOwner();
                        obj_JO.CustomerAccountId = obj_SO.JO6__c;
                        obj_JO.CustomerName = obj_SO.JO6__r.Name;
                        obj_JO.CustomerEmail = obj_SO.JO6__r.Email;
                        obj_JO.MobilePhone = obj_SO.JO6__r.MobilePhone;
                        jointOwnerDetails.add(obj_JO);
                    } 
                   obj_Property.JointOwnerDetails = jointOwnerDetails; 
                   lst_PropertyDetails.add(obj_Property); 
                }
                
            } else {
                returnErrorAPI.returnError(res, requestId, 'No data found', 200);
                return;
            }
            APIResponse response = new APIResponse('success', requestId, lst_PropertyDetails, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            
        } catch (Exception ex) { // Return generic server error response
            LoggerService.save(LoggerService.createApexLog(ex, 'CustomerPropertiesAPI', 'CustomerPropertiesAPI', 'findPropertyDetails'));
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
    
    public class PropertyDetails{
        public string SalesOrderName;
        public string SalesOrderId;
        public string Status;
        public Decimal TotalAmount;
        public string UnitName;
        public string UnitId;
        public string UnitStatus;
        public string ProjectName;
        public string PhaseName;
        public string CustomerName;
        public string CustomerAccountId;
        public string MobilePhone;
 		public string Email;
        public Boolean IsSPAGenerated;
        public List<JointOwner> JointOwnerDetails;        
    }
    public class JointOwner{
        public string CustomerAccountId;
        public string CustomerName;
        public string CustomerEmail;
        public string MobilePhone;
    }
}