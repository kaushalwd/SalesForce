public without sharing class RetrievePaymentStatusResponseWrapper {
    
    public String clientRequestId;   
    public string apiTraceId;
    public String orderId;
    public list<cls_transaction> transactions;
    
    public class cls_transaction {
        public String ipgTransactionId;
        public String transactionType;
        public String transactionResult;
        public String approvalCode;
       
    }
}