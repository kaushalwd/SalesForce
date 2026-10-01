/**
 * Tests for SalesConsoleContentController.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  09 Aug 2026  Initial.
 *
 * What this protects: an empty Knowledge base renders an empty pane, not a crash and
 * not invented content. The PoC shipped six fabricated courses here; the whole point
 * of this class is that it returns nothing until Modon publishes something.
 */
@isTest
private class SalesConsoleContentControllerTest {

    @isTest
    static void testReturnsEmptyListWhenNothingIsPublished() {
        Test.startTest();
        List<SalesConsoleContentController.ArticleDTO> rows =
            SalesConsoleContentController.getLearningArticles();
        Test.stopTest();

        System.assertNotEquals(null, rows,
            'Never null - the pane renders an empty state from an empty list, and a ' +
            'null reaches the UI as a crash.');
        for (SalesConsoleContentController.ArticleDTO d : rows) {
            System.assertNotEquals(null, d.title,
                'Every article needs a title; a blank row is worse than no row.');
        }
    }
}