public class UnitConsolidationPDFQueueable implements Queueable, Database.AllowsCallouts {
    private Id serviceRequestId;

    public UnitConsolidationPDFQueueable(Id srId) {
        this.serviceRequestId = srId;
    }

    public void execute(QueueableContext context) {
        UnitConsolidationPDFService.generateAndAttachPDF(serviceRequestId);
    }
}