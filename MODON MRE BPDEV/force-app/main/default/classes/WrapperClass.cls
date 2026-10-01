/**********************************************************************************************************************
* Name               : WrapperClass                                                        
* Description        : This class is helper for Creating JSON Body
* Usage              : Called from sendRequestToXiboApi
* Created By         : Active Minds Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                Date            Comment                                                                       
* 1.0           Manojkumar         22 Feb 2023     Initial Draft       
******************************************************************************************************************/
public class WrapperClass {
    public Integer medium=10;	
    public List<cls_cases> contacts = new List<cls_cases>();
    public List<ServiceRequestWrapper> srlst = new List<ServiceRequestWrapper>();
    Public list<SalesOrderWrapper> solst = new list<SalesOrderWrapper>();
    public class cls_cases {
        public Id extUniqueId;	
        public String email;
        public string unitName;
        public string accountName;
        public Date closedTime;
        public string typeService;
        public String recordType;
        public String CaseCategory;
        public String CaseSubCategory;
        
        public  cls_cases(Id recId,string emailvalue,string unitName, string accountName,date closedDate, string typeService,String recordType, String CaseCategory, String CaseSubCategory){
            this.extUniqueId=recId;
            this.email=emailvalue;
            this.unitName=unitName;
            this.accountName=accountName;
            this.closedTime=closedTime;
            this.typeService=typeService;
            this.recordType = recordType;
            this.CaseCategory = CaseCategory;
            this.CaseSubCategory = CaseSubCategory;
            
            
            
        }
    }
    public class ServiceRequestWrapper {
        public Id extUniqueId;
        public String email;
        public String unitName;
        public String accountName;
        public Date closedTime;
        public String typeService;
        // public String recordType;
        public String salesOrder;
        //public String salesOrderInstallment;
        //public String oldSalesOrder;
        //public String newSalesOrder;
        
        
        public ServiceRequestWrapper(Id recId, String emailVal, String unitName, String accountName,Date closedDate, String typeService,
                                     String salesOrder) {
                                         this.extUniqueId = recId;
                                         this.email = emailVal;
                                         this.unitName = unitName;
                                         this.accountName = accountName;
                                         this.closedTime = closedDate;
                                         this.typeService = typeService;
                                         // this.recordType = recordType;
                                         this.salesOrder = salesOrder;
                                         // this.salesOrderInstallment = salesOrderInstallment;
                                         
                                     }
    }
    public class SalesOrderWrapper {
        public Id extUniqueId;
        public String email;
        public String unitname;
        public String accountname;
        public Date closedtime;
        public String salestype;
        public String projectname;
        public String salesasso;
        
        public SalesOrderWrapper(Id recId, String emailVal, String unit, String accName, Date closedDate, String type, String project,String salesassociacte) {
            this.extUniqueId = recId;
            this.email = emailVal;
            this.unitname = unit;
            this.accountname = accName;
            this.closedtime = closedDate;
            this.salestype = type;
            this.projectname = project;
            this.salesasso = salesassociacte;
        }
    }
}