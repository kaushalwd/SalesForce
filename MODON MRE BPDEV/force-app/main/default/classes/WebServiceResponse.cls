global with sharing virtual class WebServiceResponse {
	
	public static Integer STATUS_CODE_SUCCESS = 200;
	public static Integer STATUS_CODE_UNAUTHORIZED = 403;
	public static Integer STATUS_CODE_SYSTEM_ERROR = 500;
	
	public Integer statusCode {get;set;}
	public String message {get;set;}
	public String requestId {get;set;}
	public Boolean success {get;set;}
	public Object data {get;set;}
	
	global WebServiceResponse() {
		
		this.statusCode = STATUS_CODE_SUCCESS;
		this.message = 'Success';
		this.success = true;
	}
	
	global String serialize () {
		
		return JSON.serialize(this);
	}
}