<script runat="server">
Platform.Load("core", "1");

var deSourceKey = "Temp_ResubscribeDE_QA"; 
var deTargetKey = "ResubscribeDE_QA"; 
var responseFieldName = "ScriptResponse"; 

try {
    var sourceDE = DataExtension.Init(deSourceKey);
    var targetDE = DataExtension.Init(deTargetKey);
    var data = sourceDE.Rows.Retrieve(); 

    if (data && data.length > 0) {
        for (var i = 0; i < data.length; i++) {
            var subKey = data[i].SubscriberKey; 
            var subObj = Subscriber.Init(subKey);
            
            var subLists = subObj.Lists.Retrieve(); 
            var updateLists = [];

            if (subLists) {
                for (var j = 0; j < subLists.length; j++) {
                    updateLists.push({
                        "ID": subLists[j].List.ID, // Fix 1: Nested ID
                        "Status": "Active",
                        "Action": "Update"        // Fix 3: Action required
                    });
                }
            }

            var subUpdateConfig = {
                "SubscriberKey": subKey,
                "Status": "Active", 
                "Lists": updateLists 
            };

            var result = subObj.Update(subUpdateConfig);

            // Fix 2: Computed property name fix
            var updateFields = {};
            updateFields[responseFieldName] = result;

            targetDE.Rows.Update(
                updateFields, 
                ["SubscriberKey"], 
                [subKey]
            );
        }
    }
} catch (err) {
    Write("General Script Error: " + Stringify(err));
}
</script>
