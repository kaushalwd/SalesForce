/**********************************************************************************************************************
* Name               : DocuSignUtil                                                        
* Description        : Wrapper Class
* Usage              : SPA
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                      01 Oct 2025     Initial Draft       
******************************************************************************************************************/
public class DocuSignUtil {
    
    public class JWTModel {
        public String iss;   // DocuSign Integration Key (Client ID)
        public String sub;   // API User GUID
        public String aud;   // account-d.docusign.com or account.docusign.com
        public String scope; // eSignature impersonation scope
    }
    
    public static String generateJWT(JWTModel jwtModel, String pvtKey) {
        // Header
        JSONGenerator header = JSON.createGenerator(false);
        header.writeStartObject();
        header.writeStringField('alg', 'RS256');
        header.writeStringField('typ', 'JWT');
        header.writeEndObject();
        String encodedHeader = base64URLencode(Blob.valueOf(header.getAsString()));
        // Body
        Long now = (DateTime.now().getTime() / 1000);
        JSONGenerator body = JSON.createGenerator(false);
        body.writeStartObject();
        body.writeStringField('iss', jwtModel.iss);
        body.writeStringField('sub', jwtModel.sub);
        body.writeStringField('aud', jwtModel.aud);
        body.writeNumberField('iat', now);
        body.writeNumberField('exp', now + 3600); // 1 hour expiry
        body.writeStringField('scope', jwtModel.scope);
        body.writeEndObject();
        String encodedBody = base64URLencode(Blob.valueOf(body.getAsString()));
        // Sign
        String unsignedJWT = encodedHeader + '.' + encodedBody;
        Blob privateKey = EncodingUtil.base64Decode(pvtKey);
        Blob signature = Crypto.sign('RSA-SHA256', Blob.valueOf(unsignedJWT), privateKey);
        return unsignedJWT + '.' + base64URLencode(signature);
    }

    private static String base64URLencode(Blob input) {
        String output = EncodingUtil.base64Encode(input);
        output = output.replace('+','-').replace('/','_').replaceAll('=','');
        return output;
    }
    
    public class URLRequestModel {
        public String returnUrl                     {get;set;}
        public String authenticationMethod          {get;set;}
        public String email                         {get;set;}
        public String userName                      {get;set;}
        public String clientUserId                  {get;set;}
    }
    public class DocumentSignResponse {
           public String url;	     
      }
    public class DocumentEnvelopeResponse {
           public String envelopeId;	
           public String uri;
           public String statusDateTime;
           public String status;
      }
    public class DocumentEnvelope {
           public String salesorderId;
           public String docuSignURL;
           public String customerAccount;
           public String accountType;
           public String emailSubject;	//Please sign this document
           public DSEDocuments[] documents;
           public DSERecipients recipients;
           public String status;	//sent 
      }
    public class DSEDocuments {
                public String documentBase64;	//BASE64_ENCODED_PDF
                public String name;	//Agreement.pdf
                public String fileExtension;	//pdf
                public String documentId;	//1
    }
    public class DSERecipients {
                public DSESigners[] signers;
    }
    public class DSESigners {
                public String email;	//john@example.com
                public String name;	//John Doe
                public String embeddedRecipientStartURL;
        		public String recipientId;	//1
                public String routingOrder;	//1
                public String clientUserId;	//1234
                public signerTab tabs;
    }
    public class DSESignersGroup {
                public String signingGroupId;	//john@example.com
                public String signingGroupName;	//John Doe
                public String recipientId;	//1
                public String routingOrder;	//1
                public String clientUserId;	//1234
                public signerTab tabs;
    }
    public class signerTab{
        public List<signHereTabsClas> dateSignedTabs = new List<signHereTabsClas>();
        public List<signHereTabsClas> signHereTabs = new List<signHereTabsClas>();//
    }
    public class signHereTabsClas{
        public String anchorString;
        public String anchorUnits;
        public String anchorXOffset;
        public String anchorYOffset;
    }
}