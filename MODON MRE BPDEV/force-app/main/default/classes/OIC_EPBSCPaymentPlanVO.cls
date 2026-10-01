/**********************************************************************************************************************
* Name               : OIC_EPBSCPaymentPlanVO
* Description        : Request payload wrapper for the EPBCS Payment Plan outbound integration.
* Usage              : Used by OIC_EPBCSPaymantPlanBatch to serialize SalesOrderInstallments__c payment plan data.
* --------------------------------------------------------------------------------------------------------------------
Version         Author              Date             Comment
 * 1.0          Karunakar Pulkam    15-08-2026       Initial Draft
***********************************************************************************************************************/
public class OIC_EPBSCPaymentPlanVO {

    public class PaymentPlanRecord {
        public String  bu_name;
        public String  project_name;
        public String  phase_name;
        public String  building_name;
        public String  building_id;
        public String  unit_name;
        public String  unit_id;
        public Decimal inst_num;
        public String  inst_id;
        public Decimal inst_net_amount;
        public Date    due_date;
        public Date    receipt_date;
        public String  status;
        public Decimal amount_due_original;
        public Decimal amount_paid;
        public Date    Due_date_extension;
        public String  so_id;
        public String  invoiceName;
    }

    public class PaymentPlanRecordWrapperList {
        public List<PaymentPlanRecord> RequestArray;
    }
}