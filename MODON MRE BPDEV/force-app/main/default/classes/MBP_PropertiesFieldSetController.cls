/********************************************************************************
 * @Name          : MBP_UnitDetailPageController
 * @Description   : Class for fetching Unit__c Info
 * @Usage         : Called form mbp_UnitDetailPageLWC
 * @Author        : AMGS
 * ------------------------------------------------------------------------------
 * @Version       : 1.0
 * @Author        : Fatima Khan
 * @Date          : 09-10-2025
 ********************************************************************************/

public without sharing class MBP_PropertiesFieldSetController {

    public class ColumnDef {
        @AuraEnabled public String label;
        @AuraEnabled public String fieldName;
        public ColumnDef(String l, String f) { label = l; fieldName = f; }
    }

    @AuraEnabled(cacheable=true)
    public static List<ColumnDef> getFieldSetColumns(String objectName, String fieldSetName) {
        if (String.isBlank(objectName) || String.isBlank(fieldSetName)) {
            throw new AuraHandledException('Both objectName and fieldSetName are required.');
        }

        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectName);
        if (sType == null) throw new AuraHandledException('Unknown object: ' + objectName);

        Schema.DescribeSObjectResult d = sType.getDescribe();
        Map<String, Schema.FieldSet> fsMap = d.fieldSets.getMap();
        if (fsMap == null || !fsMap.containsKey(fieldSetName)) {
            throw new AuraHandledException(
                'Field Set "' + fieldSetName + '" not found on ' + objectName +
                '. Available: ' + String.join(new List<String>(fsMap != null ? fsMap.keySet() : new Set<String>()), ', ')
            );
        }

        Map<String, Schema.SObjectField> fieldsMap = d.fields.getMap();
        List<ColumnDef> cols = new List<ColumnDef>();

        for (Schema.FieldSetMember m : fsMap.get(fieldSetName).getFields()) {
            String rawPath = m.getFieldPath();          
            String label   = m.getLabel();

            String displayPath = rawPath;

            Schema.DescribeFieldResult fDesc = fieldsMap.containsKey(rawPath)
                ? fieldsMap.get(rawPath).getDescribe()
                : null;

            if (fDesc != null && fDesc.getType() == Schema.DisplayType.Reference) {
                String rel = fDesc.getRelationshipName();
                if (!String.isBlank(rel)) {
                    displayPath = rel + '.Name';
                }
            }

            cols.add(new ColumnDef(label, displayPath));
        }
        return cols;
    }
}