public class PaymentReminderViewEmailController {
   
    public PaymentReminder__c paymentreminder{ get; set; }
    public date todayDate { get; set; }
    public string duedate  { get; set; }
    public boolean isChequeExpired{ get; set; }
    public Id reminderId{
        get {
            return null;
        }
        set {
            if (value != null) {
               loadServiceRequest(value);
            }
        }
    }
    
    private void loadServiceRequest(Id reminderId) {
        //todayDate = system.today();
        isChequeExpired = false;
        duedate   ='';
        List<PaymentReminder__c> paymentReminderList = [
            select id,SalesOrderInstallment__c,SalesOrderInstallment__r.SalesOrder__c,ReminderType__c,
            SalesOrderInstallment__r.SalesOrder__r.ProjectName__c,Over_Due_Amount__c,
            SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__r.Name,
            SalesOrderInstallment__r.SalesOrder__r.Primary_Contact_Title__c,
            SalesOrderInstallment__r.SalesOrder__r.PrimaryContact__r.Name,
            SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name,SalesOrderInstallment__r.ReminderDueDate__c,
            SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c,
            SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c,
            SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c
            from PaymentReminder__c where Id =:reminderId limit 1
        ];
        paymentreminder = (paymentReminderList != null && paymentReminderList.size()>0) ? paymentReminderList[0] : new PaymentReminder__c();
        todayDate = (paymentreminder.SalesOrderInstallment__r.ReminderDueDate__c != null) ? paymentreminder.SalesOrderInstallment__r.ReminderDueDate__c : system.today();
        List<Receipt__c>chequeList =[select Id,SalesOrderInstallment__c,TransactionDate__c from Receipt__c 
            where SalesOrderInstallment__c =:paymentreminder.SalesOrderInstallment__c and IsChequeExpired__c = true
        ];
        isChequeExpired = (chequeList.size()>0 && chequeList != null) ? true : false;
        duedate = DateTime.newInstance( todayDate.Year(), todayDate.Month(), todayDate.day()).format('dd/MM/yyyy');
    }
}