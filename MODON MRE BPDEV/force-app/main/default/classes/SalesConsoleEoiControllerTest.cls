/**
 * Tests for SalesConsoleEoiController.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  09 Aug 2026  Initial.
 *
 * What these protect: the pane and the hub's EOI card count the same thing. The PoC
 * fabricated that number, so a drift between the two here would look exactly like the
 * behaviour this port set out to fix.
 */
@isTest
private class SalesConsoleEoiControllerTest {

    @isTest
    static void testListAndCountAgreeOnWhatIsLive() {
        Test.startTest();
        List<SalesConsoleEoiController.EoiDTO> rows =
            SalesConsoleEoiController.getMyEois();
        Integer live = SalesConsoleEoiController.getActiveEoiCount();
        Test.stopTest();

        Integer liveInList = 0;
        Set<String> closed = new Set<String>{
            'Cancelled', 'Voided', 'Expired', 'Rejected'
        };
        for (SalesConsoleEoiController.EoiDTO d : rows) {
            if (!closed.contains(d.status)) {
                liveInList++;
            }
        }
        System.assertEquals(liveInList, live,
            'The card and the pane must count the same records. The PoC interpolated ' +
            'this number because it had no EOI object; a mismatch here would read as ' +
            'the same defect.');
    }

    @isTest
    static void testListNeverReturnsNull() {
        Test.startTest();
        List<SalesConsoleEoiController.EoiDTO> rows =
            SalesConsoleEoiController.getMyEois();
        Test.stopTest();

        System.assertNotEquals(null, rows,
            'An empty pane renders an empty state; a null reaches the UI as a crash.');
    }
}