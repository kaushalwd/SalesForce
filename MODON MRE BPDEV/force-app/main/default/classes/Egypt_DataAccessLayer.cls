/**********************************************************************************************************************
* Name               : Egypt_DataAccessLayer
* Description        : Centralized query layer class for Modon Egypt features.
*                      Implements a generic dynamic query engine with query, querySingle, and queryAllFields.
* Usage              : Called from controllers and triggers
* Created By         : Shahil Sinha
* --------------------------------------------------------------------------------------------------------------------
* Version       Author           Date            Comment
* 1.0           Shahil Sinha     02 Jun 2026     Initial Draft
* 1.1           Shahil Sinha     02 Jun 2026     Modified getInvoicesToCancel to retrieve all fields dynamically
* 1.2           Shahil Sinha     08 Jun 2026     Added getNewInvoicesForInstallments method
* 2.0           Shahil Sinha     09 Jun 2026     Refactored to implement a generic dynamic query engine utilizing
*                                                Database.queryWithBinds and a configuration mapping. Retained and
*                                                re-routed legacy wrappers for unit mappings to preserve compatibility.
******************************************************************************************************************/
public without sharing class Egypt_DataAccessLayer {

    /**
     * @description Predefined field mapping for core entities. This ensures only required
     *              fields (including parent relationship fields) are fetched dynamically.
     */
    private static final Map<String, Set<String>> OBJECT_FIELDS = new Map<String, Set<String>>{
        'SalesOrder__c' => new Set<String>{
            'Id',
            'Name',
            'Status__c',
            'Unit__c',
            'Unit__r.Name',
            'TotalAmount__c',
            'CurrencyIsoCode',
            'ExactBookingDate_Egypt__c',
            'PaymentPlan__c',
            'Egypt_Flexible_Payment_Plan__c',
            'Opportunity__c'
        },
        'Receipt__c' => new Set<String>{
            'Id',
            'SalesOrder__c',
            'SalesOrderInstallment__c',
            'Status__c',
            'TotalAmount__c',
            'AppliedAmount__c',
            'Receipt_Amount__c',
            'RemainingAmount__c',
            'ExpressionOfInterest__c',
            'CreatedDate'
        },
        'SalesOrderInstallments__c' => new Set<String>{
            'Id',
            'Name',
            'InstallmentAmount__c',
            'MilestoneDate__c',
            'PaymentStatus__c',
            'SalesOrder__r.Name',
            'MilestoneNumber__c',
            'Instalment_Number__c',
            'InstalmentPaymentDueDateArabicSPA__c',
            'SPAINFRA__c',
            'MilestoneDescriptionArabicSPA__c',
            'MilestoneDescriptionArabic__c',
            'MilestoneDescriptionSPA__c',
            'InstalmentPaymentDueDate__c',
            'InstalmentPaymentDueDateArabic__c',
            'Original_Milestone_Date__c',
            'PaymentInstallments__c',
            'IsHandoverPayment__c',
            'MilestoneDescription__c',
            'Milestone__c',
            'BrokerPayout__c',
            'SalesAgentPayout__c'
        },
        'UnitPaymentPlanMapping__c' => new Set<String>{
            'Id',
            'Base_Price__c',
            'Unit__c',
            'Payment_Plan__c',
            'Payment_Plan__r.Name',
            'Payment_Plan__r.isFurnishedPaymentPlan__c',
            'Payment_Plan__r.isDefault__c',
            'CurrencyIsoCode'
        },
        'PaymentInstallements__c' => new Set<String>{
            'Id',
            'Name',
            'PaymentInstallment__c',
            'BrokerPayout__c',
            'IsHandoverPayment__c',
            'Milestone__c',
            'MilestoneDate__c',
            'MilestoneDescription__c',
            'MilestoneNumber__c',
            'SalesAgentPayout__c',
            'Milestone_Egypt_Percent__c',
            'PaymentInstallment__r.Maintenance_Fee__c',
            'Is_Maintenance_Installment__c',
            'PaymentInstallment__r.Number_of_Maintenance_Fee__c',
            'No_Of_Months_To_Add_From_Last_Date__c'
        },
        'Unit__c' => new Set<String>{
            'Id',
            'Phase__c',
            'Phase__r.Project__c'
        },
        'PaymentPlan__c' => new Set<String>{
            'Id',
            'Name',
            'isActive__c',
            'isDefault__c',
            'isFurnishedPaymentPlan__c',
            'Discount_Percent__c',
            'Maintenance_Fee__c',
            'Number_of_Maintenance_Fee__c',
            'CurrencyIsoCode',
            '(SELECT Id, Name, BrokerPayout__c, IsHandoverPayment__c, Milestone__c, ' +
            'Milestone_Egypt_Percent__c, MilestoneDate__c, MilestoneDescription__c, ' +
            'MilestoneNumber__c, SalesAgentPayout__c, Is_Maintenance_Installment__c, ' +
            'No_Of_Months_To_Add_From_Last_Date__c ' +
            'FROM Payment_Installments__r ' +
            'ORDER BY MilestoneNumber__c ASC)'
        },
        'Invoice__c' => new Set<String>{
            'Id',
            'InvoiceBalance__c',
            'SalesOrderInstallment__c',
            'SalesOrderInstallment__r.MilestoneNumber__c',
            'Parent_Invoice__c',
            'Sales_Order__c',
            'SalesOrderInstallment__r.SalesOrder__c',
            'IsCancelled__c',
            'RecordType.DeveloperName',
            'Oracle_Integration_Status_Modon_Egypt__c',
            'Oracle_Installment_Invoice_Id__c',
            'Oracle_Maintenance_Invoice_Id__c'
        },
        'Allocation__c' => new Set<String>{
            'Id',
            'Allocation_Amount_in_Receipt_Currency__c',
            'AllocationAmount__c',
            'CreatedDate',
            'Receipt__r.Id',
            'Receipt__r.Receipt_Type__c',
            'Receipt__r.ChequeDate__c',
            'Receipt__r.CurrencyIsoCode',
            'Receipt__r.CreatedDate',
            'Receipt__r.Oracle_Receipt_Id__c',
            'Receipt__r.Modeofpayment__c',
            'Receipt__r.AccountingDate_Egypt__c',
            'Receipt__r.Cheque_Number__c',
            'Receipt__r.TransactionNumber__c',
            'Invoice__r.Id',
            'Invoice__r.Name',
            'Invoice__r.CurrencyIsoCode',
            'Invoice__r.CreatedDate',
            'Invoice__r.Oracle_Maintenance_Invoice_Id__c',
            'Invoice__r.Oracle_Installment_Invoice_Id__c',
            'Invoice__r.SalesOrderInstallment__r.Maintenance_Fee__c',
            'Invoice__r.SalesOrderInstallment__r.MilestoneDate__c',
            'Invoice__r.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c',
            'Invoice__r.SalesOrderInstallment__r.SalesOrder__r.SPA_Signed_Date_Time_Modon_Egypt__c',
            'Invoice__r.Sales_Order__c',
            'Invoice__r.SalesOrderInstallment__r.SalesOrder__c',
            'Invoice__r.Sales_Order__r.Source_Entity__c',
            'Invoice__r.SalesOrderInstallment__r.Source_Entity__c',
            'Oracle_Apply_Receipt_Status_Modon_Egypt__c',
            'Oracle_Integration_Status_Modon_Egypt__c',
            'Oracle_Status_Code_Modon_Egypt__c',
            'Oracle_Integration_Message_Modon_Egypt__c'
        },
        'Oracle_Integration_Config__mdt' => new Set<String>{
            'Id',
            'Endpoint__c',
            'Username__c',
            'Password__c',
            'Object_API_Name__c',
            'Operation_Type__c',
            'Is_Sandbox__c'
        },
        'Currency_Conversion_Rate__c' => new Set<String>{
            'Conversion_Rate__c',
            'Inverse_Conversion_Rate__c',
            'Rate_Date__c',
            'CurrencyIsoCode',
            'Target_Currency__c'
        }
    };

    /**
     * @description Generic query engine executing dynamic SOQL queries with parameters.
     *              If the objectName is not configured in OBJECT_FIELDS, it dynamically describes
     *              the schema to construct the query on all fields as a robust fallback.
     *              Author: Shahil Sinha
     */
    public static List<SObject> query(
        String objectName,
        String whereClause,
        String orderByClause,
        Integer limitSize,
        Map<String, Object> bindParams
    ) {
        Set<String> fields = OBJECT_FIELDS.get(objectName);
        if (fields == null) {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType != null) {
                fields = objType.getDescribe().fields.getMap().keySet();
            } else {
                throw new IllegalArgumentException('Field configuration and schema not found for object: ' + objectName);
            }
        }

        String safeObjectName = String.escapeSingleQuotes(objectName);
        String soql = 'SELECT ' + String.join(new List<String>(fields), ',') + ' FROM ' + safeObjectName;
        if (String.isNotBlank(whereClause)) {
            soql += ' WHERE ' + whereClause;
        }
        if (String.isNotBlank(orderByClause)) {
            soql += ' ORDER BY ' + orderByClause;
        }
        if (limitSize != null && limitSize > 0) {
            soql += ' LIMIT ' + limitSize;
        }

        return Database.queryWithBinds(soql, bindParams != null ? bindParams : new Map<String, Object>(), AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Generic query engine to retrieve a single record. Returns null if no records found.
     *              Author: Shahil Sinha
     */
    public static SObject querySingle(
        String objectName,
        String whereClause,
        Map<String, Object> bindParams
    ) {
        List<SObject> records = query(objectName, whereClause, null, 1, bindParams);
        return records.isEmpty() ? null : records[0];
    }

    /**
     * @description Generic query engine retrieving all fields of an object using schema describe.
     *              Author: Shahil Sinha
     */
    public static List<SObject> queryAllFields(
        String objectName,
        String whereClause,
        Map<String, Object> bindParams
    ) {
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType == null) {
            throw new IllegalArgumentException('Object type not found: ' + objectName);
        }
        List<String> fields = new List<String>(objType.getDescribe().fields.getMap().keySet());
        String safeObjectName = String.escapeSingleQuotes(objectName);
        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM ' + safeObjectName;
        if (String.isNotBlank(whereClause)) {
            soql += ' WHERE ' + whereClause;
        }
        return Database.queryWithBinds(soql, bindParams != null ? bindParams : new Map<String, Object>(), AccessLevel.SYSTEM_MODE);
    }
}