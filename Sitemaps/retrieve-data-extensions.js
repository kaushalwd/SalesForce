<script runat="server">
  
  Platform.Load("core", "1");
  
  /*
  var prox = new Script.Util.WSProxy();
  var cols = ["Name"];
  var data = prox.retrieve("DataExtension", cols, {
             Property: "CustomerKey",
             SimpleOperator: "isNotNull",
             Value: ""
            });
  Write("Data ==> "+Stringify(data));
  */
 
  var LogDE = DataExtension.Init("Audit Data DE");
  
  try{
    results = DataExtension.Retrieve({
      Property: "CustomerKey",
      SimpleOperator: "isNotNull",
      Value: ""
    });
    
    var x = 0;
    while (x < results.length) {
      LogDE.Rows.Add({
        Name: results[x].Name,
        Description: results[x].Description,
        IsSendable: results[x].IsSendable,
        IsTestable: results[x].IsTestable,
        CategoryID: results[x].CategoryID,
        IsPlatformObject: results[x].IsPlatformObject,
        CustomerKey: results[x].CustomerKey,
        CreatedDate: results[x].CreatedDate,
        ModifiedDate: results[x].ModifiedDate,
        ObjectID: results[x].ObjectID,
        Client: results[x].Client.ID,
        Status: results[x].Status,
        PartnerKey: results[x].PartnerKey,
        SendableDataExtensionField: results[x].SendableDataExtensionField.Name,
        SendableSubscriberField: results[x].SendableSubscriberField.Name,
        Template: results[x].Template.CustomerKey

      });
      Write(Stringify(results[x]));
      x++
    }
    
  }catch(e){

  }
</script>

