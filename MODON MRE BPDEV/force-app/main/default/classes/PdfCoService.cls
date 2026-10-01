/**
 * ------------------------------------------------------------------------------
 * Class Name  : PdfCoService
 * Author      : Arvind
 * Created     : Jul 05, 2026
 * Description : Calls pdf.co REST API to add Modon logo + branding to PDF
 *
 * Setup Required:
 *  1. Sign up free at pdf.co --> get API key
 *  2. Setup --> Named Credentials --> New:
 *       Label : PdfCo
 *       Name  : PdfCo
 *       URL   : https://api.pdf.co
 *       Auth  : No Authentication (API key sent in header)
 *  3. Setup --> Custom Labels --> New:
 *       Name  : PdfCoAPIKey
 *       Value : your-api-key-from-pdf.co
 *  4. Setup --> Static Resources --> New:
 *       Name  : ModonLogoMAX
 *       File  : Upload Modon logo PNG
 *  5. Setup --> Remote Site Settings --> Add: https://api.pdf.co
 *
 * pdf.co Free Tier: 100 API calls/month
 * ------------------------------------------------------------------------------
 */
public without sharing class PdfCoService {

}