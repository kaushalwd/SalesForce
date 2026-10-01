public class PurchaseInformationController {

    @AuraEnabled(cacheable=true)
    public static Map<String,String> getPurchaseInformationData(String recordId){
        Map<String,String> fieldToValueMap = new Map<String,String>();
        if(String.isNotBlank(recordId)){
            account a = [select id,billingAddress,billingstreet,billingcity,billingstate,billingPostalCode,BillingCountry from account where id=:recordId];
            string segment = '0';
            string classification = '0';
            string accountBillingAddress = '';
            accountBillingAddress += (String.isNotBlank(a.billingstreet))? a.billingstreet : '' ;
            accountBillingAddress += (String.isNotBlank(a.billingcity))? a.billingcity : '' ;
            accountBillingAddress += (String.isNotBlank(a.billingstate))? a.billingstate : '' ;
            accountBillingAddress += (String.isNotBlank(a.billingPostalCode))? a.billingPostalCode : '' ;
            accountBillingAddress += (String.isNotBlank(a.BillingCountry))? a.BillingCountry : '' ;
             
            List<Customer360_Field_Config__mdt> metadataList = [ SELECT DeveloperName, Component_Name__c, Field_Name_In_Object__c, Data_Type__c, 
                                                                Order__c, MasterLabel FROM Customer360_Field_Config__mdt WHERE 
                                                                Active__c = TRUE And Component_Name__c =: Constants.PURCHASE_INFORMATION_CUSTOMER_360 ORDER BY Order__c ];
            //Constants.INTERNAL_INFORMATION_CUSTOMER_360
            List<SalesOrder__c> salesOrderList = [ SELECT Id, TotalAmount__c,Totalpaidamount__c,Opportunity__r.LanguagePreference__c,Unit__r.Status__c,PrimaryContact__r.name, ProjectName__c, Unit_Name__c, Unit__r.UnitClassification__c
                                                  FROM SalesOrder__c WHERE 
                                                  CustomerAccount__c = :recordId AND Status__c = 'Completed' AND Unit__r.Status__c = 'Sold'  
                                        			ORDER BY CreatedDate DESC];
            System.debug('salesOrderList'+salesOrderList);
            Decimal totalSalesOrderValue = 0;
            Decimal totalReceivedAmount = 0;
            Decimal totalOutstandingAmount = 0;
            for(SalesOrder__c salesOrder : salesOrderList){
                //totalSalesOrderValue += salesOrder.TotalAmount__c;
                //totalReceivedAmount += salesOrder.Totalpaidamount__c;
                totalSalesOrderValue += (salesOrder.TotalAmount__c != null) ? salesOrder.TotalAmount__c : 0;
                totalReceivedAmount += (salesOrder.Totalpaidamount__c != null) ? salesOrder.Totalpaidamount__c : 0;
            }
            totalOutstandingAmount = (totalSalesOrderValue != null ? totalSalesOrderValue : 0) 
                         - (totalReceivedAmount != null ? totalReceivedAmount : 0);

            Decimal receivedAmountPercentage = 0;
            if (totalSalesOrderValue > 0) {
                receivedAmountPercentage = (totalReceivedAmount / totalSalesOrderValue) * 100;
            }
            
            if(salesOrderList != null && !salesOrderList.isEmpty()){
                 List<String> propertyNamesList = new List<String>();
                for (SalesOrder__c so : salesOrderList) {
                    if (so.Unit_Name__c != null) {
                        propertyNamesList.add(so.Unit_Name__c);
                    }
                }
                List<String> unitLinks = new List<String>();
                for (SalesOrder__c so : salesOrderList) {
                    if (so.Unit_Name__c != null) {
                        String propertyName = so.ProjectName__c != null ? so.ProjectName__c : 'N/A';
                        unitLinks.add(so.Unit_Name__c + '##' + so.Id + '##' + propertyName);
                    }
                }
                fieldToValueMap.put('Owned Property Names', String.join(unitLinks, '||'));

                for(Customer360_Field_Config__mdt meta : metadataList){
                    if(meta.Field_Name_In_Object__c == 'UnitsPurchased__c'){
                        fieldToValueMap.put(meta.MasterLabel, String.valueOf(salesOrderList.size()));
                    } else if(meta.Field_Name_In_Object__c == 'TotalInvestmentValue__c'){
                         fieldToValueMap.put(meta.MasterLabel, formatNumber(totalReceivedAmount));
                        //fieldToValueMap.put(meta.MasterLabel, formatNumber(totalSalesOrderValue));
                    } else if(meta.Field_Name_In_Object__c == 'ReceivedAmountPercentage__c'){
                        fieldToValueMap.put(meta.MasterLabel, receivedAmountPercentage.setScale(1) + '%');
                    } else if(meta.Field_Name_In_Object__c == 'LanguagePreference__c'){
                        fieldToValueMap.put(meta.MasterLabel, salesOrderList[0].Opportunity__r.LanguagePreference__c);
                    }else if(meta.Field_Name_In_Object__c == 'BillingAddress'){
                        fieldToValueMap.put(meta.MasterLabel,accountBillingAddress);
                    }else if(meta.Field_Name_In_Object__c == 'PrimaryContact__c'){
                        fieldToValueMap.put(meta.MasterLabel, salesOrderList[0].PrimaryContact__r.name);
                    }
                    else if(meta.Field_Name_In_Object__c == 'OutstandingAmount__c'){
                        fieldToValueMap.put(meta.MasterLabel, formatNumber(totalOutstandingAmount));
                    }
                    else if(meta.Field_Name_In_Object__c == 'TotalAmount__c'){
                        fieldToValueMap.put(meta.MasterLabel, formatNumber(totalSalesOrderValue));
                    }
                    else if(meta.Field_Name_In_Object__c == 'Segment__c'){
                        fieldToValueMap.put(meta.MasterLabel,segment);
                    }
                    else if(meta.Field_Name_In_Object__c == 'Classification__c'){
                        fieldToValueMap.put(meta.MasterLabel,classification);
                    }
                    
                }
            }
            if (!salesOrderList.isEmpty()) {
                List<String> propertyBreakdownList = new List<String>();
                for (SalesOrder__c so : salesOrderList) {
                    Decimal total = so.TotalAmount__c != null ? so.TotalAmount__c : 0;
                    Decimal paid = so.Totalpaidamount__c != null ? so.Totalpaidamount__c : 0;
                    Decimal pending = total - paid;
            
                    String unit = String.isNotBlank(so.Unit_Name__c) ? so.Unit_Name__c : 'Unknown Property';
                    //String breakdown = unit + '##' + 'AED' + paid.setScale(0) + '##' + 'AED' + pending.setScale(0);
                    String propertyName = so.ProjectName__c != null ? so.ProjectName__c : 'N/A';
                    String breakdown = propertyName + '##' + unit + '##' + 'AED' + paid.setScale(0) + '##' + 'AED' + pending.setScale(0);


                    propertyBreakdownList.add(breakdown);
                }
            
                fieldToValueMap.put('Collected Breakdown Tooltip', String.join(propertyBreakdownList, '||')); // custom delimiter
            }
            if (!salesOrderList.isEmpty()) {
                List<String> outstandingTooltipList = new List<String>();
                for (SalesOrder__c so : salesOrderList) {
                    Decimal total = so.TotalAmount__c != null ? so.TotalAmount__c : 0;
                    Decimal paid = so.Totalpaidamount__c != null ? so.Totalpaidamount__c : 0;
                    Decimal pending = total - paid;
                    String unit = String.isNotBlank(so.Unit_Name__c) ? so.Unit_Name__c : 'Unknown Unit';
                    //String breakdown = unit + '##' + 'AED' + pending.setScale(0);
                    String propertyName = so.ProjectName__c != null ? so.ProjectName__c : 'N/A';
                    String breakdown = propertyName + '##' + unit + '##' + 'AED' + pending.setScale(0);

                    outstandingTooltipList.add(breakdown);
                }
                fieldToValueMap.put('Outstanding Breakdown Tooltip', String.join(outstandingTooltipList, '||'));
            }
            
            
            
        }
        return fieldToValueMap;
    }
    // Helper method to format numbers like 1.2M, 4.3B, etc.
    public static String formatNumber(Decimal formattedValue) {
        if (formattedValue == null) return '0';
    
        if (formattedValue >= 1000000000) {
            return (formattedValue / 1000000000).setScale(1) + 'B'; // Billion
        } else if (formattedValue >= 1000000) {
            return (formattedValue / 1000000).setScale(1) + 'M'; // Million
        } else if (formattedValue >= 1000) {
            return (formattedValue / 1000).setScale(0) + 'K'; // Thousand (No decimal)
        } else {
            return formattedValue.format(); // Keep as is for values < 1000
        }
    }
    
    
}