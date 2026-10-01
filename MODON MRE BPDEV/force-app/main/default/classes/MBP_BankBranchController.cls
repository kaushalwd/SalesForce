/**********************************************************************************************************************
* Name               : MBP_BankBranchController
* Description        : Fetches Bank Name / Bank Branch Name reference data from the external Bank Branch API
*                       (same callout your anonymous Apex script used) and structures it for a DEPENDENT PICKLIST:
*                       a list of distinct Bank Names, plus a map of Bank Name -> its own list of Branch Names.
*                       Call getBankBranchData() ONCE from the LWC (e.g. via @wire); when the user picks a Bank,
*                       just read branchesByBank[selectedBank] locally — no extra callout needed per selection.
* Usage              : Any LWC with a Bank Name combobox + a dependent Branch Name combobox.
* Created By         : (upendra)
* --------------------------------------------------------------------------------------------------------------------
* Version     Author       Date            Comment
* 1.0        Upendra  07 sep 2026     Initial draft — built from the provided anonymous Apex callout script.
**********************************************************************************************************************/
public class MBP_BankBranchController {

    public class BankBranchException extends Exception {}

    public class BankBranchWrapper {
        @AuraEnabled public List<String> bankNames;
        @AuraEnabled public Map<String, List<String>> branchesByBank;
    }

    @AuraEnabled(cacheable=true)
    public static BankBranchWrapper getBankBranchData() {

        List<Map<String,String>> rows = fetchBankBranchRows();

        Map<String, Set<String>> branchSetByBank = new Map<String, Set<String>>();

        for (Map<String,String> row : rows) {
            String bankName   = row.get('BankName');
            String branchName = row.get('BankBranchName');

            if (String.isBlank(bankName)) continue;

            if (!branchSetByBank.containsKey(bankName)) {
                branchSetByBank.put(bankName, new Set<String>());
            }
            if (String.isNotBlank(branchName)) {
                branchSetByBank.get(bankName).add(branchName);
            }
        }

        BankBranchWrapper result = new BankBranchWrapper();
        result.bankNames = new List<String>(branchSetByBank.keySet());
        result.bankNames.sort();

        result.branchesByBank = new Map<String, List<String>>();
        for (String bankName : branchSetByBank.keySet()) {
            List<String> branchList = new List<String>(branchSetByBank.get(bankName));
            branchList.sort();
            result.branchesByBank.put(bankName, branchList);
        }

        return result;
    }

    // ---------------------------------------------------------------------
    // Alternative method — if the full dataset is ever too large to load
    // upfront, use this instead: one callout, but filtered server-side to
    // only the branches for the ONE bank the user picked. Not cacheable
    // per-bank in the same way as getBankBranchData(), since the parameter
    // changes each call, but each distinct bankName value the LWC asks for
    // still benefits from platform-level Lightning Data Service caching.
    // ---------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<String> getBranchesForBank(String bankName) {

        if (String.isBlank(bankName)) {
            return new List<String>();
        }

        Set<String> branches = new Set<String>();
        for (Map<String,String> row : fetchBankBranchRows()) {
            if (bankName.equalsIgnoreCase(row.get('BankName')) && String.isNotBlank(row.get('BankBranchName'))) {
                branches.add(row.get('BankBranchName'));
            }
        }

        List<String> result = new List<String>(branches);
        result.sort();
        return result;
    }

    // ---------------------------------------------------------------------
    // Shared callout + parse — same logic as the anonymous Apex script:
    // Custom Metadata credential lookup, Basic Auth GET, then tolerant JSON
    // parsing (root can be a bare list, or a map with the list nested inside
    // one of its values — handles both the same way the script did).
    // Returns a flat list of {'BankName' => ..., 'BankBranchName' => ...} rows.
    // ---------------------------------------------------------------------
    private static List<Map<String,String>> fetchBankBranchRows() {

        OIC_Credential__mdt cred = [
            SELECT Endpoint__c, Username__c, Password__c
            FROM OIC_Credential__mdt
            WHERE DeveloperName = 'MBP_BankBranchApi'
            LIMIT 1
        ];

        HttpRequest req = new HttpRequest();
        req.setEndpoint(cred.Endpoint__c);
        req.setMethod('GET');
        String auth = cred.Username__c + ':' + cred.Password__c;
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(auth)));
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('🏦 [BANK-BRANCH] STATUS CODE: ' + res.getStatusCode());

        if (res.getStatusCode() != 200) {
            System.debug('❌ [BANK-BRANCH] Callout failed: ' + res.getStatus() + ' - ' + res.getBody());
            throw new BankBranchException('Bank Branch API call failed: ' + res.getStatus());
        }

        Object parsed = JSON.deserializeUntyped(res.getBody());
        List<Object> bankList = new List<Object>();

        // Handle both cases: root is a list, OR root is a map with a nested list — same
        // tolerant handling as the original script.
        if (parsed instanceof List<Object>) {
            bankList = (List<Object>) parsed;
        } else if (parsed instanceof Map<String, Object>) {
            Map<String, Object> rootMap = (Map<String, Object>) parsed;
            for (Object val : rootMap.values()) {
                if (val instanceof List<Object>) {
                    bankList = (List<Object>) val;
                    break;
                }
            }
        }

        List<Map<String,String>> rows = new List<Map<String,String>>();
        for (Object o : bankList) {
            Map<String, Object> row = (Map<String, Object>) o;

            String bankName   = row.containsKey('BankName') ? String.valueOf(row.get('BankName')) : '';
            String branchName = row.containsKey('BankBranchName') ? String.valueOf(row.get('BankBranchName')) : '';

            rows.add(new Map<String,String>{
                'BankName'       => bankName,
                'BankBranchName' => branchName
            });
        }

        return rows;
    }
}