public class fetchPaymentsStatus {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> fetchReceiptStatuses(List<String> receiptNames) {
        List<Receipt__c> receipts = [SELECT Name, Status__c,TotalAmount__c,EBS_Clearing_Date__c, SalesOrder__r.Name, SalesOrder__r.Unit__r.Name,
                                     SalesOrder__r.ProjectName__c, SalesOrder__r.ClientName__c
                                     FROM Receipt__c WHERE Name IN :receiptNames];
        
        List<Map<String, String>> result = new List<Map<String, String>>();
        
        for (Receipt__c r : receipts) {
            Map<String, String> record = new Map<String, String>();
            record.put('Receipt No', r.Name);
            record.put('OldStatus', r.Status__c);
            record.put('Totalamount', String.valueOf(r.TotalAmount__c));
            record.put('Old EBS Clearing Date', String.valueOf(r.EBS_Clearing_Date__c));
            record.put('Sales Order: Sales Order Name', r.SalesOrder__r.Name);
            record.put('Sales Order: Unit: Unit Name', r.SalesOrder__r.Unit__r.Name);
            record.put('Sales Order: Project: Project Name', r.SalesOrder__r.ProjectName__c);
            record.put('Sales Order: Client: Client Name', r.SalesOrder__r.ClientName__c);
            result.add(record);
        }
        
        return result;
    }
    
    
    @AuraEnabled
    public static void uploadRecords(String jsonData) {
        List<Map<String, String>> uploadList = (List<Map<String, String>>) JSON.deserialize(jsonData, List<Map<String, String>>.class);
        
        // Collect receipt numbers from the payload
        Set<String> receiptNumbers = new Set<String>();
        Map<String, String> receiptToStatusMap = new Map<String, String>();
        Map<String, Date> receiptToClearingDateMap = new Map<String, Date>();
        
        for (Map<String, String> record : uploadList) {
            String receiptNo = record.get('Receipt No');
            String status = record.get('Status');
            String clearingDateStr = record.get('EBS Clearing Date');
            
            if (String.isNotBlank(receiptNo)) {
                receiptNumbers.add(receiptNo);
                
                if (String.isNotBlank(status)) {
                    receiptToStatusMap.put(receiptNo, status);
                }
                
                if (String.isNotBlank(clearingDateStr)) {
                    try {
                        Date parsedDate = Date.valueOf(clearingDateStr); 
                        receiptToClearingDateMap.put(receiptNo, parsedDate);
                    } catch (Exception e) {
                        System.debug('Invalid date format for: ' + clearingDateStr);
                    }
                }
            }
        }
        
        // Query all Receipt records using receipt numbers
        List<Receipt__c> receiptsToUpdate = [SELECT Id, Name, Status__c, EBS_Clearing_Date__c FROM Receipt__c WHERE Name IN :receiptNumbers];
        
        // Update fields
        for (Receipt__c receipt : receiptsToUpdate) {
            String newStatus = receiptToStatusMap.get(receipt.Name);
            if (String.isNotBlank(newStatus)) {
                receipt.Status__c = newStatus;
            }
            
            if (receiptToClearingDateMap.containsKey(receipt.Name)) {
                receipt.EBS_Clearing_Date__c = receiptToClearingDateMap.get(receipt.Name);
            }
        }
        
        // Commit updates
        if (!receiptsToUpdate.isEmpty()) {
            update receiptsToUpdate;
        }
    }
    
    
}