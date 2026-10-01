@isTest
private class PaymentLinkRequestWrapperTest {

    @isTest
    static void testPaymentLinkRequestWrapper() {
        test.Starttest();
        PaymentLinkRequestWrapper wrapper = new PaymentLinkRequestWrapper();
        wrapper.transactionNotificationURL = 'https://showmethepaymentresult.com';
        wrapper.orderId = 'sampleReceiptId';
        wrapper.transactionType = 'SALE';
        PaymentLinkRequestWrapper.tamount amount = new PaymentLinkRequestWrapper.tamount();
        amount.total = '1000';
        amount.str_currency = 'AED';
        wrapper.transactionAmount = amount;
        test.stoptest();
    }
}