public with sharing class CommissionStatementHelper {
    public String Name { get; set; }
    public String month { get; set; }
    public Date statementDate { get; set; }
    public boolean isSalesManager {get;set;}
    public boolean overRideCommission {get;set;}
    public Decimal overRideCommissionAmt {get;set;}
    public String overRideAdjustmentCommissionAmt{get;set;}
    public String overRideCommissionReason {get;set;}
    public Decimal totalCommissionOnthisMonth { get; set; }
    public Decimal onHoldCommissionOnthisMonth { get; set; }
    public Decimal onHoldPreviousCommission { get; set; }
    public Decimal overAllCommission { get; set; }
    public Decimal totalPreviousCommissionHold { get; set; }
    public List<UnitSummary> unitSummaries { get; set; }
    public List<UnitSummary> ManagerUnitSummaries { get; set; }
    public List<ProjectSummary> projectSummaries { get; set; }
    
    public decimal balancePayableCommissionOnthisMonth {get;set;}
    
    public Decimal totalCommissionNow { get; set; }
    public Decimal totalCommissionHold { get; set; }
    public Decimal totalCommissionPaid { get; set; }
    
    public Decimal salestotalCommissionNow { get; set; }
    public Decimal salestotalCommissionHold { get; set; }
    public Decimal salestotalCommissionPaid { get; set; }
    
    public Decimal totalOverAllCommissionNow {get;set;}
    public Decimal totalCommission75 {get;set;}
    public Decimal totalCommission25 {get;set;}
    /**********************************************/
    public Decimal managertotalCommissionNow { get; set; }
    public Decimal managertotalCommissionHold { get; set; }
    public Decimal managertotalCommissionPaid { get; set; }
    public Decimal managerOverAlltotalCommissionNow {get;set;}
    public Decimal prjManagerOverAlltotalCommissionNow { get; set; }
    public Decimal prjManagerOverAlltotalCommissionHold { get; set; }
    public Decimal managertotalCommission75 {get;set;}
    public Decimal managertotalCommission25 {get;set;}
    public decimal managerTotalSalesValue {get;set;}
    public decimal salesTotalSalesValue {get;set;}
    public Integer unitcount { get; set; }
    
    public decimal totalCommissionasOfnow {get;set;}
    public decimal totalCommissiononheldasofnow {get;set;}
    public decimal totalCommissiononpaidasOfnow {get;set;}
    public CommissionStatementHelper() {
        isSalesManager = false;
        overRideCommission = false;
        statementDate = Date.today();
        Id bundleId = ApexPages.currentPage().getParameters().get('id');
        prjManagerOverAlltotalCommissionNow = 0;
        prjManagerOverAlltotalCommissionHold = 0;
        unitSummaries = new List<UnitSummary>();
        ManagerUnitSummaries = new List<UnitSummary>();
        projectSummaries = new List<ProjectSummary>();
        totalCommissionNow = 0;
        totalCommissionHold = 0;
        totalCommissionPaid = 0;
        managerTotalSalesValue = 0;
        salesTotalSalesValue = 0;
        
        salestotalCommissionNow = 0;
        salestotalCommissionHold = 0;
        salestotalCommissionPaid = 0;
        
        onHoldPreviousCommission = 0;
        overAllCommission = 0;
        totalCommissionOnthisMonth = 0;
        onHoldCommissionOnthisMonth = 0;
        totalPreviousCommissionHold = 0;
        balancePayableCommissionOnthisMonth = 0;
        
        totalOverAllCommissionNow = 0;
        totalCommission75 = 0;
        totalCommission25 = 0;
        
        managertotalCommissionNow = 0;
        managertotalCommissionHold = 0;
        managertotalCommissionPaid = 0;
        managerOverAlltotalCommissionNow = 0;
        managertotalCommission75 = 0;
        managertotalCommission25 = 0;
        overRideAdjustmentCommissionAmt = 'AED 0';
        unitcount = 0;
        
        totalCommissionasOfnow = 0;
        totalCommissiononheldasofnow = 0;
        totalCommissiononpaidasOfnow = 0;
        if (bundleId == null) {
            Name = 'N/A';
            month = 'N/A';
            totalCommissionOnthisMonth = 0;
            onHoldCommissionOnthisMonth = 0;
            return;
        }
        
        
        
        Invoice_Bundle__c bundle = [
            SELECT Id, Commission_Month__c,User__c, User__r.Name,
            Total_Commission_Payout_Amount_Now__c,
            Total_Commission_Pending__c,POT_Type__c,
            Override_Payout_Amount__c,Actual_Total_Commission_Payout_Now__c,
            Override_Payout_Amount_Reason__c,Current_On_Hold_Commission__c,Current_On_Hold_Commission_Reason__c
            FROM Invoice_Bundle__c
            WHERE Id = :bundleId
            LIMIT 1
        ];
        overRideCommission = bundle.Current_On_Hold_Commission__c > 0 || bundle.Override_Payout_Amount__c > 0 ? true : false;
        overRideCommissionAmt = bundle.Current_On_Hold_Commission__c > 0 && ((bundle.Actual_Total_Commission_Payout_Now__c - bundle.Current_On_Hold_Commission__c) > 0 || (bundle.Actual_Total_Commission_Payout_Now__c - bundle.Current_On_Hold_Commission__c) == 0)? (bundle.Actual_Total_Commission_Payout_Now__c - bundle.Current_On_Hold_Commission__c) :bundle.Override_Payout_Amount__c > 0 ? bundle.Override_Payout_Amount__c : 0;
        overRideCommissionReason = bundle.Override_Payout_Amount_Reason__c <> null ? bundle.Override_Payout_Amount_Reason__c : bundle.Current_On_Hold_Commission_Reason__c <> null ? bundle.Current_On_Hold_Commission_Reason__c : '' ;
        Decimal overRideAdjustmentCommissionAmtValue = bundle.Current_On_Hold_Commission__c <> null ? bundle.Current_On_Hold_Commission__c.setScale(2, RoundingMode.HALF_UP) : 0;
        overRideAdjustmentCommissionAmt = overRideAdjustmentCommissionAmtValue <> null ? overRideAdjustmentCommissionAmtValue < 0 ? 'AED '+String.valueOf(-overRideAdjustmentCommissionAmtValue) : '- AED '+String.valueOf(overRideAdjustmentCommissionAmtValue):'AED 0.00';
        for(Commission_Line__c cli:[SELECT Id,Commission_Amount__c,Total_Commission_Amount_Pending__c,Total_Commission_Amount_Paid__c FROM Commission_Line__c WHERE Commission_POT__r.User__c =:bundle.User__c AND (NOT Sales_Order__r.Status__c LIKE '%Cancelled%')]){
            totalCommissionasOfnow += cli.Commission_Amount__c;
            totalCommissiononheldasofnow += cli.Total_Commission_Amount_Pending__c;
            totalCommissiononpaidasOfnow +=  cli.Total_Commission_Amount_Paid__c;
        }
        isSalesManager = bundle.POT_Type__c == 'Sales Manager' ? true:false;
        Name = bundle.User__r.Name;
        month = bundle.Commission_Month__c;
        //overAllCommission = bundle.Total_Commission_Payout_Amount_Now__c;
        //onHoldCommissionOnthisMonth = bundle.Total_Commission_Pending__c;
        Map<Id,List<Commission_Line_Item__c>> cpayoutLineItemMap = new Map<Id,List<Commission_Line_Item__c>>();
        List<Invoice_Line__c> lines = [
            SELECT Project_Name__c,Sales_Agent__c, Unit_Name__c, Category_Of_Sale__c, Type_Of_Commission__c,Total_Commission_Amount__c,Pending_Commission_Amount__c,Current_Commission_Payout_Now__c,Commission_Amount_Already_Paid__c,Commission_Payout_Percent__c,Team_Commission_Amount__c,
            Commission_Line__c,Commission_Line__r.Total_Commission_Amount_Paid__c,Commission_Line__r.Total_Commission_Amount_Pending__c,Commission_Line__r.Commission_Amount__c FROM Invoice_Line__c
            WHERE Invoice_Bundle__c = :bundleId
        ];
        Set<Id> commissionLineIdset = new Set<Id>();
        for(Invoice_Line__c invL: lines){
            commissionLineIdset.add(invL.Commission_Line__c);
        }
        for(Commission_Line_Item__c cliP:[SELECT Id,Commission_Payout_Amount__c,Commission_Payout_Percent__c,Expected_Commision_Payout_Amount__c,Commission_Line__c FROM Commission_Line_Item__c WHERE Commission_Line__c IN:commissionLineIdset]){
            if(cpayoutLineItemMap.containsKey(cliP.Commission_Line__c)){
                cpayoutLineItemMap.get(cliP.Commission_Line__c).add(cliP);
            }else{
                cpayoutLineItemMap.put(cliP.Commission_Line__c,new List<Commission_Line_Item__c>{cliP});
            }   
        }
        //********************* TotalCommissionAmtforThisMonth*******************//
        Map<String,ProjectSummary> projectSummaryMap = new Map<String,ProjectSummary>();
        Set<String> unitNames = new Set<String>();
        
        for(Invoice_Line__c linesOBJ:lines){
            if(linesOBJ.Commission_Amount_Already_Paid__c == 0 ){ //Commission_Line__r.Total_Commission_Amount_Paid__c == 0){
                
                prjManagerOverAlltotalCommissionNow += linesOBJ.Current_Commission_Payout_Now__c;
                
                if(projectSummaryMap.containsKey(linesOBJ.Project_Name__c)){
                    ProjectSummary pSummary = projectSummaryMap.get(linesOBJ.Project_Name__c);
                    pSummary.projectName = linesOBJ.Project_Name__c;
                    if(!unitNames.contains(linesOBJ.Unit_Name__c)){
                        unitcount += 1;
                        pSummary.unitsSold += 1;
                        totalCommissionOnthisMonth += linesOBJ.Total_Commission_Amount__c;//.Commission_Line__r.Commission_Amount__c;
                        pSummary.commissionHold += linesOBJ.Pending_Commission_Amount__c;//Commission_Line__r.Total_Commission_Amount_Pending__c;
                        totalCommissionHold += linesOBJ.Pending_Commission_Amount__c;//Commission_Line__r.Total_Commission_Amount_Pending__c;
                        prjManagerOverAlltotalCommissionHold  += linesOBJ.Pending_Commission_Amount__c;//Commission_Line__r.Total_Commission_Amount_Pending__c;
                        pSummary.commissionNow += linesOBJ.Total_Commission_Amount__c;//Commission_Line__r.Commission_Amount__c;
                        totalCommissionNow += linesOBJ.Total_Commission_Amount__c;//Commission_Line__r.Commission_Amount__c;
                    }
                    projectSummaryMap.put(linesOBJ.Project_Name__c,pSummary);                    
                }else{
                    
                    ProjectSummary pSummary = new ProjectSummary();
                    pSummary.projectName = linesOBJ.Project_Name__c;
                    pSummary.unitsSold = 1;
                    //pSummary.commissionNow = linesOBJ.Current_Commission_Payout_Now__c;
                    if(!unitNames.contains(linesOBJ.Unit_Name__c)){ 
                        unitcount += 1;
                        pSummary.commissionHold = linesOBJ.Pending_Commission_Amount__c;//Commission_Line__r.Total_Commission_Amount_Pending__c;
                        totalCommissionOnthisMonth += linesOBJ.Total_Commission_Amount__c;//Commission_Line__r.Commission_Amount__c;
                        totalCommissionHold += linesOBJ.Pending_Commission_Amount__c;//Commission_Line__r.Total_Commission_Amount_Pending__c;
                        prjManagerOverAlltotalCommissionHold  += linesOBJ.Pending_Commission_Amount__c;//Commission_Line__r.Total_Commission_Amount_Pending__c;
                        pSummary.commissionNow += linesOBJ.Total_Commission_Amount__c;//Commission_Line__r.Commission_Amount__c;
                        totalCommissionNow += linesOBJ.Total_Commission_Amount__c;//Commission_Line__r.Commission_Amount__c;
                    }
                    
                    projectSummaryMap.put(linesOBJ.Project_Name__c,pSummary);
                }
                
            }
            if(linesOBJ.Commission_Amount_Already_Paid__c == 0 ){ 
                if(!unitNames.contains(linesOBJ.Unit_Name__c)){
                    onHoldCommissionOnthisMonth += linesOBJ.Pending_Commission_Amount__c;//Commission_Line__r.Total_Commission_Amount_Pending__c;
                }
            }
            if(linesOBJ.Commission_Amount_Already_Paid__c > 0 ){ //if(linesOBJ.Commission_Line__r.Total_Commission_Amount_Paid__c > 0){
                onHoldPreviousCommission += linesOBJ.Current_Commission_Payout_Now__c;
                if(projectSummaryMap.containsKey(linesOBJ.Project_Name__c)){
                    ProjectSummary pSummary = projectSummaryMap.get(linesOBJ.Project_Name__c);
                    pSummary.projectName = linesOBJ.Project_Name__c;
                    pSummary.previouscommissionHold += linesOBJ.Current_Commission_Payout_Now__c;
                    projectSummaryMap.put(linesOBJ.Project_Name__c,pSummary);                    
                }else{
                    ProjectSummary pSummary = new ProjectSummary();
                    pSummary.projectName = linesOBJ.Project_Name__c;
                    pSummary.previouscommissionHold = linesOBJ.Current_Commission_Payout_Now__c;
                    projectSummaryMap.put(linesOBJ.Project_Name__c,pSummary);
                }
            }
            
            unitNames.add(linesOBJ.Unit_Name__c);
        }
        for(String pSm :projectSummaryMap.keySet()){
            ProjectSummary pSummary = new ProjectSummary();
            pSummary.projectName = projectSummaryMap.get(pSm).projectName;
            pSummary.unitsSold = projectSummaryMap.get(pSm).unitsSold;
            pSummary.commissionNow = projectSummaryMap.get(pSm).commissionNow;
            pSummary.commissionHold = projectSummaryMap.get(pSm).commissionHold;
            pSummary.previouscommissionHold = projectSummaryMap.get(pSm).previouscommissionHold;
            pSummary.balancePayablenow = pSummary.commissionNow - pSummary.commissionHold;
            pSummary.currentpayableNow = pSummary.balancePayablenow + pSummary.previouscommissionHold; 
            projectSummaries.add(pSummary);
        }
        overAllCommission = (totalCommissionOnthisMonth + onHoldPreviousCommission) - onHoldCommissionOnthisMonth;
        balancePayableCommissionOnthisMonth = totalCommissionOnthisMonth - onHoldCommissionOnthisMonth;
        //*************************************************************************************//
        
        //**** Manager Own Commission *********************************************************//
        Set<String> unitNameset = new Set<String>();
        Map<String,UnitSummary> managerunitSummaryMap = new Map<String,UnitSummary>();

        for(Invoice_Line__c inv:[
            SELECT Project_Name__c,Sales_Agent__c, Unit_Name__c, Category_Of_Sale__c, Type_Of_Commission__c,Total_Commission_Amount__c,Pending_Commission_Amount__c,Current_Commission_Payout_Now__c,Commission_Amount_Already_Paid__c,Commission_Payout_Percent__c,Team_Commission_Amount__c,Commission_Line__r.Lead_Source__c,Is_Hold__c,
            Commission_Line__r.Current_Commission_Payout_Now__c,Commission_Line__c,Commission_Line__r.Total_Commission_Amount_Paid__c,Commission_Line__r.Total_Commission_Amount_Pending__c,Commission_Line__r.Commission_Amount__c,Commission_Line__r.Commission_Payout_Amount_Now__c,Commission_Line__r.Total_Unit_Price__c FROM Invoice_Line__c
            WHERE Invoice_Bundle__c = :bundleId AND Commission_Line__r.Sales_Agent__c = null
        ]){
            if(cpayoutLineItemMap.containsKey(inv.Commission_Line__c)){ //} && !unitNameset.contains(inv.Unit_Name__c)){
                UnitSummary uSummary = new UnitSummary();
                 if(managerunitSummaryMap.containsKey(inv.Unit_Name__c)){
                    uSummary = managerunitSummaryMap.get(inv.Unit_Name__c);
                    uSummary.commissionNow += inv.Current_Commission_Payout_Now__c;//Commission_Line__r.Current_Commission_Payout_Now__c;
                    managertotalCommissionNow += inv.Current_Commission_Payout_Now__c;//Commission_Line__r.Current_Commission_Payout_Now__c;
                    system.debug('unitname++'+inv.Unit_Name__c);
                }else{
                uSummary.projectName = inv.Project_Name__c;
                uSummary.unitName = inv.Unit_Name__c;
                uSummary.salesCategory = inv.Category_Of_Sale__c;
                uSummary.leadSource = inv.Commission_Line__r.Lead_Source__c;
                uSummary.salesValue = inv.Commission_Line__r.Total_Unit_Price__c;
                uSummary.commissionType = inv.Type_Of_Commission__c;
                uSummary.commissionTotalAmt = inv.Total_Commission_Amount__c;//Commission_Line__r.Commission_Amount__c;
                uSummary.commissionNow = inv.Current_Commission_Payout_Now__c;//Commission_Line__r.Current_Commission_Payout_Now__c;
                uSummary.commissionHold = inv.Pending_Commission_Amount__c;//Commission_Line__r.Total_Commission_Amount_Pending__c;
                uSummary.commissionPaid = inv.Commission_Amount_Already_Paid__c;//Commission_Line__r.Total_Commission_Amount_Paid__c;
                
                managerOverAlltotalCommissionNow += inv.Total_Commission_Amount__c;//Commission_Line__r.Commission_Amount__c;
                managertotalCommissionNow += inv.Current_Commission_Payout_Now__c;//Commission_Line__r.Current_Commission_Payout_Now__c;
                managertotalCommissionHold += inv.Commission_Amount_Already_Paid__c;//Commission_Line__r.Total_Commission_Amount_Paid__c;
                managertotalCommissionPaid += inv.Pending_Commission_Amount__c;//Commission_Line__r.Total_Commission_Amount_Pending__c;
                managerTotalSalesValue += inv.Commission_Line__r.Total_Unit_Price__c;
                for(Commission_Line_Item__c cli: cpayoutLineItemMap.get(inv.Commission_Line__c)){
                    if(cli.Commission_Payout_Percent__c == 75){
                        uSummary.commissionPayoutPercent75 = cli.Expected_Commision_Payout_Amount__c;
                        managertotalCommission75 += cli.Expected_Commision_Payout_Amount__c;
                    }
                    if(cli.Commission_Payout_Percent__c == 25){
                        uSummary.commissionPayoutPercent25 = cli.Expected_Commision_Payout_Amount__c;
                        managertotalCommission25 += cli.Expected_Commision_Payout_Amount__c;
                    }
                }
                uSummary.isHold = inv.Is_Hold__c ? 'Yes' : 'No';
                ManagerUnitSummaries.add(uSummary);
                unitNameset.add(inv.Unit_Name__c);
                managerunitSummaryMap.put(inv.Unit_Name__c,uSummary);
                }
            }
        }
        
        //****Sales Person Commission *********************************************************//
        unitNameset = new Set<String>();
        Map<String,UnitSummary> unitSummaryMap = new Map<String,UnitSummary>();
        for(Invoice_Line__c inv:[
            SELECT Project_Name__c,Sales_Agent__c, Unit_Name__c, Category_Of_Sale__c, Type_Of_Commission__c,Total_Commission_Amount__c,Pending_Commission_Amount__c,Current_Commission_Payout_Now__c,Commission_Amount_Already_Paid__c,Commission_Payout_Percent__c,Team_Commission_Amount__c,Commission_Line__r.Total_Unit_Price__c,Is_Hold__c,
            Commission_Line__r.Current_Commission_Payout_Now__c,Commission_Line__c,Commission_Line__r.Total_Commission_Amount_Paid__c,Commission_Line__r.Total_Commission_Amount_Pending__c,Commission_Line__r.Commission_Amount__c,Commission_Line__r.Commission_Payout_Amount_Now__c,Commission_Line__r.Lead_Source__c FROM Invoice_Line__c
            WHERE Invoice_Bundle__c = :bundleId AND Commission_Line__r.Sales_Agent__c != null
        ]){
            
            if(cpayoutLineItemMap.containsKey(inv.Commission_Line__c)){ //} && !unitNameset.contains(inv.Unit_Name__c)){
                UnitSummary uSummary = new UnitSummary();
                if(unitSummaryMap.containsKey(inv.Unit_Name__c)){
                    uSummary = unitSummaryMap.get(inv.Unit_Name__c);
                    uSummary.commissionNow += inv.Current_Commission_Payout_Now__c;//Commission_Line__r.Current_Commission_Payout_Now__c;
                    salestotalCommissionNow += inv.Current_Commission_Payout_Now__c;//Commission_Line__r.Current_Commission_Payout_Now__c;
                    system.debug('unitname++'+inv.Unit_Name__c);
                }else{
                    system.debug('unitname22++'+inv.Unit_Name__c);
                    uSummary.commissionNow = inv.Current_Commission_Payout_Now__c;//Commission_Line__r.Current_Commission_Payout_Now__c;
                    salestotalCommissionNow += inv.Current_Commission_Payout_Now__c;//Commission_Line__r.Current_Commission_Payout_Now__c;
                    
                    
                    uSummary.SalesAssociate = inv.Sales_Agent__c;
                    uSummary.projectName = inv.Project_Name__c;
                    uSummary.unitName = inv.Unit_Name__c;
                    uSummary.leadSource = inv.Commission_Line__r.Lead_Source__c;
                    uSummary.salesValue = inv.Commission_Line__r.Total_Unit_Price__c;
                    uSummary.salesCategory = inv.Category_Of_Sale__c;
                    uSummary.commissionType = inv.Type_Of_Commission__c;
                    uSummary.commissionTotalAmt = inv.Total_Commission_Amount__c;//Commission_Line__r.Commission_Amount__c;
                    uSummary.commissionHold = inv.Pending_Commission_Amount__c;//Commission_Line__r.Total_Commission_Amount_Pending__c;
                    uSummary.commissionPaid = inv.Commission_Amount_Already_Paid__c;//Commission_Line__r.Total_Commission_Amount_Paid__c;
                    salesTotalSalesValue += inv.Commission_Line__r.Total_Unit_Price__c;
                    totalOverAllCommissionNow += inv.Total_Commission_Amount__c;//Commission_Line__r.Commission_Amount__c;
                    salestotalCommissionHold  += inv.Pending_Commission_Amount__c;//Commission_Line__r.Total_Commission_Amount_Pending__c;
                    salestotalCommissionPaid += inv.Commission_Amount_Already_Paid__c;//Commission_Line__r.Total_Commission_Amount_Paid__c;
                    
                    for(Commission_Line_Item__c cli: cpayoutLineItemMap.get(inv.Commission_Line__c)){
                        if(cli.Commission_Payout_Percent__c == 75){
                            uSummary.commissionPayoutPercent75 = cli.Expected_Commision_Payout_Amount__c;
                            totalCommission75 += cli.Expected_Commision_Payout_Amount__c;
                        }
                        if(cli.Commission_Payout_Percent__c == 25){
                            uSummary.commissionPayoutPercent25 = cli.Expected_Commision_Payout_Amount__c;
                            totalCommission25 += cli.Expected_Commision_Payout_Amount__c;
                        }
                    }
                    uSummary.iSHold = inv.Is_Hold__c ? 'Yes' : 'No';
                    unitSummaries.add(uSummary);
                    unitNameset.add(inv.Unit_Name__c);
                    unitSummaryMap.put(inv.Unit_Name__c,uSummary);
                }
            }else if(unitSummaryMap.containsKey(inv.Unit_Name__c)){
                
            }
        }
        
    }
    
    public class UnitSummary {
        public String projectName { get; set; }
        public String unitName { get; set; }
        public String salesCategory { get; set; }
        public String commissionType { get; set; }
        public String salesAssociate { get; set; }
        public String leadSource { get; set; }
        public Decimal salesValue { get; set; }
        public Decimal commissionNow { get; set; }
        public Decimal commissionHold { get; set; }
        public Decimal commissionPaid { get; set; }
        public Decimal commissionTotalAmt {get;set;}
        public Decimal commissionPayoutPercent {get;set;}
        public Decimal teamCommissionAmt {get;set;}
        public Decimal commissionPayoutPercent75 {get;set;}
        public Decimal commissionPayoutPercent25 {get;set;}
        public String isHold {get;set;}
        public UnitSummary() {
            this.salesValue = 0;
            this.commissionNow = 0;
            this.commissionHold = 0;
            this.commissionPaid = 0;
            this.commissionTotalAmt = 0;
            this.commissionPayoutPercent = 0;
            this.teamCommissionAmt = 0;
            this.commissionPayoutPercent75 = 0;
            this.commissionPayoutPercent25 = 0;
            this.isHold = 'No';
        }
    }
    
    public class ProjectSummary {
        public String projectName { get; set; }
        public Integer unitsSold { get; set; }
        public Decimal commissionNow { get; set; }
        public Decimal commissionHold { get; set; } 
        public Decimal commissionPaid { get; set; }
        public Decimal balancePayablenow { get; set; }
        public Decimal currentpayableNow { get; set; }
        public Decimal previouscommissionHold {get;set;}
        public ProjectSummary() {
            this.projectName = '';
            this.unitsSold = 0;
            this.commissionNow = 0;
            this.commissionHold = 0;
            this.previouscommissionHold = 0;
            this.balancePayablenow = 0;
            this.currentpayableNow = 0;
        }
    }
    @Future(callout=true)
    public static void callingFromTrigger(String bundleId){
        generatePDF(bundleId);
    }
    @AuraEnabled 
    public static void generatePDF(String bundleId){
        Invoice_Bundle__c bundle = [
            SELECT Id, Commission_Month__c, User__r.Name,
            Total_Commission_Payout_Amount_Now__c,
            Total_Commission_Pending__c
            FROM Invoice_Bundle__c
            WHERE Id = :bundleId
            LIMIT 1
        ];
        
        String Name = bundle.User__r.Name;
        String month = bundle.Commission_Month__c;
        PageReference pdfPage = Page.CommissionInvoicePDFController;
        pdfPage.getParameters().put('id', bundleId); 
        
        // Render page as blob
        Blob pdfBlob;
    if (Test.isRunningTest()) {
        pdfBlob = Blob.valueOf('Test PDF Content'); // dummy content
    } else {
        pdfBlob = pdfPage.getContentAsPDF();
    }
        
        // Create ContentVersion (File)
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Commission Statement Of Account for '+month+'-' + Name;
        cv.PathOnClient = 'Commission Statement Of Account for '+month+'-' + Name+'.pdf';
        cv.VersionData = pdfBlob;
        cv.IsMajorVersion = true;
        insert cv;
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        cdl.LinkedEntityId = bundleId; 
        cdl.ShareType = 'V'; // Viewer
        insert cdl;
    }
}