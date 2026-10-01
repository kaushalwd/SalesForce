/**********************************************************************************************************************
* Name               : OIC_CustomerRelationshipCallout
* Description        : Sends the Create Customer Relationship callout to Oracle whenever a SalesOrderRelationship__c
*                       record's NOC Status is updated to Signed.
* Usage              : Called from SORelationshipCallout_Queable
* Created By         : Karunakar
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Karunakar                           24 Aug 2026     Initial Draft
* 1.1           Karunakar                           25 Aug 2026     Send RelationshipSfId in the request and write
*                                                                    the returned Status back onto the record
**********************************************************************************************************************/
public without sharing class OIC_CustomerRelationshipCallout {

    private static final String SIGNED_STATUS = 'Signed';
    private static final String RELATIONSHIP_TYPE = 'Account/Party';
    private static final String PARTY_TYPE = 'Party';
    private static final String CREDENTIAL_NAME = 'CreateCustomerRelationshipAPI';
    private static final String PROCESS_NAME = 'Customer Relationship API';
    private static final String CLASS_NAME = 'OIC_CustomerRelationshipCallout';
    private static final String METHOD_NAME = 'createCustomerRelationship';

    /**
     * Description : Builds the Subject/Object relationship payload for each signed SalesOrderRelationship__c
     *               record and sends it to Oracle via the CreateCustomerRelationshipAPI callout.
     */
    public static void createCustomerRelationship(Set<Id> sorIds) {
        if (sorIds == null || sorIds.isEmpty()) {
            return;
        }

        List<SalesOrderRelationship__c> sorList = [
            SELECT Id, NOCStatus__c,
                   SalesOrder__c, SalesOrder__r.CustAcctId__c,
                   SalesOrder__r.CustomerAccount__c, SalesOrder__r.CustomerAccount__r.OraclePartyId__c,
                   ThridPartyCustomer__c, ThridPartyCustomer__r.OraclePartyId__c,
                   ThridPartyCustomer__r.IsPersonAccount, SalesOrder__r.CustomerAccount__r.IsPersonAccount
            FROM SalesOrderRelationship__c
            WHERE Id IN :sorIds
              AND NOCStatus__c = :SIGNED_STATUS
              AND SalesOrder__r.CustomerAccount__r.OraclePartyId__c != null
              AND ThridPartyCustomer__r.OraclePartyId__c != null
        ];
        
        System.debug('sorList '+sorList);

        for (SalesOrderRelationship__c sor : sorList) {
            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                break;
            }
            sendRelationshipCallout(sor);
        }
    }

    private static void sendRelationshipCallout(SalesOrderRelationship__c sor) {
        OIC_CustomerRelationshipRequestVO vo = new OIC_CustomerRelationshipRequestVO();

        vo.Type = PARTY_TYPE;

        vo.SubjectPartyId = sor.SalesOrder__r.CustomerAccount__r.OraclePartyId__c;
        vo.SubjectSfPartyId = sor.SalesOrder__r.CustomerAccount__c;
        vo.SubjectType = sor.SalesOrder__r.CustomerAccount__r.IsPersonAccount ? 'PERSON' : 'ORGANIZATION';
        vo.SubjectAccountId = sor.SalesOrder__r.CustAcctId__c;
        vo.SubjectSfAccountId = sor.SalesOrder__c;

        vo.ObjectPartyId = sor.ThridPartyCustomer__r.OraclePartyId__c;
        vo.ObjectSfPartyId = sor.ThridPartyCustomer__c;
        vo.ObjectType = sor.ThridPartyCustomer__r.IsPersonAccount ? 'PERSON' : 'ORGANIZATION';

        vo.RelationshipSfId = sor.Id;

        String reqBody = JSON.serialize(vo);
        HTTPResponse res;
        try {
            HttpRequest req = OIC_CredentialsController.getCredentials(CREDENTIAL_NAME);
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            req.setBody(reqBody);

            Http http = new Http();
            res = http.send(req);

            if (res != null && String.isNotBlank(res.getBody())) {
                OIC_CustomerRelationshipRequestVO responseVo =
                    (OIC_CustomerRelationshipRequestVO) JSON.deserialize(res.getBody(), OIC_CustomerRelationshipRequestVO.class);
                updateRelationshipStatus(responseVo);
            }

            if (res == null || res.getStatusCode() != 200) {
                LoggerService.save(LoggerService.createAPILog(
                    PROCESS_NAME, CLASS_NAME, METHOD_NAME,
                    reqBody, (res != null ? res.getBody() : null),
                    (res != null ? String.valueOf(res.getStatusCode()) : 'No Response'), 'Callout Error Log'));
            }
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createAPILog(
                PROCESS_NAME, CLASS_NAME, METHOD_NAME,
                reqBody, (res != null ? res.getBody() : null),
                'Exception: 500 Error', 'Callout Error Log'));
            LoggerService.save(LoggerService.createApexLog(ex, PROCESS_NAME, CLASS_NAME, METHOD_NAME));
        }
    }

    /**
     * Description : Validates the OIC response and writes the returned Status back onto the
     *               SalesOrderRelationship__c record identified by RelationshipSfId.
     */
    private static void updateRelationshipStatus(OIC_CustomerRelationshipRequestVO responseVo) {
        if (responseVo == null || String.isBlank(responseVo.RelationshipSfId)) {
            return;
        }

        update new SalesOrderRelationship__c(
            Id = responseVo.RelationshipSfId,
            RelationshipSyncStatus__c = responseVo.Status,
            RelationshipOracleId__c = responseVo.RelationshipId
        );
    }
}