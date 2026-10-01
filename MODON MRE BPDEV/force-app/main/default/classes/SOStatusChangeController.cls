/**-------------------------------------------------------------------
 * Description : A controller class for dynamic action buttons component to change the status of a Sales Order record
 * -------------------------------------------------------------------
 * Version      Author           			Date               Comment
 * -------------------------------------------------------------------
 * v1.0         Abdallah Hdaib   			22-01-2024         Code Creation
 * v2.0         Horizontal       			27-11-2025         As per fathy request if Appied amount is greater than or equal to 95% of invoice amount consider it as downpayment collected
 * v3.0			Gautam Mishra (Horizontal)	23-04-2026		   Enhanced SPA check to support multiple document types for 'Modon - Egypt', iterate over all matching documents, and set result/status based on any uploaded SPA document	
 * v4.0         jay.patel                   28-08-2026         Bulkified installment invoice SOQL. Status rules unchanged.
 * v4.1         jay.patel                   28-08-2026         List SOQL and DML try-catch so Aura does not crash on missing records or update errors.
 * -------------------------------------------------------------------
 * Notes: NaN
*/
public without sharing class SOStatusChangeController {

    @AuraEnabled
    public static String getCurrentSalesOrderStatus(String salesOrderId) {
        List<SalesOrder__c> salesOrders = [SELECT Id, Status__c FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1];
        if (salesOrders.isEmpty() || String.isBlank(salesOrders[0].Status__c)) {
            return 'Empty';
        }
        return salesOrders[0].Status__c;
    }

    @AuraEnabled
    public static String checkReservationFormGenerated(String salesOrderId) {

        String result = '';

        SalesOrder__c salesOrder = getSalesOrderById(salesOrderId);
        List<Documents__c> salesOrderDocs = [SELECT Id, Name, SalesOrder__c, Status__c FROM Documents__c WHERE SalesOrder__c =: salesOrderId AND name = 'Reservation Form'];

        if(salesOrder != null){
            if(!salesOrderDocs.isEmpty()){
                if(salesOrderDocs[0].Status__c == 'Uploaded'){
                    result = 'Success';
                    salesOrder.Status__c = 'Reservation form generated';
                    result = updateSalesOrder(salesOrder, result);
                } else {
                    result = 'Failed';
                }
            }
        }

        return result;
    }

    @AuraEnabled
    public static String checkDownPaymentCollected(String salesOrderId) {

        String result = '';

        SalesOrder__c salesOrder = getSalesOrderById(salesOrderId);
        SalesOrderInstallments__c salesOrderInstallements = getMilestoneOneInstallment(salesOrderId);

        if(salesOrder != null){
            if(salesOrderInstallements != null){
                Invoice__c invoiceObj = getInvoiceForInstallment(salesOrderInstallements.Id);
                if(invoiceObj != null){
                    // if(invoiceObj.InvoiceStatus__c == 'Paid'){

                        if(salesOrder.Source_Entity__c == 'Modon - Egypt'){
                            //v2.0
                            if(invoiceObj.AppliedAmount__c >= invoiceobj.InvoiceAmount__c * (1- 0.05)){
                            result = 'Success';
                            salesOrder.Status__c = 'Down payment collected';
                            result = updateSalesOrder(salesOrder, result);
                            } else {
                            result = 'Failed';
                            }
                        }
                        else{
                            if(invoiceObj.AppliedAmount__c == invoiceobj.InvoiceAmount__c){
                            result = 'Success';
                            salesOrder.Status__c = 'Down payment collected';
                            result = updateSalesOrder(salesOrder, result);
                            } else {
                            result = 'Failed';
                            }
                        }
                    // } else {
                    //     result = 'Failed';
                    // }
                } else {
                    result = 'Failed';
                }
            }
        }

        return result;
    }

    @AuraEnabled
    public static String checkDpPaymentConfirmed(String salesOrderId) {

        String result = '';

        SalesOrder__c salesOrder = getSalesOrderById(salesOrderId);
        SalesOrderInstallments__c salesOrderInstallements = getMilestoneOneInstallment(salesOrderId);

        if(salesOrder != null){
            if(salesOrderInstallements != null){
                Invoice__c invoiceObj = getInvoiceForInstallment(salesOrderInstallements.Id);
                if(invoiceObj != null){
                    if(invoiceObj.InvoiceStatus__c == 'Paid'){
                        if(invoiceObj.AppliedAmount__c == invoiceobj.InvoiceAmount__c){
                            result = 'Success';
                            salesOrder.Status__c = 'DP Payment Confirmed';
                            result = updateSalesOrder(salesOrder, result);
                        } else {
                            result = 'Failed';
                        }
                    } else {
                        result = 'Failed';
                    }
                } else {
                    result = 'Failed';
                }
            }
        }

        return result;
    }

    @AuraEnabled
    public static String checkReservationFormSigned(String salesOrderId) {

        String result = '';

        SalesOrder__c salesOrder = getSalesOrderById(salesOrderId);
        List<Documents__c> salesOrderDocs = [SELECT Id, Name, SalesOrder__c, Status__c FROM Documents__c WHERE SalesOrder__c =: salesOrderId AND name = 'Signed Reservation Form'];

        if(salesOrder != null){
            if(!salesOrderDocs.isEmpty()){
                if(salesOrderDocs[0].Status__c == 'Uploaded'){
                    result = 'Success';
                    salesOrder.Status__c = 'Reservation form signed';
                    result = updateSalesOrder(salesOrder, result);
                } else {
                    result = 'Failed';
                }
            }
        }

        return result;
    }

    @AuraEnabled
    public static String checkInstallementPaymentCollected(String salesOrderId) {

        String result = '';
        List<Boolean> checkAllSOI = new List<Boolean>();

        SalesOrder__c salesOrder = getSalesOrderById(salesOrderId);
        List<SalesOrderInstallments__c> salesOrderInstallements = [SELECT Id, Name, Milestone__c FROM SalesOrderInstallments__c WHERE SalesOrder__c =: salesOrderId];

        if(salesOrder != null){
            if(salesOrderInstallements != null){
                Map<Id, Invoice__c> invoiceByInstallmentId = getInvoicesByInstallmentId(salesOrderInstallements);
                for(SalesOrderInstallments__c soi : salesOrderInstallements){
                    Invoice__c invoiceObj = invoiceByInstallmentId.get(soi.Id);
                    if(invoiceObj != null){
                        // if(invoiceObj.InvoiceStatus__c == 'Paid'){
                            if(invoiceObj.AppliedAmount__c == invoiceobj.InvoiceAmount__c){
                                checkAllSOI.add(true);
                            } else {
                                checkAllSOI.add(false);
                            }
                        // } else {
                        //     checkAllSOI.add(false);
                        // }
                    } else {
                        checkAllSOI.add(false);
                    }
                }
            }
        }

        if(!checkAllSOI.isEmpty()){
            if(checkAllSOI.contains(false)){
                result = 'Failed';
            } else {
                result = 'Success';
                salesOrder.Status__c = 'Installment payment collected';
                result = updateSalesOrder(salesOrder, result);
            }
        }

        return result;
    }

    @AuraEnabled
    public static String checkInstallementPaymentCollectedEgypt(String salesOrderId) {

        String result = '';
        List<Boolean> checkAllSOI = new List<Boolean>();

        SalesOrder__c salesOrder = getSalesOrderById(salesOrderId);
        List<SalesOrderInstallments__c> salesOrderInstallements = [SELECT Id, Name, Milestone__c FROM SalesOrderInstallments__c WHERE SalesOrder__c =: salesOrderId];

        if(salesOrder != null){
            if(salesOrderInstallements != null){
                Map<Id, Invoice__c> invoiceByInstallmentId = getInvoicesByInstallmentId(salesOrderInstallements);
                for(SalesOrderInstallments__c soi : salesOrderInstallements){
                    Invoice__c invoiceObj = invoiceByInstallmentId.get(soi.Id);
                    if(invoiceObj != null){
                        if(invoiceObj.InvoiceStatus__c == 'Paid'){
                            if(invoiceObj.AppliedAmount__c == invoiceobj.InvoiceAmount__c){
                                checkAllSOI.add(true);
                            } else {
                                checkAllSOI.add(false);
                            }
                         } else {
                             checkAllSOI.add(false);
                         }
                    } else {
                        checkAllSOI.add(false);
                    }
                }
            }
        }

        if(!checkAllSOI.isEmpty()){
            if(checkAllSOI.contains(false)){
                result = 'Failed';
            } else {
                result = 'Success';
                salesOrder.Status__c = 'Installment payment collected';
                result = updateSalesOrder(salesOrder, result);
            }
        }

        return result;
    }

    //v3.0
    @AuraEnabled
    public static String checkSPAGenerated(String salesOrderId) {

        String result = 'Failed';

        List<SalesOrder__c> salesOrders = [SELECT Id, Status__c, Source_Entity__c FROM SalesOrder__c WHERE id =: salesOrderId LIMIT 1];

        if(!salesOrders.isEmpty()) {
            SalesOrder__c salesOrder = salesOrders[0];
            List<Documents__c> salesOrderDocs = new List<Documents__c>();
            
            if (salesOrder.Source_Entity__c == ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY) {
                Set<String> egyptSPADocNames = ModonEgyptConstants.EGYPT_SPA_DOC_NAMES;
                salesOrderDocs = [SELECT Id, Name, SalesOrder__c, Status__c FROM Documents__c WHERE SalesOrder__c =: salesOrderId AND name IN :egyptSPADocNames AND Status__c = 'Uploaded'];
            } else {
                salesOrderDocs = [SELECT Id, Name, SalesOrder__c, Status__c FROM Documents__c WHERE SalesOrder__c =: salesOrderId AND name = 'SPA' AND Status__c = 'Uploaded'];
            }
           
            if(!salesOrderDocs.isEmpty()){
                //Send success if any SPA document is uploaded
                result = 'Success';
                salesOrder.Status__c = 'SPA Generated';
                result = updateSalesOrder(salesOrder, result);
            } else {
                result = salesOrder.Source_Entity__c != ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY ? 'Failed' : 'Failed Egypt';
            }
        }

        return result;
    }

    @AuraEnabled
    public static String checkSignedSPACustomer(String salesOrderId) {

        String result = '';

        SalesOrder__c salesOrder = getSalesOrderById(salesOrderId);
        List<Documents__c> salesOrderDocs = [SELECT Id, Name, SalesOrder__c, Status__c FROM Documents__c WHERE SalesOrder__c =: salesOrderId AND name = 'Signed SPA (Customer)'];

        if(salesOrder != null){
            if(!salesOrderDocs.isEmpty()){
                if(salesOrderDocs[0].Status__c == 'Uploaded'){
                    result = 'Success';
                    salesOrder.Status__c = 'SPA Signed (Customer)';
                    result = updateSalesOrder(salesOrder, result);
                } else {
                    result = 'Failed';
                }
            }
        }

        return result;
    }

    @AuraEnabled
    public static String checkSignedSPAModon(String salesOrderId) {

        String result = '';

        SalesOrder__c salesOrder = getSalesOrderById(salesOrderId);
        List<Documents__c> salesOrderDocs = [SELECT Id, Name, SalesOrder__c, Status__c FROM Documents__c WHERE SalesOrder__c =: salesOrderId AND name = 'Signed SPA (Modon)'];

        if(salesOrder != null){
            if(!salesOrderDocs.isEmpty()){
                if(salesOrderDocs[0].Status__c == 'Uploaded'){
                    result = 'Success';
                    salesOrder.Status__c = 'SPA Signed (Modon)';
                    result = updateSalesOrder(salesOrder, result);
                } else {
                    result = 'Failed';
                }
            }
        }

        return result;
    }

    @AuraEnabled
    public static Boolean checkSubmitButtonVisibility(String leadId){
        system.debug('leadId==>' + leadId);

        List<Lead> leads = [SELECT Id, OwnerId FROM Lead WHERE Id = :leadId LIMIT 1];
        if (leads.isEmpty()) {
            return false;
        }
        Id ownerId = leads[0].OwnerId;
        Id userId = UserInfo.getUserId();
        system.debug(ownerId == userId);
        if(ownerId == userId){
            return true;
        }
        return false;
    }

    @AuraEnabled
    public static string reassignLead(String leadId){
        String result;

        List<Lead> leads = [SELECT Id, OwnerId, UAEResidentStatus__c, (SELECT Id, Status__c, Name FROM Documents__r WHERE Name IN ('Passport Copy','Emirates ID') AND Status__c = 'Pending Upload') FROM Lead WHERE Id = :leadId LIMIT 1];
        if (leads.isEmpty()) {
            return 'Failed';
        }
        Lead leObj = leads[0];
        set<String> pendingUploadDocument = new set<String>();
        
        if(!leObj.Documents__r.isEmpty()){
            for(Documents__c docObj : leObj.Documents__r){
                pendingUploadDocument.add(docObj.Name);
            }
        }

        if(leObj.UAEResidentStatus__c == 'Non-Resident' && pendingUploadDocument.contains('Passport Copy')){
            return 'Passport copy is required for non resident.';
        }else if(leObj.UAEResidentStatus__c == 'Resident'&& (pendingUploadDocument.contains('Passport Copy') || pendingUploadDocument.contains('Emirates ID'))){
            return 'Passport copy and Emirates Id is required for resident.';
        }

        leObj.ReAssignRRToSalesAssociate__c = true;
        try{
            update leObj;
            return 'Success';
        }catch(Exception ex){
            return ex.getMessage();
        }
        
    }

    @AuraEnabled 
    public static String reassignLeadToSA(String leadId){

        String result = '';

        List<Lead> leads = [SELECT Id, ReAssignRRToSalesAssociate__c FROM Lead WHERE Id =: leadId LIMIT 1];

        try{
            if(!leads.isEmpty()){
                Lead leadObj = leads[0];
                leadObj.ReAssignRRToSalesAssociate__c = true;
                update leadObj;
                result = 'Success';
            }
        }catch(DMLException e) {
            
            result = 'Failed';
        }

        return result;
    }

    private static SalesOrder__c getSalesOrderById(String salesOrderId) {
        List<SalesOrder__c> salesOrders = [
            SELECT Id, Status__c, Source_Entity__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];
        return salesOrders.isEmpty() ? null : salesOrders[0];
    }

    private static SalesOrderInstallments__c getMilestoneOneInstallment(String salesOrderId) {
        List<SalesOrderInstallments__c> installments = [
            SELECT Id, Name, Milestone__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :salesOrderId AND MilestoneNumber__c = 1
            LIMIT 1
        ];
        return installments.isEmpty() ? null : installments[0];
    }

    private static Invoice__c getInvoiceForInstallment(Id installmentId) {
        List<Invoice__c> invoices = [
            SELECT Id, Name, InvoiceStatus__c, AppliedAmount__c, InvoiceAmount__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__c = :installmentId
            LIMIT 1
        ];
        return invoices.isEmpty() ? null : invoices[0];
    }

    private static String updateSalesOrder(SalesOrder__c salesOrder, String successResult) {
        try {
            update salesOrder;
            return successResult;
        } catch (Exception e) {
            return 'Failed';
        }
    }

    private static Map<Id, Invoice__c> getInvoicesByInstallmentId(List<SalesOrderInstallments__c> salesOrderInstallements) {
        Map<Id, Invoice__c> invoiceByInstallmentId = new Map<Id, Invoice__c>();
        if (salesOrderInstallements == null || salesOrderInstallements.isEmpty()) {
            return invoiceByInstallmentId;
        }
        Set<Id> installmentIds = new Set<Id>();
        for (SalesOrderInstallments__c soi : salesOrderInstallements) {
            installmentIds.add(soi.Id);
        }
        for (Invoice__c invoiceObj : [
            SELECT Id, Name, InvoiceStatus__c, AppliedAmount__c, InvoiceAmount__c, TotalPaidAmount__c, SalesOrderInstallment__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__c IN :installmentIds
        ]) {
            if (!invoiceByInstallmentId.containsKey(invoiceObj.SalesOrderInstallment__c)) {
                invoiceByInstallmentId.put(invoiceObj.SalesOrderInstallment__c, invoiceObj);
            }
        }
        return invoiceByInstallmentId;
    }
}