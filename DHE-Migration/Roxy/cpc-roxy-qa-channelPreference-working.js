<script runat="server">
  Platform.Load("core","1.1");
  Write("inside222")
  try {
</script>
%%[
SET @firstName = RequestParameter('firstName')
SET @lastName = RequestParameter('lastName')
SET @emailContact = RequestParameter('email')
SET @guestId = RequestParameter('guestId')
SET @subsKey = RequestParameter('subsKey')
SET @emailPref = RequestParameter('emailPref')
SET @whatsAppPref = RequestParameter('whatsAppPref')
Output(concat('emailPref---------: ',@emailPref))
Output(concat('whatsAppPref---------: ',@whatsAppPref))
Output(concat('GuestID ---------: ',@guestId))
Output(concat('SubsKey ---------: ',@subsKey))
Output(concat('fName ---------: ',@firstName))
Output(concat('lName ---------: ',@lastName))
Output(concat('email ---------: ',@emailContact))
/*if (@emailPref == 'true') then*/
set @value= UpdateSingleSalesforceObject(
   'Guest_Subscription__c', @guestId,
   "Email__c", @emailPref,
   "WhatsApp__c", @whatsAppPref
)
if empty(@subsKey) OR IsNull(@subsKey) then
   Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
ELSE
   Set @ampError = ''
ENDIF
Set @p = InsertData("PreferencesLog_Test","SubscriberKey",@subsKey,"EmailAddress",@emailContact,"Submission","Communication-Preference","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)

]%%
<script runat="server">
     var subscriberKey = Variable.GetValue('subsKey')
     var value = Variable.GetValue('value')
     //Write("value:------",value);
     //Write("subKey:------",subscriberKey);
     var subObj = Subscriber.Init(subscriberKey);
     var unsubscribeSatus = subObj.Unsubscribe();
   }
   catch (err) {
       Write("Error Message-------------------: " + Stringify(err.message) + Stringify(err.description));
   }
</script>