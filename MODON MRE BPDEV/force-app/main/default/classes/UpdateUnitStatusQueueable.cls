public class UpdateUnitStatusQueueable implements Queueable, Database.AllowsCallouts{

    public set<String> unitIds = new set<String>();

    public UpdateUnitStatusQueueable(set<String> unitIds){
        this.unitIds = unitIds;
    }

    public void execute(QueueableContext context) {
        OIC_ManageSalesforceDataController.updateUnitStatus(this.unitIds);
    }
}