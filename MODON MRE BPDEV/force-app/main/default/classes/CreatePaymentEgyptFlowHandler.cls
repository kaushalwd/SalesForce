/**-------------------------------------------------------------------
 * Description : Apex class to update status, sub-status, and block until 
 *               date/time fields on Unit__c records via Salesforce Flow.
 * -------------------------------------------------------------------
 * Version      Author           Date               Comment
 * -------------------------------------------------------------------
 * v1.0         Harshit        12-06-2025         Initial creation
 * -------------------------------------------------------------------
 * Notes: This class is designed to be called from Flow as an invocable method.
 *        It bulk processes Unit records to update specified fields.
 */
public without sharing class CreatePaymentEgyptFlowHandler {

    // Input class for Flow
    public class FlowInput {
        @InvocableVariable(required=true)
        public Id recordId; // ID of Unit__c

        @InvocableVariable(required=true)
        public Datetime blockUntil; // DateTime value for BlockUntil__c field
    }

    // Method available to Flow that updates unit status, sub-status, and block until datetime
    @InvocableMethod(label='Update Unit Status' description='Updates unit status, sub-status, and Block Until date/time')
    public static void updateUnitStatus(List<FlowInput> inputList) {
        Set<Id> unitIds = new Set<Id>();
        Map<Id, Datetime> blockUntilMap = new Map<Id, Datetime>();

        for (FlowInput input : inputList) {
            if (input.recordId != null) {
                unitIds.add(input.recordId);
                blockUntilMap.put(input.recordId, input.blockUntil);
            }
        }

        List<Unit__c> unitsToUpdate = [
            SELECT Id, Status__c, Sub_Status__c, BlockUntil__c
            FROM Unit__c
            WHERE Id IN :unitIds And Status__c!= 'Sold'
        ];

        for (Unit__c unit : unitsToUpdate) {
            unit.Status__c = 'Reserved';                 
            unit.Sub_Status__c = '';             
            unit.BlockUntil__c = blockUntilMap.get(unit.Id);
        }

        if (!unitsToUpdate.isEmpty()) {
            update unitsToUpdate;
        }
    }
}