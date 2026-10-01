/**********************************************************************************************************************
 * Name               : ModonEgypt_ConversionRateAPICallout
 * Description        : Queueable class to make API callout
 * Usage              : Called by ModonEgypt_ConversionRateAPIScheduler
 * Created By         : 
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                                   Date            Comment
 * 1.0           Shahil Sinha (Horizontal)              17-12-2025      Initial Version
 * 1.1           Shahil Sinha (Horizontal)              18-12-2025      Added IsSandboxOrg check
 **********************************************************************************************************************/
public class ModonEgypt_ConversionRateAPICallout implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        try {

            //v1.1 (line 17 & 34)
            Boolean isSandboxOrg = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;

            // Get configuration from Custom Metadata
            List<Oracle_Integration_Config__mdt> configs = [
                SELECT Endpoint__c, Username__c, Password__c 
                FROM Oracle_Integration_Config__mdt 
                WHERE Object_API_Name__c = 'Currency_Conversion_Rate__c' 
                AND Operation_Type__c = 'Upsert'
                AND Is_Sandbox__c = :isSandboxOrg
                LIMIT 1
            ];

            Oracle_Integration_Config__mdt config;
            if (!configs.isEmpty()) {
                config = configs[0];
            } else {
               throw new CalloutException('Error: Invalid Credentials or Credentials are not available in metadata records');
            }
            
            String endpoint = config.Endpoint__c;
            String username = config.Username__c;
            String password = config.Password__c;

            String From_Date = Datetime.newInstance(System.today(), Time.newInstance(0, 0, 0, 0)).format('MM-dd-yyyy');
            String To_Date = Datetime.newInstance(System.today().addMonths(1), Time.newInstance(0, 0, 0, 0)).format('MM-dd-yyyy');

            endpoint += '?From_Date=' + EncodingUtil.urlEncode(From_Date, 'UTF-8');
            endpoint += '&To_Date=' + EncodingUtil.urlEncode(To_Date, 'UTF-8');

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setTimeout(120000);
            req.setHeader('Accept-Encoding', 'gzip, deflate, br');
            req.setHeader('Accept', '*/*');

            // Basic Authentication
            String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password));
            req.setHeader('Authorization', authHeader);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('API Response Status: ' + res.getStatusCode());
            System.debug('API Response Body: ' + res.getBody());
            
        } catch (Exception ex) {
            System.debug('Exception: ' + ex.getMessage());
        }
    }
}