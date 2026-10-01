/**********************************************************************************************************************
* Name               : CommissionLogicHandler                                                        
* Description        : This class is used to handle all the Commission related automation logics
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0          dinesh.selvam@modon.com              05/10/2025      Initial Draft
* 2.0          Dinesh Selvam                        25/04/2026      Added logic for Broker & Project Type based commission
**********************************************************************************************************************/
public without sharing class CommissionLogicHandler {
    /** Handle Internal Commission line creation & logics **/
    public static void createCommissionLine(List<SalesOrder__c> salesOrderList){
        List<Commission_Line__c> commissionLineList = new List<Commission_Line__c>();
        List<Commission_Line__c> brokercommissionLineList = new List<Commission_Line__c>();
        List<SalesOrder__c> externalSOList = new List<SalesOrder__c>();
        List<SalesOrder__c> soList = new List<SalesOrder__c>();
        Set<Id> soIdset = new Set<Id>();
        Set<Id> onwerIdset = new Set<Id>();
        Id recordTypeId;
        for(SalesOrder__c so:salesOrderList){
            soIdset.add(so.Id); 
            onwerIdset.add(so.OwnerId);
        }
        Map<Id,Commission_POT__c> ownerManagerIdMap = new Map<Id,Commission_POT__c>();
        for(Commission_POT__c cpot:[SELECT Id,Reporting_To__r.User__c,User__c,Reporting_To__r.POT_Type__c,POT_Type__c FROM Commission_POT__c WHERE User__c IN:onwerIdset AND POT_Type__c IN ('Sales Associate','Sales Manager')]){
            ownerManagerIdMap.put(cpot.User__c,cpot);
        }
        soList = [SELECT Id,Opportunity__c,Category_Of_Sale__c,CreatedDate,PaymentPlan__c,OwnerId,Opportunity__r.BrokerAgency__c,Opportunity__r.BrokerAgent__c,TotalAmount__c,Opportunity__r.LeadSource,Booking_Date__c,Unit__r.Unit_Launch_Date__c,Unit__r.Unit_Sold_Date__c,SOCreationDate__c,
                  Unit__r.Phase__c,Unit__r.Phase__r.Project__c,Unit__r.Phase__r.Project__r.Launch_Date__c,Referral_Type__c,Unit_Allocated_Status__c,unit__r.Number_of_Bedrooms__c,Unit__r.Phase__r.LaunchStartDate__c FROM SalesOrder__c WHERE Id IN:soIdset];
        Map<String,Commission_Rules__c> salesOrderCommissionMap = getCommissionRule(soList);
        System.debug('salesOrderCommissionMap:'+salesOrderCommissionMap);
        Map<String,Id> soCommissionRuleMap = new Map<String,Id>();
        for(SalesOrder__c so: soList){
            String key = generateKeySO(so);
            system.debug('key:'+key);
            String key1 = key <> null && so.unit__r.Number_of_Bedrooms__c <> null ? key+'-'+ so.unit__r.Number_of_Bedrooms__c:null;
            if(salesOrderCommissionMap.containsKey(key1) && salesOrderCommissionMap.get(key1) <> null){
                soCommissionRuleMap.put(key1,salesOrderCommissionMap.get(key1).Id);
            }
            else if(salesOrderCommissionMap.containsKey(key) && salesOrderCommissionMap.get(key) <> null){
                soCommissionRuleMap.put(key,salesOrderCommissionMap.get(key).Id);
            }
        }
        Set<Id> salesOrderIdset = new Set<Id>();
        Map<Id,List<Commission_Payout_Line__c>> commissionPayoutLineMap = getCommissionPayoutItems(soCommissionRuleMap.values());
        for(SalesOrder__c so: soList){
            String key2 = generateKeySO(so);
            String key1 = key2 <> null && so.unit__r.Number_of_Bedrooms__c <> null ? key2+'-'+ so.unit__r.Number_of_Bedrooms__c:null;
			String key = null;
            if(soCommissionRuleMap.containsKey(key1) && soCommissionRuleMap.get(key1) <> null){
                key = key1;
            }else if(soCommissionRuleMap.containsKey(key2) && soCommissionRuleMap.get(key2) <> null){
                 key = key2;
            }
            
            if(key <> null || Test.isRunningTest()){
                Id salesManager = null;
                Id salesAssociate = null;
                if(ownerManagerIdMap.containsKey(so.OwnerId)){
                    salesManager = ownerManagerIdMap.get(so.OwnerId).POT_Type__c == 'Sales Manager' ? so.OwnerId:(ownerManagerIdMap.get(so.OwnerId).Reporting_To__c <> null && ownerManagerIdMap.get(so.OwnerId).Reporting_To__r.POT_Type__c == 'Sales Manager' ? ownerManagerIdMap.get(so.OwnerId).Reporting_To__r.User__c : null); 
                        salesAssociate = ownerManagerIdMap.get(so.OwnerId).POT_Type__c == 'Sales Associate' ? so.OwnerId:null;
                }
                Commission_Rules__c cmrOBJ =salesOrderCommissionMap.get(key);
                for(Commission_POT__c cpot:[SELECT Id,Reporting_To__r.User__c,User__c,Reporting_To__r.POT_Type__c,POT_Type__c,Split_Type__c,Commission_Percent__c FROM Commission_POT__c]){
                    Commission_Line__c cml = new Commission_Line__c();
                    cml.Sales_Order__c = so.Id;
                    cml.Opportunity__c = so.Opportunity__c;
                    cml.Payment_Plan__c = so.PaymentPlan__c;
                    cml.Commission_Rules__c = cmrOBJ.Id;
                    cml.Commission_Type__c = so.Opportunity__r.BrokerAgency__c <> null ? 'Indirect':'Direct';
                    cml.RecordTypeId =Schema.SObjectType.Commission_Line__c.getRecordTypeInfosByName().get('Internal').getRecordTypeId(); 
                    cml.Status__c = 'Not Reviewed';
                    cml.Sales_Agent__c = salesAssociate;
                    cml.Sales_Manager__c = salesManager;
                    cml.Commission_Line_Type__c = 'Internal';
                    cml.Lead_Source__c = so.Opportunity__r.LeadSource;
                    cml.Category_Of_Sale__c = so.Category_Of_Sale__c;
                    cml.Booking_Date__c = so.Booking_Date__c <> null ? so.Booking_Date__c : so.Unit__r.Unit_Sold_Date__c;
                    cml.Unit_Launch_Date__c = so.Unit__r.Unit_Launch_Date__c <> null ? so.Unit__r.Unit_Launch_Date__c : null;
                    if(cpot.Split_Type__c == 'Total Gross Sales Value'){
                        cml.Commission_POT__c = cpot.Id;
                        cml.Commission_Percent__c = cpot.Commission_Percent__c;
                    }else if(cpot.Split_Type__c == 'Indirect - Total Gross Sales Value' && cml.Commission_Type__c == 'Indirect'){
                        cml.Commission_POT__c = cpot.Id;
                        cml.Commission_Percent__c = cpot.Commission_Percent__c;
                    }else if((cpot.Split_Type__c == 'Individual Commission' && cpot.User__c == so.OwnerId) || (cpot.POT_Type__c == 'Sales Manager' && cpot.User__c == so.OwnerId)){
                        cml.Commission_POT__c = cpot.Id;
                        if(so.Referral_Type__c <> null){
                            if(so.Unit_Allocated_Status__c == 'Allocated'){
                                cml.Commission_Amount__c = cmrOBJ.Management_Referral_Amount_UnitAllocated__c;
                            }else if(so.Unit_Allocated_Status__c == 'Un-Allocated'){
                                cml.Commission_Percent__c = cmrOBJ.Management_Referral_Unit_Unallocated__c;
                            }
                        }else if(cml.Commission_Type__c == 'Direct'){
                            cml.Commission_Percent__c = cmrOBJ.Direct_Commission__c;
                            if(cpot.POT_Type__c == 'Sales Manager'){
                                cml.Commission_Percent__c = cmrOBJ.Direct_Commission_Sales_Manager__c;
                            }
                        }else if(cml.Commission_Type__c == 'Indirect'){
                            cml.Commission_Amount__c = cmrOBJ.Indirect_Commission_Amount_Internal__c;
                            if(cpot.POT_Type__c == 'Sales Manager'){
                                cml.Commission_Amount__c = cmrOBJ.Indirect_Commission_Amount_Intrl_Mgr__c;
                            }
                        }
                    }else if(cpot.Split_Type__c == 'Team Commission Value' && ownerManagerIdMap.containsKey(so.OwnerId) && ownerManagerIdMap.get(so.OwnerId).Reporting_To__c <> null && ownerManagerIdMap.get(so.OwnerId).Reporting_To__r.user__c == cpot.User__c && cml.Commission_Type__c != 'Indirect'){
                        cml.Commission_POT__c = cpot.Id;                        
                    }else if(cpot.Split_Type__c == 'Team Gross Sales Value' && (salesManager <> null && ownerManagerIdMap.containsKey(salesManager) && ownerManagerIdMap.get(salesManager).Reporting_To__c <> null && ownerManagerIdMap.get(salesManager).Reporting_To__r.user__c == cpot.User__c || (ownerManagerIdMap.containsKey(so.OwnerId) && ownerManagerIdMap.get(so.OwnerId).Reporting_To__c <> null && ownerManagerIdMap.get(so.OwnerId).Reporting_To__r.user__c == cpot.User__c ))){
                        cml.Commission_POT__c = cpot.Id;
                        cml.Commission_Percent__c = cpot.Commission_Percent__c;
                    }
                    if(cml.Commission_POT__c <> null){
                        if(cml.Commission_Amount__c == null && cml.Commission_Percent__c <> null){
                            cml.Commission_Amount__c = so.TotalAmount__c * (cml.Commission_Percent__c/100);
                        }
                        commissionLineList.add(cml);
                        salesOrderIdset.add(so.Id);
                    }
                }
            } 
        }
        if(!commissionLineList.isEmpty()){
            insert commissionLineList;
        }
        List<SalesOrder__c> soListUpdate = new List<SalesOrder__c>();
        for(Id soId: salesOrderIdset){
            SalesOrder__c soOBJ = new  SalesOrder__c();
            soOBJ.Id = soId;
            soOBJ.IsCommissionLineExist__c = true;
            soListUpdate.add(soOBJ);
        }
        if(!soListUpdate.isEmpty()){
           // update soListUpdate;
        }
        if(!soIdset.isEmpty()){
            teamCommissionValueCalculate(soIdset);
        }
    }
    /** Handle External Commission line creation from batch **/
    public static void createExternalCommissions(List<SalesOrder__c> salesOrderList){
        createExternalCommissionsHelper(salesOrderList,null,null,false);
    }
    /** Handle External Commission line creation logic **/
    public static void createExternalCommissionsHelper(List<SalesOrder__c> salesOrderList,Id commissionLineId,decimal commissionPercent,boolean isRecalc){
        Set<Id> soIdset = new Set<Id>();
        Set<Id> ownerIdset = new Set<Id>();
        for(SalesOrder__c so:salesOrderList){
            soIdset.add(so.Id);
            ownerIdset.add(so.OwnerId);
        }
        Map<String,String> existingCommissionMap = new Map<String,String>();
        for(Commission_Line__c cliSO:[SELECT Id,Sales_Order__c,Commission_Line_Type__c,External_Commission_Payout__c FROM Commission_Line__c WHERE Sales_Order__c IN:soIdset AND Commission_Line_Type__c = 'External']){
            existingCommissionMap.put(cliSO.Sales_Order__c+':'+cliSO.External_Commission_Payout__c+':'+cliSO.Commission_Line_Type__c,cliSO.Sales_Order__c+':'+cliSO.External_Commission_Payout__c+':'+cliSO.Commission_Line_Type__c);
        }
        Map<Id,Commission_POT__c> ownerManagerIdMap = new Map<Id,Commission_POT__c>();
        for(Commission_POT__c cpot:[SELECT Id,Reporting_To__r.User__c,User__c,Reporting_To__r.POT_Type__c,POT_Type__c FROM Commission_POT__c WHERE User__c IN:ownerIdset AND POT_Type__c IN ('Sales Associate','Sales Manager')]){
            ownerManagerIdMap.put(cpot.User__c,cpot);
        }
        
        List<SalesOrder__c> soList = [SELECT Id,Opportunity__c,Category_Of_Sale__c,CreatedDate,PaymentPlan__c,OwnerId,Opportunity__r.BrokerAgency__c,Opportunity__r.BrokerAgent__c,TotalAmount__c,ExternalCommissionPaidPercent__c,Unit__r.Number_of_Bedrooms__c,Booking_Date__c,Unit__r.Phase__r.LaunchStartDate__c,ProjectName__c,
                                      Unit__r.Phase__c,Unit__r.Phase__r.Project__c,Unit__r.Type__c,Unit__r.Phase__r.Project__r.Launch_Date__c,Referral_Type__c,Unit_Allocated_Status__c,Down_Payment_Status__c,SPAStatus__c,Opportunity__r.LeadSource,Unit__r.Unit_Launch_Date__c,SOCreationDate__c FROM SalesOrder__c WHERE Id IN:soIdset];
        Map<String,Commission_Rules__c> salesOrderCommissionMap = getCommissionRule(soList);
        List<Commission_Line__c> brokercommissionLineList = new List<Commission_Line__c>();
        Map<String,Id> soCommissionRuleMap = new Map<String,Id>();
        System.debug('salesOrderCommissionMap::'+salesOrderCommissionMap);
        Set<Id> brokerAccountIdset = new Set<Id>();
        for(SalesOrder__c so: soList){
            brokerAccountIdset.add(so.Opportunity__r.BrokerAgency__c);/** 2.0 - External Commission Broker wise commission config **/
            String key = generateKeySO(so);
            String key1 = key <> null && so.unit__r.Number_of_Bedrooms__c <> null ? key+'-'+ so.unit__r.Number_of_Bedrooms__c:null;

            if(salesOrderCommissionMap.containsKey(key) && salesOrderCommissionMap.get(key) <> null){
                soCommissionRuleMap.put(key,salesOrderCommissionMap.get(key).Id);
            }else if(salesOrderCommissionMap.containsKey(key1) && salesOrderCommissionMap.get(key1) <> null){
                soCommissionRuleMap.put(key1,salesOrderCommissionMap.get(key1).Id);
            }
        }
        /** 2.0 - External Commission Broker wise commission config **/
        Map<String,Exceptional_Brokers__c> externalBrokerCommissionMap = new Map<String,Exceptional_Brokers__c>();
        for(Exceptional_Brokers__c extb: [SELECT Id,Broker_Account__c,Commission_Percent__c,Commission_Rules__c FROM Exceptional_Brokers__c
                                         WHERE Broker_Account__c IN: brokerAccountIdset]){
            externalBrokerCommissionMap.put(extb.Broker_Account__c+':'+extb.Commission_Rules__c,extb);
        }
        System.debug('soCommissionRuleMap::'+soCommissionRuleMap);

        Map<Id,SalesOrder__c> soUpdateListMap = new Map<Id,SalesOrder__c>();
        for(SalesOrder__c so: soList){
           if(so.Opportunity__r.BrokerAgency__c <> null){ 
            String key = generateKeySO(so);
            String key1 = key <> null && so.unit__r.Number_of_Bedrooms__c <> null ? key+'-'+ so.unit__r.Number_of_Bedrooms__c:null;

            Id salesManager = null;
            Id salesAssociate = null;
            decimal totalExternalPaidCommissionPercent = so.ExternalCommissionPaidPercent__c <> null ? so.ExternalCommissionPaidPercent__c:0;
            if(ownerManagerIdMap.containsKey(so.OwnerId)){
                salesManager = ownerManagerIdMap.get(so.OwnerId).POT_Type__c == 'Sales Manager' ? so.OwnerId:(ownerManagerIdMap.get(so.OwnerId).Reporting_To__c <> null && ownerManagerIdMap.get(so.OwnerId).Reporting_To__r.POT_Type__c == 'Sales Manager' ? ownerManagerIdMap.get(so.OwnerId).Reporting_To__r.User__c : null); 
                salesAssociate = ownerManagerIdMap.get(so.OwnerId).POT_Type__c == 'Sales Associate' ? so.OwnerId:null;
            }
            System.debug('Key::'+key);
            String actualKey = null;
            if(soCommissionRuleMap.containsKey(key) && soCommissionRuleMap.get(key) <> null){
                actualKey = key;
            }else if(soCommissionRuleMap.containsKey(key1) && soCommissionRuleMap.get(key1) <> null){
               actualKey = key1; 
            }
            if(actualKey <> null && soCommissionRuleMap.containsKey(actualKey) && soCommissionRuleMap.get(actualKey) <> null){
                Commission_Rules__c cmrOBJ =salesOrderCommissionMap.get(actualKey); 
              
			          //  totalExternalPaidCommissionPercent += cpay.Equity_Commission_Payout__c;
                        Commission_Line__c cml = new Commission_Line__c();
                        if(commissionLineId <> null){
                           cml.Id = commissionLineId; 
                        }
                        cml.Sales_Order__c = so.Id;
                        cml.Opportunity__c = so.Opportunity__c;
                        cml.Payment_Plan__c = so.PaymentPlan__c;
                        cml.Commission_Rules__c = cmrOBJ.Id;
                        cml.Commission_Type__c = so.Opportunity__r.BrokerAgency__c <> null ? 'Indirect':'Direct';
                        cml.RecordTypeId =Schema.SObjectType.Commission_Line__c.getRecordTypeInfosByName().get('External').getRecordTypeId(); 
                        cml.Status__c = 'Not Reviewed';
                        cml.Sales_Agent__c = salesAssociate;
                        cml.Sales_Manager__c = salesManager;
                        cml.Commission_Line_Type__c = 'External';
                		cml.Lead_Source__c = so.Opportunity__r.LeadSource;
                    	cml.Category_Of_Sale__c = so.Category_Of_Sale__c;
                        cml.Broker_Agency__c = so.Opportunity__r.BrokerAgency__c;
                        cml.Broker_Agent__c = so.Opportunity__r.BrokerAgent__c;
                		cml.Booking_Date__c = so.SOCreationDate__c;
                        /** 2.0 - External Commission Broker wise commission config start **/
                        if(commissionPercent <> null){
                            cml.Commission_Percent__c = commissionPercent;
                        }
                        if(!externalBrokerCommissionMap.containsKey(so.Opportunity__r.BrokerAgency__c+':'+cmrOBJ.Id)){
                                cml.Commission_Percent__c = cmrOBJ.Indirect_Commission__c;
                        }else if(externalBrokerCommissionMap.containsKey(so.Opportunity__r.BrokerAgency__c+':'+cmrOBJ.Id)){
                                cml.Commission_Percent__c = externalBrokerCommissionMap.get(so.Opportunity__r.BrokerAgency__c+':'+cmrOBJ.Id).Commission_Percent__c;
                        }
                        if(so.Unit__r.Type__c == 'Mega Mansion' && so.ProjectName__c.contains('Nawayef') && cmrOBJ.NW_Mega_Mansion__c <> null){
                            cml.Commission_Percent__c = cmrOBJ.NW_Mega_Mansion__c;
                        }else if(so.Unit__r.Type__c != 'Mega Mansion' && so.ProjectName__c.contains('Nawayef') && cmrOBJ.NW_Other_Units__c <> null){
                            cml.Commission_Percent__c = cmrOBJ.NW_Other_Units__c;
                        }
                       /** 2.0 - External Commission Broker wise commission config End **/
                        cml.Unit_Launch_Date__c = so.Unit__r.Unit_Launch_Date__c <> null ? so.Unit__r.Unit_Launch_Date__c :  null;
						cml.Commission_Amount__c = (so.TotalAmount__c * (cml.Commission_Percent__c/100));// * (cpay.Equity_Commission_Payout__c/100);
                       // cml.Commission_Payout_SF_ID__c = cpay.Id;
                       // cml.External_Commission_Payout__c = cpay.Equity_Commission_Payout__c;
                        cml.External_Total_Commission_Amount__c = so.TotalAmount__c * (cml.Commission_Percent__c/100);
                        cml.Recalculated__c = isRecalc;
                        if(isRecalc){
                            cml.status__c = 'Re-Calculated';
                        }
                        brokercommissionLineList.add(cml);
                            
                        SalesOrder__c soOBJ = new SalesOrder__c();
                        soOBJ.Id = so.Id;
                        soOBJ.IsExternalCommissionLineExist__c = true;
                        soUpdateListMap.put(soOBJ.Id,soOBJ);
                     }
                
            }
        }
        system.debug('brokercommissionLineList::'+brokercommissionLineList);
        if(!brokercommissionLineList.isEmpty()){
            upsert brokercommissionLineList;
            if(!soUpdateListMap.values().isEmpty()){
                update soUpdateListMap.values();
            }
            if(isRecalc){
                /*String query = 'SELECT Id,Commission_Payout_Percent__c,Direct_Commission_Amount__c,Payout_Based_On__c,Equity_Payout_Percent__c,Sales_Order_Equity__c,Indirect_Commission_Amount__c,Installment_No__c,Last_Paid_Installment_Number__c,Commission_Type__c,Commission_Line__r.Total_Unit_Price__c,Sub_Type__c,Total_Commission_Amount__c,Commission_Line__r.External_Total_Commission_Amount__c,Commission_Line__r.Down_Payment_Status__c,Commission_Line__r.Is_SPA_Signed_By_Modon__c,Commission_Line__r.ADM_Fee_Status__c FROM Commission_Line_Item__c WHERE Commission_Line__c = \'' +
                String.escapeSingleQuotes(String.valueOf(commissionLineId)) + '\'';
                CommissionLineItemPaymentBatch batchJob = new CommissionLineItemPaymentBatch(query);
                Database.executeBatch(batchJob, 1);*/
                List<Commission_Line_Item__c> clineList = [SELECT Id,Total_Commission_Amount__c,Commission_Payout_Percent__c,Direct_Commission_Amount__c,Payout_Based_On__c,Equity_Payout_Percent__c,Sales_Order_Equity__c,Indirect_Commission_Amount__c,Installment_No__c,Last_Paid_Installment_Number__c,Commission_Type__c,Commission_Line__r.Total_Unit_Price__c,Sub_Type__c,Commission_Line__c,Commission_Line__r.External_Total_Commission_Amount__c,Commission_Line__r.Down_Payment_Status__c,Commission_Line__r.Is_SPA_Signed_By_Modon__c,Commission_Line__r.ADM_Fee_Status__c,Commission_Line__r.Is_PDC_Collected__c FROM Commission_Line_Item__c WHERE Commission_Line__c =:commissionLineId];
                cliPayoutAmountCalculation(clineList,true);
                cliPayoutAmountCalculation(clineList,false);
            }
        }
    }
    /** Handle Sales Team commission **/
    public static void teamCommissionValueCalculate(Set<Id> salesOrderIdset){
        Set<Id> commissionPOTSet = new Set<Id>();
        Map<String,Decimal> teamCommissionMap = new Map<String,Decimal>();
        List<Commission_Line__c> cmlLineList = new List<Commission_Line__c>(); 
        for(Commission_Line__c cml:[SELECT Id,Sales_Agent__c,Commission_Amount__c,Sales_Order__c FROM Commission_Line__c WHERE Sales_Order__c IN:salesOrderIdset AND Sales_Agent__c <> null AND POT_Type__c ='Sales Associate']){
            teamCommissionMap.put(cml.Sales_Order__c+''+cml.Sales_Agent__c,cml.Commission_Amount__c);
        }
        for(Commission_Line__c cml:[SELECT Id,Sales_Agent__c,Commission_Amount__c,Sales_Order__c,Commission_POT__r.Commission_Percent__c FROM Commission_Line__c WHERE Sales_Order__c IN:salesOrderIdset AND Is_Sales_Manager_Commision__c = false AND POT_Split_Type__c ='Team Commission Value' AND Sales_Agent__c <> null AND Sales_Order__r.Sales_Type__c != 'Indirect']){
            Commission_Line__c cmlOBJ = new Commission_Line__c();
            cmlOBJ.Id = cml.Id;
            cmlOBJ.Commission_Percent__c = cml.Commission_POT__r.Commission_Percent__c;
            cmlOBJ.Team_Commission_Amount__c = teamCommissionMap.containsKey(cml.Sales_Order__c+''+cml.Sales_Agent__c) &&  teamCommissionMap.get(cml.Sales_Order__c+''+cml.Sales_Agent__c) <> null ? teamCommissionMap.get(cml.Sales_Order__c+''+cml.Sales_Agent__c) : 0;
            cmlOBJ.Commission_Amount__c = cmlOBJ.Team_Commission_Amount__c <> null &&  cmlOBJ.Team_Commission_Amount__c > 0 ? cmlOBJ.Team_Commission_Amount__c * (cmlOBJ.Commission_Percent__c / 100):0;
            cmlLineList.add(cmlOBJ);
        }
        if(!cmlLineList.isEmpty()){
            update cmlLineList;
        }
    }
    /** Find out the relavant commission rule to calculate the Commission for internal & external **/
    public static Map<String,Commission_Rules__c> getCommissionRule(List<SalesOrder__c> salesOrderList){
        Set<Id> projectIdset = new Set<Id>();
        Map<String,Commission_Rules__c> salesOrderCommissionMap = new Map<String,Commission_Rules__c>();
        for(SalesOrder__c so: salesOrderList){
            projectIdset.add(so.unit__r.Phase__r.Project__c); 
        }
        if(!projectIdset.isEmpty()){ /** 2.0 Added SOQL Fields - for Nawayef Project MegaMansions **/
            List<Commission_Rules__c> commissionRuleLst = [SELECT Id,Name,Direct_Commission__c,Direct_Commission_Amount__c,EndDate__c,Indirect_Commission__c,Management_Referral_Unit_Unallocated__c,Management_Referral_Amount_UnitAllocated__c,Number_Of_Bedrooms__c,NW_Mega_Mansion__c,
                                                           Indirect_Commission_Amount_Internal__c,Inventory_Launch_Category__c,Is_Bulk_Commission__c,Minimum_Units_to_be_Sold__c,Payment_Plan__c,Phase__c,Project__c,Sales_Type__c,Indirect_Commission_Amount_Intrl_Mgr__c,NW_Other_Units__c,
                                                           Sales_Values_From__c,Sales_Values_To__c,Sold_By__c,Staff_Referral__c,Staff_Referral_Amount__c,StartDate__c,Unit__c,VIP_Direct_Commission__c,VIP_Indirect_Commission__c,Direct_Commission_Sales_Manager__c FROM Commission_Rules__c WHERE Project__c IN:projectIdset AND IsActive__c = true];
            Map<String,Commission_Rules__c> commissionRuleMap = new Map<String,Commission_Rules__c>();
            for(Commission_Rules__c cmr: commissionRuleLst){
                if(cmr.Number_Of_Bedrooms__c <> null){
                    List<String> numberOfbedroomlst = cmr.Number_Of_Bedrooms__c.contains(';') ? cmr.Number_Of_Bedrooms__c.split(';') : new List<String>{cmr.Number_Of_Bedrooms__c};
                        for(String bedRooms: numberOfbedroomlst){
                            String key = cmr.Inventory_Launch_Category__c+'-'+cmr.Project__c;
                            key += cmr.Phase__c <> null ?'-'+cmr.Phase__c:'';
                            key += cmr.Unit__c <> null ?'-'+cmr.Unit__c:'';
                            key += cmr.Payment_Plan__c <> null ?'-'+cmr.Payment_Plan__c:'';
                            key += bedRooms;
                            commissionRuleMap.put(key,cmr);
                        }
                }else{
                    String key = cmr.Inventory_Launch_Category__c+'-'+cmr.Project__c;
                    key += cmr.Phase__c <> null ?'-'+cmr.Phase__c:'';
                    key += cmr.Unit__c <> null ?'-'+cmr.Unit__c:'';
                    key += cmr.Payment_Plan__c <> null ?'-'+cmr.Payment_Plan__c:'';
                    commissionRuleMap.put(key,cmr);
                }
            }
            for(SalesOrder__c so: salesOrderList){
                String key = generateKeySO(so);
                String key1 = key <> null && so.unit__r.Number_of_Bedrooms__c <> null ? key+'-'+ so.unit__r.Number_of_Bedrooms__c:null;
                for(String keyObj: commissionRuleMap.keySet()){
                    if(key1 == keyObj){
                        salesOrderCommissionMap.put(key1,commissionRuleMap.get(keyObj)); 
                    }else if(key1 <> null && key1.contains(keyObj)){
                        salesOrderCommissionMap.put(key1,commissionRuleMap.get(keyObj)); 
                    }else if(key.contains(keyObj)){
                        salesOrderCommissionMap.put(key,commissionRuleMap.get(keyObj)); 
                    }
                }    
            }
        }
        return salesOrderCommissionMap;
    }
    public static Map<Id,List<Commission_Payout_Line__c>> getCommissionPayoutItems(List<Id> commissionRuleIdset){
        Map<Id,List<Commission_Payout_Line__c>> commissionPayoutLineMap = new Map<Id,List<Commission_Payout_Line__c>>();
        for(Commission_Payout_Line__c cpayout:[SELECT Id,Commission_Rules__c,Commission_Type__c,Equity__c,Equity_Commission_Payout__c,Installment_Commission_Payout__c,Installment_No__c,Payout_Based_On__c,Sub_Type__c FROM Commission_Payout_Line__c WHERE Commission_Rules__c IN: commissionRuleIdset]){
            if(commissionPayoutLineMap.containsKey(cpayout.Commission_Rules__c)){
                commissionPayoutLineMap.get(cpayout.Commission_Rules__c).add(cpayout);
            }else{
                commissionPayoutLineMap.put(cpayout.Commission_Rules__c,new List<Commission_Payout_Line__c>{cpayout});
            }
        }
        return commissionPayoutLineMap;
    }
    public static String generateKeySO(SalesOrder__c so){
        String key = so.Category_Of_Sale__c+'-'+so.Unit__r.Phase__r.Project__c+'-'+so.Unit__r.Phase__c+'-'+so.Unit__c+'-'+so.PaymentPlan__c;
        return key;
    }
    /** Internal Commission - Generate monthly commission invoice bundle **/
    public static void monthlyInvoiceBundle(List<Commission_POT__c> cPotList,Date today){
        List<Invoice_Bundle__c> invBundleList = new List<Invoice_Bundle__c>();
        Date startOfMonth = Date.newInstance(today.year(), today.month(), 1);
        Integer periodMonths = Integer.valueOf(Label.InvoiceBundleFrequency);
        Date endOfMonth = startOfMonth.addMonths(periodMonths).addDays(-1);
        String invoiceBundleMonth = getMonthNameFromDate(today);
        List<Commission_POT__c> cPOTUpdateList = new List<Commission_POT__c>();
        Set<Id> POTIdSet = new Set<Id>();
        Map<Id,Id> existingBundleMap = new Map<Id,Id>();
        Id masterInvoiceRecTypeId = Schema.SObjectType.Invoice_Bundle__c.getRecordTypeInfosByName().get('Master Invoice Bundle').getRecordTypeId(); 
        Id masterInvoiceBundleId;
        for(Invoice_Bundle__c inv:[SELECT Id FROM Invoice_Bundle__c WHERE Commission_Month__c =:invoiceBundleMonth AND RecordTypeId =:masterInvoiceRecTypeId ]){
            masterInvoiceBundleId = inv.Id;
        }
        if(masterInvoiceBundleId == null){
            Invoice_Bundle__c invOBJ = new Invoice_Bundle__c();
            invOBJ.Invoice_Date_From__c = startOfMonth;
            invOBJ.Invoice_Date_To__c = endOfMonth;
            invOBJ.RecordTypeId = masterInvoiceRecTypeId;
            invOBJ.Commission_Type__c = 'Direct';
            insert invOBJ;
            masterInvoiceBundleId = [SELECT Id FROM Invoice_Bundle__c WHERE Commission_Month__c =:invoiceBundleMonth AND RecordTypeId =:masterInvoiceRecTypeId LIMIT 1].Id;
        }
        for(Commission_POT__c cpot: cPotList){
            POTIdSet.add(cpot.Id);
        }
        for(Invoice_Bundle__c inv:[SELECT Id FROM Invoice_Bundle__c WHERE Commission_POT__c IN:POTIdSet AND Commission_Month__c =:invoiceBundleMonth]){
            existingBundleMap.put(inv.Id,inv.Id);
        }
        Id internalRecordtypeId = Schema.SObjectType.Invoice_Bundle__c.getRecordTypeInfosByName().get('Internal').getRecordTypeId();
        for(Commission_POT__c cpot: cPotList){
            if(!existingBundleMap.containsKey(cpot.Id)){
                Invoice_Bundle__c invBundle = new Invoice_Bundle__c();
                invBundle.Invoice_Bundle__c = masterInvoiceBundleId;
                invBundle.recordTypeId = internalRecordtypeId;
                invBundle.Invoice_Date_From__c = startOfMonth;
                invBundle.Invoice_Date_To__c = endOfMonth;
                invBundle.User__c = cpot.User__c;
                invBundle.Commission_POT__c = cpot.Id;
                invBundle.Previous_On_Hold_Commission__c = cpot.On_Hold_Previous_Pending_Commission__c;
                invBundle.Previous_On_Hold_Commission_Reason__c = cpot.On_Hold_Pending_Commission_Reason__c;
                invBundle.Commission_Type__c = 'Direct';
                invBundleList.add(invBundle);
                
                Commission_POT__c cpotOBJ = new Commission_POT__c();
                cpotOBJ.Id = cpot.Id;
                cpotOBJ.On_Hold_Previous_Pending_Commission__c = null;
                cpotOBJ.On_Hold_Pending_Commission_Reason__c = null;
                cPOTUpdateList.add(cpotOBJ);
            }
        }
        if(!invBundleList.isEmpty()){
            insert invBundleList;
            if(!cPOTUpdateList.isEmpty()){
                update cPOTUpdateList;
            }
        }
    }
    /** Handle commission line item - from Create Commission lines Item batch **/
    public static void createCommissionLineItem(List<Commission_Line__c> commissionLineList){
        try{
            List<Commission_Line_Item__c> commissionLineItemList = new List<Commission_Line_Item__c>();
            List<Commission_Line__c> commissionLineListUpdate = new List<Commission_Line__c>();
            Set<Id> commissionRuleIdset = new Set<Id>();
            Map<Id,List<Commission_Line__c>> commissionLineMap = new Map<Id,List<Commission_Line__c>>();
            for(Commission_Line__c cml: commissionLineList){
                if(commissionLineMap.containsKey(cml.Commission_Rules__c)){
                    commissionLineMap.get(cml.Commission_Rules__c).add(cml);
                }else{
                    commissionLineMap.put(cml.Commission_Rules__c,new List<Commission_Line__c>{cml});
                }
            }
            system.debug('commissionLineMap:'+commissionLineMap);
            List<Commission_Payout_Line__c> cpLineItemList = [SELECT Id,Installment_Commission_Payout__c,Equity_Commission_Payout__c,Commission_Rules__c,
                                                              Commission_Type__c,Equity__c,Installment_No__c,Sub_Type__c FROM Commission_Payout_Line__c WHERE Commission_Rules__c IN:commissionLineMap.keySet()];
            
            Map<Id,List<Commission_Payout_Line__c>> commissionPayoutLineMap = new Map<Id,List<Commission_Payout_Line__c>>();
            for(Commission_Payout_Line__c cpt:[SELECT Id,Payout_Based_On__c,Installment_Commission_Payout__c,Equity_Commission_Payout__c,Commission_Rules__c,  Commission_Type__c,Equity__c,Installment_No__c,Sub_Type__c FROM Commission_Payout_Line__c WHERE Commission_Rules__c IN:commissionLineMap.keySet()]){
                if(commissionPayoutLineMap.containsKey(cpt.Commission_Rules__c)){
                    commissionPayoutLineMap.get(cpt.Commission_Rules__c).add(cpt);
                }else{
                    commissionPayoutLineMap.put(cpt.Commission_Rules__c,new List<Commission_Payout_Line__c>{cpt});
                }
            }
            system.debug('commissionPayoutLineMap:'+commissionPayoutLineMap);
            List<String> potType = System.label.CommissionReleaseFullPotType.contains(',') ? System.label.CommissionReleaseFullPotType.split(',') : new List<String>{System.label.CommissionReleaseFullPotType};
            for(Id ruleId: commissionLineMap.keySet()){
                if(commissionLineMap.containsKey(ruleId)){
                    for(Commission_Line__c cli:commissionLineMap.get(ruleId)){
                        Commission_Line__c cliUpd = new Commission_Line__c();
                        cliUpd.Id = cli.Id;
                        cliUpd.Commission_Line_Item_Is_Created__c = true;
                        commissionLineListUpdate.add(cliUpd);
                        if(potType.contains(cli.POT_Type__c)){
                             commissionLineItemList.add(generateCommissionLineItem(cli.Id,0,'Internal',100,'Equity',null,1,'Direct Commission'));   
                        }else if(commissionPayoutLineMap.containsKey(ruleId)){
                            for(Commission_Payout_Line__c clip:commissionPayoutLineMap.get(ruleId)){
                                if(clip.Commission_Type__c == 'Direct' && cli.Commission_Line_Type__c == 'Internal'){
                                    if(clip.Payout_Based_On__c == 'Installment'){
                                        commissionLineItemList.add(generateCommissionLineItem(cli.Id,0,'Internal',clip.Installment_Commission_Payout__c,clip.Payout_Based_On__c,clip.Installment_No__c,null,clip.Sub_Type__c)); //(Id commissionId,Decimal commissionAmt,String commissionType,Decimal payoutPercent,String payoutType,Decimal installmentNo,decimal equityPayoutPercent)
                                    }else{
                                        commissionLineItemList.add(generateCommissionLineItem(cli.Id,0,'Internal',clip.Equity_Commission_Payout__c,clip.Payout_Based_On__c,null,clip.Equity__c,clip.Sub_Type__c)); 
                                    } 
                                    
                                }else if(clip.Commission_Type__c == 'Indirect' && cli.Commission_Line_Type__c == 'External'){
                                  //  if(clip.Payout_Based_On__c == 'SPA Signed (Modon)'){
                                        commissionLineItemList.add(generateCommissionLineItem(cli.Id,0,'External',clip.Equity_Commission_Payout__c,clip.Payout_Based_On__c,null,clip.Equity__c,clip.Sub_Type__c)); 
                                  //  } 
                                }
                            }
                        }
                    }
                }
            }
            system.debug('commissionLineItemList:'+commissionLineItemList);
            if(!commissionLineItemList.isEmpty()){
                insert commissionLineItemList;
                List<Commission_Line_Item__c> clineList = new List<Commission_Line_Item__c>(); 
                Set<Id> commissionLineIdset = new Set<Id>();
                for(Commission_Line_Item__c cl:commissionLineItemList){
                    commissionLineIdset.add(cl.Id);
                }
                clineList = [SELECT Id,Total_Commission_Amount__c,Commission_Payout_Percent__c,Direct_Commission_Amount__c,Payout_Based_On__c,Equity_Payout_Percent__c,Sales_Order_Equity__c,Indirect_Commission_Amount__c,Installment_No__c,Last_Paid_Installment_Number__c,Commission_Type__c,Commission_Line__r.Total_Unit_Price__c,Sub_Type__c,Commission_Line__c,Commission_Line__r.External_Total_Commission_Amount__c,Commission_Line__r.Down_Payment_Status__c,Commission_Line__r.Is_SPA_Signed_By_Modon__c,Commission_Line__r.ADM_Fee_Status__c,Commission_Line__r.Compliance_Status__c FROM Commission_Line_Item__c WHERE Id IN:commissionLineIdset];
                cliPayoutAmountCalculation(clineList,true);
            }
            if(!commissionLineListUpdate.isEmpty()){
                update commissionLineListUpdate;
            }        
        }catch(Exception ex){
            System.debug('Exception Ex:'+ex.getMessage());
        }
    }
    public static Commission_Line_Item__c generateCommissionLineItem(Id commissionId,Decimal commissionAmt,String commissionType,Decimal payoutPercent,String payoutType,Decimal installmentNo,decimal equityPayoutPercent,String subType){
        Commission_Line_Item__c cliR = new Commission_Line_Item__c();
        cliR.Commission_Line__c = commissionId;
        cliR.Commission_Payout_Amount__c = commissionAmt;
        cliR.Commission_Type__c = commissionType;
        cliR.Commission_Payout_Percent__c = payoutPercent;
        cliR.Payout_Based_On__c = payoutType;
        //cliR.Sub_Type__c = subType;
        cliR.Installment_No__c = installmentNo;
        cliR.Equity_Payout_Percent__c = equityPayoutPercent;
        cliR.UniqueKey__c = commissionId+''+commissionType+''+payoutType+'-'+equityPayoutPercent;
        return cliR;
    }
    /** Handle commission payout calculation based on the CommissionPayment Batch **/
    public static void cliPayoutAmountCalculation(List<Commission_Line_Item__c> cliList,boolean expectedPay){
        List<Commission_Line_Item__c> cliUpdateList = new List<Commission_Line_Item__c>();
        List<Commission_Line__c> commisisonLineList = new List<Commission_Line__c>();
        for(Commission_Line_Item__c cli: cliList){
            if(cli.Commission_Type__c == 'External'){
                PayoutCalcWrapper cliExt = externalPayoutCalc(cli,expectedPay,cli.Sub_Type__c);
                if(cliExt <> null && cliExt.cliItemOBJ <> null){
                    cliUpdateList.add(cliExt.cliItemOBJ);
                }
                if(cliExt <> null && cliExt.cliOBJ <> null){
                    commisisonLineList.add(cliExt.cliOBJ);
                }
            }else if(cli.Commission_Type__c == 'Internal'){
                PayoutCalcWrapper cliExt = internalPayoutCalc(cli,expectedPay,cli.Sub_Type__c);
                if(cliExt <> null && cliExt.cliItemOBJ <> null){
                    cliUpdateList.add(cliExt.cliItemOBJ);
                }
                if(cliExt <> null && cliExt.cliOBJ <> null){
                    commisisonLineList.add(cliExt.cliOBJ);
                }
            }
        }  
        if(!cliUpdateList.isEmpty()){
            update cliUpdateList;
        }
        if(!commisisonLineList.isEmpty()){
            update commisisonLineList;
            //updateExternalSOCommission(commisisonLineList);
        }
    }
    public static PayoutCalcWrapper externalPayoutCalc(Commission_Line_Item__c cli,boolean expectedPay,String subType){
        PayoutCalcWrapper pWrap = new PayoutCalcWrapper();
        if(cli.Commission_Line__r.External_Total_Commission_Amount__c <> null && cli.Commission_Payout_Percent__c <> null){
            Commission_Line_Item__c cliUpdate = new Commission_Line_Item__c();
            Commission_Line__c cml = new Commission_Line__c();
            cliUpdate.Id = cli.Id;
            cml.Id = cli.Commission_Line__c;
            if( cli.Payout_Based_On__c == 'Equity' && (cli.Equity_Payout_Percent__c <= cli.Sales_Order_Equity__c || expectedPay)){
                if(expectedPay){
                    cliUpdate.Expected_Commision_Payout_Amount__c = cli.Commission_Line__r.External_Total_Commission_Amount__c * (cli.Commission_Payout_Percent__c/100);
                }else{
                    cliUpdate.Commission_Payout_Amount__c = cli.Commission_Line__r.External_Total_Commission_Amount__c * (cli.Commission_Payout_Percent__c/100);
                    cliUpdate.Commission_Month__c = DateTime.now().format('MMMM');
                    cml.Status__c = 'Internal Review In-Progress';//cml.Status__c = 'Ready To Process';
                    cml.Payment_Eligible_Date__c = System.today();
                }
            }else if( cli.Payout_Based_On__c == 'Installment' && (cli.Installment_No__c <= cli.Last_Paid_Installment_Number__c || expectedPay)){
                if(expectedPay){
                    cliUpdate.Expected_Commision_Payout_Amount__c = cli.Commission_Line__r.External_Total_Commission_Amount__c * (cli.Commission_Payout_Percent__c/100); 
                }else{
                    cliUpdate.Commission_Payout_Amount__c = cli.Commission_Line__r.External_Total_Commission_Amount__c * (cli.Commission_Payout_Percent__c/100);
                    cliUpdate.Commission_Month__c =  DateTime.now().format('MMMM');
                    cml.Status__c = 'Internal Review In-Progress';//cml.Status__c = 'Ready To Process';
                    cml.Payment_Eligible_Date__c = System.today();
                }
            }else if( cli.Payout_Based_On__c == 'Down Payment Cleared'){
                if(expectedPay){
                    cliUpdate.Expected_Commision_Payout_Amount__c = cli.Commission_Line__r.External_Total_Commission_Amount__c * (cli.Commission_Payout_Percent__c/100); 
                }else if(cli.Commission_Line__r.Down_Payment_Status__c == 'Paid'){
                    cliUpdate.Commission_Payout_Amount__c = cli.Commission_Line__r.External_Total_Commission_Amount__c * (cli.Commission_Payout_Percent__c/100);
                    cliUpdate.Commission_Month__c =  DateTime.now().format('MMMM');
                    cml.Status__c = 'Internal Review In-Progress';
                    cml.Payment_Eligible_Date__c = System.today();
                }
            }else if( cli.Payout_Based_On__c == 'SPA Signed (Modon)'){
                if(expectedPay){
                    cliUpdate.Expected_Commision_Payout_Amount__c = cli.Commission_Line__r.External_Total_Commission_Amount__c * (cli.Commission_Payout_Percent__c/100); 
                }else if(cli.Commission_Line__r.Is_SPA_Signed_By_Modon__c ==true && cli.Commission_Line__r.Down_Payment_Status__c == 'Paid' && cli.Commission_Line__r.ADM_Fee_Status__c == 'Paid' && cli.Commission_Line__r.Is_PDC_Collected__c <> 'No' && cli.Commission_Line__r.Compliance_Status__c == 'Approved'){
                    cliUpdate.Commission_Payout_Amount__c = cli.Commission_Line__r.External_Total_Commission_Amount__c * (cli.Commission_Payout_Percent__c/100);
                    cliUpdate.Commission_Month__c =  DateTime.now().format('MMMM');
                    cml.Status__c = 'Internal Review In-Progress';
                    cml.Payment_Eligible_Date__c = System.today();
                }
            }
            pWrap.cliItemOBJ = cliUpdate;
            pWrap.cliOBJ = cml;
            return pWrap;
        }
        return null;
    }
    public static PayoutCalcWrapper internalPayoutCalc(Commission_Line_Item__c cli,boolean expectedPay,String subType){
        Commission_Line_Item__c cliUpdate = new Commission_Line_Item__c();
        Commission_Line__c cml = new Commission_Line__c();
        PayoutCalcWrapper pWrap = new PayoutCalcWrapper();
        cliUpdate.Id = cli.Id;
        cml.Id = cli.Commission_Line__c;
        if(cli.Total_Commission_Amount__c <> null && cli.Commission_Payout_Percent__c <> null){
            if(cli.Payout_Based_On__c == 'Equity' && (cli.Equity_Payout_Percent__c <= cli.Sales_Order_Equity__c || expectedPay)){
                if(expectedPay){
                    cliUpdate.Expected_Commision_Payout_Amount__c = cli.Total_Commission_Amount__c * (cli.Commission_Payout_Percent__c/100);
                }else{
                    cliUpdate.Commission_Payout_Amount__c = cli.Total_Commission_Amount__c * (cli.Commission_Payout_Percent__c/100);
                    cliUpdate.Commission_Month__c = DateTime.now().format('MMMM');
                    cml.Status__c = 'Ready To Process';
                }
            }else if(cli.Payout_Based_On__c == 'Installment' && (cli.Installment_No__c <= cli.Last_Paid_Installment_Number__c || expectedPay)){
                if(expectedPay){
                    cliUpdate.Expected_Commision_Payout_Amount__c = cli.Total_Commission_Amount__c * (cli.Commission_Payout_Percent__c/100);
                }else{
                    cliUpdate.Commission_Payout_Amount__c = cli.Total_Commission_Amount__c * (cli.Commission_Payout_Percent__c/100);
                    cliUpdate.Commission_Month__c = DateTime.now().format('MMMM');
                    cml.Status__c = 'Ready To Process';
                }
            }
            pWrap.cliItemOBJ = cliUpdate;
            pWrap.cliOBJ = cml;
            return pWrap;
        }
        return null;
    }
    public static void invoiceLineCreation(List<Commission_Line_Item__c> cliItemList,String Month){
        Set<Id> POTIdSet = new Set<Id>();
        Date today = Date.today();
        Date startOfMonth = Date.newInstance(today.year(), today.month(), 1);
        Integer periodMonths = Integer.valueOf(Label.InvoiceBundleFrequency);
        Date endOfMonth = startOfMonth.addMonths(periodMonths).addDays(-1);
        Set<Id> brokerAgencyIdset = new Set<Id>();
        Id masterInvoiceBundleId;
        for(Invoice_Bundle__c inv:[SELECT Id FROM Invoice_Bundle__c WHERE Commission_Month__c =:month]){
            masterInvoiceBundleId = inv.Id;
        }
        for(Commission_Line_Item__c cli:cliItemList){
            if(cli.Commission_Type__c == 'Internal' && cli.Commission_Line__r.Commission_POT__c <> null){
                POTIdSet.add(cli.Commission_Line__r.Commission_POT__c);
            }
           /* if(cli.Commission_Type__c == 'External' && cli.Commission_Line__r.broker_agency__c <> null){
                brokerAgencyIdset.add(cli.Commission_Line__r.broker_agency__c);
            } */
        }
        Map<Id,Id> invoiceBundleMap = new Map<Id,Id>();
        for(Invoice_Bundle__c inv:[SELECT Id,Commission_POT__c FROM Invoice_Bundle__c WHERE Commission_Month__c =:Month AND Commission_POT__c IN:POTIdSet]){
            invoiceBundleMap.put(inv.Commission_POT__c,inv.Id);
        }
      /*  Map<Id,Account> brokerOnHoldCommissionMap = new Map<Id,Account> ();
        for(Account acc:[SELECT Id,On_Hold_Previous_Pending_Commission__c,On_Hold_Pending_Commission_Reason__c FROM Account WHERE Id IN:brokerAgencyIdset]){
            brokerOnHoldCommissionMap.put(acc.Id,acc);
        }*/
        List<Invoice_Line__c> invList = new List<Invoice_Line__c>();
        Map<Id,Invoice_Bundle__c> invBundleMap = new Map<Id,Invoice_Bundle__c>();
   /*     Map<Id,Id> existingbrokerBundleMap = new Map<Id,Id>();
        for(Invoice_Bundle__c inv:[SELECT Id,Commission_POT__c,Broker_Agency__c FROM Invoice_Bundle__c WHERE Commission_Month__c =:Month AND Commission_Type__c = 'Indirect']){
            existingbrokerBundleMap.put(inv.Broker_Agency__c,inv.Id);
        }
        for(Commission_Line_Item__c cli:cliItemList){
            if(cli.Commission_Type__c == 'External'){
                if(!existingbrokerBundleMap.containsKey(cli.commission_line__r.Broker_Agency__c)){
                    Invoice_Bundle__c invBundle = new Invoice_Bundle__c();
                    invBundle.Broker_Agency__c = cli.commission_line__r.Broker_Agency__c;
                    invBundle.Invoice_Bundle__c = masterInvoiceBundleId;
                    // invBundle.Broker_Agent__c =  cli.commission_line__r.Broker_Agent__c;
                    invBundle.Commission_Type__c = 'Indirect';
                    invBundle.Invoice_Date_From__c = startOfMonth;
                    invBundle.Invoice_Date_To__c = endOfMonth;
                    invBundle.RecordTypeId = Schema.SObjectType.Invoice_Bundle__c.getRecordTypeInfosByName().get('External').getRecordTypeId(); 
                    invBundle.Previous_On_Hold_Commission__c = brokerOnHoldCommissionMap.get(cli.commission_line__r.Broker_Agency__c).On_Hold_Previous_Pending_Commission__c;
                    invBundle.Previous_On_Hold_Commission_Reason__c = brokerOnHoldCommissionMap.get(cli.commission_line__r.Broker_Agency__c).On_Hold_Pending_Commission_Reason__c;
                    invBundleMap.put(invBundle.Broker_Agency__c,invBundle);
                }
            }
        }
        if(!invBundleMap.values().isEmpty()){
            insert invBundleMap.values();
        }
        Map<Id,Id> brokerBundleMap = new Map<Id,Id>();
        for(Invoice_Bundle__c inv:[SELECT Id,Commission_POT__c,Broker_Agency__c FROM Invoice_Bundle__c WHERE Commission_Month__c =:Month AND Commission_Type__c = 'Indirect']){
            brokerBundleMap.put(inv.Broker_Agency__c,inv.Id);
        }*/
        Set<Id> commissionItemIdset = new Set<Id>();
        Set<Id> commissionLineIdset = new Set<Id>();
        for(Commission_Line_Item__c cli:cliItemList){
            if(cli.Commission_Type__c == 'Internal' && invoiceBundleMap.containsKey(cli.Commission_Line__r.Commission_POT__c)){
                Invoice_Line__c inv = new Invoice_Line__c();
                inv.Invoice_Bundle__c = invoiceBundleMap.get(cli.Commission_Line__r.Commission_POT__c);
                inv.Commission_Line__c = cli.commission_line__c;
                inv.Commission_Line_Item__c = cli.Id;
                inv.Current_Commission_Payout_Now__c = cli.Commission_Payout_Amount__c <> null ? cli.Commission_Payout_Amount__c : 0;
                inv.Commission_Amount_Already_Paid__c = cli.commission_line__r.Total_Commission_Amount_Paid__c <> null ? cli.commission_line__r.Total_Commission_Amount_Paid__c : 0;
                inv.Pending_Commission_Amount__c = cli.commission_line__r.Total_Commission_Amount_Pending__c <> null ? cli.commission_line__r.Total_Commission_Amount_Pending__c : 0;
                inv.UniqueKey__c = inv.Invoice_Bundle__c+'-'+inv.Commission_Line__c+'-'+inv.Commission_Line_Item__c;
                inv.Total_Commission_Amount__c = cli.commission_line__r.Commission_Amount__c;
                inv.Team_Commission_Amount__c = cli.commission_line__r.Team_Commission_Amount__c;
                invList.add(inv);
                commissionItemIdset.add(inv.Commission_Line_Item__c);
                commissionLineIdset.add(inv.Commission_Line__c);
            }/*else if(cli.Commission_Type__c == 'External' && brokerBundleMap.containsKey(cli.Commission_Line__r.Broker_Agency__c)){
                Invoice_Line__c inv = new Invoice_Line__c();
                inv.Invoice_Bundle__c = brokerBundleMap.get(cli.Commission_Line__r.Broker_Agency__c);
                inv.Commission_Line__c = cli.commission_line__c;
                inv.Commission_Line_Item__c = cli.Id;
                inv.Current_Commission_Payout_Now__c = cli.Commission_Payout_Amount__c <> null ? cli.Commission_Payout_Amount__c : 0;
                inv.Commission_Amount_Already_Paid__c = cli.commission_line__r.Total_Commission_Amount_Paid__c <> null ? cli.commission_line__r.Total_Commission_Amount_Paid__c : 0;
                inv.Pending_Commission_Amount__c = cli.commission_line__r.Total_Commission_Amount_Pending__c <> null ? cli.commission_line__r.Total_Commission_Amount_Pending__c : 0;
                inv.UniqueKey__c = inv.Invoice_Bundle__c+'-'+inv.Commission_Line__c+'-'+inv.Commission_Line_Item__c;
                invList.add(inv);
                commissionItemIdset.add(inv.Commission_Line_Item__c);
                commissionLineIdset.add(inv.Commission_Line__c);
            }*/
        }
        if(!invList.isEmpty()){
            upsert invList UniqueKey__c;
        }
        if(!commissionItemIdset.isEmpty()){
            List<Commission_Line_Item__c> cliItemUpdList = new List<Commission_Line_Item__c>();
            for(Commission_Line_Item__c cliItem:[SELECT Id FROM Commission_Line_Item__c WHERE Id IN:commissionItemIdset]){
                Commission_Line_Item__c cliOBJ = new Commission_Line_Item__c();
                cliOBJ.Id = cliItem.Id;
                cliOBJ.Status__c = 'In-Progress';
                cliItemUpdList.add(cliOBJ);
            }
            if(!cliItemUpdList.isEmpty()){
                update cliItemUpdList;
            }
        }
        if(!commissionLineIdset.isEmpty()){
            List<Commission_Line__c> commissionlineUpdate = new List<Commission_Line__c>();
            for(Commission_Line__c cli:[SELECT Id FROM Commission_Line__c WHERE ID IN: commissionLineIdset]){
                Commission_Line__c cliUpd = new Commission_Line__c();
                cliUpd.Id = cli.Id;
                cliUpd.Status__c = 'In Progress';
                commissionlineUpdate.add(cliUpd);
            }
            if(!commissionlineUpdate.isEmpty()){
                update commissionlineUpdate;
            }
        }
        
    }
    public static void approvedCommissionPayoutsHandler(List<sObject> invoiceBundleList,Map<Id,sObject> oldMap){
        Set<Id> invoiceBundleSetId = new Set<Id>();
        Set<Id> commissionLineIdset = new Set<Id>();
        Set<Id> approvedInvoiceBundleSetId = new Set<Id>();
        for(Invoice_Bundle__c inv: (List<Invoice_Bundle__c>)invoiceBundleList){
            Invoice_Bundle__c oldData = (Invoice_Bundle__c)oldMap.get(inv.Id);
            if(inv.Approval_Status__c <> null && oldData.Approval_Status__c <> inv.Approval_Status__c){
                invoiceBundleSetId.add(inv.Id);
                if(inv.Approval_Status__c == 'Approval In-Progress'){
                    approvedInvoiceBundleSetId.add(inv.Id);
                }
            }
        }
        List<Commission_Line_Item__c> cliListUpdate = new List<Commission_Line_Item__c>();
        for(Invoice_Line__c inv:[SELECT Id,Invoice_Bundle__r.Approval_Status__c,Commission_Line_Item__c FROM Invoice_Line__c WHERE Invoice_Bundle__c IN:invoiceBundleSetId AND Commission_Line_Item__r.Status__c = 'In-Progress' AND Invoice_Bundle__r.Approval_Status__c IN ('Approved','Rejected')]){
            Commission_Line_Item__c cli = new Commission_Line_Item__c();
            cli.Id = inv.Commission_Line_Item__c;
            cli.Status__c = inv.Invoice_Bundle__r.Approval_Status__c;
            cliListUpdate.add(cli);
        }
        if(!cliListUpdate.isEmpty()){
            update cliListUpdate;
        }
        if(!approvedInvoiceBundleSetId.isEmpty()){
            for(Id idSet: approvedInvoiceBundleSetId){
                CommissionStatementHelper.callingFromTrigger(idSet);
            }
        }
    }
    public static void approvedCommissionPayoutsHelper(Set<Id> invoiceBundleSetId){
        Set<Id> commissionPOTIdSet = new Set<Id>();
        Set<Id> brokerAgentIdSet = new Set<Id>();
        
        for(Invoice_Bundle__c inv: [SELECT Id,Current_On_Hold_Commission__c,Commission_Type__c,Broker_Agency__c FROM Invoice_Bundle__c WHERE ID IN:invoiceBundleSetId]){
            // if(inv.Current_On_Hold_Commission__c <> null && inv.Current_On_Hold_Commission__c > 0){
            if(inv.Commission_Type__c == 'Direct'){
                commissionPOTIdSet.add(inv.Id);
            }else if(inv.Commission_Type__c == 'Indirect' && inv.Broker_Agency__c <> null){
                brokerAgentIdSet.add(inv.Id);
            }
            //}
        }
        if(!commissionPOTIdSet.isEmpty()){
            List<Commission_POT__c> CPOTUpdateList = new List<Commission_POT__c>();
            for(Invoice_Bundle__c inv:[SELECT Id,Commission_POT__c,Current_On_Hold_Commission__c,Override_Payout_Amount__c,Override_Payout_Amount_Reason__c FROM Invoice_Bundle__c WHERE Id IN: commissionPOTIdSet]){
                Commission_POT__c cpot = new Commission_POT__c();
                cpot.Id = inv.Commission_POT__c;
                cpot.On_Hold_Pending_Commission_Reason__c = inv.Override_Payout_Amount_Reason__c;
                cpot.On_Hold_Previous_Pending_Commission__c =  inv.Current_On_Hold_Commission__c > 0 ? inv.Current_On_Hold_Commission__c : 0;
                CPOTUpdateList.add(cpot);
            }
            if(!CPOTUpdateList.isEmpty()){
                update CPOTUpdateList;
            }
        }
        if(!brokerAgentIdSet.isEmpty()){
          /*  List<Account> accountUpdateList = new List<Account>();
            for(Invoice_Bundle__c inv:[SELECT Id,Broker_Agency__c,Current_On_Hold_Commission__c,Commission_POT__c,Override_Payout_Amount__c,Override_Payout_Amount_Reason__c FROM Invoice_Bundle__c WHERE Id IN: commissionPOTIdSet]){
                Account acc = new Account();
                acc.Id = inv.Broker_Agency__c;
                //acc.On_Hold_Pending_Commission_Reason__c = inv.Override_Payout_Amount_Reason__c;
                //acc.On_Hold_Previous_Pending_Commission__c = inv.Current_On_Hold_Commission__c > 0 ? inv.Current_On_Hold_Commission__c : 0;
                accountUpdateList.add(acc);
            }
            if(!accountUpdateList.isEmpty()){
                update accountUpdateList;
            }
            if(!invoiceBundleSetId.isEmpty()){
                updateCommissionPayoutLines(invoiceBundleSetId);
            }*/
        }
        if(!invoiceBundleSetId.isEmpty()){
           updateCommissionPayoutLines(invoiceBundleSetId);
        }
    }
    public static void handleCommissionLineItem(List<sObject> commissionLineItemList,Map<Id,sObject> oldMap){
        Set<Id> commissionLineIdset = new Set<Id>();
        for(Commission_Line_Item__c cli:(List<Commission_Line_Item__c>)commissionLineItemList){
            Commission_Line_Item__c old = (Commission_Line_Item__c) oldMap.get(cli.Id);
            if(cli.Status__c == 'Approved' && cli.Status__c <> old.Status__c){
                commissionLineIdset.add(cli.Commission_Line__c); 
            }
        }
        if(!commissionLineIdset.isEmpty()){
            updateCommissionLineStatus(commissionLineIdset);
        }
    }
    public static void updateCommissionLineStatus(Set<Id> commissionLineIdset){
        List<Commission_Line__c> cliListUpdate = new List<Commission_Line__c>();
        Map<Id,decimal> commissionTotalAmtMap = new Map<Id,decimal>();
        for(Commission_Line__c cliItem:[SELECT Id,Commission_Amount__c FROM Commission_Line__c WHERE Id IN:commissionLineIdset]){
            commissionTotalAmtMap.put(cliItem.Id,cliItem.Commission_Amount__c);
        }
        for(AggregateResult cli:[SELECT SUM(Commission_Payout_Amount__c) TOTALSUM,Commission_Line__c CLMLINE FROM Commission_Line_Item__c WHERE Commission_Line__c IN:commissionLineIdset AND Status__c = 'Approved' GROUP BY Commission_Line__c]){
            Commission_Line__c cliOBJ = new Commission_Line__c();
            cliOBJ.Id = (Id)cli.get('CLMLINE');
            if((Decimal)cli.get('TOTALSUM') == commissionTotalAmtMap.get(cliOBJ.Id )){
                cliOBJ.Status__c = 'Completed';
                cliOBJ.paid_status__c = 'Paid';
            }else{
                cliOBJ.Status__c = 'Completed - Partially'; 
                cliOBJ.paid_status__c = 'Partially Paid';
            }
            cliListUpdate.add(cliOBJ);
        }
        if(!cliListUpdate.isEmpty()){
            update cliListUpdate;
        }
    }
    public static void handleInvoiceLineHoldAmt(List<sObject> invoiceLineLst,Map<Id,sObject> oldMap){
        List<Invoice_Bundle__c> invoiceBundleLst = new List<Invoice_Bundle__c>();
        Set<Id> invoiceBundleIdSet = new Set<Id>();
        for(Invoice_Line__c inv:(List<Invoice_Line__c>)invoiceLineLst){
            Invoice_Line__c oldData = (Invoice_Line__c) oldMap.get(inv.Id);
            if(oldData.Is_hold__c != inv.Is_hold__c){
                //if(inv.Is_hold__c){
                invoiceBundleIdSet.add(inv.Invoice_Bundle__c);
                //}
            }
        }
        if(!invoiceBundleIdSet.isEmpty()){
            updateHoldAmount(invoiceBundleIdSet);
        }
    }
    public static void handleInvoicebundleHold(List<sObject> invoiceBundleLst,Map<Id,sObject> oldMap){
        Set<Id> invoiceBundleIdSet = new Set<Id>();
        for(Invoice_Bundle__c inv:(List<Invoice_Bundle__c>)invoiceBundleLst){
            Invoice_Bundle__c oldData = (Invoice_Bundle__c) oldMap.get(inv.Id);
            if(oldData.Hold_Status__c != inv.Hold_Status__c){
                //if(inv.Is_hold__c){
                invoiceBundleIdSet.add(inv.Id);
                //}
            }
        }
        if(!invoiceBundleIdSet.isEmpty()){
            updateHoldAmount(invoiceBundleIdSet);
        }
    }
    public static void InvBundlehandleOverRideAmt(List<sObject> invoiceBundle,Map<Id,sObject> oldMap){
        List<Invoice_Bundle__c> invoiceBundleLst = new List<Invoice_Bundle__c>();
        Set<Id> invoiceBundleIdset = new Set<Id>();
        for(Invoice_Bundle__c inv:(List<Invoice_Bundle__c>)invoiceBundle){
            Invoice_Bundle__c oldData = (Invoice_Bundle__c) oldMap.get(inv.Id);
            if(inv.Override_Payout_Amount__c != oldData.Override_Payout_Amount__c || inv.Hold_Status__c != oldData.Hold_Status__c){
                invoiceBundleIdset.add(inv.Id);
            }
            
        }
        if(!invoiceBundleIdset.isEmpty()){
            updateHoldAmount(invoiceBundleIdset);
        } 
    }
    public static void updateHoldAmount( Set<Id> invoiceBundleIdSet){
        Set<Id> invBundleIdset = new Set<Id>();
        List<Invoice_Bundle__c> invbundleList = new List<Invoice_Bundle__c>();
        Map<Id,Decimal> invoiceBundleMap = new Map<Id,Decimal>();
        for(AggregateResult agg:[SELECT SUM(Current_Commission_Payout_Now__c)TOTALSUM,Invoice_Bundle__c INVBUNDLE FROM Invoice_Line__c WHERE Invoice_Bundle__c IN:invoiceBundleIdSet AND Is_Hold__c = true GROUP By  Invoice_Bundle__c]){
            invoiceBundleMap.put((Id)agg.get('INVBUNDLE'),(Decimal)agg.get('TOTALSUM'));
        }
        system.debug('invoiceBundleMap:'+invoiceBundleMap);
        for(Invoice_Bundle__c inv:[SELECT Id,Hold_Status__c,Actual_Total_Commission_Payout_Now__c,Override_Payout_Amount__c,Current_On_Hold_Commission__c,Invoice_Line_Hold_Amount__c FROM Invoice_Bundle__c WHERE Id IN:invoiceBundleIdSet]){
            Invoice_Bundle__c invOBJ = new Invoice_Bundle__c();
            invOBJ.Id = inv.Id;
            invBundleIdset.add(inv.Id);
            if(inv.Override_Payout_Amount__c > 0 || (invoiceBundleMap.containsKey(inv.Id) && invoiceBundleMap.get(inv.Id) > 0) || inv.Hold_Status__c <> null){
                if(inv.Override_Payout_Amount__c > 0){
                    invOBJ.Current_On_Hold_Commission__c = inv.Actual_Total_Commission_Payout_Now__c - inv.Override_Payout_Amount__c;
                }else if(invoiceBundleMap.containsKey(inv.Id) && invoiceBundleMap.get(inv.Id) > 0){
                    invOBJ.Current_On_Hold_Commission__c = invoiceBundleMap.get(inv.Id);
                }else if(inv.Hold_Status__c == 'Hold'){
                    invOBJ.Current_On_Hold_Commission__c = inv.Actual_Total_Commission_Payout_Now__c;
                }else if(inv.Hold_Status__c == 'Release'){
                    invOBJ.Current_On_Hold_Commission__c = 0;
                }
            }else{
                invOBJ.Current_On_Hold_Commission__c = 0;
            }
            invbundleList.add(invOBJ);
        }
        if(!invbundleList.isEmpty()){
            update invbundleList;
            approvedCommissionPayoutsHelper(invBundleIdset);
        }
    }
    public static String getMonthNameFromDate(Date d) {
        String[] monthNames = new String[] {
            'January', 'February', 'March',
                'April',   'May',      'June',
                'July',    'August',   'September',
                'October', 'November', 'December'
                };
                    Integer m = d.month();  // 1–12
        return monthNames[m - 1];  // list is zero-based
    }
    public static void holdCommissionLine(List<Invoice_Line__c> invoiceLineList, String reasonForHold,boolean isHold){
        Map<Id,Invoice_Line__c> commissionLineMap = new Map<Id,Invoice_Line__c>();
        List<Invoice_Line__c> invUpdateList = new List<Invoice_Line__c>();
        for(Invoice_Line__c inv: invoiceLineList){
            Invoice_Line__c invOBJ = new Invoice_Line__c();
            invOBJ.Id = inv.Id;
            invOBJ.Hold_Reason__c = reasonForHold;
            invOBJ.Is_Hold__c = isHold;
            invUpdateList.add(invOBJ);
            commissionLineMap.put(inv.Commission_Line__c,invOBJ);
        }
        if(!invUpdateList.isEmpty()){
            update invUpdateList; 
            List<Commission_Line__c> updateCommissionLine = new List<Commission_Line__c>();
            for(Id cli:commissionLineMap.keySet()){
                Commission_Line__c cliOBJ = new Commission_Line__c();
                cliOBJ.Id = cli;
                cliOBJ.Is_Hold__c = commissionLineMap.get(cli).Is_Hold__c;
                cliOBJ.Hold_Reason__c = commissionLineMap.get(cli).Hold_Reason__c;
                updateCommissionLine.add(cliOBJ);
            }
            if(!updateCommissionLine.isEmpty()){
                update updateCommissionLine;
            }
        }
    }
    @AuraEnabled
    public static Commission_Line__c holdCommissionFromCommissionLine(String recordId){
        if(!String.isBlank(recordId)){
            Commission_Line__c cli = [SELECT Id,Is_Hold__c,Hold_Reason__c FROM Commission_Line__c WHERE Id=:recordId];
            return cli;
        }
        return null;
    }
    @AuraEnabled
    public static void runTheHoldReasonBatch(String recordId, String reason,boolean IsOnhold){
        
        Commission_Line__c cvId = new Commission_Line__c();
        cvId.Id = recordId;
        cvId.Is_Hold__c = IsOnhold;
        cvId.Hold_Reason__c = reason;
        update cvId;
        
        //Database.executeBatch(new InvoiceLineHoldBatch(recordId,reason,IsOnhold),1);
    }
    public static void updateCommissionPayoutLines(Set<Id> invoiceBundleId){
        Set<Id> commissionLineItemIdSet = new Set<Id>();
        List<Commission_Line_Item__c> cliItemUpdate = new List<Commission_Line_Item__c>();
        for(Invoice_Line__c inv:[SELECT Id,Commission_Line__c,Commission_Line_Item__c FROM Invoice_Line__c WHERE Invoice_Bundle__c IN:invoiceBundleId]){
            commissionLineItemIdSet.add(inv.Commission_Line_Item__c);
        }
        for(Commission_Line_Item__c cli:[SELECT Id FROM Commission_Line_Item__c WHERE Id IN:commissionLineItemIdSet AND Status__c = 'In-Progress']){
            Commission_Line_Item__c cliUpd = new Commission_Line_Item__c();
            cliUpd.Id = cli.Id;
            cliUpd.Status__c = 'Approved';
            cliItemUpdate.add(cliUpd);
        }
        if(!cliItemUpdate.isEmpty()){
            update cliItemUpdate;
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<invBundleWrapper> getInvoicesByBundle(Id bundleId) {
        System.debug('bundleId::'+bundleId);
        List<invBundleWrapper> invBundleList = new List<invBundleWrapper>();
        for(Invoice_Bundle__c inv:[
            SELECT Id, Name, Invoice_Bundle__c,Approval_Status__c,Member_Name__c,POT_Type__c,Split_Type__c,Split_Percent__c,Commission_Month__c,Total_Commission_Payout_Amount_Now__c,Current_On_Hold_Commission__c,Hold_Status__c 
            FROM Invoice_Bundle__c 
            WHERE Invoice_Bundle__c = :bundleId 
        ]){
            invBundleWrapper invWrap = new invBundleWrapper();
            invWrap.Id = inv.Id;
            invWrap.invoiceBundleName = inv.Name;
            invWrap.memberName = inv.Member_Name__c;
            invWrap.type = inv.POT_Type__c;
            invWrap.splitType = inv.Split_Type__c;
            invWrap.splitPercent = inv.Split_Percent__c <> null ? String.valueOf(inv.Split_Percent__c)+'%':'0%';
            invWrap.month = inv.Commission_Month__c;
            invWrap.totalCommissionAmount = inv.Total_Commission_Payout_Amount_Now__c;
            invWrap.approvalSts = inv.Approval_Status__c;
            invWrap.holdSts = inv.Hold_Status__c;
            invBundleList.add(invWrap);
        }
        return invBundleList;
    }
    
    @AuraEnabled
    public static void processSelectedInvoices(List<Id> selectedInvoiceIds,String notes) {
        System.debug('selectedInvoiceIds:'+selectedInvoiceIds);
        Id masterBundleId;
        String month;
        // Perform your logic here on selected records
        List<Invoice_Bundle__c> invoiceBundleList = new List<Invoice_Bundle__c>();
        for(Invoice_Bundle__c inv:[SELECT Id, Name,Approval_Status__c,Invoice_Bundle__c,Invoice_Bundle__r.Commission_Month__c FROM Invoice_Bundle__c WHERE Id IN :selectedInvoiceIds]){
            Invoice_Bundle__c invOBJ = new Invoice_Bundle__c();
            invOBJ.Id = inv.Id;
            invOBJ.Approval_Status__c = 'Approval In-Progress';
            invoiceBundleList.add(invOBJ);
            masterBundleId = inv.Invoice_Bundle__c;
            month = inv.Invoice_Bundle__r.Commission_Month__c;
        }
        for(Invoice_Bundle__c inv:[SELECT Id, Name,Approval_Status__c,Invoice_Bundle__c,Invoice_Bundle__r.Commission_Month__c FROM Invoice_Bundle__c WHERE Id NOT IN :selectedInvoiceIds AND Invoice_Bundle__c =:masterBundleId]){
            Invoice_Bundle__c invOBJ = new Invoice_Bundle__c();
            invOBJ.Id = inv.Id;
           // invOBJ.Approval_Status__c = 'Not Submitted';
            invoiceBundleList.add(invOBJ);
            month = inv.Invoice_Bundle__r.Commission_Month__c;
        }
        if (!invoiceBundleList.isEmpty()) {
            update invoiceBundleList;
            if (!Test.isRunningTest()) {
                generateMemoPDF(selectedInvoiceIds, notes, month, masterBundleId);
            }
        } 
    }
    
    @future(callout=true)
public static void generateMemoPDF(List<Id> selectedInvoiceIds, String notes, String month, Id masterBundleId) {
    PageReference pdfPage = Page.invoiceBundleApprovalMemo;

    if (notes != null && notes != '') {
        String decodedNotes = EncodingUtil.urlDecode(notes, 'UTF-8');
        decodedNotes = decodedNotes.replaceAll('<p>', '').replaceAll('</p>', '<br/>');
        decodedNotes = decodedNotes.replaceAll('(<br/>)+', '<br/>');
        pdfPage.getParameters().put('notes', decodedNotes);
    }

    pdfPage.getParameters().put('id', JSON.serialize(selectedInvoiceIds));

    // Render page as blob (skip in test context)
    Blob pdfBlob;
    if (Test.isRunningTest()) {
        pdfBlob = Blob.valueOf('Fake PDF Content'); // mock blob
    } else {
        pdfBlob = pdfPage.getContentAsPDF();
    }

    // Create ContentVersion (File)
    ContentVersion cv = new ContentVersion();
    cv.Title = 'Invoice Bundle for the Month ' + month + '-Direct Commission';
    cv.PathOnClient = 'Invoice Bundle for the Month ' + month + '-Direct Commission.pdf';
    cv.VersionData = pdfBlob;
    cv.IsMajorVersion = true;
    insert cv;

    ContentDocumentLink cdl = new ContentDocumentLink();
    cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    cdl.LinkedEntityId = masterBundleId;
    cdl.ShareType = 'V';
    insert cdl;
}

    public static void handleInvoiceDocusignApproval(List<sObject> invoiceBundleList, Map<Id,sObject> oldMap){
        Set<Id> invoiceBundleIdset = new Set<Id>();
        Id masterRecordTypeId = Schema.SObjectType.Invoice_Bundle__c.getRecordTypeInfosByName().get('Master Invoice Bundle').getRecordTypeId(); 
        for(Invoice_Bundle__c inv:(List<Invoice_Bundle__c>)invoiceBundleList){
            Invoice_Bundle__c oldData = (Invoice_Bundle__c) oldMap.get(inv.Id);
            if(inv.Approval_Status__c == 'Approved' && inv.Approval_Status__c != oldData.Approval_Status__c && inv.RecordTypeId == masterRecordTypeId){
                invoiceBundleIdset.add(inv.Id);
            }
        }
        List<Invoice_Bundle__c> invoicebundleUpdate = new List<Invoice_Bundle__c>();
        for(Invoice_Bundle__c inv:[SELECT Id FROM Invoice_Bundle__c WHERE Invoice_Bundle__c IN:invoiceBundleIdset AND Approval_Status__c ='Approval In-Progress']){
            Invoice_Bundle__c invObj = new Invoice_Bundle__c();
            invObj.Id = inv.Id;
            invObj.Approval_Status__c = 'Approved';
            invoicebundleUpdate.add(invObj);
        }
        if(!invoicebundleUpdate.isEmpty()){
            update invoicebundleUpdate;
        }
    }
    public static void updateExternalCommissionSO(){
        
    }
    public class PayoutCalcWrapper{
        public Commission_Line_Item__c cliItemOBJ;
        public Commission_Line__c cliOBJ;
    }
    public class invBundleWrapper{
        @AuraEnabled public String approvalSts;
        @AuraEnabled public String holdSts;
        @AuraEnabled public Id Id;
        @AuraEnabled public String invoiceBundleName;
        @AuraEnabled public String memberName;
        @AuraEnabled public String type;
        @AuraEnabled public String splitType;
        @AuraEnabled public String splitPercent;
        @AuraEnabled public String month;
        @AuraEnabled public decimal totalCommissionAmount;
    }
    public class pdfWrapper{
        Id masterbundleId;
        List<Id> bundleIdset = new List<Id>();
    }
}