public class DocuSignQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> srIds;

    public DocuSignQueueable(List<Id> srIds){
        this.srIds = srIds;
    }

    public void execute(QueueableContext context){
        MBP_SendForSignatureController.sendEnvelopeBulk(srIds); 
    }
}