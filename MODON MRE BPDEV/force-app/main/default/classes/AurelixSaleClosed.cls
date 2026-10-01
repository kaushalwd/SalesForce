/**
 * AurelixSaleClosed - has MODON closed this Sales Order's sale?
 *
 * Version  Author       Date         Detail
 * 1.0      Aurelix Dev  29 Sep 2026  The closed-sale rule in one place, so Total Sales and the booking pop-up's chip
 *                                    agree. MODON's Sales_Order_Record_Triggered_Flow closes a sale (opportunity
 *                                    Closed Won, unit Sold) but leaves SalesOrder__c.Status__c at New.
 */
public inherited sharing class AurelixSaleClosed {

    /** The two statuses MODON leaves in place when its flow closes a sale. */
    public static final Set<String> STATUSES_LEFT_AT_CLOSE = new Set<String>{ 'New', 'In Progress' };

    /**
     * True when the order is New or In Progress, its unit is Sold, and this order sold it (opportunity won or
     * SalesTeamVoidCheck__c set). Closed Won alone is not enough: a basket's opportunity closes with its first order.
     * The caller's query must select Status__c, SalesTeamVoidCheck__c, Opportunity__r.IsWon and Unit__r.Status__c;
     * a unit the running user cannot read makes the sale read as not closed.
     */
    public static Boolean isClosed(SalesOrder__c o) {
        if (o == null || !STATUSES_LEFT_AT_CLOSE.contains(o.Status__c)) {
            return false;
        }
        Boolean unitSold = o.Unit__r != null && 'Sold'.equalsIgnoreCase(o.Unit__r.Status__c);
        Boolean soldHere = (o.Opportunity__r != null && o.Opportunity__r.IsWon == true)
            || o.SalesTeamVoidCheck__c == true;
        return unitSold && soldHere;
    }
}