<script runat="server">
  
  Platform.Load("core", "1");
 
  try{
    //Sample of Str to be passed to do simple query on CB
var clientId = 'x12v2sizs05n1q6muw1u3fuo';
var clientSecret = 'b3y2GfVJWQnbzPNoGidGMvdP';
var subDomain = 'https://mcyl0bsfb6nnjg5v3n6gbh9v6gc0.auth.marketingcloudapis.com/';

var mid = 100016735

// var authToken = generateToken(clientId,clientSecret,subDomain,mid)
var authToken = generateAccessToken()
var LogDE = DataExtension.Init("Email Audit Data");

var url = 'https://mcyl0bsfb6nnjg5v3n6gbh9v6gc0.rest.marketingcloudapis.com/asset/v1/content/assets/query'


    var pagenumber = 1;
    var resultcount = 50;

    while (resultcount==50) {
      var body = {
        "page":
        {
          "page":pagenumber,
          "pageSize":50
        },
        "fields":
        [
          "enterpriseId",
          "memberId",
          "objectID",
          "thumbnail",
          "category",
          "data",
          "assetType","description","createdBy","createdDate","modifiedDate","modifiedBy","status"
        ],
        "query": {
          "leftOperand": {
            "property": "assetType.id",
            "simpleOperator": "lessThanOrEqual",
            "value": 209
          },
          "logicalOperator": "AND",
          "rightOperand": {
            "property": "assetType.id",
            "simpleOperator": "greaterThanOrEqual",
            "value": 207
          }
        }
      }
      var request = HTTP.Post(url, "application/json", Stringify(body), ["Authorization"], ["Bearer " + authToken]);
      var result = Platform.Function.ParseJSON(String(request.Response));
      resultcount = result.items.length;
      var x = 0;
      while (x < result.items.length) {
        // Write("id: "+result.items[x].id);
        // Write("customerKey: "+result.items[x].customerKey);
        // Write("objectID: "+result.items[x].objectID)
       LogDE.Rows.Add({
          id: result.items[x].id,
          customerKey: result.items[x].customerKey,
          objectID: result.items[x].objectID,
          assetType: result.items[x].assetType.displayName,
          name: result.items[x].name,
          description: result.items[x].description,
          createdDate: result.items[x].createdDate,
          createdByemail: result.items[x].createdBy.email,
          createdByname: result.items[x].createdBy.name,
          modifiedDate: result.items[x].modifiedDate,
          modifiedByemail: result.items[x].modifiedBy.email,
          modifiedByname: result.items[x].modifiedBy.name,
          Client: result.items[x].memberId,
          category: result.items[x].category.name
        });
        x++
      }
      Write(result.items.length+":");
      Write(pagenumber+" - ");
      pagenumber++;
    }    
    
function generateToken(clientId,clientSecret,subDomain,mid) {
  var authJSON = {
  "grant_type": "client_credentials",
  "client_id": clientId,
  "client_secret": clientSecret,
  "account_id": mid
  }

  var authUrl = 'https://mcyl0bsfb6nnjg5v3n6gbh9v6gc0.auth.marketingcloudapis.com/v2/token';
  var contentType = 'application/json';
  var authPayload = Platform.Function.Stringify(authJSON);

  var accessTokenResult = HTTP.Post(authUrl, contentType, authPayload);
  var response = accessTokenResult["Response"][0];

  var accessToken = Platform.Function.ParseJSON(response).access_token;

  return accessToken;
}
    
function generateAccessToken(){
  var packageData = {
   client_id: "a62tuggehvqgwx0j6to6gr3m",
   client_secret: "0XN1eG8KarRx86iMkkLS0nql",
   grant_type: "client_credentials"
 };
 var url = 'https://mcyl0bsfb6nnjg5v3n6gbh9v6gc0.auth.marketingcloudapis.com/v2/token';
 var contentType = 'application/json';
 var accessTokenRequest = HTTP.Post(url, contentType, Stringify(packageData));
 if (accessTokenRequest.StatusCode == 200) {
   var tokenResponse = Platform.Function.ParseJSON(accessTokenRequest.Response[0]);
   var accessToken = tokenResponse.access_token;
 };
  Write(accessToken) 
 return accessToken;
}

  }catch(e){
Write(Stringify(e));
  }
</script>
