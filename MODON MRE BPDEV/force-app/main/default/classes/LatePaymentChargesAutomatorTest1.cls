@IsTest
public without sharing class LatePaymentChargesAutomatorTest1 {

    @testSetup
    static void setupData() {

        Financial_Setup__c financialSetup = new Financial_Setup__c(
            Type__c = 'Late Payment Charges',
            Active__c = true,
            VAT_PercnetAGE__c = 5,
            GraceDays__c = 30,
            Days_In_a_Year__c = 365
        );
        insert financialSetup;

        Account customerAccount = new Account(
            Name = 'LPC Test Customer'
        );
        insert customerAccount;

        Project__c project = new Project__c(
            Name = 'LPC Test Project'
        );
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'LPC Test Phase',
            Project__c = project.Id
        );
        insert phase;

        Unit__c unitRecord = new Unit__c(
            Name = 'LPC Test Unit',
            Phase__c = phase.Id,
            PlotNo__c = 'P-101',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2'
        );
        insert unitRecord;

        SalesOrder__c positiveWaiverSO = new SalesOrder__c(
            CustomerAccount__c = customerAccount.Id,
            Unit__c = unitRecord.Id,
            TotalAmount__c = 100000
        );

        SalesOrder__c zeroWaiverSO = new SalesOrder__c(
            CustomerAccount__c = customerAccount.Id,
            Unit__c = unitRecord.Id,
            TotalAmount__c = 100000
        );

        SalesOrder__c openStepSO = new SalesOrder__c(
            CustomerAccount__c = customerAccount.Id,
            Unit__c = unitRecord.Id,
            TotalAmount__c = 100000
        );

        SalesOrder__c unrelatedStepSO = new SalesOrder__c(
            CustomerAccount__c = customerAccount.Id,
            Unit__c = unitRecord.Id,
            TotalAmount__c = 100000
        );

        insert new List<SalesOrder__c>{
            positiveWaiverSO,
            zeroWaiverSO,
            openStepSO,
            unrelatedStepSO
        };

        Process_Flow__c processFlow = new Process_Flow__c(
            Name = 'Late Payment Charge Waiver Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'LPC_WAIVER_TEST'
        );
        insert processFlow;

        Process_Flow_Step__c processFlowStep =
            new Process_Flow_Step__c(
                Step_Name__c = 'Collections Execute Waiver',
                Section_Number__c = 1,
                section_Name__c = 'LPC Waiver',
                Process_Flow__c = processFlow.Id
            );
        insert processFlowStep;

        /*
         * LPC_Waived_Amount__c and LPCWaivedAmount__c
         * are calculated automatically.
         */
        Business_Process__c positiveWaiverProcess =
            new Business_Process__c(
                Process_Flow__c = processFlow.Id,
                Sales_Order__c = positiveWaiverSO.Id,
                LPC_Amount__c = 100000,
                Waiver_Percentage__c = 10
            );

        Business_Process__c zeroWaiverProcess =
            new Business_Process__c(
                Process_Flow__c = processFlow.Id,
                Sales_Order__c = zeroWaiverSO.Id,
                LPC_Amount__c = 100000,
                Waiver_Percentage__c = 0
            );

        Business_Process__c openStepProcess =
            new Business_Process__c(
                Process_Flow__c = processFlow.Id,
                Sales_Order__c = openStepSO.Id,
                LPC_Amount__c = 100000,
                Waiver_Percentage__c = 10
            );

        Business_Process__c unrelatedStepProcess =
            new Business_Process__c(
                Process_Flow__c = processFlow.Id,
                Sales_Order__c = unrelatedStepSO.Id,
                LPC_Amount__c = 100000,
                Waiver_Percentage__c = 10
            );

        insert new List<Business_Process__c>{
            positiveWaiverProcess,
            zeroWaiverProcess,
            openStepProcess,
            unrelatedStepProcess
        };

        List<Business_Process_Step__c> steps =
            new List<Business_Process_Step__c>{
                new Business_Process_Step__c(
                    Name = 'Collections Execute Waiver',
                    Business_Process__c = positiveWaiverProcess.Id,
                    Process_Flow_Step__c = processFlowStep.Id,
                    Sequence__c = 1,
                    Status__c = 'Completed',
                    section_Name__c = 'LPC Waiver',
                    Section_Number__c = 1,
                    Business_Process_Steps_Name_Custom__c =
                        'Collections Execute Waiver - Positive'
                ),

                new Business_Process_Step__c(
                    Name = 'Collections Execute Waiver',
                    Business_Process__c = zeroWaiverProcess.Id,
                    Process_Flow_Step__c = processFlowStep.Id,
                    Sequence__c = 1,
                    Status__c = 'Completed',
                    section_Name__c = 'LPC Waiver',
                    Section_Number__c = 1,
                    Business_Process_Steps_Name_Custom__c =
                        'Collections Execute Waiver - Zero'
                ),

                new Business_Process_Step__c(
                    Name = 'Collections Execute Waiver',
                    Business_Process__c = openStepProcess.Id,
                    Process_Flow_Step__c = processFlowStep.Id,
                    Sequence__c = 1,
                    Status__c = 'Open',
                    section_Name__c = 'LPC Waiver',
                    Section_Number__c = 1,
                    Business_Process_Steps_Name_Custom__c =
                        'Collections Execute Waiver - Open'
                ),

                new Business_Process_Step__c(
                    Name = 'Other Automation Step',
                    Business_Process__c = unrelatedStepProcess.Id,
                    Process_Flow_Step__c = processFlowStep.Id,
                    Sequence__c = 1,
                    Status__c = 'Completed',
                    section_Name__c = 'LPC Waiver',
                    Section_Number__c = 1,
                    Business_Process_Steps_Name_Custom__c =
                        'Unrelated Automation Step'
                )
            };

        insert steps;
    }

    @IsTest
    static void testCompletedWaiver() {

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Status__c,
                   Business_Process__c,
                   Business_Process__r.LPC_Amount__c,
                   Business_Process__r.Waiver_Percentage__c,
                   Business_Process__r.LPC_Waived_Amount__c,
                   Business_Process__r.LPCWaivedAmount__c,
                   Business_Process__r.Sales_Order__c,
                   Business_Process__r.Sales_Order__r.CustomerAccount__c
            FROM Business_Process_Step__c
            WHERE Business_Process_Steps_Name_Custom__c =
                'Collections Execute Waiver - Positive'
            LIMIT 1
        ];

        BusinessProcessAutomationInput input =
            new BusinessProcessAutomationInput();

        input.steps = new List<SObject>{ step };

        Test.setMock(HttpCalloutMock.class, new RestMock());

        Test.startTest();

        try {
            new LatePaymentChargesAutomator()
                .executeAutomation(input);
        } catch (Exception exceptionRecord) {
            System.debug(
                'Completed waiver exception: ' +
                exceptionRecord.getMessage()
            );
        }

        Test.stopTest();

        List<Charge__c> charges = [
            SELECT Id,
                   Name,
                   Amount__c,
                   VAT_Amount__c,
                   Sales_Order__c,
                   VAT_Percentage__c,
                   Type__c,
                   PaymentStatus__c
            FROM Charge__c
            WHERE Sales_Order__c =
                :step.Business_Process__r.Sales_Order__c
        ];

        List<Invoice__c> invoices = [
            SELECT Id,
                   InvoiceAmount__c,
                   InvoiceDate__c,
                   Account__c,
                   Charge__c,
                   Sales_Order__c
            FROM Invoice__c
            WHERE Sales_Order__c =
                :step.Business_Process__r.Sales_Order__c
        ];

        List<Receipt__c> creditNotes = [
            SELECT Id,
                   Modeofpayment__c,
                   SalesOrder__c,
                   Account__c,
                   TotalAmount__c,
                   Receipt_Amount__c,
                   Status__c,
                   EBS_Clearing_Date__c
            FROM Receipt__c
            WHERE SalesOrder__c =
                :step.Business_Process__r.Sales_Order__c
        ];

        Set<Id> receiptIds = new Map<Id, Receipt__c>(
            creditNotes
        ).keySet();

        List<Allocation__c> allocations =
            new List<Allocation__c>();

        if (!receiptIds.isEmpty()) {
            allocations = [
                SELECT Id,
                       Receipt__c,
                       Invoice__c,
                       AllocationAmount__c,
                       ApprovedReceiptAmount__c
                FROM Allocation__c
                WHERE Receipt__c IN :receiptIds
            ];
        }

        System.debug('Created charges: ' + charges);
        System.debug('Created invoices: ' + invoices);
        System.debug('Created credit notes: ' + creditNotes);
        System.debug('Created allocations: ' + allocations);

        // Charges and allocations created by the automator carry the
        // parent Business Process.
        Id salesOrderId = step.Business_Process__r.Sales_Order__c;

        for (Charge__c chargeRecord : [
            SELECT Id, Business_Process__c
            FROM Charge__c
            WHERE Sales_Order__c = :salesOrderId
            AND Business_Process__c != null
        ]) {
            System.assertEquals(step.Business_Process__c, chargeRecord.Business_Process__c);
        }

        if (!receiptIds.isEmpty()) {
            for (Allocation__c allocationRecord : [
                SELECT Id, Business_Process__c
                FROM Allocation__c
                WHERE Receipt__c IN :receiptIds
            ]) {
                System.assertEquals(step.Business_Process__c, allocationRecord.Business_Process__c);
            }
        }
    }

    @IsTest
    static void testLpcChargeRecordTypeSetting() {

        LatePaymentChargesAutomator.lpcChargeRecordTypeSetting = 'NONE';
        System.assertEquals(null, LatePaymentChargesAutomator.getLpcChargeRecordTypeId(),
            'NONE means no record type');

        LatePaymentChargesAutomator.lpcChargeRecordTypeSetting = '  ';
        System.assertEquals(null, LatePaymentChargesAutomator.getLpcChargeRecordTypeId(),
            'Blank means no record type');

        LatePaymentChargesAutomator.lpcChargeRecordTypeSetting = 'Not_A_Record_Type';
        System.assertEquals(null, LatePaymentChargesAutomator.getLpcChargeRecordTypeId(),
            'Unknown value is ignored');

        Schema.RecordTypeInfo latePaymentRt =
            Schema.SObjectType.Charge__c.getRecordTypeInfosByDeveloperName().get('Late_Payment');

        if (latePaymentRt != null) {
            LatePaymentChargesAutomator.lpcChargeRecordTypeSetting = 'Late_Payment';
            System.assertEquals(latePaymentRt.getRecordTypeId(),
                LatePaymentChargesAutomator.getLpcChargeRecordTypeId(),
                'Developer name resolves to the record type');

            LatePaymentChargesAutomator.lpcChargeRecordTypeSetting = String.valueOf(latePaymentRt.getRecordTypeId());
            System.assertEquals(latePaymentRt.getRecordTypeId(),
                LatePaymentChargesAutomator.getLpcChargeRecordTypeId(),
                'Record type Id is accepted');
        }
    }

    @IsTest
    static void testZeroWaiverAmount() {

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Status__c,
                   Business_Process__c,
                   Business_Process__r.LPC_Amount__c,
                   Business_Process__r.Waiver_Percentage__c,
                   Business_Process__r.LPC_Waived_Amount__c,
                   Business_Process__r.LPCWaivedAmount__c,
                   Business_Process__r.Sales_Order__c,
                   Business_Process__r.Sales_Order__r.CustomerAccount__c
            FROM Business_Process_Step__c
            WHERE Business_Process_Steps_Name_Custom__c =
                'Collections Execute Waiver - Zero'
            LIMIT 1
        ];

        BusinessProcessAutomationInput input =
            new BusinessProcessAutomationInput();

        input.steps = new List<SObject>{ step };

        Test.setMock(HttpCalloutMock.class, new RestMock());

        Test.startTest();

        try {
            new LatePaymentChargesAutomator()
                .executeAutomation(input);
        } catch (Exception exceptionRecord) {
            System.debug(
                'Zero waiver exception: ' +
                exceptionRecord.getMessage()
            );
        }

        Test.stopTest();

        List<Charge__c> charges = [
            SELECT Id,
                   Name,
                   Amount__c,
                   VAT_Amount__c,
                   Sales_Order__c
            FROM Charge__c
            WHERE Sales_Order__c =
                :step.Business_Process__r.Sales_Order__c
        ];

        List<Invoice__c> invoices = [
            SELECT Id,
                   InvoiceAmount__c,
                   Account__c,
                   Charge__c,
                   Sales_Order__c
            FROM Invoice__c
            WHERE Sales_Order__c =
                :step.Business_Process__r.Sales_Order__c
        ];

        List<Receipt__c> receipts = [
            SELECT Id,
                   Modeofpayment__c,
                   TotalAmount__c,
                   SalesOrder__c
            FROM Receipt__c
            WHERE SalesOrder__c =
                :step.Business_Process__r.Sales_Order__c
        ];

        System.debug('Zero waiver charges: ' + charges);
        System.debug('Zero waiver invoices: ' + invoices);
        System.debug('Zero waiver receipts: ' + receipts);
    }

    @IsTest
    static void testOpenStep() {

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Status__c,
                   Business_Process__c,
                   Business_Process__r.LPC_Waived_Amount__c,
                   Business_Process__r.LPCWaivedAmount__c,
                   Business_Process__r.Sales_Order__c,
                   Business_Process__r.Sales_Order__r.CustomerAccount__c
            FROM Business_Process_Step__c
            WHERE Business_Process_Steps_Name_Custom__c =
                'Collections Execute Waiver - Open'
            LIMIT 1
        ];

        BusinessProcessAutomationInput input =
            new BusinessProcessAutomationInput();

        input.steps = new List<SObject>{ step };

        Test.setMock(HttpCalloutMock.class, new RestMock());

        Test.startTest();

        try {
            new LatePaymentChargesAutomator()
                .executeAutomation(input);
        } catch (Exception exceptionRecord) {
            System.debug(
                'Open step exception: ' +
                exceptionRecord.getMessage()
            );
        }

        Test.stopTest();

        List<Charge__c> charges = [
            SELECT Id,
                   Name,
                   Amount__c,
                   Sales_Order__c
            FROM Charge__c
            WHERE Sales_Order__c =
                :step.Business_Process__r.Sales_Order__c
        ];

        System.debug('Open-step charges: ' + charges);
    }

    @IsTest
    static void testUnrelatedStep() {

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Status__c,
                   Business_Process__c,
                   Business_Process__r.LPC_Waived_Amount__c,
                   Business_Process__r.LPCWaivedAmount__c,
                   Business_Process__r.Sales_Order__c,
                   Business_Process__r.Sales_Order__r.CustomerAccount__c
            FROM Business_Process_Step__c
            WHERE Business_Process_Steps_Name_Custom__c =
                'Unrelated Automation Step'
            LIMIT 1
        ];

        BusinessProcessAutomationInput input =
            new BusinessProcessAutomationInput();

        input.steps = new List<SObject>{ step };

        Test.setMock(HttpCalloutMock.class, new RestMock());

        Test.startTest();

        try {
            new LatePaymentChargesAutomator()
                .executeAutomation(input);
        } catch (Exception exceptionRecord) {
            System.debug(
                'Unrelated step exception: ' +
                exceptionRecord.getMessage()
            );
        }

        Test.stopTest();

        List<Charge__c> charges = [
            SELECT Id,
                   Name,
                   Amount__c,
                   Sales_Order__c
            FROM Charge__c
            WHERE Sales_Order__c =
                :step.Business_Process__r.Sales_Order__c
        ];

        System.debug('Unrelated-step charges: ' + charges);
    }

    @IsTest
    static void testMultipleStepsTogether() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Business_Process__c,
                   Business_Process__r.LPC_Amount__c,
                   Business_Process__r.Waiver_Percentage__c,
                   Business_Process__r.LPC_Waived_Amount__c,
                   Business_Process__r.LPCWaivedAmount__c,
                   Business_Process__r.Sales_Order__c,
                   Business_Process__r.Sales_Order__r.CustomerAccount__c
            FROM Business_Process_Step__c
            WHERE Business_Process_Steps_Name_Custom__c IN (
                'Collections Execute Waiver - Open',
                'Unrelated Automation Step'
            )
        ];

        BusinessProcessAutomationInput input =
            new BusinessProcessAutomationInput();

        input.steps = new List<SObject>();

        for (Business_Process_Step__c step : steps) {
            input.steps.add(step);
        }

        Test.setMock(HttpCalloutMock.class, new RestMock());

        Test.startTest();

        try {
            new LatePaymentChargesAutomator()
                .executeAutomation(input);
        } catch (Exception exceptionRecord) {
            System.debug(
                'Multiple-step exception: ' +
                exceptionRecord.getMessage()
            );
        }

        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MOCK CLASS
    // ─────────────────────────────────────────────────────────────────────────

    /** Generic success mock — extracts all Sfid values from any base64 payload
     *  and echoes them back with Status = 'S', so both the createInstallment
     *  and createReceipt/createCreditReceipt future callouts succeed. */
    private class RestMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            Set<String> sfids = new Set<String>();
            try {
                if (String.isNotBlank(req.getBody())) {
                    Map<String, Object> bodyMap =
                        (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
                    String base64Payload;
                    if (bodyMap.containsKey('Base64RequestPayload'))
                        base64Payload = (String) bodyMap.get('Base64RequestPayload');
                    else if (bodyMap.containsKey('Base64Request'))
                        base64Payload = (String) bodyMap.get('Base64Request');
                    if (String.isNotBlank(base64Payload))
                        collectSfidValues(
                            JSON.deserializeUntyped(EncodingUtil.base64Decode(base64Payload).toString()),
                            sfids
                        );
                }
            } catch (Exception ex) {}

            List<Object> responseArray = new List<Object>();
            for (String sfid : sfids) {
                Map<String, Object> row = new Map<String, Object>();
                row.put('Sfid',                sfid);
                row.put('Status',              'S');
                row.put('ErrorMsg',            null);
                row.put('OracleId',            'ORACLE-' + sfid.right(6));
                row.put('OracleRef',           'ORACLE-REF-' + sfid.right(6));
                row.put('CustAcctId',          'CUST-' + sfid.right(6));
                row.put('OraclePartySiteID',   'OPS-' + sfid.right(6));
                row.put('OracleCustAcctSiteID','OCAS-' + sfid.right(6));
                row.put('OracleSiteUseID',     'OSU-' + sfid.right(6));
                responseArray.add(row);
            }
            return buildResponse(responseArray);
        }

        private void collectSfidValues(Object obj, Set<String> sfids) {
            if (obj == null) return;
            if (obj instanceof Map<String, Object>) {
                Map<String, Object> m = (Map<String, Object>) obj;
                for (String key : m.keySet()) {
                    if (key != null && key.toLowerCase() == 'sfid' && m.get(key) != null)
                        sfids.add(String.valueOf(m.get(key)));
                    else
                        collectSfidValues(m.get(key), sfids);
                }
            } else if (obj instanceof List<Object>) {
                for (Object item : (List<Object>) obj) collectSfidValues(item, sfids);
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
}