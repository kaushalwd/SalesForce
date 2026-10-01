/**
 * SalesConsoleContentController - the Learning pane.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  09 Aug 2026  Initial. Reads published Knowledge articles.
 */

/**
 * The PoC's Learning screen was six hardcoded courses with invented scores,
 * completion dates and certificates - its own comment called it "mock/read-only
 * (no persistence)". Porting that would have shown a named agent a training record
 * they never took, in a sandbox that mirrors production.
 *
 * So this reads the real source instead. Knowledge is enabled in this org and has no
 * published articles yet, which means the pane renders an honest empty state today
 * and fills itself the moment Modon publishes anything - no code change needed.
 */
public with sharing class SalesConsoleContentController {

    public class ArticleDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String title;
        @AuraEnabled public String summary;
        @AuraEnabled public String urlName;
        @AuraEnabled public String articleNumber;
        @AuraEnabled public Datetime lastPublished;
    }

    /**
     * Published, current-version articles in the running user's language, newest
     * first. Language matters: without it a rep sees every translation of the same
     * article as separate rows.
     */
    @AuraEnabled(cacheable=true)
    public static List<ArticleDTO> getLearningArticles() {
        List<ArticleDTO> out = new List<ArticleDTO>();
        String lang = UserInfo.getLanguage();
        try {
            for (Knowledge__kav a : [
                SELECT Id, Title, Summary, UrlName, ArticleNumber, LastPublishedDate
                FROM Knowledge__kav
                WHERE PublishStatus = 'Online'
                  AND IsLatestVersion = true
                  AND Language = :lang
                ORDER BY LastPublishedDate DESC NULLS LAST
                LIMIT 100
            ]) {
                ArticleDTO d = new ArticleDTO();
                d.id = a.Id;
                d.title = a.Title;
                d.summary = a.Summary;
                d.urlName = a.UrlName;
                d.articleNumber = a.ArticleNumber;
                d.lastPublished = a.LastPublishedDate;
                out.add(d);
            }
        } catch (Exception e) {
            // Knowledge can be disabled per-org and per-user. An empty pane is the
            // right outcome there; an exception would take the whole sheet down.
            return new List<ArticleDTO>();
        }
        return out;
    }
}