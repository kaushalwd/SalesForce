public without sharing class EmployeePaymentPlanChangeController {
    
	@AuraEnabled
public static Boolean checkEmployeePaymentPlanProcess(
    Id salesOrderId
) {

    if (salesOrderId == null) {
        throw new AuraHandledException(
            'Sales Order Id is required.'
        );
    }

    List<Business_Process__c> processes = [
        SELECT Id
        FROM Business_Process__c
        WHERE Sales_Order__c = :salesOrderId
        AND Type__c = 'Employee Payment Plan'
        AND Status__c != 'Cancelled'
        LIMIT 1
    ];

	List<SalesOrder__c> salesOrder=[Select Id,CustomerAccount__r.Is_Employee_Payment_Plan_Applied__c from SalesOrder__c where Id=:salesOrderId];

    return !processes.isEmpty() || salesOrder[0].CustomerAccount__r.Is_Employee_Payment_Plan_Applied__c ;
}


@AuraEnabled
public static Id createEmployeePaymentPlanProcess(
    Id salesOrderId
) {

    if (salesOrderId == null) {
        throw new AuraHandledException(
            'Sales Order Id is required.'
        );
    }

    List<Business_Process__c> existingProcesses = [
        SELECT Id
        FROM Business_Process__c
        WHERE Sales_Order__c = :salesOrderId
        AND Type__c = 'Employee Payment Plan'
        AND Status__c = 'In Progress'
        LIMIT 1
    ];

    if (!existingProcesses.isEmpty()) {

        throw new AuraHandledException(
            'An Employee Payment Plan Change is already in progress for this Sales Order.'
        );
    }

    Process_Flow__c processFlow = [
        SELECT Id
        FROM Process_Flow__c
        WHERE Name = 'Employee Payment Plan'
        LIMIT 1
    ];

    Id businessProcessId =
        CreateBusinessProcess.createPreRegistration(
            salesOrderId,
            processFlow.Id
        );

    return businessProcessId;
}

}