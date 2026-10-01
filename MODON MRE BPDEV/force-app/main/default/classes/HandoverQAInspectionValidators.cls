public class HandoverQAInspectionValidators {
    private static final Set<String> ALLOWED_PRIORITY = new Set<String>{'High', 'Medium', 'Low'};
    private static final Set<String> ALLOWED_INTEGRATION_TYPES = new Set<String>{
        'QA Snagging',
        'Contractor Snags Rectification',
        'QA Desnagging',
        'Customer Snagging',
        'Customer Desnagging'
    };

    public static void validateSaveSnaggingSectionRequest(HandoverQAInspectionDtos.SaveSnaggingSectionRequest reqObj) {
        if (reqObj == null) {
            throw new AuraHandledException('Request body is empty or invalid');
        }
        if (reqObj.businessProcessId == null) {
            throw new AuraHandledException('businessProcessId is mandatory');
        }
        if (reqObj.salesOrderId == null) {
            throw new AuraHandledException('salesOrderId is mandatory');
        }
        if (reqObj.unitId == null) {
            throw new AuraHandledException('unitId is mandatory');
        }
    }

    public static void validateSaveDeSnaggingSectionRequest(HandoverQAInspectionDtos.SaveDeSnaggingSectionRequest reqObj) {
        if (reqObj == null) {
            throw new AuraHandledException('Request body is empty or invalid');
        }
        if (reqObj.businessProcessId == null) {
            throw new AuraHandledException('businessProcessId is mandatory');
        }
        if (reqObj.salesOrderId == null) {
            throw new AuraHandledException('salesOrderId is mandatory');
        }
        if (reqObj.unitId == null) {
            throw new AuraHandledException('unitId is mandatory');
        }
    }

    public static void validateCreateSnagRequest(HandoverQAInspectionDtos.CreateSnagRequest reqObj) {
        if (reqObj == null) {
            throw new AuraHandledException('Request body is empty or invalid');
        }
        if (reqObj.salesOrderId == null) {
            throw new AuraHandledException('salesOrderId is mandatory');
        }
        if (reqObj.unitId == null) {
            throw new AuraHandledException('unitId is mandatory');
        }
        if (String.isBlank(reqObj.snagName)) {
            throw new AuraHandledException('snagName is mandatory');
        }
        validatePriority(reqObj.priority);
        validateIntegrationType(reqObj.integrationType);
    }

    public static void validateUpdateSnagRequest(HandoverQAInspectionDtos.UpdateSnagRequest reqObj) {
        if (reqObj == null) {
            throw new AuraHandledException('Request body is empty or invalid');
        }
        if (reqObj.snaggingId == null) {
            throw new AuraHandledException('snaggingId is mandatory');
        }
    }

    public static void validatePriority(String priority) {
        if (String.isBlank(priority)) {
            throw new AuraHandledException('priority is mandatory');
        }
        if (!ALLOWED_PRIORITY.contains(priority)) {
            throw new AuraHandledException('Invalid priority. Allowed values: High, Medium, Low');
        }
    }

    public static void validateIntegrationType(String integrationType) {
        if (String.isBlank(integrationType)) {
            throw new AuraHandledException('integrationType is mandatory');
        }
        if (!ALLOWED_INTEGRATION_TYPES.contains(integrationType)) {
            throw new AuraHandledException(
                'Invalid integrationType. Allowed values: QA Snagging, Contractor Snags Rectification, QA Desnagging, Customer Snagging, Customer Desnagging'
            );
        }
    }
}