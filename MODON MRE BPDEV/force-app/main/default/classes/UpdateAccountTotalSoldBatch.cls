public class UpdateAccountTotalSoldBatch implements Database.Batchable<AggregateResult> {
    
    public Iterable<AggregateResult> start(Database.BatchableContext bc) {
        return [
            SELECT CustomerAccount__c, SUM(TotalAmount__c) totalSold
            FROM SalesOrder__c
            WHERE CustomerAccount__c != NULL AND Status__c NOT IN ('Voided','System Cancelled','Cancelled SR','Cancelled')
            GROUP BY CustomerAccount__c
        ];
    }
    
    public void execute(Database.BatchableContext bc, List<AggregateResult> scope) {
        List<Account> accountsToUpdate = new List<Account>();
        
        for (AggregateResult ar : scope) {
            Id accountId = (Id) ar.get('CustomerAccount__c');
            Decimal total = (Decimal) ar.get('totalSold');
            
            accountsToUpdate.add(new Account(
                Id = accountId,
                Total_Sold_Value__c = total
            ));
        }
        
        // if (!accountsToUpdate.isEmpty()) {
        //    update accountsToUpdate;
        // }
        if (!accountsToUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(accountsToUpdate, false); 
            
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    for (Database.Error err : results[i].getErrors()) {
                        System.debug('Failed Account Id: ' + accountsToUpdate[i].Id +
                                     ' | Error: ' + err.getMessage());
                    }
                }
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        // Optional: notification or logging
    }
}