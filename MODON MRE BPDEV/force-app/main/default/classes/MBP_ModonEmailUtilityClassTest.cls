@IsTest
public class MBP_ModonEmailUtilityClassTest {

    @IsTest
    static void test_getFullEmailHtml_basic() {
        String body = '<tr><td><p>Hello</p></td></tr>';
        String html = MBP_ModonEmailUtilityClass.getFullEmailHtml(body);
    }

    @IsTest
    static void test_getFullEmailHtml_emptyBody() {
        String html = MBP_ModonEmailUtilityClass.getFullEmailHtml('');
    }

    @IsTest
    static void test_getFullEmailHtml_nullBody() {
        String html = MBP_ModonEmailUtilityClass.getFullEmailHtml(null);
    }

    @IsTest
    static void test_getFullEmailHtml_largeBody() {
        String body = '';
        for (Integer i = 0; i < 50; i++) {
            body += '<tr><td>Line ' + i + '</td></tr>';
        }
        String html = MBP_ModonEmailUtilityClass.getFullEmailHtml(body);
    }
}