/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 05-14-2025
 * @last modified by  : Krishna Chaitanya
**/
public class PaymentExtensionPDFQueueable implements Queueable, Database.AllowsCallouts {
    private Id serviceRequestId;

    public PaymentExtensionPDFQueueable(Id srId){
        this.serviceRequestId = srId;
    }
   

    public void execute(QueueableContext context){
      
            PaymentExtensionPDFService.generateAndEmailPDF(serviceRequestId);
    }
}