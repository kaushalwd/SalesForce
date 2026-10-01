/**********************************************************************************************************************
* Name               : OIC_WhatsappCustomerPropertiesV2                                                        
* Description        : This class is used for Whatsapp integration to get SPA and SOA document.
* Usage              : Called from Whatsapp.
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	            28 Mar 2026     Initial Draft 
***********************************************************************************************************************/
@RestResource(urlMapping='/WhatsappCustomerPropertiesAPIV2/*')
global class OIC_WhatsappCustomerPropertiesV2 {
    @HttpGet
    global static void findPropertyDetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        list<string> projectFilter =new list<string>();
        try {
            String mobileNumber = req.params.get('MobileNumber');
            if (String.isBlank(mobileNumber)) {
                returnErrorAPI.returnError(res, requestId, 'Missing Customer Mobile Number parameter', 200);
                return;
            } 
            if(!mobileNumber.startsWith('+')){
                mobileNumber = '+'+mobileNumber;
            }
            list<string> statusFilter = getfilters(System.Label.CP_SO_Statusfilters);
            string MIREExcludelst = System.Label.MIRE_Exclude_List;
            for (String c2 : MIREExcludelst.split(',')) {
               if (c2 != null && c2.contains('^')) {
                        projectFilter.add(c2.replace('^', ',').trim());
                } else {
                        projectFilter.add(c2.trim());
                }
            } 
            System.debug('>>>>>>>>>>>>>>>>>>>>> MobileNumber >>>> '+mobileNumber);
            List<PropertyDetails> lst_PropertyDetails = new List<PropertyDetails>();
            Set<String> set_SOId = new Set<String>();
            List<Invoice__c> lst_Invoice = new List<Invoice__c>();
            List<Documents__c> lst_Docs = new List<Documents__c>();
            Map<String, String> map_SPA = new Map<String, String>();
            Map<Id, SalesOrderInstallmentSummary> summaryMap = new Map<Id, SalesOrderInstallmentSummary>();
            Map<Id, List<Invoice>> map_InvoiceDetails = new Map<Id, List<Invoice>>();
            List<SalesOrder__c> lst_SalesOrder = [SELECT ProjectName__c, Name, Image_Name_pc__c,Unit__r.TotalGrossSellableAreaGSA__c,SPAPublicUrl__c, 
                                                  PortalImageName__c, Unit__c, UnitOption__c,Unit__r.Number_of_Bedrooms__c, 
                                                  Unit__r.Phase__r.Description__c, Status__c,Unit__r.Status__c,
                                                  Unit__r.Numberofbathroom__c,UnitOption__r.AdditionalPrice__c, UnitOption__r.AED_SQM__c, 
                                                  UnitOption__r.AreaUnitofMeasure__c,UnitOption__r.BalconyArea__c, UnitOption__r.BasePrice__c, 
                                                  UnitOption__r.Description__c,UnitOption__r.GrossFloorAreaGFA__c, UnitOption__r.Internal_Area__c, 
                                                  UnitOption__r.NumberofBedrooms__c,UnitOption__r.NumberofCarParks__c, UnitOption__r.PlotNo__c, 
                                                  UnitOption__r.PlotAreasqm__c, UnitOption__r.Name, UnitOption__r.TotalGrossSellableAreaGSA__c, 
                                                  UnitOption__r.TotalPrice__c, UnitOption__r.Type__c,UnitOption__r.Typology__c, UnitOption__r.Unit__c, 
                                                  UnitOption__r.Unit_Option_Image__c,Unit__r.Type__c, Unit__r.Phase__c, Unit__r.UnitClassification__c, 
                                                  Unit__r.Numberofbalcony__c,Unit__r.TotalArea__c, Unit__r.PlotNo__c, Unit__r.Project_Name__c, 
                                                  Unit__r.NumberofCarParks__c, Unit__r.PlotAreasqm__c,TotalGrossSellableAreaGSA__c, TotalAmount__c, 
                                                  PaymentPlanStructure__c, Unit__r.Name, Unit__r.GrossFloorAreaGFA__c,PaymentPlan__c, 
                                                  PaymentPlan__r.Name, PhaseImagePublicURL__c, Unit__r.Phase__r.Name, CustomerAccount__c, JO1__c, JO1__r.Name,JO2__c, 
                                                 JO2__r.Name,JO3__c, JO3__r.Name,JO4__c, JO4__r.Name,JO5__c, JO5__r.Name,JO6__c, JO6__r.Name, 
                                                 CustomerAccount__r.Name, PrimaryContact__r.Email, PrimaryContact__r.MobilePhone, JO1__r.Email, 
                                                 JO1__r.MobilePhone, JO2__r.Email, JO2__r.MobilePhone, JO3__r.Email, JO3__r.MobilePhone, 
                                                 JO4__r.Email, JO4__r.MobilePhone, JO5__r.Email, JO5__r.MobilePhone, JO6__r.Email, JO6__r.MobilePhone
                                                 From SalesOrder__c 
                                                 where Status__c NOT IN : statusFilter 
                                                 and Unit__r.Project_Name__c NOT IN : projectFilter 
                                                 and (PrimaryContact__r.MobilePhone = :mobileNumber or CustomerAccount__r.PersonMobilePhone = :mobileNumber
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
                for(Invoice__c  Inv : [select id,Name, InvoiceDate__c, Dari_Charges__c, InvoiceStatus__c,TotalPaidAmount__c,AppliedAmount__c,
                                       InvoiceAmount__c,InvoiceBalance__c,ADM_Fees__c,ADM_Fees_Dari_charges__c, Actual_ADM_Fee__c, 
                                       SalesOrderInstallment__r.SalesOrder__c,SalesOrderInstallment__r.SalesOrder__r.Totalpaidamount__c, 
                                       SalesOrderInstallment__r.SalesOrder__r.TotalAmount__c,SalesOrderInstallment__r.InstallmentAmount__c, 
                                       SalesOrderInstallment__r.MilestoneNumber__c, SalesOrderInstallment__r.PaymentStatus__c, 
                                       SalesOrderInstallment__r.MilestoneDate__c, Is_ADM_Fees_and_Dari_charges__c, Charge__c, Charge__r.Name,
                                       SalesOrderInstallment__r.MilestoneDescription__c, Sales_Order__c
                                       from Invoice__c where (SalesOrderInstallment__r.SalesOrder__c IN :set_SOId OR Sales_Order__c IN :set_SOId)
                                       and InvoiceStatus__c != 'Cancelled' ORDER BY SalesOrderInstallment__r.MilestoneNumber__c ASC ]){
                                       
                                       Id salesOrderId = Inv.Sales_Order__c!=null?Inv.Sales_Order__c:Inv.SalesOrderInstallment__r.SalesOrder__c;
                                       Invoice obj_Invoice = new Invoice();    
                                       if (!summaryMap.containsKey(Inv.SalesOrderInstallment__r.SalesOrder__c)) {
                                           summaryMap.put(Inv.SalesOrderInstallment__r.SalesOrder__c, new SalesOrderInstallmentSummary());
                                       }
                                       if(salesOrderId != null && !map_InvoiceDetails.containsKey(salesOrderId)){
                                           map_InvoiceDetails.put(salesOrderId, new List<Invoice>());      
                                       }     
                                       SalesOrderInstallmentSummary summary = summaryMap.get(Inv.SalesOrderInstallment__r.SalesOrder__c);
                                       
                                       if(Inv.Is_ADM_Fees_and_Dari_charges__c == true){
                                           obj_Invoice.InvoiceNumber = Inv.Name;
                                           obj_Invoice.InvoiceDate = Inv.InvoiceDate__c;
                                           obj_Invoice.InvoiceAmount = Inv.InvoiceAmount__c;
                                           obj_Invoice.InvoiceBalance = Inv.InvoiceBalance__c;
                                           obj_Invoice.InvoicePaidAmount = Inv.TotalPaidAmount__c;
                                           obj_Invoice.InvoiceDescription = 'ADM & Dari Fee';
                                           obj_Invoice.DariCharges = Inv.Dari_Charges__c;
                                           obj_Invoice.ADMFee = Inv.Actual_ADM_Fee__c;
                                           obj_Invoice.ADMFeeAndDariCharge = Inv.ADM_Fees_Dari_charges__c;
                                       } else if(Inv.Charge__c != null){
                                           obj_Invoice.InvoiceNumber = Inv.Name;
                                           obj_Invoice.InvoiceDate = Inv.InvoiceDate__c;
                                           obj_Invoice.InvoiceAmount = Inv.InvoiceAmount__c;
                                           obj_Invoice.InvoiceBalance = Inv.InvoiceBalance__c;
                                           obj_Invoice.InvoicePaidAmount = Inv.TotalPaidAmount__c;
                                           obj_Invoice.InvoiceDescription = Inv.Charge__r.Name;
                                           obj_Invoice.DariCharges = 0.00;
                                           obj_Invoice.ADMFee = 0.00;
                                           obj_Invoice.ADMFeeAndDariCharge = 0.00;
                                       } else {
                                           obj_Invoice.InvoiceNumber = Inv.Name;
                                           obj_Invoice.InvoiceDate = Inv.InvoiceDate__c;
                                           obj_Invoice.InvoiceAmount = Inv.InvoiceAmount__c;
                                           obj_Invoice.InvoiceBalance = Inv.InvoiceBalance__c;
                                           obj_Invoice.InvoicePaidAmount = Inv.TotalPaidAmount__c;
                                           obj_Invoice.InvoiceDescription = Inv.SalesOrderInstallment__r.MilestoneDescription__c;
                                           obj_Invoice.MilestoneNumber = Integer.valueOf(Inv.SalesOrderInstallment__r.MilestoneNumber__c);
                                           obj_Invoice.DariCharges = 0.00;
                                           obj_Invoice.ADMFee = 0.00;
                                           obj_Invoice.ADMFeeAndDariCharge = 0.00;
                                       } 
                                       if(map_InvoiceDetails.containsKey(salesOrderId)){
                                          map_InvoiceDetails.get(salesOrderId).add(obj_Invoice);     
                                       }                                          
                                           
                                       if ((Inv.InvoiceStatus__c == 'Paid' || Inv.InvoiceStatus__c == 'Partially Paid') 
                                            && (Inv.Charge__c == NULL && Inv.Is_ADM_Fees_and_Dari_charges__c == false)) {
                                           summary.totalPaidInstallments++;
                                           summary.totalpaidCollectedAmount += (Inv.TotalPaidAmount__c != null ? Inv.TotalPaidAmount__c : 0);
                                           system.debug('summary.totalpaidCollectedAmount---'+summary.totalpaidCollectedAmount);
                                       } 
                                       if((Inv.InvoiceStatus__c == 'Generated') && (Inv.Charge__c == NULL && Inv.Is_ADM_Fees_and_Dari_charges__c == false)){ //5.0 Add Chat
                                           summary.totalNotPaidInstallments++;
                                           summary.balanceAmount += (Inv.InvoiceBalance__c != null ? Inv.InvoiceBalance__c : 0);
                                           if (summary.nextMilestoneDate == null) {
                                               summary.nextMilestoneDate = Inv.SalesOrderInstallment__r.MilestoneDate__c;
                                               summary.nextInstallmentAmount = Inv.InvoiceBalance__c;
                                           }
                                       }
                                       summary.installmentsNumber = Integer.valueOf(Inv.SalesOrderInstallment__r.MilestoneNumber__c);
                                       Decimal totalAmount = summary.totalpaidCollectedAmount ;
                                       system.debug('totalAmount---'+totalAmount);
                                       summary.totalCollectedAmount =Inv.SalesOrderInstallment__r.SalesOrder__r.TotalAmount__c;
                                       summary.paidPercentage = (totalAmount > 0) ? ( totalAmount/summary.totalCollectedAmount) * 100 : 0;
                                       summary.totalInstallments++;
                                   }
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
                    Boolean useOption = (obj_SO.UnitOption__c != null);
                    Decimal area = null;
                    area= (obj_SO.Unit__r != null && obj_SO.Unit__r.PlotAreasqm__c != null) ? obj_SO.Unit__r.PlotAreasqm__c : obj_SO.Unit__r.TotalArea__c;
                    
                    obj_Property.SalesOrderName = obj_SO.Name;
                    obj_Property.Id = obj_SO.Id;
                    obj_Property.Status = obj_SO.Status__c;
                    obj_Property.TotalAmount = obj_SO.TotalAmount__c;
                    obj_Property.ProjectName = obj_SO.ProjectName__c;
                    obj_Property.PhaseName = obj_SO.Unit__r.Phase__r.Name;
                    obj_Property.UnitClass = useOption ? obj_SO.UnitOption__r.Typology__c : (obj_SO.Unit__r != null ? obj_SO.Unit__r.UnitClassification__c : null);
                    obj_Property.UnitName = obj_SO.Unit__r.Name;
                    obj_Property.UnitStatus = obj_SO.Unit__r.Status__c;
                    
                    obj_Property.UnitNumber = obj_SO.Unit__r.PlotNo__c;
                    obj_Property.UnitType = useOption ? obj_SO.UnitOption__r.Type__c : (obj_SO.Unit__r != null ? obj_SO.Unit__r.Type__c : null);
                    obj_Property.NoofBedrooms = useOption ? String.valueOf(obj_SO.UnitOption__r.NumberofBedrooms__c)
                        						: (obj_SO.Unit__r != null ? obj_SO.Unit__r.Number_of_Bedrooms__c : null);
                    obj_Property.NoofBathroom = (obj_SO.Unit__r != null) ? String.valueOf(obj_SO.Unit__r.Numberofbathroom__c) : null;
                    obj_Property.NoofCars = useOption ? String.valueOf(obj_SO.UnitOption__r.NumberofCarParks__c)
                                            : (obj_SO.Unit__r != null ? String.valueOf(obj_SO.Unit__r.NumberofCarParks__c) : null);
                    obj_Property.TotalArea = useOption ? obj_SO.UnitOption__r.PlotAreasqm__c : area;
                    obj_Property.TotalAmount = obj_SO.TotalAmount__c;
                    obj_Property.PaymentPlan = obj_SO.PaymentPlanStructure__c;
                    obj_Property.Noofbalcony =  useOption ? '' : (obj_SO.Unit__r != null ? String.valueOf(obj_SO.Unit__r.Numberofbalcony__c) : null);
                    if(useOption == true){
                        obj_Property.TotalGrossArea = useOption && obj_SO.UnitOption__r.TotalGrossSellableAreaGSA__c !=null ? obj_SO.UnitOption__r.TotalGrossSellableAreaGSA__c : obj_SO.UnitOption__r.GrossFloorAreaGFA__c;
                    }else{
                        obj_Property.TotalGrossArea = obj_SO.Unit__r.TotalGrossSellableAreaGSA__c != null ? obj_SO.Unit__r.TotalGrossSellableAreaGSA__c : obj_SO.Unit__r.GrossFloorAreaGFA__c;
                    }
                         
                    obj_Property.FloorPlanId = useOption ? obj_SO.UnitOption__r.Unit__c : obj_SO.Unit__c;
                    obj_Property.DisplayImageName = obj_SO.Image_Name_pc__c;
                    obj_Property.CustomerName = obj_SO.CustomerAccount__r.Name;
                    obj_Property.CustomerAccountId = obj_SO.CustomerAccount__c;
                    obj_Property.MobilePhone = obj_SO.PrimaryContact__r.MobilePhone;
                    obj_Property.Email = obj_SO.PrimaryContact__r.Email;
                    obj_Property.installmentSummary = summaryMap.containskey(obj_SO.Id)?summaryMap.get(obj_SO.Id):new SalesOrderInstallmentSummary();
                    if(map_InvoiceDetails.containsKey(obj_SO.Id)){
                       obj_Property.InvoiceDetails = map_InvoiceDetails.get(obj_SO.Id); 
                    }
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
        public String Id;
        public String SalesOrderName;
        public String Status;
        public String ProjectName;
        public String PhaseName;
        public String UnitClass;
        public String UnitName;
        public String UnitNumber;
        public String UnitType;
        public String UnitStatus;
        public String NoofBedrooms;
        public String NoofBathroom;
        public String NoofCars;
        public Decimal TotalArea;
        public Decimal TotalAmount;
        public String PaymentPlan;
        public String Noofbalcony;
        public Decimal TotalGrossArea;
        public String FloorPlanId;
        public String DisplayImageName;        
        public string CustomerName;
        public string CustomerAccountId;
        public string MobilePhone;
 		public string Email;
        public Boolean IsSPAGenerated;
        public List<JointOwner> JointOwnerDetails; 
        public List<Invoice> InvoiceDetails;
        public SalesOrderInstallmentSummary installmentSummary;
    }
    public class JointOwner{
        public string CustomerAccountId;
        public string CustomerName;
        public string CustomerEmail;
        public string MobilePhone;
    }
    public class Invoice{
        public string InvoiceNumber;
        public Date InvoiceDate;
        public Decimal InvoiceAmount;
        public Decimal InvoiceBalance;
        public Decimal InvoicePaidAmount;
        public string InvoiceDescription;
        public Integer MilestoneNumber;
        public Decimal DariCharges;
        public Decimal ADMFee;
        public Decimal ADMFeeAndDariCharge;
    }
    public class SalesOrderInstallmentSummary {
        public Integer TotalPaidInstallments = 0;
        public Integer TotalNotPaidInstallments = 0;
        public Integer TotalInstallments = 0;
        public Decimal TotalCollectedAmount = 0;
        public Decimal BalanceAmount = 0;
        public Date NextMilestoneDate;
        public Decimal NextInstallmentAmount = 0;
        public Decimal PaidPercentage = 0;
        public Integer InstallmentsNumber = 0;
        public Decimal TotalpaidCollectedAmount =0;
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