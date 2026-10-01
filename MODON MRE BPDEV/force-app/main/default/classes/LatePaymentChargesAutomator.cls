/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : LPC Process                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     22-07-2026      Initial Draft    
**********************************************************************************************************************/
public without sharing class LatePaymentChargesAutomator implements BusinessProcessAutomation {

    // Custom label LPC_Charge_Record_Type holds the Charge__c record type
    // (developer name, e.g. Late_Payment, or a record type Id). Custom labels
    // cannot be empty, so 'NONE' (or blank) means "do not set a record type".
    private static final String LPC_RECORD_TYPE_NOT_SET = 'NONE';

    @TestVisible
    private static String lpcChargeRecordTypeSetting = System.Label.LPC_Charge_Record_Type;

    @TestVisible
    private static Id getLpcChargeRecordTypeId() {
        String setting = lpcChargeRecordTypeSetting == null ? '' : lpcChargeRecordTypeSetting.trim();

        if (String.isBlank(setting) || LPC_RECORD_TYPE_NOT_SET.equalsIgnoreCase(setting)) {
            return null;
        }

        Schema.RecordTypeInfo rtInfo =
            Schema.SObjectType.Charge__c.getRecordTypeInfosByDeveloperName().get(setting);

        if (rtInfo == null && (setting.length() == 15 || setting.length() == 18) && setting.startsWith('012')) {
            rtInfo = Schema.SObjectType.Charge__c.getRecordTypeInfosById().get((Id) setting);
        }

        if (rtInfo == null) {
            System.debug(LoggingLevel.WARN, 'LPC_Charge_Record_Type "' + setting + '" is not a Charge__c record type; record type not set.');
            return null;
        }

        return rtInfo.getRecordTypeId();
    }

    public void executeAutomation( BusinessProcessAutomationInput input){
        List<Receipt__c> creditNoteList=new List<Receipt__c>();
        List<Charge__c> chargeList=new List<Charge__c>();
        Set<String> invoiceIdsForOracleCallout=new Set<String>();
        Set<String> receiptIdsForOracleCallout=new Set<String>();
        Financial_Setup__c financialSetup=[SELECT Id, Customer_Type__c, Fee_Type__c, Nationality__c, PropertyClassification__c, Type__c, Active__c, Days_In_a_Year__c, Default_Amount__c, End_Date__c, GraceDays__c, Lower_Cap__c, Penality_Charge__c, Phase__c, ReservationThresholdAmount__c, SR_RecordType__c, Sub_Type__c, Upper_Cap__c, VAT_Percnetage__c, Value__c, Tax_Code__c, VATAmount__c from Financial_Setup__c where Type__c ='Late Payment Charges'];
        System.debug('*** financialSetup ***'+financialSetup);
        for (Business_Process_Step__c step : input.steps) {
            switch on step.Name {
                when 'Collections Execute Waiver' {
                    if (step.Status__c == 'Completed') {
                        Charge__c charge= new Charge__c();
                        charge.Name = financialSetup.Type__c;
                        charge.Amount__c = step.Business_Process__r.LPC_Amount__c;
                      //  charge.recordTypeId = '012VH00000AqGZB';
                        charge.PaymentStatus__c = Constants.INSTALLMENT_PAYMENT_STATUS_NOT_PAID;
                        charge.VAT_Amount__c = (financialSetup.VAT_Percnetage__c != null && financialSetup.VAT_Percnetage__c >0) ? (1000 * financialSetup.VAT_Percnetage__c)/100 : 0;          
                        charge.Sales_Order__c = step.Business_Process__r.Sales_Order__c;
                        charge.Tax_Code__c =financialSetup.Tax_Code__c;
                        charge.VAT_Percentage__c=financialSetup.VAT_Percnetage__c;
                        charge.Type__c=financialSetup.Type__c;
                        charge.Business_Process__c = step.Business_Process__c;

                        Id lpcChargeRecordTypeId = getLpcChargeRecordTypeId();
                        if (lpcChargeRecordTypeId != null) {
                            charge.RecordTypeId = lpcChargeRecordTypeId;
                        }
                        insert charge;
                                          
                         Invoice__c invObj = new Invoice__c();
                         invObj.Sales_Order__c= charge.Sales_Order__c ;
                         Decimal vatAmount = (charge.VAT_Amount__c != null) ? charge.VAT_Amount__c :0;
                         invObj.InvoiceAmount__c = charge.Amount__c +vatAmount ;
                         invObj.InvoiceDate__c = system.today();
                         invObj.Account__c = step.Business_Process__r.Sales_Order__r.CustomerAccount__c;
                         invObj.Charge__c = charge.Id;
                         invObj.Is_ADM_Fees_and_Dari_charges__c = false;
                         invObj.System_Sync__c = true;
                         invObj.Business_Process__c = step.Business_Process__c;
                         insert invObj;

                          if(step.Business_Process__r.LPCWaivedAmount__c>0){
                          Receipt__c crNote = new Receipt__c();
                              crNote.Modeofpayment__c = 'Credit Note';
                              crNote.SalesOrder__c = step.Business_Process__r.Sales_Order__c;
                              crNote.Account__c = step.Business_Process__r.Sales_Order__r.CustomerAccount__c;
                              crNote.TotalAmount__c = step.Business_Process__r.LPCWaivedAmount__c;
                              crNote.Receipt_Amount__c = step.Business_Process__r.LPCWaivedAmount__c;
                              crNote.Is_ADM_Fees_and_Dari_charges__c = false;
                              crNote.Status__c = 'Cleared';
                              crNote.EBS_Clearing_Date__c = System.today();
                              crNote.System_Sync__c = true;
                              crNote.Business_Process__c = step.Business_Process__c;
                          insert crNote;

                         Allocation__c alloc = new Allocation__c();
                            alloc.Receipt__c = crNote.Id;
                            alloc.Invoice__c = invObj.ID;
                            alloc.AllocationAmount__c = crNote.Receipt_Amount__c;
                            alloc.ApprovedReceiptAmount__c = crNote.Receipt_Amount__c;
                            alloc.Allocation_Type__c = 'Credit Note';
                            alloc.Business_Process__c = step.Business_Process__c;
                            Database.insert(alloc, true, AccessLevel.SYSTEM_MODE);
                        }                
                    }
                }   
            }
        }
    }
}