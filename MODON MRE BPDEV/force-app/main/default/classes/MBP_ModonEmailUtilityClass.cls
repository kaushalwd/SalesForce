/**********************************************************************************************
* Version       Author                              Date         Comment
* 1.0           Sanath.Manohar@activemindsit.com   19 June 2025 Initial Draft
* 1.1           Ashok.Kotagiri@activemindsit.com   08-03-2026   Second change
* 1.2           raghu.chilukuri@activemindsit.com  12-03-2026   Put the Images That are using Git into Static Resources and are Using Those Static Resources
* 1.3           (fix requested 27 August 2026)      Added an overridable header image. getHeader()
*                                                    and getFullEmailHtml() now accept an optional
*                                                    headerImageUrl -- when blank/null, the standard
*                                                    Modon banner (HEADER_IMAGE static resource) is
*                                                    used exactly as before. When a URL is passed
*                                                    (e.g. a tier-specific Aspire banner), that image
*                                                    REPLACES the standard banner in that single slot
*                                                    -- it does not add a second image / a second row.
*                                                    This fixes the double-header rendering seen when
*                                                    a caller was previously appending its own header
*                                                    row on top of the fixed Modon banner.
**********************************************************************************************/

public class MBP_ModonEmailUtilityClass {

    /* Update Version 1.2
    @description :
    * Replaced external/Git-based image URLs with Salesforce Static Resources.
    * Added BASE_RESOURCE_URL to dynamically construct resource paths.
    * Updated all email template images (header, logo, social icons) to use static resources.
    */

    
private static final String BASE_RESOURCE_URL = 'https://modonproperties.my.site.com/Brokers/sfsites/c/resource/';
    private static final String HEADER_IMAGE     = BASE_RESOURCE_URL + 'Modon_EmailHeader';
    private static final String WHITE_LOGO       = BASE_RESOURCE_URL + 'Modon_White_Logo';
    private static final String LINKEDIN_ICON    = BASE_RESOURCE_URL + 'Modon_LinkedIn';
    private static final String INSTAGRAM_ICON   = BASE_RESOURCE_URL + 'Modon_Instagram';
    private static final String TWITTER_ICON     = BASE_RESOURCE_URL + 'Modon_Twitter';
    private static final String FACEBOOK_ICON    = BASE_RESOURCE_URL + 'Modon_Facebook';
    private static final String YOUTUBE_ICON     = BASE_RESOURCE_URL + 'Modon_Youtube';

    /* Update Version 1.2
    @description :
    * Updated email structure to use header and footer built with Static Resource-based images.
    *
    * Version 1.3 -- kept as the default entry point. Behaves EXACTLY as before:
    * always uses the standard Modon banner (HEADER_IMAGE). Delegates to the new
    * overload below with a null override.
    */

    public static String getFullEmailHtml(String bodyContent) {
        return getFullEmailHtml(bodyContent, null);
    }

    /* Version 1.3 -- new overload. Pass a non-blank headerImageUrl to REPLACE the
    * standard Modon banner with a different image for this email (e.g. a
    * tier-specific Aspire banner for the UPGRADE/welcome email). Pass null or
    * blank to get the standard banner, same as calling getFullEmailHtml(bodyContent).
    */
    public static String getFullEmailHtml(String bodyContent, String headerImageUrl) {
        return getHeader(headerImageUrl) + bodyContent + getFixedBody() + getFooter();
    }

    /* Update Version 1.2
    @description :
    * Replaced header image source with Static Resource (Modon_EmailHeader).
    * Ensures dynamic URL generation using BASE_RESOURCE_URL.
    *
    * Version 1.3 -- kept as a zero-arg convenience method for any other caller;
    * delegates to the overload below with a null override (standard banner).
    */

    private static String getHeader() {
        return getHeader(null);
    }

    /* Version 1.3 -- headerImageUrl, when non-blank, REPLACES the single banner
    * image in this slot. It does not add a second image or a second table row --
    * the table structure is identical either way, only the src attribute changes.
    */
    private static String getHeader(String headerImageUrl) {
        String bannerUrl = String.isBlank(headerImageUrl) ? HEADER_IMAGE : headerImageUrl;

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
        '<table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="margin:0; padding:0; background:#f4f4f4;">' +
        '  <tr>' +
        '    <td align="center">' +
        '      <table width="600" cellpadding="0" cellspacing="0" role="presentation" style="max-width:600px; width:100%; background:#ffffff;">' +

        '        <tr>' +
        '          <td style="padding:0; line-height:0; font-size:0;">' +
        '            <img src="' + bannerUrl + '" alt="Modon Header" width="600" style="width:100%; max-width:600px; height:auto;">' +
        '          </td>' +
        '        </tr>' +

        '        <tr>' +
        '          <td style="padding:0;">';
    }

    /* Update Version 1.2
    @description :
    * Updated logo and social media icons to use Static Resources.
    * Ensures all footer images are loaded from Salesforce resources instead of external URLs.
    */

    private static String getFooter() {
        return
        '          </td>' +
        '        </tr>' +

        '        <tr>' +
        '          <td bgcolor="#000000" style="padding:10px 15px;">' +
        '            <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="max-width:600px; margin:0 auto; padding:8px 16px;">' +
        '              <tr>' +

        '                <td width="70%" valign="top" style="color:#ffffff; font-family:Arial, sans-serif; font-size:11px; line-height:16px;">' +
        '                  FOLLOW US ON SOCIAL MEDIA' +
        '                  <table cellpadding="0" cellspacing="0" role="presentation" style="margin-top:4px;">' +
        '                    <tr>' +
                             socialIcon('https://www.linkedin.com/company/modon/', LINKEDIN_ICON) +
                             socialIcon('https://www.instagram.com/modonproperties', INSTAGRAM_ICON) +
                             socialIcon('https://x.com/ModonProperties', TWITTER_ICON) +
                             socialIcon('https://www.facebook.com/modonproperties', FACEBOOK_ICON) +
                             socialIcon('https://www.youtube.com/@ModonRealEstate-n9p', YOUTUBE_ICON) +
        '                    </tr>' +
        '                  </table>' +
        '                </td>' +

        '                <td width="30%" align="right" valign="middle">' +
        '                  <a href="https://www.modon.com/" target="_blank">' +
        '                    <img src="' + WHITE_LOGO + '" width="100" height="18" style="border:0;">' +
        '                  </a>' +
        '                </td>' +

        '              </tr>' +
        '            </table>' +
        '          </td>' +
        '        </tr>' +

        '      </table>' +
        '    </td>' +
        '  </tr>' +
        '</table>' +
        '</body>' +
        '</html>';
    }

    /* Update Version 1.2
    @description :
    * Modified to accept Static Resource image paths for rendering social media icons.
    */

    private static String socialIcon(String link, String imagePath) {
        return
        '<td style="padding-right:6px;">' +
        '  <a href="' + link + '" target="_blank">' +
        '    <img src="' + imagePath + '" width="20" height="20" style="border:0;">' +
        '  </a>' +
        '</td>';
    }

    private static String getFixedBody() {
        return
        '<tr>' +
        '  <td style="padding:20px 30px 10px 30px; font-family:Arial, sans-serif; font-size:16px; line-height:20px; color:#000000;">' +
        '    <p style="margin:0;">Best Regards,</p>' +
        '    <p style="margin:4px 0 0 0; font-weight:bold;">Modon</p>' +
        '  </td>' +
        '</tr>';
    }
}