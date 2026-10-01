Public without sharing Class createPreCancellation{
@AuraEnabled
public static String createPreCancellations(
    String salesOrderId,
    String processId,
    String cancellationType,
    String admRefundValue,
    Decimal admPaidAmount,
    Decimal downPaymentAmount,
    Decimal totalRefundAmount,
    String consolidationData
) {

    System.debug('========== CREATE PRE CANCELLATION BP ==========');



    if (
        String.isBlank(salesOrderId) 
       
       // String.isBlank(processId)
    ) {
        throw new AuraHandledException(
            'Sales Order and Process Flow are required.'
        );
    }

    Id soId;

    try {
        soId = (Id)salesOrderId;
    } catch (Exception e) {
        throw new AuraHandledException(
            'Invalid Sales Order Id.'
        );
    }


    /* ============================================================
     * SALES ORDER
     * ============================================================ */

    SalesOrder__c so = [
        SELECT
            Id,
            Name,
            Unit__c,
            Unit__r.Phase__c,
            Unit__r.Phase__r.Project__c,
            CustomerAccount__c,
            PrimaryContact__c,
            Collection_Associate__c,
            Status__c,
            ADM_Fees_and_Dari__c,
            Down_Payment_Status__c
        FROM SalesOrder__c
        WHERE Id = :soId
        LIMIT 1
    ];


    /* ============================================================
     * PROCESS FLOW
     * ============================================================ */

    Process_Flow__c process = [
        SELECT
            Id,
            Name,
            Active__c,
            Initial_Submitter_Roles__c,
            Initial_submitter_User_Ids__c,
            Process_Flow_Unique_Name__c,
            Is_check_List__c,
            Milestone_To_Complete_In_Hours__c
        FROM Process_Flow__c
        WHERE Name='Pre Unit Cancellation and Refund Process'
        LIMIT 1
    ];


    if (!process.Active__c) {

        throw new AuraHandledException(
            'Selected Process Flow is not active.'
        );
    }


    /* ============================================================
     * CREATE BUSINESS PROCESS
     * ============================================================ */

    Business_Process__c bp =
        new Business_Process__c();

    bp.Sales_Order__c =
        so.Id;

    bp.Account__c =
        so.CustomerAccount__c;

    bp.Contact__c =
        so.PrimaryContact__c;

    bp.Unit__c =
        so.Unit__c;

    bp.Phase__c =
        so.Unit__r != null
        ? so.Unit__r.Phase__c
        : null;

    bp.Project__c =
        so.Unit__r != null &&
        so.Unit__r.Phase__r != null
        ? so.Unit__r.Phase__r.Project__c
        : null;

    bp.Process_Flow__c =
        process.Id;

    bp.Status__c =
        'In Progress';

    bp.Start_Date__c =
        System.now();

    bp.Is_check_List__c =
        process.Is_check_List__c;

    bp.Milestone_To_Complete_In_Hours__c =
        process.Milestone_To_Complete_In_Hours__c;

    bp.Type__c =
        process.Process_Flow_Unique_Name__c;


    /* ============================================================
     * CANCELLATION INFORMATION
     *
     * These assignments should only be retained if these fields
     * exist on Business_Process__c.
     * ============================================================ */

    /*
    bp.Cancellation_Type__c =
        cancellationType;

    bp.ADM_Refund_Needed__c =
        admRefundValue;

    bp.ADM_Amount__c =
        admPaidAmount;

    bp.Down_Payment_Amount__c =
        downPaymentAmount;

    bp.Total_Refund_Amount__c =
        totalRefundAmount;
    */


    insert bp;


    /* ============================================================
     * PROCESS FLOW STEPS
     * ============================================================ */

    List<Process_Flow_Step__c> processFlowStepsList = [
        SELECT
            Id,
            Expression__c,
            Active__c,
            Description__c,
            Process_Flow__c,
            Name,
            canMassUpdate__c,
            isSingleUser__c,
            Is_check_List__c,
            Is_Process_End__c,
            Step_Entry_Criteria__c,
            Skip_Step_To_Reopen__c,
            Setp_No__c,
            Department__c,
            Department_Queue__c,
            Duration_To_Complete_In_Days__c,
            section_Name__c,
            Section_Number__c,
            Duration_To_Complete_In_Hourss__c,
            Is_Single_Level_Required_Info__c,
            Choose_Next_Owner__c,
            Is_Reject_Button_Required__c,
            Is_Required_More_Button_Required__c,
            Is_Review_Comments_Req__c,
            View_review_comments__c,
            Is_Assigned_TO__c,
            Dont_Activate__c,
            Activate_On_Creation__c,
            Is_Multi_Select_Reopen__c,
            Is_Management_Step__c
        FROM Process_Flow_Step__c
        WHERE Process_Flow__c = :process.Id
        AND Active__c = true
        ORDER BY Setp_No__c ASC
    ];


    /* ============================================================
     * CREATE BUSINESS PROCESS STEPS
     * ============================================================ */

    List<Business_Process_Step__c>
        listToCreateBPS =
        new List<Business_Process_Step__c>();

    Integer stepNumber = 1;

    for (
        Process_Flow_Step__c step :
        processFlowStepsList
    ) {

        if (!step.Active__c) {
            continue;
        }

        listToCreateBPS.add(
            CreateBusinessProcess.createBusinessProcessStep(
                stepNumber,
                step,
                bp.Id,
                so,
                null
            )
        );

        stepNumber++;
    }


    if (!listToCreateBPS.isEmpty()) {

        insert listToCreateBPS;
    }


    /* ============================================================
     * FIND CURRENT STEP
     * ============================================================ */

    String openOrAcceptedStepId = '';

    Map<String, String>
        stepNameAndIdMap =
        new Map<String, String>();


    for (
        Business_Process_Step__c step :
        listToCreateBPS
    ) {

        if (
            step.Status__c == 'Open' ||
            step.Status__c == 'Accepted'
        ) {

            openOrAcceptedStepId =
                step.Id;
        }

        stepNameAndIdMap.put(
            step.Name,
            step.Id
        );
    }


    if (
        !String.isBlank(openOrAcceptedStepId)
    ) {

        bp.Current_Business_Process_Step__c =
            openOrAcceptedStepId;

        update bp;
    }


    /* ============================================================
     * PROCESS FLOW DOCUMENTS
     * ============================================================ */

    List<Process_Flow_Document__c>
        processFlowDocumentList = [

        SELECT
            Id,
            Name,
            Document_Upload_Criteria__c,
            Record_Creation_Criteria__c,
            Active__c,
            Process_Flow__c,
            Process_Flow_Step__r.Step_Name__c,
            Document_Entry_Criteria__c

        FROM Process_Flow_Document__c

        WHERE Process_Flow__c = :process.Id
        AND Active__c = true
    ];


    /* ============================================================
     * CREATE BP DOCUMENT RECORDS
     * ============================================================ */

    List<String>
        documentNames =
        new List<String>();

    List<Business_Process_Documents__c>
        listToCreateBDS =
        new List<Business_Process_Documents__c>();


    for (
        Process_Flow_Document__c doc :
        processFlowDocumentList
    ) {

        if (!doc.Active__c) {
            continue;
        }


        /*
         * Avoid duplicate document names.
         */
        if (
            documentNames.contains(
                doc.Name
            )
        ) {
            continue;
        }


        Business_Process_Documents__c
            newDoc =
            new Business_Process_Documents__c();

        newDoc.Name =
            doc.Name;

        newDoc.Business_Process__c =
            bp.Id;

        newDoc.Process_Flow_Document__c =
            doc.Id;

        newDoc.Business_Process_Step_Name__c =
            doc.Process_Flow_Step__r != null
            ? doc.Process_Flow_Step__r.Step_Name__c
            : null;


        if (
            doc.Process_Flow_Step__r != null &&
            !String.isBlank(
                doc.Process_Flow_Step__r.Step_Name__c
            ) &&
            stepNameAndIdMap.containsKey(
                doc.Process_Flow_Step__r.Step_Name__c
            )
        ) {

            newDoc.Business_Process_Step__c =
                stepNameAndIdMap.get(
                    doc.Process_Flow_Step__r.Step_Name__c
                );
        }


        listToCreateBDS.add(
            newDoc
        );

        documentNames.add(
            doc.Name
        );
    }


    if (!listToCreateBDS.isEmpty()) {

        insert listToCreateBDS;
    }





    System.debug(
        'PRE CANCELLATION BP CREATED: ' +
        bp.Id
    );


    return bp.Id;
}

@AuraEnabled
public static void createOtherDocumentAndAssociateFile(
    Id businessProcessId,
    Id contentDocumentId
) {
    if (businessProcessId == null || contentDocumentId == null) {
        throw new AuraHandledException(
            'Business Process Id and File Id are required.'
        );
    }


    Business_Process_Documents__c bpDocument =
        new Business_Process_Documents__c();

    bpDocument.Name = 'Other Documents';
    bpDocument.Business_Process__c = businessProcessId;

    insert bpDocument;


    ContentDocumentLink fileLink = new ContentDocumentLink();

    fileLink.ContentDocumentId = contentDocumentId;


    fileLink.LinkedEntityId = bpDocument.Id;

    fileLink.ShareType = 'V';
    fileLink.Visibility = 'AllUsers';

    insert fileLink;
}

@AuraEnabled
public static void saveConsolidationRecords(
    List<Unit_Consolidation__c> records
) {
    if (records == null || records.isEmpty()) {
        return;
    }

    try {
        Database.SaveResult[] results =
            Database.insert(records, false);

        for (Database.SaveResult sr : results) {

            if (!sr.isSuccess()) {

                for (Database.Error err : sr.getErrors()) {

                    throw new AuraHandledException(
                        err.getMessage()
                    );
                }
            }
        }

    } catch (AuraHandledException e) {

        throw e;

    } catch (Exception e) {

        throw new AuraHandledException(
            'Error saving consolidation records: ' +
            e.getMessage()
        );
    }
}

}