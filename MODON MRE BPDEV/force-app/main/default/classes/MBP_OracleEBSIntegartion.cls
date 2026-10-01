/**********************************************************************************************************************
* Name               : MBP_OracleEBSIntegartion
* Description        : REST service endpoint exposed by Salesforce to receive supplier and bank integration
*                      responses from Oracle EBS via Oracle Integration Cloud (OIC).
*
* Usage              : Invoked by Oracle Integration Cloud (OIC) after successful processing of supplier
*                      or bank information in Oracle EBS. OIC sends the generated EBS identifiers which
*                      are stored in Salesforce for reference and further processing.
*
*                      Endpoint Example:
*                      /services/apexrest/ebs
*
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date            Comment
* 1.0         upendra.asam@activemindsit.com  11 Feb 2026     Initial Draft – Implemented REST endpoint to receive
*                                                            Oracle EBS supplier and bank response payload from OIC
*                                                            and update Account records accordingly.
* 1.1         Jay Patel                       23 Sep 2026     MCR-73 — USER_MODE SOQL/DML, createApexLog
**********************************************************************************************************************/

@RestResource(urlMapping='/ebs')
global with sharing class MBP_OracleEBSIntegartion {

    @HttpPost
    global static ResponseWrapper receiveFromOIC() {

        ResponseWrapper response = new ResponseWrapper();
        Account acc;

        try {

            RequestWrapper input = (RequestWrapper) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                RequestWrapper.class
            );

            if (!String.isBlank(input.accountId)) {

                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Account query
                acc = [
                    SELECT Id, OIC_Supplier_Vendor_ID__c
                    FROM Account
                    WHERE Id = :input.accountId
                    WITH USER_MODE
                    LIMIT 1
                ];
            }

            else if (!String.isBlank(input.vendorId)) {

                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Account query
                List<Account> accList = [
                    SELECT Id, OIC_Supplier_Vendor_ID__c
                    FROM Account
                    WHERE OIC_Supplier_Vendor_ID__c = :input.vendorId
                    WITH USER_MODE
                    LIMIT 1
                ];

                if (accList.isEmpty()) {
                    response.status = 'FAILED';
                    response.message = 'No Account found for given VendorId';
                    return response;
                }

                acc = accList[0];
            }

            else {
                throw new AuraHandledException('accountId or vendorId is required');
            }

            acc.EBS_BANK_BRANCH_PARTY_ID__c = input.ebsBankBranchPartyId;
            acc.EBS_BANK_PARTY_ID__c        = input.ebsBankPartyId;
            acc.EBS_VENDOR_ADDRESS_ID__c    = input.ebsVendorAddressId;
            acc.EBS_VENDOR_ID__c            = input.ebsVendorId;
            acc.EBS_VENDOR_PARTY_ID__c      = input.ebsVendorPartyId;
            acc.EBS_VENDOR_SITE_ID__c       = input.ebsVendorSiteId;
            acc.EBS_BANK_ACCOUNT_ID__c      = input.ebsAccountId;
            acc.EBS_BANK_ID__c              = input.ebsBankPartyId;

            acc.EBS_Supplier_Response__c = 'SUCCESS';
            acc.EBS_Bank_Response__c     = 'SUCCESS';
            acc.EBS_SUPPLIER_SYNC_STATUS__c = 'Synced';
            acc.EBS_BANK_SYNC_STATUS__c     = 'Synced';

            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Account update
            Database.update(acc, AccessLevel.USER_MODE);

            response.status = 'SUCCESS';
            response.message = 'Account updated successfully';
            response.accountId = acc.Id;
            response.vendorId = acc.OIC_Supplier_Vendor_ID__c;

        } 
        catch (Exception e) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Oracle EBS Integration',
                'MBP_OracleEBSIntegartion',
                'receiveFromOIC'
            ));

            System.debug(LoggingLevel.ERROR,
                'Oracle EBS Integration Error: ' + e.getMessage()
            );

            if (acc != null) {

                try {

                    acc.EBS_Supplier_Response__c = 'ERROR : ' + e.getMessage();
                    acc.EBS_Bank_Response__c     = 'ERROR : ' + e.getMessage();
                    acc.EBS_SUPPLIER_SYNC_STATUS__c = 'FAILED';
                    acc.EBS_BANK_SYNC_STATUS__c     = 'FAILED';

                    //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Account update
                    Database.update(acc, AccessLevel.USER_MODE);

                } 
                catch (Exception updateEx) {

                    System.debug(LoggingLevel.ERROR,
                        'Failed updating Account failure status. AccountId: '
                        + acc.Id + ' Error: ' + updateEx.getMessage()
                    );
                }
            }

            response.status = 'ERROR';
            response.message = e.getMessage();
        }

        return response;
    }

    global class RequestWrapper {

        public String accountId;
        public String vendorId;

        public String ebsBankBranchPartyId;
        public String ebsBankId;
        public String ebsBankPartyId;
        public String ebsVendorAddressId;
        public String ebsVendorId;
        public String ebsVendorPartyId;
        public String ebsVendorSiteId;
        public String ebsAccountId;
    }

    global class ResponseWrapper {

        public String status;
        public String message;
        public String accountId;
        public String vendorId;
    }
}