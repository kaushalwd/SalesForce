public class UntUpgradeOrSwapPDFQueueable  implements Queueable, Database.AllowsCallouts{
 private Id serviceRequestId;

    public UntUpgradeOrSwapPDFQueueable(Id srId){
        this.serviceRequestId = srId;
    }
   

    public void execute(QueueableContext context){
      
            UnitUpgradeOrSwapPDFService.generateAndEmailPDF(serviceRequestId);
    }
}