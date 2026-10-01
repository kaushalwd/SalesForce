/**********************************************************************************************************************
* Name               : ModonEgyptConstantsTest
*                                                          
* Description        : Test class for ModonEgyptConstants to verify all constant values
* Usage              : Run as part of Apex test suite
* Created By         : Shahil Sinha                                                
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Shahil Sinha                      24 Feb 2026     Initial Draft
* 2.0 			Milin Kapatel					  03 Mar 2026	  Covered Manage Inventory and Manage Bucket Const's
* 3.0			Milin Kapatel					  05 Mar 2026 	  Covered new Manage Bucket Const
******************************************************************************************************************/
@isTest
private class ModonEgyptConstantsTest {

    /**
     * @description Verifies Xebo Integration field name constants on Account.
     */
    @isTest
    static void testXeboFieldConstants() {
        System.assertEquals(
            'Xebo_Request__c',
            ModonEgyptConstants.FIELD_XEBO_REQUEST,
            'FIELD_XEBO_REQUEST should be "Xebo_Request__c"'
        );
        System.assertEquals(
            'Xebo_Response__c',
            ModonEgyptConstants.FIELD_XEBO_RESPONSE,
            'FIELD_XEBO_RESPONSE should be "Xebo_Response__c"'
        );
        System.assertEquals(
            'Xebo_Status__c',
            ModonEgyptConstants.FIELD_XEBO_STATUS,
            'FIELD_XEBO_STATUS should be "Xebo_Status__c"'
        );
        System.assertEquals(
            'Xebo_Id__c',
            ModonEgyptConstants.FIELD_XEBO_ID,
            'FIELD_XEBO_ID should be "Xebo_Id__c"'
        );
    }

    /**
     * @description Verifies Xebo Status constants.
     */
    @isTest
    static void testXeboStatusConstants() {
        System.assertEquals(
            'SUCCESS',
            ModonEgyptConstants.STATUS_SUCCESS,
            'STATUS_SUCCESS should be "SUCCESS"'
        );
        System.assertEquals(
            'FAILED_',
            ModonEgyptConstants.STATUS_FAILED_PREFIX,
            'STATUS_FAILED_PREFIX should be "FAILED_"'
        );
    }

    /**
     * @description Verifies the Xebo Configuration Name constant.
     */
    @isTest
    static void testXeboConfigDefault() {
        System.assertEquals(
            'Default',
            ModonEgyptConstants.XEBO_CONFIG_DEFAULT,
            'XEBO_CONFIG_DEFAULT should be "Default"'
        );
    }

    /**
     * @description Verifies HTTP Settings constants.
     */
    @isTest
    static void testHttpSettingsConstants() {
        System.assertEquals(
            120000,
            ModonEgyptConstants.HTTP_TIMEOUT,
            'HTTP_TIMEOUT should be 120000'
        );
        System.assertEquals(
            'Content-Type',
            ModonEgyptConstants.HEADER_CONTENT_TYPE,
            'HEADER_CONTENT_TYPE should be "Content-Type"'
        );
        System.assertEquals(
            'application/json',
            ModonEgyptConstants.HEADER_CONTENT_JSON,
            'HEADER_CONTENT_JSON should be "application/json"'
        );
        System.assertEquals(
            'x-api-key',
            ModonEgyptConstants.HEADER_API_KEY,
            'HEADER_API_KEY should be "x-api-key"'
        );
        System.assertEquals(
            'POST',
            ModonEgyptConstants.HTTP_POST,
            'HTTP_POST should be "POST"'
        );
    }

    /**
     * @description Verifies Sales Order field name constants.
     */
    @isTest
    static void testSalesOrderFieldConstants() {
        System.assertEquals(
            'Downpayment Payments Cleared',
            ModonEgyptConstants.FIELD_STATUS,
            'FIELD_STATUS should be "Downpayment Payments Cleared"'
        );
    }

    /**
     * @description Verifies the MODON_EGYPT_SOURCE_ENTITY constant.
     */
    @isTest
    static void testModonEgyptSourceEntity() {
        System.assertEquals(
            'Modon - Egypt',
            ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY,
            'MODON_EGYPT_SOURCE_ENTITY should be "Modon - Egypt"'
        );
    }

    /**
     * @description Verifies the SALES_ORDER_API_NAME constant.
     */
    @isTest
    static void testSalesOrderApiName() {
        System.assertEquals(
            'SalesOrder__c',
            ModonEgyptConstants.SALES_ORDER_API_NAME,
            'SALES_ORDER_API_NAME should be "SalesOrder__c"'
        );
    }

