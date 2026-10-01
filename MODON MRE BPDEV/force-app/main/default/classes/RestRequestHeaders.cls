public with sharing class RestRequestHeaders {
	
	public String buildNumber {get;set;}
	public String appVersion {get;set;}
	public String deviceOS {get;set;}
	public String deviceOSVersion {get;set;}
	public String deviceModel {get;set;}
	public String deviceBrand {get;set;}
	public String deviceId {get;set;}
	
	public RestRequestHeaders() {
		
		this.appVersion	= '';
		this.buildNumber = '';
		this.deviceOS = '';
		this.deviceOSVersion = '';
		this.deviceModel = '';
		this.deviceBrand = '';
		this.deviceId = '';
	}

	public RestRequestHeaders(RestRequest request) {

		if (request != null) {
			
			Map<String, String> requestHeaders = request.headers;
			this.initWithMap(requestHeaders);
		}
	}

	public RestRequestHeaders(Map<String, String> headers) {

		this.initWithMap(headers);
	}

	public void validateHeaders() {

		try {
			Decimal.valueOf(this.appVersion);
			Decimal.valueOf(this.buildNumber);
		}
		catch(Exception e) {
			Exceptions.WebServiceException wsExc = new Exceptions.WebServiceException();
			wsExc.setMessage('Invalid headers provided. Please update to a valid version.');
			wsExc.statusCode = 500;
			throw wsExc;
		}
	}

	public void initWithMap(Map<String, String> headers) {
		
		if (headers != null) {
			for (String headerKey : headers.keySet()) {       
			        
		        String value = headers.get(headerKey);
		        Switch on headerKey {
		        	when 'App-Version' {
		        		this.appVersion = value;
		        	}
		        	when 'Build-Number' {
		        		this.buildNumber = value;
		        	}
		        	when 'Device-OS' {
		        		this.deviceOS = value;
		        	}
		        	when 'Device-OS-Version' {
		        		this.deviceOSVersion = value;
		        	}
		        	when 'Device-Model' {
		        		this.deviceModel = value;
		        	}
					when 'Device-Id' {
		        		this.deviceId = value;
		        	}
					when 'Device-Brand' {
		        		this.deviceBrand = value;
		        	}
		        }
		    }
		}
	}	
}