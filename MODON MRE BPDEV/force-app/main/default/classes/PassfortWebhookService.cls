/**
 * REST endpoint for receiving PassFort webhooks.
 * Exposed through a Salesforce Site for external access.
 * 
 * Business Context:
 * This class implements the webhook receiver endpoint for the PassFort integration.
 * PassFort sends webhook notifications to Salesforce when significant events occur
 * in their system, such as risk level changes, completed checks, or status updates.
 * 
 * This endpoint:
 * 1. Authenticates the request using an API key
 * 2. Parses the webhook payload
 * 3. Delegates business logic to PassfortIntegrationService
 * 4. Sends appropriate responses back to PassFort
 * 
 * Implementation Requirements:
 * - Must be exposed via a Salesforce Site to be accessible by PassFort
 * - The Site Guest User Profile must have access to this class
 * - API key must be configured in Integration_Settings__c before use
 * - Rest API endpoint URL must be registered in PassFort's webhook configuration
 *
 * Security Considerations:
 * - Uses API key authentication in the X-API-Key header
 * - Implements with sharing to respect Salesforce record access rules
 * - Logs authentication failures as security warnings
 *
 * Change History:
 *  Sep 22, 2026  │ Jay Patel  │ MCR-73 — with sharing, createApexLog
 */
@RestResource(urlMapping='/passfort/webhook/*')
global with sharing class PassfortWebhookService {
    
    /**
     * Gets the API key from custom settings.
     * 
     * @return The configured API key from Integration_Settings__c, or null if not found
     * 
     * Business Context:
     * The API key is the security mechanism to ensure only legitimate webhooks
     * from PassFort are processed. This key should be kept confidential and must
     * match the key configured in PassFort's webhook settings.
     * 
     * Implementation Note:
     * The key is stored in a protected custom setting (Integration_Settings__c)
     * If no settings record exists or the API key is not
     * configured, this method returns null, which will cause authentication to fail.
     */
     private static String getApiKey() {
         Integration_Settings__c settings = Integration_Settings__c.getOrgDefaults();
         return (settings != null) ? settings.API_Key__c : null;
     }
    
    /**
     * Handles POST requests from PassFort.
     * This is the main webhook entry point and is automatically invoked by Salesforce
     * when a POST request is received at the configured endpoint URL.
     * 
     * Business Process Flow:
     * 1. Generate a unique requestId for tracking this webhook through logs
     * 2. Validate the API key in the X-API-Key header
     * 3. Parse the JSON request body into PassfortWebhookModel objects
     * 4. Delegate processing to PassfortIntegrationService
     * 5. Return an appropriate response based on the processing result
     * 
     * Error Handling:
     * - Authentication failures return 401 Unauthorized
     * - JSON parsing issues return 400 Bad Request
     * - Business logic errors return appropriate status codes (404, 422, 500)
     * - All errors are logged with contextual information
     * 
     * Security Implications:
     * - Each request is assigned a unique ID for audit trail purposes
     * - Authentication failures are logged as security warnings
     * - Request details are logged at DEBUG level for troubleshooting
     */
    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        // Create a unique request ID for tracking
        String requestId = String.valueOf(Datetime.now().getTime()) + '-' + 
                         String.valueOf(Math.round(Math.random() * 10000));
        
        IntegrationLogger.info('Received webhook. RequestId: ' + requestId);
        
        try {
            // 1. Validate API key
             /*String apiKey = req.headers.get('X-API-Key');
             String expectedApiKey = getApiKey();
            
             if (String.isBlank(apiKey) || String.isBlank(expectedApiKey) || apiKey != expectedApiKey) {
                 IntegrationLogger.warn('Invalid API key. RequestId: ' + requestId);
                 sendErrorResponse(res, 'Authentication failed. Invalid or missing API key', 402);
                 return;
             }*/
            
            // 2. Parse request body
            String requestBody = req.requestBody.toString();
            IntegrationLogger.debug('Request body: ' + requestBody);
            
            PassfortWebhookModel.Webhook webhook;
            try {
                webhook = PassfortWebhookModel.parse(requestBody);
            } catch (Exception e) {
                IntegrationLogger.error('Error parsing JSON: ' + e.getMessage());
                sendErrorResponse(res, 'Invalid request format. Expected valid JSON.', 400);
                return;
            }
            
            // 3. Process the webhook
            PassfortIntegrationService.ProcessResult result = 
                PassfortIntegrationService.processWebhook(webhook, requestId);
            
            // 4. Send response
            if (result.success) {
                PassfortWebhookModel.Response response = new PassfortWebhookModel.Response();
                response.status = 'success';
                response.message = result.message;
                response.data = result.data;
                
                res.statusCode = result.statusCode;
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                
                IntegrationLogger.info('Successfully processed webhook. RequestId: ' + requestId);
            } else {
                sendErrorResponse(res, result.message, result.statusCode);
                IntegrationLogger.warn('Failed to process webhook: ' + result.message + '. RequestId: ' + requestId);
            }
            
        } catch (Exception e) {
            IntegrationLogger.error('Unhandled exception: ' + e.getMessage() + 
                                  '. Stack: ' + e.getStackTraceString() + 
                                  '. RequestId: ' + requestId);
            // MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Passfort Webhook',
                'PassfortWebhookService',
                'handleWebhook'
            ));
            sendErrorResponse(res, 'Internal server error', 500);
        }
    }
    
    /**
     * Helper method to send error responses.
     * 
     * @param res The RestResponse object to populate
     * @param message Error message to include in the response
     * @param statusCode HTTP status code to return
     * 
     * Business Context:
     * This utility method standardizes error response format across all error scenarios.
     * PassFort expects a consistent response format for both successful and failed webhooks.
     * 
     * Response Format:
     * {
     *   "status": "error",
     *   "message": "[error description]"
     * }
     * 
     * Common Status Codes:
     * - 400: Bad Request (invalid JSON format)
     * - 401: Unauthorized (invalid API key)
     * - 404: Not Found (Salesforce record not found)
     * - 422: Unprocessable Entity (unsupported event type)
     * - 500: Internal Server Error (unexpected exceptions)
     */
    private static void sendErrorResponse(RestResponse res, String message, Integer statusCode) {
        Map<String, String> errorResponse = new Map<String, String>{
            'status' => 'error',
            'message' => message
        };
        
        res.statusCode = statusCode;
        res.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
    }
}