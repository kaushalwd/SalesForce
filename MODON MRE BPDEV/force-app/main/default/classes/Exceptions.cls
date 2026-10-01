public class Exceptions {
 
    public class WebServiceException extends Exception {
        public Integer statusCode {get;set;}
    }

}