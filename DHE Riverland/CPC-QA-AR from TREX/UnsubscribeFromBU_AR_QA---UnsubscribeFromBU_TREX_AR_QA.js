<script runat="server">
  Platform.Load("core","1.1");
  Write("inside2222222")
  try {
</script>
%%[
SET @guestId = RequestParameter('guestId')
SET @subsKey = RequestParameter('subsKey')
 SET @now=Now()
SET @currentConsetDate = FormatDate(@now,"ISO")
UpdateSingleSalesforceObject(
   'Guest_Subscription__c', @guestId,
   "Status__c", 'Unsubscribed',
    "Offers_and_Promotions__c","False",
    "Upcoming_events_for_families__c","False",
    "New_shows__c","False",
    "New_Upgrades_add_ons__c","False",
    "Customer_Survey__c","False",
    "Consent_Collection_Asset__c","Dubai Parks and Resorts",
    "Consent_Collection_Sub_Asset__c","T-REX GLAMPING",
    "Consent_Latest_Source__c","CPC",
    "Subscription_Date__c",@currentConsetDate
)
SET @updateContactRecord = UpdateSingleSalesforceObject(
                                 "Contact", @subsKey,
                                 "Latest_Channel_Source__c", "CPC - T-Rex Glamping"
                                  )


SET @rowFound = LookupRows("ENT.TempPauseHandle_QA","SubscriberKey", @guestId)
SET @count = rowcount(@rowFound)
IF @count > 0 then
set @deleteCount = DeleteData("ENT.TempPauseHandle_QA","SubscriberKey", @guestId)
ENDIF
]%%
<script runat="server">
     var subscriberKey = Variable.GetValue('subsKey')
     var subObj = Subscriber.Init(subscriberKey);
     var unsubscribeSatus = subObj.Unsubscribe();
  var lst = List.Init("Mock_AllSubscribersList_TREX");
var filter = {
            Property: "SubscriberKey",
            SimpleOperator: "equals",
            Value: subscriberKey
        };

        var result = lst.Subscribers.Retrieve(filter);

        Write("<br> result:"+Stringify(result));
        Write("<br> length:"+result.length);
      if (result.length != 0){
        var resub = {
                                     "SubscriberKey": subscriberKey,
                                     "Lists": [{
                                    ID: 2320,
                                    Status: 'Unsubscribed'
                                }]
                                  };
                          Write("resub = "+Stringify(resub)+"<br>");
                            var subObj = Subscriber.Init(subscriberKey);
                            var updateStatus = subObj.Update(resub);
                           Write("updateStatus = "+Stringify(updateStatus)+"<br>");
      }
   }
   catch (err) {
       Write("Error Message: " + Stringify(err.message) + Stringify(err.description));
   }
</script>