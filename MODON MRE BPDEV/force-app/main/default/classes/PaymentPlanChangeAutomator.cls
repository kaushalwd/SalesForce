/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : PaymentPlanImplementationController
 * Author          : Siva
 * Created Date    : Jun 7, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Jun 14, 2026
 * Description     : 
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  AUG 6, 2026  │ Siva   │ Payment Plan Phase 2 Changes
 *  Aug 14, 2026    Karunakar   Callout SalesOrder on CM Finance Verification step
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public class PaymentPlanChangeAutomator implements BusinessProcessAutomation {

    public void executeAutomation(BusinessProcessAutomationInput input) {
        List<Id> bpIds = new List<Id>();
        Set<Id> financeVerificationBpIds = new Set<Id>();

        for (Business_Process_Step__c step : input.steps) {
            switch on step.Name {

                when 'CM Senior Manager Approval' {
                    if (step.Status__c == 'Completed') {
                        bpIds.add(step.business_Process__c);
                    }
                }

                when 'CM Finance Verification' {
                    if (step.Status__c == 'Completed') {
                        financeVerificationBpIds.add(step.business_Process__c);
                    }
                }
            }
        }

        //Salesorder and Line items callout
        if (!financeVerificationBpIds.isEmpty()) {
            Set<String> financeSalesOrderIds = new Set<String>();
            for (Business_Process__c bp : [SELECT Sales_Order__c FROM Business_Process__c WHERE Id IN :financeVerificationBpIds AND Sales_Order__c != null]) {
                financeSalesOrderIds.add(bp.Sales_Order__c);
            }
            if (!financeSalesOrderIds.isEmpty()) {
                System.enqueueJob(new SalesOrderCallout_Queable(financeSalesOrderIds));
                //OIC_ManageSalesforceDataController.createSalesOrderAndSOInstallments(financeSalesOrderIds);
            }
        }

        if (bpIds.isEmpty()) return;

        String salesOrderId = [SELECT Sales_Order__c FROM Business_Process__c WHERE Id = :bpIds[0]].Sales_Order__c;

        List<PaymentPlanChangeRequest__c> reqList = [
            SELECT Id, Revised_Payment_Plan__c, Status__c
            FROM PaymentPlanChangeRequest__c
            WHERE Sales_Order__c = :salesOrderId AND Status__c IN ('Draft')
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (reqList.isEmpty()) return;

        PaymentPlanImplementationController.createPlan(reqList[0].Id);
    }

}