public without sharing class PaymentLinkRequestWrapper {
        
        public String transactionNotificationURL;   // https://showmethepaymentresult.com
        public string orderId; // receipt ID
        public String transactionType;  //SALE
        public tamount transactionAmount;
        public String storeId;  
        
        public class tamount {
            public String total;    // 1000
            public String str_currency; // AED
           
        }
        
}