    /**
     * @description Verifies Manage Inventory controller related constants.
     */
    @isTest
    static void testManageInventoryConstants() {
        // Map keys
        System.assertEquals('label', ModonEgyptConstants.INVENTORY_KEY_LABEL);
        System.assertEquals('value', ModonEgyptConstants.INVENTORY_KEY_VALUE);
        System.assertEquals('CurrencyIsoCode', ModonEgyptConstants.INVENTORY_KEY_CURRENCY);

        // Error prefix
        System.assertEquals('Error fetching fields from layout: ', ModonEgyptConstants.INVENTORY_ERROR_FETCH_FIELDS);

        // Status and sub-status
        System.assertEquals('Draft', ModonEgyptConstants.INVENTORY_STATUS_DRAFT);
        System.assertEquals('UnReleased', ModonEgyptConstants.INVENTORY_STATUS_UNRELEASED);
        System.assertEquals('Released', ModonEgyptConstants.INVENTORY_STATUS_RELEASED);
        System.assertEquals('Available', ModonEgyptConstants.INVENTORY_UNIT_STATUS_AVAILABLE);
        System.assertEquals('Assigned', ModonEgyptConstants.INVENTORY_SUBSTATUS_ASSIGNED);
        System.assertEquals('Un-Assigned', ModonEgyptConstants.INVENTORY_SUBSTATUS_UNASSIGNED);

        // Actions
        System.assertEquals('Draft', ModonEgyptConstants.INVENTORY_ACTION_DRAFT);
        System.assertEquals('UnRelease', ModonEgyptConstants.INVENTORY_ACTION_UNRELEASE);
        System.assertEquals('Release', ModonEgyptConstants.INVENTORY_ACTION_RELEASE);
        System.assertEquals('Assign', ModonEgyptConstants.INVENTORY_ACTION_ASSIGN);
        System.assertEquals('Un-Assign', ModonEgyptConstants.INVENTORY_ACTION_UNASSIGN);
        System.assertEquals('Bucket', ModonEgyptConstants.INVENTORY_ACTION_BUCKET);

        // Misc
        System.assertEquals('Unlimited', ModonEgyptConstants.INVENTORY_UNLIMITED);
        System.assertEquals('Min', ModonEgyptConstants.INVENTORY_MIN_SUFFIX);
        System.assertEquals('SUCCESS', ModonEgyptConstants.INVENTORY_SUCCESS);
        System.assertEquals('', ModonEgyptConstants.INVENTORY_EMPTY_STRING);
    }

    /**
     * @description Verifies Manage Bucket LWC controller related constants.
     */
    @isTest
    static void testManageBucketConstants() {
        System.assertEquals('Internal', ModonEgyptConstants.BUCKET_INTERNAL);
        System.assertEquals('Broker', ModonEgyptConstants.BUCKET_BROKER);
        System.assertEquals('Partner', ModonEgyptConstants.BUCKET_PARTNER);

        System.assertEquals('Standard', ModonEgyptConstants.BUCKET_USER_TYPE_STANDARD);
        System.assertEquals('PowerPartner', ModonEgyptConstants.BUCKET_USER_TYPE_POWER_PARTNER);
        System.assertEquals('Partner', ModonEgyptConstants.BUCKET_USER_TYPE_PARTNER);

        System.assertEquals('%Egypt%', ModonEgyptConstants.BUCKET_PROFILE_LIKE_EGYPT);
        System.assertEquals('Bucket and at least one User are required.', ModonEgyptConstants.BUCKET_ERR_BUCKET_USER_REQUIRED);

        System.assertEquals('Regular', ModonEgyptConstants.BUCKET_GROUP_TYPE_REGULAR);
        System.assertEquals('Salesforce', ModonEgyptConstants.BUCKET_LICENSE_SF);
        System.assertEquals('Partner Community Login\', \'Partner Community', ModonEgyptConstants.BUCKET_LICENSES_PARTNER);
        System.assertEquals('Modon - Egypt', ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY);
    }

    /**
     * @description Verifies User profile name constant.
     */
    @isTest
    static void testUserProfileConstants() {
        System.assertEquals(
            'Modon Egypt - Sales Management',
            ModonEgyptConstants.MODON_EGYPT_SALES_MANAGEMENT_PROFILE_NAME
        );
    }
    /**
     * @description Verifies User profile name constant.
     */
    @isTest
    static void testModeOfPaymentChequeConstant() {
        System.assertEquals(
            'Cheque',
            ModonEgyptConstants.MODE_OF_PAYMENT_CHEQUE
        );
    }
}