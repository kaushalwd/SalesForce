/**
* @description       : Server-side Apex class for Email templates in Salesforce
* @author            : raghu.chilukuri@activemindsit.com.srdev
* @group             : Email templates class
* @last modified on  : 5-02-2025
* @last modified by  : ashok.kotagiri@activemindsit.com.srdev
                     : Updated the css according to the mails
*/

public class mbpCommunicationtemplate {

    public static String getFullEmailHtml(String bodyContent) {
        return getHeader() + bodyContent + getFixedBody()+ getFooter();
    }

    // =========================
    // HEADER + OUTER WRAPPER
    // =========================
    private static String getHeader() {
        return
        '<!DOCTYPE html>' +
        '<html>' +
        '<head>' +
        '  <meta charset="UTF-8">' +
        '  <meta name="viewport" content="width=device-width, initial-scale=1.0">' +
        '  <style>' +
        '    body { margin:0; padding:0; background:#f4f4f4; }' +
        '    table { border-collapse:collapse; }' +
        '    img { display:block; border:0; outline:none; text-decoration:none; }' +
        '  </style>' +
        '</head>' +

        '<body>' +

        '<table width="100%" cellpadding="0" cellspacing="0" role="presentation" ' +
        'style="margin:0; padding:0; background:#f4f4f4;">' +
        '  <tr>' +
        '    <td align="center">' +

        '      <table width="600" cellpadding="0" cellspacing="0" role="presentation" ' +
        'style="max-width:600px; width:100%; background:#ffffff;">' +

        // HEADER IMAGE
        '        <tr>' +
        '          <td style="padding:0; line-height:0; font-size:0;">' +
        '            <img src="https://github.com/Nibraz999/sendgridemo/blob/main/Modon_ADNOC_Koysk_EDM%20Header%20-%20Footer_SH_V01(High)-01.jpg?raw=true" ' +
        '                 alt="Modon Header" width="600" style="width:100%; max-width:600px; height:auto;">' +
        '          </td>' +
        '        </tr>' +

        // BODY CONTAINER START
        '        <tr>' +
        '          <td style="padding:0;">';
        
    }

    // =========================
    // FOOTER
    // =========================
    private static String getFooter() {
        return

        // CLOSE BODY TD/TR
        '          </td>' +
        '        </tr>' +
		
        // FOOTER SECTION
        '        <tr>' +
        '          <td bgcolor="#000000" style="padding:10px 15px;">' +

        '            <table width="100%" cellpadding="0" cellspacing="0" role="presentation" ' +
        'style="max-width:600px; margin:0 auto; padding:8px 16px;">' +

        '              <tr>' +

        // SOCIAL
        '                <td width="70%" valign="top" style="color:#ffffff; font-family:Arial, sans-serif; font-size:11px; line-height:16px;">' +
        '                  FOLLOW US ON SOCIAL MEDIA' +

        '                  <table cellpadding="0" cellspacing="0" role="presentation" style="margin-top:4px;">' +
        '                    <tr>' +
        socialIcon('https://www.linkedin.com/company/modon/', 'linkedin.png') +
        socialIcon('https://www.instagram.com/modonproperties', 'insta.png') +
        socialIcon('https://x.com/ModonProperties', 'twitter.png') +
        socialIcon('https://www.facebook.com/modonproperties', 'fb_icon.png') +
        socialIcon('https://www.youtube.com/@ModonRealEstate-n9p', 'youtube.png') +
        '                    </tr>' +
        '                  </table>' +
        '                </td>' +

        // LOGO
        '                <td width="30%" align="right" valign="middle">' +
        '                  <a href="https://www.modon.com/" target="_blank">' +
        '                    <img src="https://github.com/Nibraz999/sendgridemo/blob/main/MODON%20LOGO_White%201.png?raw=true" ' +
        '                         width="100" height="18" style="border:0;">' +
        '                  </a>' +
        '                </td>' +

        '              </tr>' +
        '            </table>' +
        '          </td>' +
        '        </tr>' +

        // CLOSE INNER + OUTER TABLES
        '      </table>' +
        '    </td>' +
        '  </tr>' +
        '</table>' +

        '</body>' +
        '</html>';
    }

    // =========================
    // HELPER FOR SOCIAL ICONS
    // =========================
    private static String socialIcon(String link, String imageName) {
        return
        '<td style="padding-right:6px;">' +
        '  <a href="' + link + '" target="_blank">' +
        '    <img src="https://github.com/Nibraz999/sendgridemo/blob/main/' + imageName + '?raw=true" ' +
        '         width="20" height="20" style="border:0;">' +
        '  </a>' +
        '</td>';
    }

    private static String getFixedBody() {
    return
    '<tr>' +
    '  <td style="padding:20px 30px 10px 30px; ' +
    '             font-family:Arial, sans-serif; ' +
    '             font-size:16px; ' +
    '             line-height:20px; ' +
    '             color:#000000;">' +

    '    <p style="margin:0;">Best Regards,</p>' +
    '    <p style="margin:4px 0 0 0; font-weight:bold;">Modon</p>' +

    '  </td>' +
    '</tr>';
}
}