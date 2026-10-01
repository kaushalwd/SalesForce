/**********************************************************************************************************************
* Name               : MBP_OracleSupplierPayloadBuilder
* Description        : This class is used to construct and serialize Supplier JSON payload
*                      for Oracle Integration from Salesforce Account records.
* Usage              : Invoked by integration services (Queueable / Future / Service Classes)
*                      to send Supplier data to Oracle.
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com   11 Feb 2026      Initial Draft – Core logic for building Supplier
*                                                              and Supplier Site payload structure including
*                                                              status handling (Active/Inactive),
*                                                              address mapping, site flags configuration,
*                                                              and JSON serialization for Oracle API.
**********************************************************************************************************************/


public with sharing class MBP_OracleSupplierPayloadBuilder {

    public static String buildSupplierJson(Account acc) {

        Map<String, Object> supplier = new Map<String, Object>();

        String supplierStatus =
            acc.Agency_Status__c == 'Active' ? 'Active' : 'INACTIVE';

        supplier.put('Supplier', acc.Name);
        supplier.put('Status', supplierStatus);

        if (supplierStatus == 'INACTIVE') {
            supplier.put(
                'InactiveDate',
                String.valueOf(acc.LastModifiedDate.date())
            );
        } else {
            supplier.put('InactiveDate', null);
        }

        supplier.put('TaxOrganizationType', 'Limited Liability Company (LLC)');
        supplier.put('SupplierType', null);
        supplier.put('BusinessRelationship', 'Spend Authorized');
        supplier.put('DUNSNumber', '');
        supplier.put('OneTimeSupplierFlag', '');
        supplier.put('TaxpayerCountry', 'United Arab Emirates');
        supplier.put('TaxpayerId', '');

        Map<String, Object> site = new Map<String, Object>();
        site.put('SupplierSite', acc.BillingStreet);
        site.put('ProcurementBU', 'Modon Properties PJSC');
        site.put('SupplierAddressName', acc.BillingCity);

        if (supplierStatus == 'INACTIVE') {
            site.put(
                'InactiveDate',
                String.valueOf(acc.LastModifiedDate.date())
            );
        } else {
            site.put('InactiveDate', null);
        }

        site.put('SitePurposeSourcingOnlyFlag', false);
        site.put('SitePurposePurchasingFlag', true);
        site.put('SitePurposeProcurementCardFlag', false);
        site.put('SitePurposePrimaryPayFlag', false);
        site.put('SitePurposePayFlag', true);
        site.put('IncomeTaxReportingSiteFlag', true);
        site.put('AlternateSiteName', acc.BillingCity);

        site.put('AddressName', acc.BillingStreet);
        site.put('Country', acc.BillingCountry);
        site.put('AddressLine1', acc.BillingStreet);
        site.put('City', acc.BillingCity);
        site.put('State', acc.BillingState);
        site.put('PostalCode', acc.BillingPostalCode);
        site.put('AddressPurposeOrderingFlag', true);
        site.put('AddressPurposeRemitToFlag', true);
        site.put('AddressPurposeRFQOrBiddingFlag', false);

        supplier.put('Sites', new List<Object>{ site });

        Map<String, Object> root = new Map<String, Object>();
        root.put('Supplier', supplier);

        return JSON.serialize(root);
    }
}