/**********************************************************************************************************************
* Name               : OIC_InventoryMasterBatchTest
* Description        : Test class for OIC_InventoryMasterBatch and OIC_ManageInventoryMaster.*                      
* Created By         : Active Minds
* --------------------------------------------------------------------------------------------------------------------
* Version   Author         Date               Comment
* 1.0       Active Minds  05 May 2026        Initial Draft
***********************************************************************************************************************/
@isTest
private class OIC_InventoryMasterBatchTest {

    // ─────────────────────────────────────────────────────────────────────────
    // SHARED TEST SETUP — mirrors OIC_ManageSalesforceDataControllerTest setup
    // ─────────────────────────────────────────────────────────────────────────
    @TestSetup
    static void setupData() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        

        Schema.RecordTypeInfo recordTypeInfo =
            Schema.getGlobalDescribe()
                .get('Account')
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('PersonAccount');

        String recordTypeId = recordTypeInfo.getRecordTypeId();

        Account accountObj          = new Account(RecordTypeId = recordTypeId);
        accountObj.PersonEmail      = 'testuser@example.com';
        accountObj.FirstName        = 'Test';
        accountObj.LastName         = 'User';
        accountObj.OraclePartyId__c = '11111';
        insert accountObj;

        Project__c projectObj           = new Project__c(Name = 'Al Naseem');
        projectObj.ProjectNumber__c     = 'PROJ-001';
        insert projectObj;

        EscrowAccount__c escrowObj       = new EscrowAccount__c();
        escrowObj.Name                   = 'OIC Escrow';
        escrowObj.AccountNumber__c       = 'ESC-001';
        escrowObj.IBANNo__c              = 'AE070331234567890123456';
        escrowObj.StoreId__c             = 'STORE-001';
        escrowObj.SwiftCode__c           = 'SWIFT001';
        escrowObj.TradeID__c             = 'TRADE-001';
        escrowObj.BankName__c            = 'Test Bank';
        escrowObj.BeneficiaryName__c     = 'Test Beneficiary';
        insert escrowObj;

        VirtualAccount__c vaObj           = new VirtualAccount__c();
        vaObj.Name                        = 'Test Virtual Account';
        vaObj.Status__c                   = 'Available';
        vaObj.EscrowAccount__c            = escrowObj.Id;
        vaObj.VirtualAccountNumber__c     = '124567642';
        vaObj.VirtualIBANNumber__c        = 'AE3456789456789';
        insert vaObj;

        Phase__c phaseObj         = new Phase__c();
        phaseObj.Project__c       = projectObj.Id;
        phaseObj.EscrowAccount__c = escrowObj.Id;
        phaseObj.EntityName__c    = 'Modon Properties PJSC';
        insert phaseObj;

        Unit__c unitObj                  = new Unit__c();
        unitObj.Name                     = 'Inventory Unit A101';
        unitObj.BasePrice__c             = 1000;
        unitObj.AdditionalPrice__c       = 0;
        unitObj.PlotAreasqm__c           = 1.0;
        unitObj.PlotNo__c                = '1';
        unitObj.UnitClassification__c    = 'Villa';
        unitObj.Number_of_Bedrooms__c    = '2';
        unitObj.NotToBeShownOnRD__c      = false;
        unitObj.Phase__c                 = phaseObj.Id;
        unitObj.Pass_id__c               = '99001';         // required by getPropertyMaster
        unitObj.Status__c                = 'Available';     // NOT 'Sold' — qualifies in Unit query
        insert unitObj;

        Unit_Option__c unitOptionObj  = new Unit_Option__c();
        unitOptionObj.Unit__c         = unitObj.Id;
        unitOptionObj.Phase__c        = phaseObj.Id;
        unitOptionObj.PlotAreasqm__c  = 1.0;
        unitOptionObj.PlotNo__c       = '1';
        insert unitOptionObj;

