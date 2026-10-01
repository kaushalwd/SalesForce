/**
 * @description       : Queueable Apex class responsible for applying
 *                      Salesforce Receipt allocations to Oracle Receivables.
 *                      Invoked both asynchronously and via Flow using
 *                      an invocable method.
 *
 *                      Uses SOAP-based Oracle APIs to apply receipts
 *                      against installment or maintenance invoices
 *                      with exchange-rate handling.
 *
 * @author            : Gautam Mishra
 * @company           : Horizontal Digital
 * @last modified on  : 13-02-2026
 * @last modified by  : Gautam Mishra
 *
 * Modifications Log
 * Ver   Date         Author             Modification
 * 1.0   23-01-2026   Gautam Mishra      Initial Version
 * 2.0	 17-02-2026	  Gautam Mishra		 Modified Success Message of response from API
 */
public class ModonEgypt_ReceiptApplyQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> allocationIds;

    /**
     * @description       : Constructor used to initialize Queueable job
     *                      with Allocation record IDs that need to be
     *                      applied to Oracle invoices.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    public ModonEgypt_ReceiptApplyQueueable(List<Id> allocationIds) {
        this.allocationIds = allocationIds;
    }

    /**
     * @description       : Executes Queueable job to apply receipts to Oracle.
     *                      Delegates processing to the invocable method
     *                      for reuse with Flow and Queueable execution.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    public void execute(QueueableContext context) {
        applyReceiptFromFlow(allocationIds);
    }
      
    /**
     * @description       : Invocable method exposed to Salesforce Flow
     *                      to apply Receipt allocations to Oracle.
     *                      Processes Allocation records related to
     *                      Modon Egypt Sales Orders.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    @InvocableMethod(label='Apply Receipt to Oracle' description='Applies receipt allocation to Oracle')
    public static void applyReceiptFromFlow(List<Id> allocationIds) {
        List<ResponseWrapper> responseList = new List<ResponseWrapper>();
        List<Allocation__c> recsToUpdate = new List<Allocation__c>();
        
        List<Allocation__c> allocations = [
            SELECT Id,
                   Allocation_Amount_in_Receipt_Currency__c,
                   AllocationAmount__c,
            	   CreatedDate,
                   Receipt__r.Id,
            	   Receipt__r.Receipt_Type__c,
            	   Receipt__r.ChequeDate__c,
                   Receipt__r.CurrencyIsoCode,
                   Receipt__r.CreatedDate,
                   Receipt__r.Oracle_Receipt_Id__c,
                   Receipt__r.Modeofpayment__c,
                   Receipt__r.AccountingDate_Egypt__c,
                   Invoice__r.Id,
                   Invoice__r.CurrencyIsoCode,
                   Invoice__r.CreatedDate,
                   Invoice__r.Oracle_Maintenance_Invoice_Id__c,
                   Invoice__r.Oracle_Installment_Invoice_Id__c,
                   Invoice__r.SalesOrderInstallment__r.Maintenance_Fee__c,
            	   Invoice__r.SalesOrderInstallment__r.MilestoneDate__c,
                   Invoice__r.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c,
            	   Invoice__r.SalesOrderInstallment__r.SalesOrder__r.SPA_Signed_Date_Time_Modon_Egypt__c
            FROM Allocation__c
            WHERE Id IN :allocationIds
            AND Invoice__r.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c = 'Modon - Egypt'
        ];

        for (Allocation__c alloc : allocations) {
            ResponseWrapper response = applyReceiptToOracle(alloc);
            if (response != null) {
                Allocation__c recToUpdate = new Allocation__c(Id = alloc.Id);
                recToUpdate.Oracle_Integration_Status_Modon_Egypt__c = response.Status;
                recToUpdate.Oracle_Apply_Receipt_Status_Modon_Egypt__c = response.ReceiptApplyStatus;
                recToUpdate.Oracle_Status_Code_Modon_Egypt__c = response.StatusCode;
                recToUpdate.Oracle_Integration_Message_Modon_Egypt__c = response.Message;
                recsToUpdate.add(recToUpdate);
            }
        }
        
        if(!recsToUpdate.isEmpty()){
            update recsToUpdate;
        }
    }

    /**
     * @description       : Applies a Salesforce Receipt allocation to
     *                      an Oracle invoice using SOAP integration.
     *                      Determines invoice type (installment or maintenance),
     *                      calculates exchange rates when required, and
     *                      updates Oracle with receipt application details.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra      Initial Version
     * 2.0	 17-02-2026	  Gautam Mishra		 Modified Success Message of response from API
     */
    private static ResponseWrapper applyReceiptToOracle(Allocation__c alloc) {
        ResponseWrapper response = new ResponseWrapper();

        try {

            // Check if the current user is an integration user
            User currentUser = [SELECT Id, Name, Profile.Name 
                                FROM User 
                                WHERE Id = :UserInfo.getUserId()];
            
            Boolean isIntegrationUser = false;
            
            // Check profile
            if (currentUser.Profile.Name == 'Modon Egypt - Salesforce Integration Profile' && currentUser.Name == 'Integration User (Modon - Egypt)') {
                isIntegrationUser = true;
            }
            
            if (!isIntegrationUser) {
                Boolean isSandboxOrg = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
                
                List<Oracle_Integration_Config__mdt> configs = [
                    SELECT Endpoint__c, Username__c, Password__c
                    FROM Oracle_Integration_Config__mdt
                    WHERE Object_API_Name__c = 'Receipt__c'
                      AND Operation_Type__c = 'APPLY'
                      AND Is_Sandbox__c =: isSandboxOrg
                    LIMIT 1
                ];
                
                Oracle_Integration_Config__mdt config;
                
                if (!configs.isEmpty()) {
                    config = configs[0];
                } 
                else {
                    response.Status = 'Failed';
                    response.ReceiptApplyStatus = 'Unapplied';
                    response.StatusCode = '500';
                    response.Message = 'Syncing Failed : Invalid Credentials or Credentials are not available in metadata records';
                    return response;
                }
        
                String authHeader = 'Basic ' + EncodingUtil.base64Encode(
                    Blob.valueOf(config.Username__c + ':' + config.Password__c)
                );
        
                Receipt__c rec = alloc.Receipt__r;
                Invoice__c inv = alloc.Invoice__r;
                
                String customerTrxId;
                
                if (rec.Receipt_Type__c == 'Maintenance Receipt') {
                    customerTrxId = inv.Oracle_Maintenance_Invoice_Id__c;
                }
                else {
                    customerTrxId = inv.Oracle_Installment_Invoice_Id__c;
                }
        
                Decimal appliedAmount = alloc.AllocationAmount__c;
        
                String receiptCurrency = rec.CurrencyIsoCode;
                String invoiceCurrency = inv.CurrencyIsoCode;
        
                String exchangeRate = '';
        
                // -------------------------------------------
                // Exchange Rate Logic
                // -------------------------------------------
                if (receiptCurrency != invoiceCurrency) {
        
                    List<Currency_Conversion_Rate__c> rates = [
                        SELECT Conversion_Rate__c, Inverse_Conversion_Rate__c 
                        FROM Currency_Conversion_Rate__c
                        WHERE Rate_Date__c = :alloc.CreatedDate.Date()
                        AND CurrencyIsoCode = :receiptCurrency
                        AND Target_Currency__c = :invoiceCurrency
                        LIMIT 1
                    ];
        
                    if (rates.isEmpty()) {
                        throw new CalloutException(
                            'No exchange rate found for ' +
                            receiptCurrency + ' - ' + invoiceCurrency +
                            ' on ' + System.today()
                        );
                    }
        
                    exchangeRate = String.valueof(rates[0].Inverse_Conversion_Rate__c);
                }
        
                //String receiptDate = String.valueof(rec.CreatedDate.date());
                String receiptDate = (rec.Modeofpayment__c == 'Cheque' && rec.ChequeDate__c != null && rec.ChequeDate__c < rec.CreatedDate.date()) ? String.valueOf(rec.ChequeDate__c) : String.valueOf(rec.CreatedDate.date());
                //String invoiceDate = String.valueof(inv.CreatedDate.date());
                Date milestoneDate = inv.SalesOrderInstallment__r.MilestoneDate__c;
        
                // Convert SPA DateTime to Date (null safe)
                Date spaSignedDate = inv.SalesOrderInstallment__r.SalesOrder__r.SPA_Signed_Date_Time_Modon_Egypt__c != null ? inv.SalesOrderInstallment__r.SalesOrder__r.SPA_Signed_Date_Time_Modon_Egypt__c.date() : Date.today();
                
                Date transactionDate = null;
                
                // Null handling logic
                if (milestoneDate != null && spaSignedDate != null) {
                    transactionDate = milestoneDate < spaSignedDate ? milestoneDate : spaSignedDate;
                }
                else if (milestoneDate != null) {
                    transactionDate = milestoneDate;
                }
                else if (spaSignedDate != null) {
                    transactionDate = spaSignedDate;
                }

                String tranDateStr = String.valueOf(transactionDate).substring(0,10);
                Date accDate = rec.AccountingDate_Egypt__c != null ? rec.AccountingDate_Egypt__c : System.today();

                Date latestDate = transactionDate > accDate ? transactionDate : accDate;
                String accDateStr = String.valueOf(latestDate).substring(0,10);
        
                
                // --------------------------------------------------
                // SOAP Payload
                // --------------------------------------------------
                String soapBody =
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:typ="http://xmlns.oracle.com/apps/financials/receivables/receipts/shared/standardReceiptService/commonService/types/" ' +
                'xmlns:com="http://xmlns.oracle.com/apps/financials/receivables/receipts/shared/standardReceiptService/commonService/" ' +
                'xmlns:typ1="http://xmlns.oracle.com/adf/svc/types/">' +
                    '<soapenv:Header/>' +
                    '<soapenv:Body>' +
                        '<typ:processApplyReceipt>' +
                            '<typ:changeOperation>Create</typ:changeOperation>' +
                            '<typ:applyReceipt>' +
        
                                '<com:AmountApplied>' + appliedAmount + '</com:AmountApplied>' +
                                '<com:ReceiptId>' + rec.Oracle_Receipt_Id__c + '</com:ReceiptId>' +
                                '<com:CustomerTrxId>' + customerTrxId + '</com:CustomerTrxId>' +
        
                                '<com:ReceiptAmount currencyCode="' + invoiceCurrency + '">' +
                                    appliedAmount +
                                '</com:ReceiptAmount>' +
        
                                '<com:ReceiptDate>' + receiptDate + '</com:ReceiptDate>' +
                                '<com:TransactionDate>' + tranDateStr + '</com:TransactionDate>' +
                                '<com:ReceiptCurrency>' + invoiceCurrency + '</com:ReceiptCurrency>'+
                                '<com:ExchangeRate>' + exchangeRate +'</com:ExchangeRate>'+
                                '<com:ApplicationDate>' + accDateStr + '</com:ApplicationDate>' +
                                '<com:AccountingDate>' + accDateStr + '</com:AccountingDate>' +
                            '</typ:applyReceipt>' +
        
                            '<typ:processControl>' +
                                '<typ1:returnMode>Full</typ1:returnMode>' +
                                '<typ1:exceptionReturnMode>Full</typ1:exceptionReturnMode>' +
                                '<typ1:partialFailureAllowed>false</typ1:partialFailureAllowed>' +
                            '</typ:processControl>' +
                        '</typ:processApplyReceipt>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>';
        
                System.debug('Apply Receipt Payload >>> ' + soapBody);
        
                HttpRequest req = new HttpRequest();
                req.setEndpoint(config.Endpoint__c);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'text/xml');
                req.setHeader('Authorization', authHeader);
                req.setTimeout(120000);
                req.setBody(soapBody);
        
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                if((res.getStatusCode() == 200 || res.getStatusCode() == 201)){
                    response.Status = 'Success';
                    response.ReceiptApplyStatus = 'Applied';
                    response.StatusCode = String.valueof(res.getStatusCode());
                    //v2.0(Line 279)
                    response.Message = 'Synced Successfully: Receipt is applied for the related invoice successfully';
                }
                
                else if((res.getStatusCode() == 400 || res.getStatusCode() == 401 || res.getStatusCode() == 500)){
                    response.Status = 'Failed';
                    response.ReceiptApplyStatus = 'Unapplied';
                    response.StatusCode = String.valueof(res.getStatusCode());
                    response.Message = 'Syncing Failed : ' + res.getBody();
                }
        
                System.debug(
                    'Oracle Apply Receipt Response >>> ' +
                    res.getStatusCode() + ' | ' + res.getBody()
                );
            }

        } catch (Exception e) {

            response.Status = 'Failed';
            response.ReceiptApplyStatus = 'Unapplied';
            response.StatusCode = '500';
            response.Message = e.getMessage();
        }
        return response;
    }
    
    /**
     * @description       : Wrapper class used to standardize Oracle
     *                      receipt application responses.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    public class ResponseWrapper{
        public String ReceiptApplyStatus;
        public String Message;
        public String StatusCode;
        public String Status;
    }
}