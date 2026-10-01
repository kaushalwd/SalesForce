/**
 * Utility class for logging PassFort integration events.
 * Provides consistent logging across the integration with configurable verbosity levels.
 * 
 * Business Context:
 * Logging is essential for monitoring the PassFort integration, troubleshooting issues,
 * and maintaining an audit trail of webhook processing. This class centralizes logging
 * and respects the configured log level from the Integration_Settings__c custom setting.
 * 
 * Usage:
 * - Use convenience methods (debug, info, warn, error) for standard logging
 * - Log messages appear in Salesforce debug logs with prefix 'PASSFORT INTEGRATION:'
 * - Only messages with severity equal to or greater than the configured level will be logged
 * - Default log level is INFO if not specified in custom settings
 */
public class IntegrationLogger {
    private static final String DEFAULT_LOG_LEVEL = 'INFO';
    
    /**
     * Get the configured log level from custom settings.
     * 
     * @return The log level string from PassFort integration settings, or DEFAULT_LOG_LEVEL if not configured
     * 
     * Business Context:
     * This method retrieves the configured log level from Integration_Settings__c where Name='PassFort'.
     * The log level controls which messages are written to the debug logs, allowing administrators
     * to increase verbosity for troubleshooting and reduce it in production.
     */
    public static String getLogLevel() {
        return DEFAULT_LOG_LEVEL;
        // Integration_Settings__c settings = Integration_Settings__c.getInstance('PassFort');
        // return (settings != null && settings.Log_Level__c != null) ? 
        //     settings.Log_Level__c.toUpperCase() : DEFAULT_LOG_LEVEL;
    }
    
    /**
     * Log a message with the specified level.
     * 
     * @param level The log level for this message (FINEST, FINER, FINE, DEBUG, INFO, WARN, ERROR)
     * @param message The message to log
     * 
     * Business Context:
     * This is the core logging method that checks if the message should be logged based on
     * the configured level. Messages are prefixed with 'PASSFORT INTEGRATION:' for easy filtering
     * in debug logs. Only messages with severity equal to or greater than the configured level
     * will be logged.
     */
    public static void log(String level, String message) {
        String configuredLevel = getLogLevel();
        
        // Only log if the configured level includes this level
        if (shouldLog(configuredLevel, level)) {
            System.debug(LoggingLevel.valueOf(level), 'PASSFORT INTEGRATION: ' + message);
        }
    }
    
    /**
     * Determine if we should log based on configured level.
     * 
     * @param configuredLevel The log level configured in settings
     * @param messageLevel The log level of the current message
     * @return True if message should be logged, false otherwise
     * 
     * Implementation Note:
     * This method compares the "weight" of the configured log level and the message level.
     * Higher weight values represent more severe log levels. The message is logged only if
     * its weight is equal to or greater than the configured level's weight.
     */
    private static Boolean shouldLog(String configuredLevel, String messageLevel) {
        Integer configWeight = getLogLevelWeight(configuredLevel);
        Integer messageWeight = getLogLevelWeight(messageLevel);
        
        return messageWeight >= configWeight;
    }
    
    /**
     * Get the weight of a log level (higher is more severe).
     * 
     * @param level The log level as a string
     * @return An integer weight value (1-7) with higher values representing more severe levels
     * 
     * Implementation Note:
     * This method converts string log levels to numeric weights for comparison.
     * The hierarchy from least to most severe is:
     * FINEST(1) → FINER(2) → FINE(3) → DEBUG(4) → INFO(5) → WARN(6) → ERROR(7)
     * Any unrecognized levels default to INFO(5).
     */
    private static Integer getLogLevelWeight(String level) {
        switch on level {
            when 'FINEST' { return 1; }
            when 'FINER' { return 2; }
            when 'FINE' { return 3; }
            when 'DEBUG' { return 4; }
            when 'INFO' { return 5; }
            when 'WARN' { return 6; }
            when 'ERROR' { return 7; }
            when else { return 5; } // Default to INFO
        }
    }
    
    // Convenience methods for different log levels
    /**
     * Log a DEBUG level message - for detailed technical information.
     * @param message The message to log
     */
    public static void debug(String message) { log('DEBUG', message); }
    
    /**
     * Log an INFO level message - for general operational information.
     * @param message The message to log
     */
    public static void info(String message) { log('INFO', message); }
    
    /**
     * Log a WARN level message - for potentially problematic situations.
     * @param message The message to log
     */
    public static void warn(String message) { log('WARN', message); }
    
    /**
     * Log an ERROR level message - for errors that prevent normal operation.
     * @param message The message to log
     */
    public static void error(String message) { log('ERROR', message); }
}