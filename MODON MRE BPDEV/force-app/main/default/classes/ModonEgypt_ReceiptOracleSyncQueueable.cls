/**
 * @description       : Queueable Apex job responsible for asynchronously
 *                      updating Oracle Receipts using SOAP-based integration.
 *                      Designed to handle callouts safely by offloading
 *                      receipt update operations to a Queueable context.
 *
 *                      Uses metadata-driven endpoint configuration and
 *                      updates Oracle Receipt DFF attributes based on
 *                      Salesforce Receipt changes.
 *
 * @author            : Gautam Mishra
 * @company           : Horizontal Digital
 * @last modified on  : 23-01-2026
 * @last modified by  : Gautam Mishra
 *
 * Modifications Log
 * Ver   Date         Author             Modification
 * 1.0   23-01-2026   Gautam Mishra       Initial Version
 */
public class ModonEgypt_ReceiptOracleSyncQueueable implements Queueable, Database.AllowsCallouts {

    private List<Receipt__c> receipts;

    /**
     * @description       : Constructor to initialize Queueable job with
     *                      Receipt records that require Oracle update.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    public ModonEgypt_ReceiptOracleSyncQueueable(List<Receipt__c> receipts) {
        this.receipts = receipts;
    }

    /**
     * @description       : Executes Queueable job to update Oracle Receipts.
     *                      Iterates over provided Receipt records, performs
     *                      SOAP callouts, and updates integration status
     *                      back in Salesforce.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    public void execute(QueueableContext qc) {
        List<Receipt__c> receiptsToUpdate = new List<Receipt__c>();
        
        for (Receipt__c rec : receipts) {
            receiptsToUpdate.add(updateReceiptToOracle(rec));
        }
        
        if (!receiptsToUpdate.isEmpty()) {
            update receiptsToUpdate;
        }
    }

    /**
     * @description       : Builds and sends SOAP XML request to Oracle Fusion
     *                      to update Receipt DFF attributes.
     *                      Parses SOAP response and prepares Salesforce
     *                      Receipt record with Oracle integration status.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    private Receipt__c updateReceiptToOracle(Receipt__c rec) {
        Receipt__c recToUpdate = new Receipt__c(Id = rec.Id);
        
        try {
            Boolean isSandboxOrg = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
            
            // Load Metadata config
            List<Oracle_Integration_Config__mdt> configs = [
                SELECT Endpoint__c, Username__c, Password__c
                FROM Oracle_Integration_Config__mdt
                WHERE Object_API_Name__c = 'Receipt__c'
                  AND Operation_Type__c = 'UPDATE'
                  AND Is_Sandbox__c =: isSandboxOrg
                LIMIT 1
            ];
            
            Oracle_Integration_Config__mdt config;
            
            if (!configs.isEmpty()) {
                config = configs[0];
            } 
            else {
                recToUpdate.Oracle_Integration_Status_Modon_Egypt__c = 'Failed';
                recToUpdate.Oracle_Status_Code_Modon_Egypt__c = '500';
                recToUpdate.Oracle_Integration_Message_Modon_Egypt__c = 'Syncing Failed : Invalid Credentials or Credentials are not available in metadata records';
                return recToUpdate;
            }
    
            // Basic Auth header
            String authHeader = 'Basic ' + EncodingUtil.base64Encode(
                Blob.valueOf(config.Username__c + ':' + config.Password__c)
            );
            
            String userKeyA = rec.Modeofpayment__c == 'Cheque' ? rec.Cheque_Number__c : rec.TransactionNumber__c;
            String unitType = rec.SalesOrder__c != null ? rec.SalesOrder__r.Unit__r.UnitClassification__c  : null;
            String salesOrder = rec.SalesOrder__c != null ? rec.SalesOrder__r.Name : null;
    
            // Create SOAP XML body
            String soapBody =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
            'xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/" ' +
            'xmlns:erp="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/">' +
                '<soapenv:Header/>' +
                '<soapenv:Body>' +
                    '<typ:updateDffEntityDetails>' +
                        '<typ:operationMode>single</typ:operationMode>' +
    
                        '<typ:object>' +
                            '<erp:EntityName>Receivables Invoice Cash Receipt</erp:EntityName>' +
                            '<erp:ContextValue>EOI DETAILS</erp:ContextValue>' +
                            '<erp:UserKeyA>' + userKeyA + '</erp:UserKeyA>' +
                            '<erp:UserKeyB>' + rec.Oracle_Receipt_Id__c + '</erp:UserKeyB>' +
    
                            '<erp:DFFAttributes>{' +
                                '"sfReceiptNo": "' + rec.Name + '",' +
                                '"unittype": "' + unitType + '",' +
                                '"unitNumber": "' + rec.UnitNumber__c + '",' +
                                '"appliedAmount": "' + rec.AppliedAmount__c + '",' +
                                '"remainingAmount": "' + rec.RemainingAmount__c + '",' +
                                '"salesOrderNumber": "' + salesOrder + '",' +
                                '"receiptStatus": "' + rec.Status__c + '",' +
                                '"modeOfPayment": "' + rec.Modeofpayment__c + '"' +
                            '}</erp:DFFAttributes>' +
                        '</typ:object>' +
    
                    '</typ:updateDffEntityDetails>' +
                '</soapenv:Body>' +
            '</soapenv:Envelope>';
            
            System.debug('Payload>>> '+soapBody);
    
            // Prepare HTTP Request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(config.Endpoint__c);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml');
            req.setHeader('Authorization', authHeader);
            req.setTimeout(120000);
            req.setBody(soapBody);
    
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            String responseBody = res.getBody();
            
            // Parse <result> tag
            String resultValue = extractResultValue(responseBody);
            if (resultValue == '1') {
                recToUpdate.Oracle_Integration_Status_Modon_Egypt__c = 'Success';
                recToUpdate.Oracle_Status_Code_Modon_Egypt__c = '200';
                recToUpdate.Oracle_Integration_Message_Modon_Egypt__c = 'Receipt Record Updated Successfully';
            } else if (resultValue == '0'){
                recToUpdate.Oracle_Integration_Status_Modon_Egypt__c = 'Failed';
                recToUpdate.Oracle_Status_Code_Modon_Egypt__c = '400';
                recToUpdate.Oracle_Integration_Message_Modon_Egypt__c = responseBody;
            }
            
            System.debug('Oracle SOAP Response: ' + res.getStatusCode() + ' | ' + res.getBody());
        }
        catch(Exception e){
            recToUpdate.Oracle_Integration_Status_Modon_Egypt__c = 'Failed';
            recToUpdate.Oracle_Integration_Message_Modon_Egypt__c = e.getMessage();
        }
        
        return recToUpdate;
    }
    
    /**
     * @description       : Extracts the <result> value from Oracle SOAP
     *                      response XML to determine operation success
     *                      or failure.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    private static String extractResultValue(String soapResponse) {

        if (String.isBlank(soapResponse)) return null;

        Integer start = soapResponse.indexOf('<result');
        if (start == -1) return null;

        start = soapResponse.indexOf('>', start) + 1;
        Integer endPoint = soapResponse.indexOf('</result>', start);

        if (endPoint == -1) return null;

        return soapResponse.substring(start, endPoint).trim();
    }
}