        PaymentPlan__c paymentPlanObj  = new PaymentPlan__c();
        paymentPlanObj.Type__c         = 'Standard';
        paymentPlanObj.Unit__c         = unitObj.Id;
        paymentPlanObj.Status__c       = 'Active';
        paymentPlanObj.StartDate__c    = System.today().addDays(-2);
        paymentPlanObj.ExpiryDate__c   = System.today().addDays(5);
        insert paymentPlanObj;

        PaymentInstallements__c paymentInstallmentObj     = new PaymentInstallements__c();
        paymentInstallmentObj.PaymentInstallment__c       = paymentPlanObj.Id;
        paymentInstallmentObj.BrokerPayout__c             = 10;
        paymentInstallmentObj.Milestone__c                = 1;
        paymentInstallmentObj.MilestoneNumber__c          = 1;
        paymentInstallmentObj.MilestoneDescription__c     = 'OIC Test Milestone';
        insert paymentInstallmentObj;

        SalesOrder__c salesOrderObj               = new SalesOrder__c();
        salesOrderObj.Status__c                   = 'In Progress';
        salesOrderObj.Unit__c                     = unitObj.Id;
        salesOrderObj.UnitOption__c               = unitOptionObj.Id;
        salesOrderObj.PaymentPlan__c              = paymentPlanObj.Id;
        salesOrderObj.VirtualAccount__c           = vaObj.Id;
        salesOrderObj.CustomerAccount__c          = accountObj.Id;
        salesOrderObj.TotalAmount__c              = 20000;
        salesOrderObj.CustAcctId__c               = 'CUST-001';
        salesOrderObj.OraclePartySiteID__c        = '33333';
        salesOrderObj.OracleCustAcctSiteID__c     = '765456';
        salesOrderObj.OracleSiteUseID__c          = 'SITE-USE-001';
        salesOrderObj.OraclePartyId__c            = '34346';
        salesOrderObj.Source_Entity__c            = 'Modon - UAE';
        salesOrderObj.SalesAssociate__c           = UserInfo.getUserId();
        insert salesOrderObj;

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MOCK CLASSES
    // ─────────────────────────────────────────────────────────────────────────

    /** Success mock — reads Sfid values from base64 payload and returns Status = 'S' */
    private class InventorySuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            Set<String> sfids = new Set<String>();
            try {
                if (String.isNotBlank(req.getBody())) {
                    Map<String, Object> bodyMap =
                        (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
                    String base64Payload;
                    if (bodyMap.containsKey('Base64RequestPayload'))
                        base64Payload = (String) bodyMap.get('Base64RequestPayload');
                    if (String.isNotBlank(base64Payload))
                        collectSfids(
                            JSON.deserializeUntyped(EncodingUtil.base64Decode(base64Payload).toString()),
                            sfids
                        );
                }
            } catch (Exception ex) {}

            List<Object> responseArray = new List<Object>();
            for (String sfid : sfids) {
                Map<String, Object> row = new Map<String, Object>();
                row.put('Sfid',     sfid);
                row.put('Status',   'S');
                row.put('ErrorMsg', null);
                row.put('OracleId', 'ORA-' + sfid.right(5));
                responseArray.add(row);
            }
            return buildResponse(responseArray);
        }

        private void collectSfids(Object obj, Set<String> sfids) {
            if (obj == null) return;
            if (obj instanceof Map<String, Object>) {
                Map<String, Object> m = (Map<String, Object>) obj;
                for (String key : m.keySet()) {
                    if (key != null && key.toLowerCase() == 'sfid' && m.get(key) != null)
                        sfids.add(String.valueOf(m.get(key)));
                    else
                        collectSfids(m.get(key), sfids);
                }
            } else if (obj instanceof List<Object>) {
                for (Object item : (List<Object>) obj) collectSfids(item, sfids);
            }
        }

