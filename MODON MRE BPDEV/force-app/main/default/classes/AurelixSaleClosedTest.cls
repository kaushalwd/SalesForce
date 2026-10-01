/**
 * Tests for AurelixSaleClosed.
 *
 * Version  Author       Date         Detail
 * 1.1      Aurelix Dev  29 Sep 2026  SalesConsoleController 1.80 calls isClosed and has no copy of its own, so
 *                                    theRuleIsTheSameAsTheBookingPopUps is removed.
 * 1.0      Aurelix Dev  29 Sep 2026  The closed-sale rule case by case, compared with
 *                                    SalesConsoleController.saleClosed.
 */
@isTest
private class AurelixSaleClosedTest {

    /** The order the flow's Closed Won and Sold describe, built in memory (IsWon and the gate are read only). */
    private static SalesOrder__c shape(String status, String unitStatus, Boolean oppWon, Boolean gate) {
        Map<String, Object> so = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'SalesOrder__c' },
            'Status__c' => status,
            'SalesTeamVoidCheck__c' => gate,
            'Opportunity__r' => new Map<String, Object>{
                'attributes' => new Map<String, Object>{ 'type' => 'Opportunity' },
                'IsWon' => oppWon
            },
            'Unit__r' => new Map<String, Object>{
                'attributes' => new Map<String, Object>{ 'type' => 'Unit__c' },
                'Status__c' => unitStatus
            }
        };
        return (SalesOrder__c) JSON.deserialize(JSON.serialize(so), SalesOrder__c.class);
    }

    /** Every case the rule has to tell apart. */
    private static Map<String, SalesOrder__c> cases() {
        return new Map<String, SalesOrder__c>{
            'SO-15561: New, Closed Won, Sold' => shape('New', 'Sold', true, true),
            'In Progress, gate met, Sold' => shape('In Progress', 'Sold', false, true),
            'Basket sibling: Closed Won, unit Reserved' => shape('New', 'Reserved', true, false),
            'Sold by another order' => shape('New', 'Sold', false, false),
            'Voided' => shape('Voided', 'Sold', true, true),
            'Cancelled SR' => shape('Cancelled SR', 'Sold', true, true),
            'Completed' => shape('Completed', 'Sold', true, true),
            'Open booking' => shape('New', 'Available', false, false),
            'Unit status blank' => shape('New', null, true, true),
            'No status' => shape(null, 'Sold', true, true)
        };
    }

    @isTest
    static void aSaleModonClosedReadsAsClosedThoughStatusStaysNew() {
        Map<String, SalesOrder__c> c = cases();

        System.assertEquals(true, AurelixSaleClosed.isClosed(c.get('SO-15561: New, Closed Won, Sold')),
            'SO-15561: New, opportunity Closed Won, unit Sold. The sale has closed.');
        System.assertEquals(true, AurelixSaleClosed.isClosed(c.get('In Progress, gate met, Sold')),
            'The gate met and the unit Sold is the flow closing this order.');
        System.assertEquals(false, AurelixSaleClosed.isClosed(c.get('Basket sibling: Closed Won, unit Reserved')),
            'A basket opportunity closes with its first order; a sibling whose unit is still Reserved has not.');
        System.assertEquals(false, AurelixSaleClosed.isClosed(c.get('Sold by another order')),
            'A Sold unit with neither this order\'s gate nor its opportunity closed was sold by another order.');
        System.assertEquals(false, AurelixSaleClosed.isClosed(c.get('Voided')), 'A voided order keeps its label.');
        System.assertEquals(false, AurelixSaleClosed.isClosed(c.get('Cancelled SR')), 'So does a cancelled one.');
        System.assertEquals(false, AurelixSaleClosed.isClosed(c.get('Completed')),
            'Completed is MODON\'s own later word and keeps its label.');
        System.assertEquals(false, AurelixSaleClosed.isClosed(c.get('Open booking')), 'An open booking is not closed.');
        System.assertEquals(false, AurelixSaleClosed.isClosed(c.get('Unit status blank')),
            'No unit status, no Sold unit, nothing closed.');
        System.assertEquals(false, AurelixSaleClosed.isClosed(c.get('No status')), 'No status is not New.');
        System.assertEquals(false, AurelixSaleClosed.isClosed(null), 'No order, nothing closed.');
    }
}