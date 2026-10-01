/**********************************************************************************************************************
* Name               : CustomerPropertiesAPI                                                        
* Description        : This class is used to fetch the properties of the customer.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft 
* 2.0           Suresh   	                13 05 2026      Filters are added to Sales Order
***********************************************************************************************************************/
@RestResource(urlMapping='/CustomerPropertiesAPI/*')
global class CustomerPropertiesAPI {

    @HttpGet
    global static void findPropertyDetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        try {
            String customerEmail = req.params.get('CustomerEmail');
            if (String.isBlank(customerEmail)) {
                returnErrorAPI.returnError(res, requestId, 'Missing Customer Email parameter', 200);
                return;
            } 
            System.debug('>>>>>>>>>>>>>>>>>>>>> customerEmail >>>> '+customerEmail);
            List<PropertyDetails> lst_PropertyDetails = new List<PropertyDetails>();
            //2.0 added
            list<string> projectFilter =new list<string>();
            list<string> statusFilter = getfilters(System.Label.CP_SO_Statusfilters);
            string MIREExcludelst = System.Label.MIRE_Exclude_List;
            for (String c2 : MIREExcludelst.split(',')) {
               if (c2 != null && c2.contains('^')) {
                        projectFilter.add(c2.replace('^', ',').trim());
                } else {
                        projectFilter.add(c2.trim());
                }
            }
            //2.0 added
            List<SalesOrder__c> lst_SalesOrder = [SELECT Id, Name, Status__c,Sub_Status__c, TotalAmount__c, ProjectName__c, Unit__c, Unit__r.Name, 
                                                 Unit__r.Status__c, Unit__r.Phase__r.Name, Unit__r.TotalGrossSellableAreaGSA__c, 
                                                 Unit__r.GrossFloorAreaGFA__c, Unit__r.Number_of_Bedrooms__c, 
                                                 Unit__r.NumberofAllocatedParking__c, Unit__r.NumberofBedrooms__c, 
                                                 Unit__r.AED_SQM__c, Unit__r.Category__c, Unit__r.District__c, 
                                                 Unit__r.FacadeStyle__c,Unit__r.FacadeType__c, Unit__r.FloorNumber__c, 
                                                 Unit__r.Internal_Area__c, Unit__r.Model__c,Unit__r.PlotAreasqm__c, 
                                                 Unit__r.PlotNo__c, Unit__r.Project_Launch_Date__c, Unit__r.Type__c,  
                                                 Unit__r.Typology__c,Unit__r.Unit_Sold_Date__c, Unit__r.UnitClassification__c,  
                                                 Unit__r.View__c, Unit__r.Zone__c,Unit__r.Phase__c,Unit__r.Phase__r.Project__c, Unit__r.Phase__r.EstimatedCompletionDate__c, 
                                                 Unit__r.Phase__r.EstimatedHandoverDate__c, CustomerAccount__c, JO1__c, JO1__r.Name,JO2__c, 
                                                 JO2__r.Name,JO3__c, JO3__r.Name,JO4__c, JO4__r.Name,JO5__c, JO5__r.Name,JO6__c, JO6__r.Name, 
                                                 CustomerAccount__r.Name, PrimaryContact__r.Email, JO1__r.Email, JO2__r.Email, 
                                                 JO3__r.Email, JO4__r.Email, JO5__r.Email, JO6__r.Email,
                                                 Unit__r.Unit_Image_URL__c,Unit__r.DPG_Unit_Image_URL__c,Owner.Name, Owner.Email, 
                                                 Owner.Phone, Unit__r.Phase__r.EscrowAccount__r.MerchantID__c, ADM_Registration_Status__c,
                                                 UAE_Resident_Status__c, Nationality__c 
                                                 From SalesOrder__c 
                                                 where Status__c NOT IN : statusFilter 
                                                 AND Unit__r.Project_Name__c NOT IN : projectFilter 
                                                 AND (CustomerAccount__r.PersonEmail = :customerEmail 
                                                 OR PrimaryContact__r.Email = :customerEmail OR JO1__r.Email = :customerEmail 
                                                 OR JO2__r.Email = :customerEmail OR JO3__r.Email = :customerEmail 
                                                 OR JO4__r.Email = :customerEmail OR JO5__r.Email = :customerEmail 
                                                 OR JO6__r.Email = :customerEmail)];  
            
            if(lst_SalesOrder.size() > 0){
                for(SalesOrder__c obj_SO : lst_SalesOrder){
                    PropertyDetails obj_Property = new PropertyDetails();
                    List<JointOwner> jointOwnerDetails = new List<JointOwner>();
                    obj_Property.SalesOrderName = obj_SO.Name;
                    obj_Property.SalesOrderId = obj_SO.Id;
                    obj_Property.Status = obj_SO.Status__c;
                    obj_Property.Substatus = obj_SO.Sub_Status__c;
                    obj_Property.TotalAmount = obj_SO.TotalAmount__c;
                    obj_Property.UnitName = obj_SO.Unit__r.Name;
                    obj_Property.UnitId = obj_SO.Unit__c;
                    obj_Property.UnitStatus = obj_SO.Unit__r.Status__c;
                    obj_Property.UnitImageURL = obj_SO.Unit__r.DPG_Unit_Image_URL__c;
                    obj_Property.ProjectName = obj_SO.ProjectName__c;
                    obj_Property.ProjectId = obj_SO.Unit__r.Phase__r.Project__c;
                    obj_Property.PhaseId = obj_SO.Unit__r.Phase__c;
                    obj_Property.PhaseName = obj_SO.Unit__r.Phase__r.Name;
                    
                    obj_Property.TotalGrossSellableAreaGSA = obj_SO.Unit__r.TotalGrossSellableAreaGSA__c;
                    obj_Property.GrossFloorAreaGFA = obj_SO.Unit__r.GrossFloorAreaGFA__c;
                    obj_Property.Number_of_Bedrooms = obj_SO.Unit__r.Number_of_Bedrooms__c;
                    obj_Property.NumberofAllocatedParking = obj_SO.Unit__r.NumberofAllocatedParking__c;
                    obj_Property.AED_SQM = obj_SO.Unit__r.AED_SQM__c;
                    obj_Property.Category = obj_SO.Unit__r.Category__c;
                    obj_Property.District = obj_SO.Unit__r.District__c;
                    obj_Property.FacadeStyle = obj_SO.Unit__r.FacadeStyle__c;
                    obj_Property.FacadeType = obj_SO.Unit__r.FacadeType__c;
                    obj_Property.FloorNumber = obj_SO.Unit__r.FloorNumber__c;
                    obj_Property.Internal_Area = obj_SO.Unit__r.Internal_Area__c;
                    obj_Property.Model = obj_SO.Unit__r.Model__c;
                    obj_Property.PlotAreasqm = obj_SO.Unit__r.PlotAreasqm__c;
                    obj_Property.PlotNo = obj_SO.Unit__r.PlotNo__c;
                    obj_Property.Project_Launch_Date = obj_SO.Unit__r.Project_Launch_Date__c;
                    obj_Property.Type = obj_SO.Unit__r.Type__c;
                    obj_Property.Typology = obj_SO.Unit__r.Typology__c;
                    obj_Property.Unit_Sold_Date = obj_SO.Unit__r.Unit_Sold_Date__c;
                    obj_Property.UnitClassification = obj_SO.Unit__r.UnitClassification__c;
                    obj_Property.View = obj_SO.Unit__r.View__c;
                    obj_Property.Zone = obj_SO.Unit__r.Zone__c;
                    obj_Property.EstimatedCompletionDate = obj_SO.Unit__r.Phase__r.EstimatedCompletionDate__c;
                    obj_Property.EstimatedHandoverDate = obj_SO.Unit__r.Phase__r.EstimatedHandoverDate__c;
                    obj_Property.RelationshipManager = obj_SO.Owner.Name;
                    obj_Property.RelationshipManagerMobile = obj_SO.Owner.Phone;
                    obj_Property.RelationshipManagerEmail =  obj_SO.Owner.Email;
                    obj_Property.PropertyRegistration = obj_SO.ADM_Registration_Status__c;
                    obj_Property.CustomerName = obj_SO.CustomerAccount__r.Name;
                    obj_Property.CustomerAccountId = obj_SO.CustomerAccount__c;
                    obj_Property.MerchantID = obj_SO.Unit__r.Phase__r.EscrowAccount__r.MerchantID__c;
                    if(!String.isBlank(obj_SO.JO1__c)){
                        JointOwner obj_JO = new JointOwner();
                        obj_JO.CustomerAccountId = obj_SO.JO1__c;
                        obj_JO.CustomerName = obj_SO.JO1__r.Name;
                        obj_JO.CustomerEmail = obj_SO.JO1__r.Email;
                        jointOwnerDetails.add(obj_JO);
                    }
                    if(!String.isBlank(obj_SO.JO2__c)){
                        JointOwner obj_JO = new JointOwner();
                        obj_JO.CustomerAccountId = obj_SO.JO2__c;
                        obj_JO.CustomerName = obj_SO.JO2__r.Name;
                        obj_JO.CustomerEmail = obj_SO.JO2__r.Email;
                        jointOwnerDetails.add(obj_JO);
                    }
                    if(!String.isBlank(obj_SO.JO3__c)){
                        JointOwner obj_JO = new JointOwner();
                        obj_JO.CustomerAccountId = obj_SO.JO3__c;
                        obj_JO.CustomerName = obj_SO.JO3__r.Name;
                        obj_JO.CustomerEmail = obj_SO.JO3__r.Email;
                        jointOwnerDetails.add(obj_JO);
                    }
                    if(!String.isBlank(obj_SO.JO4__c)){
                        JointOwner obj_JO = new JointOwner();
                        obj_JO.CustomerAccountId = obj_SO.JO4__c;
                        obj_JO.CustomerName = obj_SO.JO4__r.Name;
                        obj_JO.CustomerEmail = obj_SO.JO4__r.Email;
                        jointOwnerDetails.add(obj_JO);
                    }
                    if(!String.isBlank(obj_SO.JO5__c)){
                        JointOwner obj_JO = new JointOwner();
                        obj_JO.CustomerAccountId = obj_SO.JO5__c;
                        obj_JO.CustomerName = obj_SO.JO5__r.Name;
                        obj_JO.CustomerEmail = obj_SO.JO5__r.Email;
                        jointOwnerDetails.add(obj_JO);
                    }
                    if(!String.isBlank(obj_SO.JO6__c)){
                        JointOwner obj_JO = new JointOwner();
                        obj_JO.CustomerAccountId = obj_SO.JO6__c;
                        obj_JO.CustomerName = obj_SO.JO6__r.Name;
                        obj_JO.CustomerEmail = obj_SO.JO6__r.Email;
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
        public string Substatus;
        public String UAE_Resident_Status;
        public String Nationality; 
        public Decimal TotalAmount;
        public string UnitName;
        public string UnitId;
        public string UnitStatus;
        public string UnitImageURL;
        public string ProjectName;
        public string ProjectId;
        public string PhaseName;
        public string PhaseId;
        public decimal TotalGrossSellableAreaGSA;
        public decimal GrossFloorAreaGFA;
        public String Number_of_Bedrooms;
        public decimal NumberofAllocatedParking;
        public decimal AED_SQM;
        public string Category;
        public string District;
        public string FacadeStyle;
        public string FacadeType;
        public string FloorNumber;
        public decimal Internal_Area;
        public string Model;
        public decimal PlotAreasqm;
        public string PlotNo;
        public date Project_Launch_Date;
        public string Type;
        public string Typology;
        public date Unit_Sold_Date;
        public string UnitClassification;
        public string View;
        public string Zone;
        public string EstimatedCompletionDate;
        public string EstimatedHandoverDate;
        public string CustomerName;
        public string CustomerAccountId;
        public string RelationshipManager;
        public string RelationshipManagerMobile;
        public string RelationshipManagerEmail;
        public string PropertyRegistration;
        public string MerchantID;
        public List<JointOwner> JointOwnerDetails;        
    }
    public class JointOwner{
        public string CustomerAccountId;
        public string CustomerName;
        public string CustomerEmail;
    } 
    public static List<String> getfilters(string customlablename) {
        String labelValue = customlablename;
        
        List<String> filterString = new List<String>();
        if (String.isNotBlank(labelValue)) {
            if (labelValue.contains(',')) {
                // Split by comma and trim spaces
                for (String s : labelValue.split(',')) {
                    filterString.add(s.trim());
                }
            } else {
                // No comma, just single value
                filterString.add(labelValue.trim());
            }
        }
        return filterString;
   } 
}