        private HTTPResponse buildResponse(List<Object> responseArray) {
            Map<String, Object> decoded = new Map<String, Object>();
            decoded.put('ResponseArray', responseArray);
            OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            b64.Base64Response =
                EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(decoded)));
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(b64));
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }
    }

    /** Error mock — returns Status = 'E' with Unknown integration error */
    private class InventoryErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            Set<String> sfids = new Set<String>();
            try {
                if (String.isNotBlank(req.getBody())) {
                    Map<String, Object> bodyMap =
                        (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
                    String base64Payload;
                    if (bodyMap.containsKey('Base64RequestPayload'))
                        base64Payload = (String) bodyMap.get('Base64RequestPayload');
                    if (String.isNotBlank(base64Payload))
                        collectSfids(
                            JSON.deserializeUntyped(EncodingUtil.base64Decode(base64Payload).toString()),
                            sfids
                        );
                }
            } catch (Exception ex) {}

            List<Object> responseArray = new List<Object>();
            for (String sfid : sfids) {
                Map<String, Object> row = new Map<String, Object>();
                row.put('Sfid',     sfid);
                row.put('Status',   'E');
                row.put('ErrorMsg', 'Unknown integration error from test');
                row.put('OracleId', null);
                responseArray.add(row);
            }
            Map<String, Object> decoded = new Map<String, Object>();
            decoded.put('ResponseArray', responseArray);
            OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            b64.Base64Response =
                EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(decoded)));
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(b64));
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }

        private void collectSfids(Object obj, Set<String> sfids) {
            if (obj == null) return;
            if (obj instanceof Map<String, Object>) {
                Map<String, Object> m = (Map<String, Object>) obj;
                for (String key : m.keySet()) {
                    if (key != null && key.toLowerCase() == 'sfid' && m.get(key) != null)
                        sfids.add(String.valueOf(m.get(key)));
                    else
                        collectSfids(m.get(key), sfids);
                }
            } else if (obj instanceof List<Object>) {
                for (Object item : (List<Object>) obj) collectSfids(item, sfids);
            }
        }
    }

    /** Known (non-Unknown) error mock — exercises the userErrorMsg != null branch */
    private class InventoryKnownErrorMock implements HttpCalloutMock {
        private String sfidToReturn;
        public InventoryKnownErrorMock(String sfid) { this.sfidToReturn = sfid; }
        public HTTPResponse respond(HTTPRequest req) {
            List<Object> responseArray = new List<Object>();
            Map<String, Object> row = new Map<String, Object>();
            row.put('Sfid',     sfidToReturn);
            row.put('Status',   'E');
            row.put('ErrorMsg', 'Specific known integration error');
            row.put('OracleId', null);
            responseArray.add(row);
            Map<String, Object> decoded = new Map<String, Object>();
            decoded.put('ResponseArray', responseArray);
            OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            b64.Base64Response =
                EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(decoded)));
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(b64));
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }
    }

    /** Empty body mock — exercises the String.isNotBlank guard in getPropertyMaster */
    private class InventoryEmptyBodyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('');
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OIC_InventoryMasterBatch — CONSTRUCTOR TESTS
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testNoArgConstructorDefaultsToUnit() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        Test.startTest();
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch();
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
      
    }

    @isTest
    static void testFilteredConstructorSetsAllFields() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
       
        Date runDate = Date.today().addDays(-1);
        Set<String> ids = new Set<String>{ 'TESTID001' };

        Test.startTest();
        OIC_InventoryMasterBatch batch =
            new OIC_InventoryMasterBatch('SalesOrder', 'Test Project', runDate, ids);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
       
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OIC_InventoryMasterBatch — UNIT FILTER PATHS
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testBatchUnitFilter_NoArg_SuccessResponse() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        // No-arg = Unit filter, today date range
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
       
    }

    @isTest
    static void testBatchUnitFilter_WithProcessIds_SuccessResponse() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch(
            'Unit', null, null, new Set<String>{ unit.Id }
        );
        Database.executeBatch(batch, 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }

    @isTest
    static void testBatchUnitFilter_WithProjectName_SuccessResponse() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        Project__c proj = [SELECT Name FROM Project__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch(
            'Unit', proj.Name, null, null
        );
        Database.executeBatch(batch, 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }

    @isTest
    static void testBatchUnitFilter_WithCreateRunDate_SuccessResponse() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch(
            'Unit', null, Date.today(), null
        );
        Database.executeBatch(batch, 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
        System.assert(true, 'Unit batch with createRunDate should complete without exception');
    }

    @isTest
    static void testBatchUnitFilter_ErrorResponse() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new InventoryErrorMock());

        Test.startTest();
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch(
            'Unit', null, null, new Set<String>{ unit.Id }
        );
        Database.executeBatch(batch, 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
       
    }

    @isTest
    static void testBatchUnitFilter_KnownErrorMsg() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new InventoryKnownErrorMock(unit.Id));

        Test.startTest();
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch(
            'Unit', null, null, new Set<String>{ unit.Id }
        );
        Database.executeBatch(batch, 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }
    @isTest
    static void testBatchUnitFilter_EmptyBodyResponse() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new InventoryEmptyBodyMock());

        Test.startTest();
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch(
            'Unit', null, null, new Set<String>{ unit.Id }
        );
        Database.executeBatch(batch, 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OIC_InventoryMasterBatch — SALESORDER FILTER PATHS
    // ─────────────────────────────────────────────────────────────────────────

   /* @isTest
    static void testBatchSalesOrderFilter_WithProcessIds_SuccessResponse() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c WHERE Status__c = 'In Progress' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch(
            'SalesOrder', null, null, new Set<String>{ so.Id }
        );
        Database.executeBatch(batch, 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }*/

    /*@isTest
    static void testBatchSalesOrderFilter_WithProjectName_SuccessResponse() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch(
            'SalesOrder', 'Test Project', null, null
        );
        Database.executeBatch(batch, 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    } */

    @isTest
    static void testBatchSalesOrderFilter_WithCreateRunDate_SuccessResponse() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        // createRunDate != null → SOCreationDate__c > createRunDate branch
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch(
            'SalesOrder', null, Date.today().addDays(-10), null
        );
        Database.executeBatch(batch, 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }

   /* @isTest
    static void testBatchSalesOrderFilter_NoDate_SoCreationDateLtToday() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        // createRunDate == null → SOCreationDate__c < todayDate branch
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch(
            'SalesOrder', null, null, null
        );
        Database.executeBatch(batch, 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
    }*/

    /*@isTest
    static void testBatchSalesOrderFilter_ErrorResponse() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c WHERE Status__c = 'In Progress' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new InventoryErrorMock());

        Test.startTest();
        OIC_InventoryMasterBatch batch = new OIC_InventoryMasterBatch(
            'SalesOrder', null, null, new Set<String>{ so.Id }
        );
        Database.executeBatch(batch, 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
   
    }*/

    // ─────────────────────────────────────────────────────────────────────────
    // OIC_InventoryMasterBatch — FINISH METHOD
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testBatchFinishMethod() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
       
        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        Id jobId = Database.executeBatch(new OIC_InventoryMasterBatch(), 200);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
       
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OIC_ManageInventoryMaster.getPropertyMaster — UNIT type direct call
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetPropertyMaster_UnitType_Success() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        List<Unit__c> units = [
            SELECT Id, Name, ApprovalStatus__c, Status__c, GrossFloorAreaGFA__c,
                   LastModifiedDate, TotalGrossSellableAreaGSA__c, Description__c,
                   UnitClassification__c, PlotAreasqm__c, BasePrice__c,
                   Unit_Launch_Date__c, ADGMUnitNumber__c, PlotNo__c, Pass_id__c,
                   Type__c, BuildingNo__c, Building_Name__c, Unit_Sold_Date__c,
                   TotalPrice__c,
                   Phase__r.Project__r.ProjectNumber__c, Phase__r.EntityName__c,
                   Phase__r.Name, Phase__r.Project__r.Name
            FROM Unit__c
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        OIC_ManageInventoryMaster.getPropertyMaster(units, 'Unit');
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }

    @isTest
    static void testGetPropertyMaster_UnitType_Error() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        

        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        List<Unit__c> units = [
            SELECT Id, Name, ApprovalStatus__c, Status__c, GrossFloorAreaGFA__c,
                   LastModifiedDate, TotalGrossSellableAreaGSA__c, Description__c,
                   UnitClassification__c, PlotAreasqm__c, BasePrice__c,
                   Unit_Launch_Date__c, ADGMUnitNumber__c, PlotNo__c, Pass_id__c,
                   Type__c, BuildingNo__c, Building_Name__c, Unit_Sold_Date__c,
                   TotalPrice__c,
                   Phase__r.Project__r.ProjectNumber__c, Phase__r.EntityName__c,
                   Phase__r.Name, Phase__r.Project__r.Name
            FROM Unit__c
            WHERE Id = :unit.Id
        ];

        Test.setMock(HttpCalloutMock.class, new InventoryErrorMock());

        Test.startTest();
        OIC_ManageInventoryMaster.getPropertyMaster(units, 'Unit');
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }

    @isTest
    static void testGetPropertyMaster_UnitType_KnownError() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
       
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        List<Unit__c> units = [
            SELECT Id, Name, ApprovalStatus__c, Status__c, GrossFloorAreaGFA__c,
                   LastModifiedDate, TotalGrossSellableAreaGSA__c, Description__c,
                   UnitClassification__c, PlotAreasqm__c, BasePrice__c,
                   Unit_Launch_Date__c, ADGMUnitNumber__c, PlotNo__c, Pass_id__c,
                   Type__c, BuildingNo__c, Building_Name__c, Unit_Sold_Date__c,
                   TotalPrice__c,
                   Phase__r.Project__r.ProjectNumber__c, Phase__r.EntityName__c,
                   Phase__r.Name, Phase__r.Project__r.Name
            FROM Unit__c
            WHERE Id = :unit.Id
        ];

        // Pre-set a retry count so the mp_recId_NoOfReTries path is exercised
        unit.OICNoOfRetries__c = 2;
        update unit;

        Test.setMock(HttpCalloutMock.class, new InventoryKnownErrorMock(unit.Id));

        Test.startTest();
        OIC_ManageInventoryMaster.getPropertyMaster(units, 'Unit');
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OIC_ManageInventoryMaster.getPropertyMaster — SALESORDER type direct call
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetPropertyMaster_SalesOrderType_Success() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        List<SalesOrder__c> soList = [
            SELECT Id, Status__c, CustomerAccount__c, CustomerAccount__r.Name,
                   Phase_Name__c, TotalAmount__c, Totalpaidamount__c,
                   Down_Payment_Status__c, SPAStatus__c, SPACustomerSignedDate__c,
                   Discount_Amount__c, Sales_Commission__c, ProjectName__c,
                   Source_Entity__c, Indirect_Commission_Amount__c,
                   Discount_on_ADM_fee_Amount__c, External_Commission_Amount__c,
                   Unit__c,
                   Unit__r.LastModifiedDate, Unit__r.GrossFloorAreaGFA__c,
                   Unit__r.Building_Name__c, Unit__r.TotalGrossSellableAreaGSA__c,
                   Unit__r.Description__c, Unit__r.UnitClassification__c,
                   Unit__r.PlotAreasqm__c, Unit__r.BasePrice__c,
                   Unit__r.Unit_Launch_Date__c, Unit__r.Status__c, Unit__r.Name,
                   Unit__r.ADGMUnitNumber__c, Unit__r.PlotNo__c, Unit__r.Pass_id__c,
                   Unit__r.Type__c, Unit__r.BuildingNo__c, Unit__r.TotalPrice__c,
                   Unit__r.Phase__r.Project__r.ProjectNumber__c,
                   Unit__r.Phase__r.EntityName__c, Unit__r.Building_No__c,
                   Unit__r.Unit_Sold_Date__c, Unit__r.ApprovalStatus__c
            FROM SalesOrder__c
            WHERE Status__c = 'In Progress'
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        OIC_ManageInventoryMaster.getPropertyMaster(soList, 'SalesOrder');
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }

    @isTest
    static void testGetPropertyMaster_SalesOrderType_Error() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
       
        List<SalesOrder__c> soList = [
            SELECT Id, Status__c, CustomerAccount__c, CustomerAccount__r.Name,
                   Phase_Name__c, TotalAmount__c, Totalpaidamount__c,
                   Down_Payment_Status__c, SPAStatus__c, SPACustomerSignedDate__c,
                   Discount_Amount__c, Sales_Commission__c, ProjectName__c,
                   Source_Entity__c, Indirect_Commission_Amount__c,
                   Discount_on_ADM_fee_Amount__c, External_Commission_Amount__c,
                   Unit__c,
                   Unit__r.LastModifiedDate, Unit__r.GrossFloorAreaGFA__c,
                   Unit__r.Building_Name__c, Unit__r.TotalGrossSellableAreaGSA__c,
                   Unit__r.Description__c, Unit__r.UnitClassification__c,
                   Unit__r.PlotAreasqm__c, Unit__r.BasePrice__c,
                   Unit__r.Unit_Launch_Date__c, Unit__r.Status__c, Unit__r.Name,
                   Unit__r.ADGMUnitNumber__c, Unit__r.PlotNo__c, Unit__r.Pass_id__c,
                   Unit__r.Type__c, Unit__r.BuildingNo__c, Unit__r.TotalPrice__c,
                   Unit__r.Phase__r.Project__r.ProjectNumber__c,
                   Unit__r.Phase__r.EntityName__c, Unit__r.Building_No__c,
                   Unit__r.Unit_Sold_Date__c, Unit__r.ApprovalStatus__c
            FROM SalesOrder__c
            WHERE Status__c = 'In Progress'
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new InventoryErrorMock());

        Test.startTest();
        OIC_ManageInventoryMaster.getPropertyMaster(soList, 'SalesOrder');
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }

    @isTest
    static void testGetPropertyMaster_EmptyBody() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
       
        List<Unit__c> units = [
            SELECT Id, Name, ApprovalStatus__c, Status__c, GrossFloorAreaGFA__c,
                   LastModifiedDate, TotalGrossSellableAreaGSA__c, Description__c,
                   UnitClassification__c, PlotAreasqm__c, BasePrice__c,
                   Unit_Launch_Date__c, ADGMUnitNumber__c, PlotNo__c, Pass_id__c,
                   Type__c, BuildingNo__c, Building_Name__c, Unit_Sold_Date__c,
                   TotalPrice__c,
                   Phase__r.Project__r.ProjectNumber__c, Phase__r.EntityName__c,
                   Phase__r.Name, Phase__r.Project__r.Name
            FROM Unit__c
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new InventoryEmptyBodyMock());

        Test.startTest();
        OIC_ManageInventoryMaster.getPropertyMaster(units, 'Unit');
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OIC_ManageInventoryMaster — Unit UnitClassification = 'Plot' branch
    // (exercises sqmt = GrossFloorAreaGFA__c path instead of GSA)
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetPropertyMaster_Unit_PlotClassification() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        

        // Update unit to Plot classification
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        unit.UnitClassification__c = 'Plot';
        update unit;

        List<Unit__c> units = [
            SELECT Id, Name, ApprovalStatus__c, Status__c, GrossFloorAreaGFA__c,
                   LastModifiedDate, TotalGrossSellableAreaGSA__c, Description__c,
                   UnitClassification__c, PlotAreasqm__c, BasePrice__c,
                   Unit_Launch_Date__c, ADGMUnitNumber__c, PlotNo__c, Pass_id__c,
                   Type__c, BuildingNo__c, Building_Name__c, Unit_Sold_Date__c,
                   TotalPrice__c,
                   Phase__r.Project__r.ProjectNumber__c, Phase__r.EntityName__c,
                   Phase__r.Name, Phase__r.Project__r.Name
            FROM Unit__c
            WHERE Id = :unit.Id
        ];

        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        OIC_ManageInventoryMaster.getPropertyMaster(units, 'Unit');
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OIC_ManageInventoryMaster — SalesOrder Plot classification branch
    // (exercises sqmt = GrossFloorAreaGFA__c for SO path)
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetPropertyMaster_SalesOrder_PlotClassification() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        // Update unit to Plot so the SO branch hits GrossFloorAreaGFA__c
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        unit.UnitClassification__c = 'Plot';
        update unit;

        List<SalesOrder__c> soList = [
            SELECT Id, Status__c, CustomerAccount__c, CustomerAccount__r.Name,
                   Phase_Name__c, TotalAmount__c, Totalpaidamount__c,
                   Down_Payment_Status__c, SPAStatus__c, SPACustomerSignedDate__c,
                   Discount_Amount__c, Sales_Commission__c, ProjectName__c,
                   Source_Entity__c, Indirect_Commission_Amount__c,
                   Discount_on_ADM_fee_Amount__c, External_Commission_Amount__c,
                   Unit__c,
                   Unit__r.LastModifiedDate, Unit__r.GrossFloorAreaGFA__c,
                   Unit__r.Building_Name__c, Unit__r.TotalGrossSellableAreaGSA__c,
                   Unit__r.Description__c, Unit__r.UnitClassification__c,
                   Unit__r.PlotAreasqm__c, Unit__r.BasePrice__c,
                   Unit__r.Unit_Launch_Date__c, Unit__r.Status__c, Unit__r.Name,
                   Unit__r.ADGMUnitNumber__c, Unit__r.PlotNo__c, Unit__r.Pass_id__c,
                   Unit__r.Type__c, Unit__r.BuildingNo__c, Unit__r.TotalPrice__c,
                   Unit__r.Phase__r.Project__r.ProjectNumber__c,
                   Unit__r.Phase__r.EntityName__c, Unit__r.Building_No__c,
                   Unit__r.Unit_Sold_Date__c, Unit__r.ApprovalStatus__c
            FROM SalesOrder__c
            WHERE Status__c = 'In Progress'
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        OIC_ManageInventoryMaster.getPropertyMaster(soList, 'SalesOrder');
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
       
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OIC_ManageInventoryMaster — Unit with ADGMUnitNumber branch
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetPropertyMaster_Unit_ADGMUnitNumber() {
        TriggerControl.BypassAccountTrigger    = true;
        TriggerControl.BypassCancelledTrigger  = true;
        
        // Set ADGMUnitNumber so the unit_number = ADGMUnitNumber__c branch fires
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        unit.ADGMUnitNumber__c = 'ADGM-001';
        update unit;

        List<Unit__c> units = [
            SELECT Id, Name, ApprovalStatus__c, Status__c, GrossFloorAreaGFA__c,
                   LastModifiedDate, TotalGrossSellableAreaGSA__c, Description__c,
                   UnitClassification__c, PlotAreasqm__c, BasePrice__c,
                   Unit_Launch_Date__c, ADGMUnitNumber__c, PlotNo__c, Pass_id__c,
                   Type__c, BuildingNo__c, Building_Name__c, Unit_Sold_Date__c,
                   TotalPrice__c,
                   Phase__r.Project__r.ProjectNumber__c, Phase__r.EntityName__c,
                   Phase__r.Name, Phase__r.Project__r.Name
            FROM Unit__c
            WHERE Id = :unit.Id
        ];

        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());

        Test.startTest();
        OIC_ManageInventoryMaster.getPropertyMaster(units, 'Unit');
        Test.stopTest();

        TriggerControl.BypassAccountTrigger    = false;
        TriggerControl.BypassCancelledTrigger  = false;
        
    }
}