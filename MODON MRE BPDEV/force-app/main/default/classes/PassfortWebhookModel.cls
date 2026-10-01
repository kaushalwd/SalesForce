/**
 * Data model for PassFort webhook payloads.
 * Defines the structure of incoming webhooks for type-safe processing.
 * 
 * Business Context:
 * PassFort is a KYC/AML service that sends webhook notifications to Salesforce when
 * significant events occur, such as risk level changes, completed checks, or product
 * status changes. This class provides the type-safe structure needed to deserialize 
 * and process these webhook payloads.
 * 
 * Usage:
 * 1. The PassfortWebhookService receives JSON payloads from PassFort
 * 2. The parse() method converts the JSON into typed objects
 * 3. The PassfortIntegrationService uses these typed objects for business logic processing
 * 
 * Integration Pattern:
 * This class implements a standard webhook receiver pattern, where the structure
 * matches the expected JSON payload format from PassFort's API.
 */
public class PassfortWebhookModel {
    /**
     * Main webhook model representing the root JSON payload from PassFort.
     * This is the primary data structure used for processing webhook events.
     */
    public class Webhook {
        /**
         * The type of event that triggered this webhook.
         * Common values include:
         * - RISK_LEVEL_CHANGED: When an entity's risk assessment results change
         * - CHECK_COMPLETED: When a verification check process completes
         * - PRODUCT_STATUS_CHANGED: When a PassFort product's status changes
         */
        public String event { get; set; }
        
        /**
         * The entity (individual or organization) this webhook relates to.
         * Contains identifiers and risk information.
         */
        public Entity data { get; set; }
    }
    
    /**
     * Entity model representing an individual or organization in PassFort.
     * Contains identification and risk information about the subject.
     */
    public class Entity {
        /**
         * PassFort's unique identifier for this entity.
         * This should be stored in Salesforce as External_ID__c for record linking.
         */
        public String profile_id { get; set; }
        
        /**
         * The type of entity.
         * Common values:
         * - INDIVIDUAL: A natural person
         * - ORGANIZATION: A company or other legal entity
         */
        public String new_category { get; set; }
        
        public String new_status { get; set; }
        /**
         * The current risk assessment level for this entity.
         * Common values:
         * - LOW: Minimal risk identified
         * - MEDIUM: Some risk factors present
         * - HIGH: Significant risk factors identified
         * - PROHIBITED: Entity matches prohibited lists or sanctions
         */
        public String riskLevel { get; set; }
        // Add other fields as needed based on PassFort's data model
    }
    
    /**
     * Response model for replying to PassFort webhooks.
     * Provides a standardized format for responses back to the PassFort system.
     */
    public class Response {
        /**
         * Response status: "success" or "error"
         * PassFort uses this to determine if the webhook was processed correctly.
         */
        public String status { get; set; }
        
        /**
         * Human-readable message describing the result.
         * For errors, this should contain a description of what went wrong.
         */
        public String message { get; set; }
        
        /**
         * Additional data to return to PassFort.
         * May include:
         * - accountId: The Salesforce ID of the updated record
         * - riskLevel: The new risk level that was applied
         * - Any other information that might be useful for audit trails
         */
        public Map<String, Object> data { get; set; }
        
        /**
         * Default constructor initializes a success response with an empty data map.
         */
        public Response() {
            this.status = 'success';
            this.data = new Map<String, Object>();
        }
    }
    
    /**
     * Parse a JSON string into the webhook model.
     * 
     * @param json The JSON payload received from PassFort
     * @return A typed Webhook object containing the deserialized data
     * @throws JSONException If the JSON is malformed or doesn't match the expected structure
     * 
     * Implementation Note:
     * This method centralizes JSON parsing to ensure consistent error handling.
     * The webhook service should catch any exceptions thrown by this method.
     */
    public static Webhook parse(String jsonString) {
        return (Webhook)JSON.deserialize(jsonString, Webhook.class);
    }
}