<script runat="server">
  
  Platform.Load("core", "1");
 
  var LogDE = DataExtension.Init("Audit Data SendDefinitions");
  
  try{
    var prox = new Script.Util.WSProxy(),
        objectType = "EmailSendDefinition",
        cols = ["Client.ID","CreatedDate","ObjectID","CustomerKey","Name","Description","Email.ID","SendDefinitionList"],
        moreData = true,
        reqID = null,
        numItems = 0;

    while(moreData) {
      moreData = false;
      var data = reqID == null ?
          prox.retrieve(objectType, cols) :
      prox.getNextBatch(objectType, reqID);

      if(data != null) {
        moreData = data.HasMoreRows;
        reqID = data.RequestID;
        if(data && data.Results) {
          for(var i=0; i< data.Results.length; i++) {
              
            for(var x=0; x< data.Results[i].SendDefinitionList.length; x++) {
              LogDE.Rows.Add({
                ID:data.Results[i].ID,
                Client:data.Results[i].Client.ID,
                ObjectID:data.Results[i].ObjectID,
                CustomerKey:data.Results[i].CustomerKey,
                CreatedDate:data.Results[i].CreatedDate,
                Name:data.Results[i].Name,
                Description:data.Results[i].Description,
                EmailID:data.Results[i].Email.ID,
                SendDefinitionCustomObjectID:data.Results[i].SendDefinitionList[x].CustomObjectID,
                SendDefinitionObjectID:data.Results[i].SendDefinitionList[x].ObjectID
              });
              //Write(Stringify(data.Results[i]SendDefinitionList[x]));
              
            }
            numItems++;
          }
        }
      }
    }
    Write("<br />" + numItems + " total " + objectType);
    
  }catch(e){
   //Write(Stringify(e));
  }
</script>