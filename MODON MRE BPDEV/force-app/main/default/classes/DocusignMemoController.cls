public without sharing class DocusignMemoController {
    public String memoSubject{
        get;
        set;
    }
    public String memoFrom{
        get;
        set;
    }
    public String memoTo{
        get;
        set;
    }
    public String refNumber {
        get;
        set;
    }
    public String commissionMonthandYear {
        get;
        set;
    }
    public Decimal employessCount {
        get;
        set;
    }
    public Decimal employessTotalAmount {
        get;
        set;
    }
    public Decimal managersCount {
        get;
        set;
    }
    public Decimal managersTotalAmount {
        get;
        set;
    }
    public Decimal totalOverAllCommissionAmount {
        get;
        set;
    }
    public Decimal totalOverAllCommissionAmountSalesPsnAndMgr {
        get;
        set;
    }
    public String notes{
        get;
        set;
    }
    public Set<Id> managerBundleIdset;
    public Set<Id> salesAssociateBundleIdset;
    public DocusignMemoController(){
        CommissionMemoRefNp__c userLoc = CommissionMemoRefNp__c.getInstance(UserInfo.getUserId());

        notes = '';
        commissionMonthandYear = getCurrentMonthYear();
        DateTime now = System.now();
        String formattedDate = now.format('dd_MM_yyyy');
        refNumber = 'MRE/FN/MR/'+formattedDate;
        memoTo = 'Group Chief Financial Officer';
        memoSubject = 'Staff Sales Commission - ';
        memoFrom = 'Modon Real Estate, CFO';
        if(userLoc <> null){
            refNumber = userLoc.MemoRefPrefix__c+formattedDate+'/0';//+userLoc.LastMemoGeneratedNumber__c <> null ?String.valueOf(userLoc.LastMemoGeneratedNumber__c+1):'1';
            memoSubject = userLoc.Memo_Subject__c;
            memoFrom = userLoc.Memo_From__c;
            memoTo = userLoc.Memo_To__c;
        }
        managerBundleIdset = new Set<Id>();
        salesAssociateBundleIdset = new Set<Id>();
        String bundleIdList = ApexPages.currentPage().getParameters().get('id');
        notes = ApexPages.currentPage().getParameters().get('notes');
        if(bundleIdList == null){
            List<Id> selectedInvoiceIdsOBJ = new List<Id>{'a2STI00000HiiWg2AJ'};
                bundleIdList = JSON.serialize(selectedInvoiceIdsOBJ);
        }
        List<Id> selectedInvoiceIds = (List<Id>) JSON.deserialize(bundleIdList,List<Id>.class);
        this.totalOverAllCommissionAmount = 0;
        this.totalOverAllCommissionAmountSalesPsnAndMgr = 0;
        Set<String> potTypeList = new Set<String>();
        potTypeList.add('Sales Manager');
        potTypeList.add('Sales Director');
        potTypeList.add('Sales Associate');
        for(Invoice_Bundle__c inv:[SELECT Id,user__c,user__r.Name,Total_Commission_Payout_Amount_Now__c,POT_Type__c,Employee_ID__c FROM Invoice_Bundle__c WHERE user__c <> null AND Id IN:selectedInvoiceIds ]){ //AND POT_Type__c IN: potTypeList
            this.totalOverAllCommissionAmount += inv.Total_Commission_Payout_Amount_Now__c;
            if((inv.POT_Type__c != 'Sales Associate')){
                this.managerBundleIdset.add(inv.Id);
            }
            if(inv.POT_Type__c == 'Sales Associate'){
                this.salesAssociateBundleIdset.add(inv.Id);
            }
            if(inv.POT_Type__c == 'Sales Associate' || inv.POT_Type__c == 'Sales Manager'){
                this.totalOverAllCommissionAmountSalesPsnAndMgr += inv.Total_Commission_Payout_Amount_Now__c;
            }
        }       
    }
    // Inner class to structure commission data
    public class CommissionEntry {
        public String name {
            get;
            set;
        }
        public decimal amount {
            get;
            set;
        }
        public String employeesId {
            get;
            set;
        }
        public String designation {
            get;
            set;
        }
        public CommissionEntry(String name, decimal amount, String employeesId, String designation) {
            this.name = name;
            this.amount = amount;
            this.employeesId = employeesId;
            this.designation = designation;
        }
    }
    
    public List <CommissionEntry> getEmployeeCommission() {
        this.employessTotalAmount = 0;
        List<CommissionEntry> CommissionEntryList = new List<CommissionEntry>();
        List<Invoice_Bundle__c> invoiceBundleEmpList =[SELECT Id,user__c,user__r.Name,Total_Commission_Payout_Amount_Now__c,POT_Type__c,Employee_ID__c FROM Invoice_Bundle__c WHERE user__c <> null AND Id IN:salesAssociateBundleIdset];
        for(Invoice_Bundle__c inv: invoiceBundleEmpList){
            CommissionEntryList.add(new CommissionEntry(inv.user__r.Name, inv.Total_Commission_Payout_Amount_Now__c, inv.Employee_ID__c, inv.POT_Type__c));
            this.employessTotalAmount += inv.Total_Commission_Payout_Amount_Now__c;
        }
        this.employessCount = invoiceBundleEmpList.size();
        return CommissionEntryList;
    }
    
    public List <CommissionEntry> getManagerCommission() {
        this.managersTotalAmount = 0;
        List<CommissionEntry> CommissionEntryList = new List<CommissionEntry>();
        List<Invoice_Bundle__c> invoiceBundleMgrList = [SELECT Id,user__c,user__r.Name,Total_Commission_Payout_Amount_Now__c,POT_Type__c,Employee_ID__c FROM Invoice_Bundle__c WHERE user__c <> null AND ID IN:managerBundleIdset];
        Decimal managersCount = 0;
        for(Invoice_Bundle__c inv:invoiceBundleMgrList){
            CommissionEntryList.add(new CommissionEntry(inv.user__r.Name, inv.Total_Commission_Payout_Amount_Now__c, inv.Employee_ID__c, inv.POT_Type__c));
            this.managersTotalAmount += inv.Total_Commission_Payout_Amount_Now__c; 
            if(inv.POT_Type__c == 'Sales Manager'){
                managersCount += 1;
            }
        }
        this.managersCount = managersCount;
        return CommissionEntryList;
    }
    public String getFormattedCurrentDate() {
        return Datetime.now().format('dd MMMM yyyy');
    }
    public String getCurrentMonthYear(){
        DateTime now = System.now();
        String currentMonthYear = now.format('MMMM yyyy');
        
        Date today = System.today();
        Map<Integer, String> monthNames = new Map<Integer, String>{
            1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April', 5 => 'May', 6 => 'June',
                7 => 'July', 8 => 'August', 9 => 'September', 10 => 'October', 11 => 'November', 12 => 'December'
                };
                    String monthName = monthNames.get(today.month());
        String currentMonthYear2 = monthName + ' ' + String.valueOf(today.year());
        System.debug('Option 2 - Current Month and Year: ' + currentMonthYear2);
        return currentMonthYear2;
    }
}