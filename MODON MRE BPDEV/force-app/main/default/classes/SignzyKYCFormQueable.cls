global class SignzyKYCFormQueable implements Queueable, Database.AllowsCallouts {
	public String docId;
    public String ReturnUrl;
    public blob pdfBlob;
    public Id kycId;
    global SignzyKYCFormQueable(String docId, String ReturnUrl, blob pdfBlob,Id kycId) {
        this.docId = docId;
        this.ReturnUrl = ReturnUrl;
        this.pdfBlob = pdfBlob;
        this.kycId = kycId;
    }

    global void execute(QueueableContext context) { 
        // Sales Order Callout  
        CustomerKYCHandler.callDocuSignLink(docId, ReturnUrl,pdfBlob,kycId);
	 }
}