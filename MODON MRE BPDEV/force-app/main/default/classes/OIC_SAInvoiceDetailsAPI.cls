/**********************************************************************************************************************
* Name               : OIC_SAInvoiceDetailsAPI                                                        
* Description        : This class is used to fetch the invoice details based on Sales Order.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft 
* 2.0           Suresh   	                12 07 2026      MerchantId updated
* 2.1           Jay Patel                   21 Sep 2026     MCR-73 — USER_MODE SOQL
***********************************************************************************************************************/
@RestResource(urlMapping='/InvoiceDetailsAPI/*')
global without sharing class OIC_SAInvoiceDetailsAPI {

    @HttpGet
    global static void findInvoiceDetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        
        res.addHeader('Content-Type', 'application/json');
        
        try {
            String salesOrderName = req.params != null ? req.params.get('SalesOrderName') : null;
            String userEmail = req.params != null ? req.params.get('UserEmail') : null;
            if (String.isBlank(salesOrderName)) {
                returnErrorAPI.returnError(res, requestId, 'Missing mandatory query parameter: SalesOrderName', 200);
                return;
            } 
            
            System.debug('OIC_SAInvoiceDetailsAPI Searching SalesOrderName: ' + salesOrderName);
            List<Invoice> lst_InvoiceDetails = new List<Invoice>();
            
            Date twoWeeksBefore = System.today().addDays(-14);
            Date twoWeeksAfter = System.today().addDays(14);
            //2.0 change added merchant id
            //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Invoice__c query
            List<Invoice__c> lst_Invoice = [
                SELECT Id, Name, Account__r.Name, Is_ADM_Fees_and_Dari_charges__c, Charge__c, Charge__r.Name, 
                       SalesOrderInstallment__r.MilestoneDescription__c, InvoiceStatus__c, InvoiceAmount__c, 
                       AppliedAmount__c, InvoiceBalance__c, TotalPaidAmount__c,
                       Account__r.PersonEmail, Account__r.PersonMobilePhone,
                       Sales_Order__r.Unit__r.Phase__r.EscrowAccount__r.MerchantID__c, 
                       SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EscrowAccount__r.MerchantID__c,
                       Sales_Order__r.Unit__r.Phase__r.EscrowAccount__r.Current_Acc_Merchant_ID__c, 
                       SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EscrowAccount__r.Current_Acc_Merchant_ID__c,
                       Sales_Order__r.ProjectName__c, Sales_Order__r.Unit__r.Name, 
                       SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, 
                       SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name,
                       Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c, 
                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, Charge__r.Type__c,
                       (Select Id from Payment_Links__r)
                FROM Invoice__c 
                WHERE (Sales_Order__r.Name = :salesOrderName OR SalesOrderInstallment__r.SalesOrder__r.Name = :salesOrderName) 
                  AND (InvoiceStatus__c = 'Generated' OR InvoiceStatus__c = 'Partially Paid')
                  AND (InvoiceDate__c > :twoWeeksAfter OR InvoiceDate__c < :twoWeeksBefore)
                  AND (Sales_Order__r.Owner.Email = :userEmail OR SalesOrderInstallment__r.SalesOrder__r.Owner.Email = :userEmail)
                  AND Sales_Order__r.Source_Entity__c !='Modon - Egypt'
                WITH USER_MODE
                LIMIT 1000
            ];
            
            if (!lst_Invoice.isEmpty()) {
                for (Invoice__c obj_Invoice : lst_Invoice) {
                    Invoice obj_InvoiceDetails = new Invoice();
                    obj_InvoiceDetails.SalesOrderName = salesOrderName;
                    obj_InvoiceDetails.CustomerName = obj_Invoice.Account__r.Name;
                    obj_InvoiceDetails.CustomerEmail = obj_Invoice.Account__r.PersonEmail;
                    obj_InvoiceDetails.CustomerMobile = obj_Invoice.Account__r.PersonMobilePhone;
                    obj_InvoiceDetails.InvoiceName = obj_Invoice.Name;
                    obj_InvoiceDetails.InvoiceId = obj_Invoice.Id;
                    //2.0 change added merchant id
                    if (obj_Invoice.Is_ADM_Fees_and_Dari_charges__c) {
                        obj_InvoiceDetails.MilestoneName = 'ADM & Dhari Charges';
                        if (obj_Invoice.Sales_Order__r != null && String.isNotBlank(obj_Invoice.Sales_Order__r.Unit__r?.Phase__r?.EscrowAccount__r?.Current_Acc_Merchant_ID__c)) {
                        	obj_InvoiceDetails.MerchantID = obj_Invoice.Sales_Order__r.Unit__r.Phase__r.EscrowAccount__r.Current_Acc_Merchant_ID__c;
                        }
                    } else {
                        obj_InvoiceDetails.MilestoneName = obj_Invoice.Charge__c != null ? obj_Invoice.Charge__r.Name : obj_Invoice.SalesOrderInstallment__r?.MilestoneDescription__c;
                        if (obj_Invoice.SalesOrderInstallment__r?.SalesOrder__r != null && String.isNotBlank(obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.Unit__r?.Phase__r?.EscrowAccount__r?.MerchantID__c)) {
                        	obj_InvoiceDetails.MerchantID = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EscrowAccount__r.MerchantID__c;
                        }
                    }
                    
                    if (obj_Invoice.Sales_Order__r != null) {
                        obj_InvoiceDetails.ProjectName = obj_Invoice.Sales_Order__r.ProjectName__c;
                        obj_InvoiceDetails.UnitId = obj_Invoice.Sales_Order__r.Unit__r?.Name;   
                        obj_InvoiceDetails.VirtualAccountNumber = obj_Invoice.Sales_Order__r.VirtualAccount__r?.VirtualAccountNumber__c;
                    } else if (obj_Invoice.SalesOrderInstallment__r?.SalesOrder__r != null) {
                        obj_InvoiceDetails.ProjectName = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.ProjectName__c;
                        obj_InvoiceDetails.UnitId = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.Unit__r?.Name;
                        obj_InvoiceDetails.VirtualAccountNumber = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r?.VirtualAccountNumber__c;
                    }
                    
                    obj_InvoiceDetails.InvoiceStatus = obj_Invoice.InvoiceStatus__c;
                    obj_InvoiceDetails.InvoiceAmount = obj_Invoice.InvoiceBalance__c > 0 ? obj_Invoice.InvoiceBalance__c : 0.0;
                    obj_InvoiceDetails.TotalInvoiceAmount = obj_Invoice.InvoiceAmount__c > 0 ? obj_Invoice.InvoiceAmount__c : 0.0;
                    obj_InvoiceDetails.PaidInvoiceAmount = obj_Invoice.TotalPaidAmount__c > 0 ? obj_Invoice.TotalPaidAmount__c : 0.0;
                    if (obj_Invoice.Payment_Links__r != null && !obj_Invoice.Payment_Links__r.isEmpty()) {
                        obj_InvoiceDetails.PaymentLinkId = obj_Invoice.Payment_Links__r[0].Id;
                    } else {
                       obj_InvoiceDetails.PaymentLinkId = null;
                    }
                    lst_InvoiceDetails.add(obj_InvoiceDetails);
                } 
            } else {                
                //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on SalesOrder__c query
                List<SalesOrder__c> lst_SO = [SELECT Id, Owner.Email, Total_Amount_Cleared__c, TotalAmount__c 
                                              from SalesOrder__c WHERE Name = :salesOrderName 
                                              AND Source_Entity__c !='Modon - Egypt'
                                            WITH USER_MODE
                                            LIMIT 1];
                if (!lst_SO.isEmpty() && userEmail != lst_SO.get(0).Owner.Email) {
                     returnErrorAPI.returnError(res, requestId, 'PG-001', 200);
                     return;
                } else if(!lst_SO.isEmpty() && userEmail == lst_SO.get(0).Owner.Email
                         && lst_SO.get(0).TotalAmount__c > 0
                         && lst_SO.get(0).TotalAmount__c == lst_SO.get(0).Total_Amount_Cleared__c){
                    returnErrorAPI.returnError(res, requestId, 'PG-002', 200);
                    return;
                } else {
                     returnErrorAPI.returnError(res, requestId, 'PG-003', 200);
                     return;
                }
            }
            
            APIResponse response = new APIResponse('success', requestId, lst_InvoiceDetails, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.statusCode = 200;
            
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(ex, 'OIC_SAInvoiceDetailsAPI', 'OIC_SAInvoiceDetailsAPI', 'findInvoiceDetails'));
            returnErrorAPI.returnError(res, requestId, 'Internal Server Error: ' + ex.getMessage(), 200); 
        }
    }
    
    // JSON Data Transfer Object Structures
    global class Invoice {
        public String PaymentLinkId;
        public String SalesOrderName;
        global String CustomerName;
        global String CustomerEmail;
        global String CustomerMobile;
        global String InvoiceName;
        global String InvoiceId;
        global String MilestoneName;
        global String InvoiceStatus;
        global String MerchantID;
        global String ProjectName;
        global String UnitId;
        global String VirtualAccountNumber;
        global Decimal InvoiceAmount;
        global Decimal TotalInvoiceAmount;
        global Decimal PaidInvoiceAmount;
    }
    
}