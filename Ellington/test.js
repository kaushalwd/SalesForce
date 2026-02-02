/* ---------- Helper Function ---------- */
function updateList(listId, status) {

    var sub = {
        SubscriberKey: contactKey,
        Lists: [{
            ID: listId,
            Status: status
        }]
    };

    Subscriber.Update(sub);
}
/* Map preferences to List IDs */
var pubLists = [
    { flag: "true", listId: 1074 },
    { flag: "true", listId: 1076 },
    { flag: "true", listId: 1075 }
];

for (var i = 0; i < pubLists.length; i++) {

    if (pubLists[i].flag == "true") {
        updateList(pubLists[i].listId, "Active");
    }
    else if (pubLists[i].flag == "False") {
        updateList(pubLists[i].listId, "Unsubscribed");
    }
}

