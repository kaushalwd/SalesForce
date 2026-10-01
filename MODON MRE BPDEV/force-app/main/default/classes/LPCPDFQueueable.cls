/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 08-12-2025
 * @last modified by  : Krishna Chaitanya
**/
public class LPCPDFQueueable implements Queueable, Database.AllowsCallouts {
    private Id serviceRequestId;

    public LPCPDFQueueable(Id srId){
        this.serviceRequestId = srId;
    }

    public void execute(QueueableContext context){
      
            LPCWaiverPDFService.generateAndAttachPDF(serviceRequestId);
    }
}