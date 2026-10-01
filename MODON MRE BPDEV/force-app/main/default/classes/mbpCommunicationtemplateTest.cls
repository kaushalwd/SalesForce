@IsTest
public class mbpCommunicationtemplateTest {

    @IsTest
    static void testGetFullEmailHtml_AllPartsPresent() {
        String body = '<p>Hello</p>';

        Test.startTest();
        String html = mbpCommunicationtemplate.getFullEmailHtml(body);
        Test.stopTest();

        System.assertNotEquals(null, html);
        System.assert(html.length() > body.length());

        System.assert(html.startsWith('<!DOCTYPE html><html><head>'), 'Header start missing');
        System.assert(html.contains('<meta charset="UTF-8">'), 'Meta charset missing');
        System.assert(html.contains('Modon Header'), 'Header image alt missing');
        System.assert(html.contains('Modon_ADNOC_Koysk_EDM%20Header%20-%20Footer_SH_V01(High)-01.jpg?raw=true'), 'Header image url missing');

        System.assert(html.contains(body), 'Body content not included');

        System.assert(html.contains('Best Regards,'), 'Fixed body missing');
        System.assert(html.contains('<p style="margin:4px 0 0 0; font-weight:bold;">Modon</p>'), 'Fixed body signature missing');

        System.assert(html.contains('FOLLOW US ON SOCIAL MEDIA'), 'Footer text missing');
        System.assert(html.contains('https://www.modon.com/'), 'Footer Modon link missing');
        System.assert(html.contains('MODON%20LOGO_White%201.png?raw=true'), 'Footer logo missing');

        System.assert(html.contains('https://www.linkedin.com/company/modon/'), 'LinkedIn link missing');
        System.assert(html.contains('/linkedin.png?raw=true'), 'LinkedIn icon image missing');

        System.assert(html.contains('https://www.instagram.com/modonproperties'), 'Instagram link missing');
        System.assert(html.contains('/insta.png?raw=true'), 'Instagram icon image missing');

        System.assert(html.contains('https://x.com/ModonProperties'), 'X link missing');
        System.assert(html.contains('/twitter.png?raw=true'), 'X icon image missing');

        System.assert(html.contains('https://www.facebook.com/modonproperties'), 'Facebook link missing');
        System.assert(html.contains('/fb_icon.png?raw=true'), 'Facebook icon image missing');

        System.assert(html.contains('https://www.youtube.com/@ModonRealEstate-n9p'), 'YouTube link missing');
        System.assert(html.contains('/youtube.png?raw=true'), 'YouTube icon image missing');

        System.assert(html.endsWith('</body></html>'), 'Footer end missing');

        Integer idxBody = html.indexOf(body);
        Integer idxFixed = html.indexOf('Best Regards,');
        Integer idxFooter = html.indexOf('FOLLOW US ON SOCIAL MEDIA');

        System.assert(idxBody > 0, 'Body should appear after header');
        System.assert(idxFixed > idxBody, 'Fixed body should appear after provided body');
        System.assert(idxFooter > idxFixed, 'Footer should appear after fixed body');
    }

    @IsTest
    static void testGetFullEmailHtml_EmptyBodyStillBuildsHtml() {
        String body = '';

        Test.startTest();
        String html = mbpCommunicationtemplate.getFullEmailHtml(body);
        Test.stopTest();

        System.assertNotEquals(null, html);
        System.assert(html.contains('Best Regards,'), 'Fixed body should still be present');
        System.assert(html.contains('FOLLOW US ON SOCIAL MEDIA'), 'Footer should still be present');
        System.assert(html.contains('Modon Header'), 'Header should still be present');
        System.assert(html.endsWith('</body></html>'), 'Should still close html tags');
    }

    @IsTest
    static void testGetFullEmailHtml_NullBodyStillBuildsHtml() {
        String body = null;

        Test.startTest();
        String html = mbpCommunicationtemplate.getFullEmailHtml(body);
        Test.stopTest();

        System.assertNotEquals(null, html);
        System.assert(html.contains('Best Regards,'), 'Fixed body should still be present');
        System.assert(html.contains('FOLLOW US ON SOCIAL MEDIA'), 'Footer should still be present');
        System.assert(html.contains('Modon Header'), 'Header should still be present');
        System.assert(html.endsWith('</body></html>'), 'Should still close html tags');
    }
}