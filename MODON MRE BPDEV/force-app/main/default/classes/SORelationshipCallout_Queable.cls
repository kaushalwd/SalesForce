/**********************************************************************************************************************
* Name               : SORelationshipCallout_Queable
* Description        : Async wrapper so SORelationshipTriggerHelper can trigger the Customer Relationship
*                       callout (Apex disallows synchronous callouts from trigger context).
* Usage              : Enqueued from SORelationshipTriggerHelper.createCustomerRelationshipCallout
* Created By         : MODON IT
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           MODON IT                            24 Aug 2026     Initial Draft
**********************************************************************************************************************/
public class SORelationshipCallout_Queable implements Queueable, Database.AllowsCallouts {
    private Set<Id> sorIds;

    public SORelationshipCallout_Queable(Set<Id> sorIds) {
        this.sorIds = sorIds;
    }

    public void execute(QueueableContext context) {
        OIC_CustomerRelationshipCallout.createCustomerRelationship(sorIds);
    }
}