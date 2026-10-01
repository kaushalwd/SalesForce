/**********************************************************************************************************************
* Name               : OutboundPayloadRenderer
* Description        : Renders metadata-backed outbound payload templates
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    15 May 2026     Render JSON payloads using field paths and runtime values
* 1.1           Prateek Bansal                    13 Sep 2026     Plain-text render mode, so the same tokens build SMS.
* 1.2           Prateek Bansal                    13 Sep 2026     Added the amount formatter: the figure with no AED in front.
**********************************************************************************************************************/
public without sharing class OutboundPayloadRenderer {
    private static final Pattern TOKEN_PATTERN = Pattern.compile('\\{\\{([^}]+)\\}\\}');

    /** Renders a JSON payload. Values are JSON-escaped. */
    public static String render(
        String payloadTemplate,
        SObject rootRecord,
        MessagingConfigService.OutboundConfig config,
        Map<String, Object> runtimeValues
    ) {
        return render(payloadTemplate, rootRecord, config, runtimeValues, true);
    }

    /**
     * Renders a template. Pass jsonEscape = false for plain text such as SMS, where the value must
     * appear exactly as it reads.
     */
    public static String render(
        String payloadTemplate,
        SObject rootRecord,
        MessagingConfigService.OutboundConfig config,
        Map<String, Object> runtimeValues,
        Boolean jsonEscape
    ) {
        if (String.isBlank(payloadTemplate)) return null;

        Matcher matcher = TOKEN_PATTERN.matcher(payloadTemplate);
        String rendered = payloadTemplate;
        while (matcher.find()) {
            String token = matcher.group(1).trim();
            Object value = resolveToken(token, rootRecord, config, runtimeValues);
            String replacement = jsonEscape == false ? plainValue(value) : escapeJsonValue(value);
            rendered = rendered.replace('{{' + matcher.group(1) + '}}', replacement);
        }
        return rendered;
    }

    /** A token that resolved to nothing leaves no gap; anything else prints as it reads. */
    private static String plainValue(Object value) {
        return value == null ? '' : String.valueOf(value);
    }

    private static Object resolveToken(
        String token,
        SObject rootRecord,
        MessagingConfigService.OutboundConfig config,
        Map<String, Object> runtimeValues
    ) {
        List<String> parts = token.split('\\|');
        String path = parts[0].trim();
        Object value;
        if (path.startsWith('config.')) {
            value = getConfigValue(config, path.substringAfter('config.'));
        } else if (path.startsWith('runtime.')) {
            value = runtimeValues == null ? null : runtimeValues.get(path.substringAfter('runtime.'));
        } else {
            value = getFieldPathValue(rootRecord, path);
        }

        for (Integer index = 1; index < parts.size(); index++) {
            value = applyFormatter(value, parts[index].trim());
        }
        return value;
    }

    private static Object getFieldPathValue(SObject record, String path) {
        if (record == null || String.isBlank(path)) return null;
        List<String> pathParts = path.split('\\.');
        SObject cursor = record;
        for (Integer index = 0; index < pathParts.size(); index++) {
            String part = pathParts[index];
            if (index == pathParts.size() - 1) {
                try {
                    return cursor.get(part);
                } catch (Exception ex) {
                    return null;
                }
            }
            try {
                cursor = cursor.getSObject(part);
            } catch (Exception ex) {
                return null;
            }
            if (cursor == null) return null;
        }
        return null;
    }

    private static Object getConfigValue(MessagingConfigService.OutboundConfig config, String fieldName) {
        if (config == null) return null;
        if (fieldName == 'Template_Name__c') return config.templateName;
        if (fieldName == 'Message_Type__c') return config.messageType;
        if (fieldName == 'Channel__c') return config.channel;
        return null;
    }

    private static Object applyFormatter(Object value, String formatter) {
        if (value == null || String.isBlank(formatter)) return value;
        if (formatter == 'currency') {
            Decimal amount = toDecimal(value);
            return 'AED ' + (amount == null ? '0' : amount.setScale(0).format());
        }
        // The same figure without the AED, for templates that carry the currency in their own wording.
        if (formatter == 'amount') {
            Decimal plainAmount = toDecimal(value);
            return plainAmount == null ? '0' : plainAmount.setScale(0).format();
        }
        if (formatter == 'phone') {
            return normalizePhone(String.valueOf(value));
        }
        if (formatter.startsWith('datetime:')) {
            return formatDatetime(value, formatter.substringAfter('datetime:'));
        }
        if (formatter.startsWith('date:')) {
            return formatDate(value, formatter.substringAfter('date:'));
        }
        return value;
    }

    private static String escapeJsonValue(Object value) {
        if (value == null) return '';
        String serialized = JSON.serialize(String.valueOf(value));
        return serialized.substring(1, serialized.length() - 1);
    }

    private static String normalizePhone(String rawPhone) {
        if (String.isBlank(rawPhone)) return null;
        String trimmed = rawPhone.trim();
        Boolean hasPlus = trimmed.startsWith('+');
        String digits = trimmed.replaceAll('[^0-9]', '');
        if (String.isBlank(digits)) return null;
        return hasPlus ? '+' + digits : digits;
    }

    private static String formatDatetime(Object value, String pattern) {
        if (!(value instanceof Datetime)) return value == null ? null : String.valueOf(value);
        return ((Datetime) value).format(String.isBlank(pattern) ? 'dd/MM/yyyy HH:mm' : pattern);
    }

    private static String formatDate(Object value, String pattern) {
        if (value instanceof Date) {
            return DateTime.newInstance((Date) value, Time.newInstance(0, 0, 0, 0)).format(pattern);
        }
        if (value instanceof Datetime) {
            return ((Datetime) value).format(pattern);
        }
        return value == null ? null : String.valueOf(value);
    }

    private static Decimal toDecimal(Object value) {
        if (value instanceof Decimal) return (Decimal) value;
        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception ex) {
            return null;
        }
    }
}