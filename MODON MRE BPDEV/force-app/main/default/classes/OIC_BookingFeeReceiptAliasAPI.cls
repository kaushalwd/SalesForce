/**********************************************************************************************
 * Name        : OIC_BookingFeeReceiptAliasAPI
 * Description : Alias REST entry point for /booking/receipts/* that delegates to
 *               OIC_BookingFeeReceiptAPI.createReceipts() to ensure both URL paths work.
 * Usage       : POST /services/apexrest/booking/receipts/
 **********************************************************************************************/
@RestResource(urlMapping='/booking/receipts/*')
global with sharing class OIC_BookingFeeReceiptAliasAPI {
    @HttpPost
    global static void createReceipts() {
        OIC_BookingFeeReceiptAPI.createReceipts();
    }
}