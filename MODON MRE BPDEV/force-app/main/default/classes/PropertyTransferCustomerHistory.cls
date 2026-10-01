/**********************************************************************************************************************
* Name               : PropertyTransferCustomerHistory                                                        
* Description        : Controller class used to fetch Account change history
*                      (Old Value, New Value, Changed Date, Changed By)
*                      for SalesOrder__c object
* Usage              : Invoked from LWC to display Account update history
*                      on Sales Order record page.
* Created By         : Active minds Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj   	            20 FEB 2026     Initial Draft 
***********************************************************************************************************************/
public class PropertyTransferCustomerHistory {
	/**
     * Method Name   : getAccountHistory
     * Description   : Retrieves CustomerAccount__c field history
     *                 for a given Sales Order.
     */
    @AuraEnabled(cacheable=true)
    public static List<SalesOrderHistoryWrapper> getAccountHistory(Id salesOrderId){

        // List to hold formatted history response
        List<SalesOrderHistoryWrapper> historyList = new List<SalesOrderHistoryWrapper>();

        // Query Sales Order History for Account changes
        for(SalesOrder__History hist : [
            SELECT Id,
                   Field,
                   OldValue,
                   NewValue,
                   CreatedDate,
                   CreatedBy.Name,Parent.Resale_Transfer_Date__c
            FROM SalesOrder__History
            WHERE ParentId = :salesOrderId 
            AND Field = 'CustomerAccount__c'
            ORDER BY CreatedDate DESC]){
            if(hist.Parent.Resale_Transfer_Date__c != null){
                historyList.add(new SalesOrderHistoryWrapper(String.valueOf(hist.OldValue),String.valueOf(hist.NewValue),hist.CreatedDate, hist.CreatedBy.Name));
            }
            
        }

        return historyList;
    }


    /**
     * Wrapper Class : SalesOrderHistoryWrapper
     * Description   : Used to send structured history data
     *                 to Lightning Web Component.
     */
    public class SalesOrderHistoryWrapper{

        @AuraEnabled public String oldValue;      // Previous Account Id
        @AuraEnabled public String newValue;      // Updated Account Id
        @AuraEnabled public Datetime changedDate; // Date of change
        @AuraEnabled public String changedBy;     // User who made change

        /**
         * Constructor
         *
         * @param oldVal   Previous Account value
         * @param newVal   Updated Account value
         * @param dt       Change timestamp
         * @param user     User who modified record
         */
        public SalesOrderHistoryWrapper(
            String oldVal,
            String newVal,
            Datetime dt,
            String user
        ){
            this.oldValue = oldVal;
            this.newValue = newVal;
            this.changedDate = dt;
            this.changedBy = user;
        }
}
}