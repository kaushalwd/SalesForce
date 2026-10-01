public class BookingDateRemindEmailHelper {
    public static String buildMinimalFragmentHtml(List<SalesOrder__c> salesOrders) {
        if (salesOrders == null || salesOrders.isEmpty()) {
            return '<p>No records.</p>';
        }

        String baseUrl ='';
        List<String> parts = new List<String>();
        parts.add('<table style="width:100%;border-collapse:collapse;margin-top:12px;">');
        parts.add('<thead><tr>');
        parts.add('<th style="text-align:left;padding:8px;border:1px solid #e8e8e8;">Sale Order Number</th>');
        parts.add('<th style="text-align:left;padding:8px;border:1px solid #e8e8e8;">Unit Number</th>');
        parts.add('<th style="text-align:left;padding:8px;border:1px solid #e8e8e8;">SO SF Id</th>');
        parts.add('<th style="text-align:left;padding:8px;border:1px solid #e8e8e8;">Booking Date</th>');
        parts.add('<th style="text-align:left;padding:8px;border:1px solid #e8e8e8;">Unit Launch Date</th>');
        parts.add('</tr></thead><tbody>');

        for (SalesOrder__c so : salesOrders) {
            // safe encoding and null checks
            String soName = (so.Name == null) ? '&mdash;' : escapeHtml(so.Name);
            String soId   = (so.Id == null) ? '' : String.valueOf(so.Id);
            String booking = (so.Booking_Date__c == null) ? '&mdash;' : escapeHtml(formatDate(so.Booking_Date__c));
            String launch  = (so.Unit_Launch_Date__c == null) ? '&mdash;' : escapeHtml(formatDate(so.Unit_Launch_Date__c));
            String unitName = (so.Unit__c == null) ? '&mdash;' : so.Unit__r.Name;
            String link = baseUrl + '/' + soId;

            parts.add('<tr>');
            parts.add('<td style="padding:8px;border:1px solid #e8e8e8;">'+ soName + '</td>');
            parts.add('<td style="padding:8px;border:1px solid #e8e8e8;">' + unitName + '</td>');
            parts.add('<td style="padding:8px;border:1px solid #e8e8e8;">' + soId + '</td>');
            parts.add('<td style="padding:8px;border:1px solid #e8e8e8;">' + booking + '</td>');
            parts.add('<td style="padding:8px;border:1px solid #e8e8e8;">' + launch + '</td>');
            parts.add('</tr>');
        }

        parts.add('</tbody></table>');
        return String.join(parts, '');
    }

    /**
     * Build a plain-text fallback listing the Sales Orders.
     */
    public static String buildMinimalPlainText(List<SalesOrder__c> salesOrders) {
        if (salesOrders == null || salesOrders.isEmpty()) return 'No records.';

        String baseUrl = '';
        List<String> parts = new List<String>();

        for (SalesOrder__c so : salesOrders) {
            String soName = (so.Name == null) ? '' : so.Name;
            String soId = (so.Id == null) ? '' : String.valueOf(so.Id);
            String booking = (so.Booking_Date__c == null) ? '—' : formatDate(so.Booking_Date__c);
            String launch  = (so.Unit_Launch_Date__c == null) ? '—' : formatDate(so.Unit_Launch_Date__c);
            parts.add(soName + ' (' + soId + ') | Booking Date: ' + booking + ' | Unit Launch Date: ' + launch + ' | Link: ' + baseUrl + '/' + soId);
        }

        return String.join(parts, '\n');
    }

    /**
     * Format Date as yyyy-MM-dd (zero-padded).
     * Avoids using Date.format(pattern) which may not be available.
     */
    private static String formatDate(Date d) {
        if (d == null) return '';
        Integer y = d.year();
        Integer m = d.month();
        Integer day = d.day();

        String mStr = (m < 10) ? ('0' + String.valueOf(m)) : String.valueOf(m);
        String dayStr = (day < 10) ? ('0' + String.valueOf(day)) : String.valueOf(day);

        return String.valueOf(y) + '-' + mStr + '-' + dayStr;
    }

    /**
     * Escape basic HTML special characters to prevent broken markup.
     */
    private static String escapeHtml(String input) {
        if (input == null) return '';
        // order matters: replace & first so we don't double-encode other entities
        String out = input.replace('&', '&amp;');
        out = out.replace('<', '&lt;');
        out = out.replace('>', '&gt;');
        out = out.replace('"', '&quot;');
        out = out.replace('\'', '&#39;');
        return out;
    }
}