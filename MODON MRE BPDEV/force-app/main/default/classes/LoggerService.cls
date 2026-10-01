public without sharing class LoggerService {
    private static final String LOG_TYPE_APEX_EXCEPTION = 'Apex Exception';
	

    public static void save(Logger__c loggerRecord){
        if(loggerRecord !=null){
           upsert loggerRecord ;        
        }
    }
    

    public static void save(List<Logger__c> loggerRecord){
        if(loggerRecord !=null){
           upsert loggerRecord ;        
        }
    }
    
    public static Logger__c createApexLog(Exception exc, string processName, string className, string methodName) {       
        Logger__c newLog = new Logger__c();
            Integer lineNumber = exc.getLineNumber();
            newLog.LineNumber__c = lineNumber;
            newLog.Message__c = exc.getMessage(); 
            newLog.ExceptionMessage__c = exc.getMessage();
            newLog.StackTrace__c = exc.getStackTraceString();
            newLog.ExecutingProcessName__c = processName;
            newLog.ClassName__c = className;
            newLog.MethodName__c = methodName;
            newLog.LogType__c = LOG_TYPE_APEX_EXCEPTION;
        return newLog;
    }

    public static Logger__c createAPILog(string processName, string className, string methodName, string intReqBody, string intRespBody, string intStatusCode, string logType) {       
        Logger__c newLog = new Logger__c();
            
            newLog.ExecutingProcessName__c = processName;
            newLog.ClassName__c = className;
            newLog.MethodName__c = methodName;
            newLog.LogType__c = logType;
            newLog.Integration_Request_Body__c = intReqBody;
            newLog.Integration_Response_Body__c = intRespBody;
            newLog.Integration_Status_Code__c = intStatusCode;
        return newLog;
    }

    public static Logger__c createAPILogCP(string processName, string className, string methodName, string intReqBody, string intRespBody, string intStatusCode, string logType, String message) {       
        Logger__c newLog = new Logger__c();
            newLog.Message__c = message;
            newLog.ExecutingProcessName__c = processName;
            newLog.ClassName__c = className;
            newLog.MethodName__c = methodName;
            newLog.LogType__c = logType;
            newLog.Integration_Request_Body__c = intReqBody;
            newLog.Integration_Response_Body__c = intRespBody;
            newLog.Integration_Status_Code__c = intStatusCode;
        return newLog;
    }
    
    public static Logger__c createApexLogforGenesys(Exception exc, string processName, string className, string methodName, String UUID) {       
        Logger__c newLog = new Logger__c();
            Integer lineNumber = exc.getLineNumber();
            newLog.LineNumber__c = lineNumber;
            newLog.Message__c = exc.getMessage(); 
            newLog.ExceptionMessage__c = exc.getMessage();
            newLog.StackTrace__c = exc.getStackTraceString();
            newLog.ExecutingProcessName__c = processName;
            newLog.ClassName__c = className;
            newLog.MethodName__c = methodName;
            newLog.LogType__c = LOG_TYPE_APEX_EXCEPTION;
            newLog.UUID__c = UUID;
        return newLog;
    }
    
    public static Logger__c createAPILogforGenesys(string processName, string className, string methodName, string intReqBody, string intRespBody, string intStatusCode, string logType, String UUID) {       
        Logger__c newLog = new Logger__c();
            
            newLog.ExecutingProcessName__c = processName;
            newLog.ClassName__c = className;
            newLog.MethodName__c = methodName;
            newLog.LogType__c = logType;
            newLog.Integration_Request_Body__c = intReqBody;
            newLog.Integration_Response_Body__c = intRespBody;
            newLog.Integration_Status_Code__c = intStatusCode;
            newLog.UUID__c = UUID;
        return newLog;
    }
    
        public static Logger__c createSendGridLog(String className, string methodName, string salesOrderId, string primaryEmail, integer statusCode, string resBody) {       
        Logger__c newLog = new Logger__c();
            
           // newLog.Message__c = exc.getMessage(); 
			newLog.Integration_Request_Body__c =resBody;
            newLog.ExceptionMessage__c = resBody;
            newLog.MethodName__c = methodName;
            newLog.Integration_Status_Code__c =String.valueOf(statusCode);
            newLog.LogType__c = LOG_TYPE_APEX_EXCEPTION;
            newLog.UUID__c = salesOrderId;
        return newLog;
    }

   
    
    public static Logger__c addMobileLog(RestRequest restRequest, Exception exc, String responseMessage, Integer statusCode) {
        
     
        
        Logger__c newLog = new Logger__c();
        newLog = updateMobileLog(newLog, restRequest, exc, responseMessage, statusCode);
      
        return newLog;
    }

    public static Logger__c updateMobileLog(Logger__c logger, RestRequest restRequest, Exception exc, String responseMessage, Integer statusCode) {
        logger.LogType__c = 'Mobile Exception';
            
        Map<String, String> requestHeaders = restRequest.headers;        
        Map<String, String> headerToLogField = new Map<String, String>{
            'App-Version' => 'AppVersion__c',
            'Device-OS' => 'DeviceOS__c',
            'Device-OS-Version' => 'DeviceOSVersion__c',
            'Device-Model' => 'DeviceModel__c',
            'Build-Number' => 'BuildNumber__c'
        };
            
        for (String headerKey : headerToLogField.keySet()) {       
            if (requestHeaders.containsKey(headerKey)) {          
                String headerValue =  requestHeaders.get(headerKey);
                String logField = headerToLogField.get(headerKey);             
                logger.put(logField, headerValue);
            }
        }
        
        if (exc != null) {          
            logger.LineNumber__c = exc.getLineNumber();
            //logger.ExceptionTypeName__c = exc.getTypeName(); 
            logger.StackTrace__c = exc.getStackTraceString();
            logger.Message__c = exc.getMessage();
        }  
        system.debug('inside logger');
       // logger.ResourcePath__c = restRequest.resourcePath;
        //logger.StatusCode__c = statusCode;
        //logger.ResponseMessage__c = responseMessage;
       // logger.ExceptionLogId__c = (system.today().format() + '-' + logger.ResourcePath__c);

        return logger;      
    }
    
    public class FlowExceptionRequest {
        @InvocableVariable(label='Flow Name' description='Name of the flow' required=true)
        public String flowName;

        @InvocableVariable(label='Fault Error Message' description='Fault error message' required=true)
        public String faultErrorMessage;

        @InvocableVariable(label='Related Record ID' description='Record ID that triggered or was operated on by the flow' required=false)
        public String relatedRecordId;
    }

    @InvocableMethod(label='Log Flow Exception' description='Logs exception details from flow fault paths into Logger__c object')
    public static void LogFlowException(List<FlowExceptionRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }
        List<Logger__c> logList = new List<Logger__c>();
        for (FlowExceptionRequest req : requests) {
            Logger__c log = new Logger__c();
            String safeFlowName = req.flowName != null ? req.flowName.left(255) : null;
            log.ExecutingProcessName__c = safeFlowName;
            log.FlowName__c = safeFlowName;
            log.Message__c = req.faultErrorMessage;
            log.ExceptionMessage__c = req.faultErrorMessage;
            log.LogType__c = 'Flow Exception';
            log.Related_Record_ID__c = req.relatedRecordId;
            log.OwnerId = UserInfo.getUserId();
            logList.add(log);
        }
        save(logList);
    }
}