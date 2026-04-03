var dateInput = document.getElementById("meetingDate");
var timeSlot = document.getElementById("time-slot");
var scheduleBtn = document.getElementById("scheduledMeeting");

function isWeekend(d) {
    var day = d.getDay(); // 0=Sun ... 6=Sat
    return day === 0 || day === 6;
}

// Get GST time
function getGSTNow() {
    var now = new Date();
    return new Date(now.toLocaleString("en-US", { timeZone: "Asia/Dubai" }));
}

// Disable button by default
function disableButton() {
    scheduleBtn.disabled = true;
    //scheduleBtn.classList.add("readonly");
}

// Enable button
function enableButton() {
    scheduleBtn.disabled = false;
    //scheduleBtn.classList.remove("readonly");
}

// Validate everything
function validateForm() {

    var selectedDateValue = dateInput.value;
    var selectedSlot = timeSlot.value;

    // Default disable
    disableButton();

    if (!selectedDateValue || selectedSlot === "Select") return;

    var gstNow = getGSTNow();

    var gstToday = new Date(gstNow);
    gstToday.setHours(0,0,0,0);

    var selectedDate = new Date(selectedDateValue + "T00:00:00");
    
    if (isWeekend(selectedDate)) return;

    // ❌ Past Date
    if (selectedDate < gstToday) return;

    // ✅ Future Date → valid
    if (selectedDate > gstToday) {
        enableButton();
        return;
    }

    // ✅ Same Day → check time
    var startTimeStr = selectedSlot.split(" to ")[0];

    var timeParts = startTimeStr.match(/(\d+):(\d+)\s(AM|PM)/);
    var hours = parseInt(timeParts[1]);
    var minutes = parseInt(timeParts[2]);
    var ampm = timeParts[3];

    if (ampm === "PM" && hours !== 12) hours += 12;
    if (ampm === "AM" && hours === 12) hours = 0;

    var selectedDateTime = new Date(gstNow);
    selectedDateTime.setHours(hours);
    selectedDateTime.setMinutes(minutes);
    selectedDateTime.setSeconds(0);

    if (selectedDateTime >= gstNow) {
        enableButton();
    }
}


// Date Change
dateInput.addEventListener("change", function () {

    var selectedDateValue = this.value;
    if (!selectedDateValue) return;

    var gstNow = getGSTNow();

    var gstToday = new Date(gstNow);
    gstToday.setHours(0,0,0,0);

    var selectedDate = new Date(selectedDateValue + "T00:00:00");

    if (isWeekend(selectedDate)) {
        // alert("Please do not select Saturday or Sunday.");
        epAlert("Please do not select Saturday or Sunday.");
        this.value = "";
        timeSlot.disabled = true;
        timeSlot.value = "Select";
        disableButton();
        return;
    }
    
    // ❌ Past date
    if (selectedDate < gstToday) {
        // alert("You cannot select a past date (GST).");
        epAlert("You cannot select a past date (GST).");
        this.value = "";
        timeSlot.disabled = true;
        //timeSlot.classList.add("readonly");
        timeSlot.value = "Select";

        disableButton();
        return;
    }

    // ✅ Enable time slot
    timeSlot.disabled = false;
    //timeSlot.classList.remove("readonly");

    validateForm();
});


// Time Change
timeSlot.addEventListener("change", function () {

    var selectedSlot = this.value;
    var selectedDateValue = dateInput.value;

    if (selectedSlot === "Select" || !selectedDateValue) {
        disableButton();
        return;
    }

    var gstNow = getGSTNow();

    var gstToday = new Date(gstNow);
    gstToday.setHours(0,0,0,0);

    var selectedDate = new Date(selectedDateValue + "T00:00:00");

    // Same day → validate time
    if (selectedDate.getTime() === gstToday.getTime()) {

        var startTimeStr = selectedSlot.split(" to ")[0];

        var timeParts = startTimeStr.match(/(\d+):(\d+)\s(AM|PM)/);
        var hours = parseInt(timeParts[1]);
        var minutes = parseInt(timeParts[2]);
        var ampm = timeParts[3];

        if (ampm === "PM" && hours !== 12) hours += 12;
        if (ampm === "AM" && hours === 12) hours = 0;

        var selectedDateTime = new Date(gstNow);
        selectedDateTime.setHours(hours);
        selectedDateTime.setMinutes(minutes);
        selectedDateTime.setSeconds(0);

        if (selectedDateTime < gstNow) {
            // alert("Please select a future time slot (GST).");
            epAlert("Please select a future time slot (GST).");
            this.value = "Select";
            disableButton();
            return;
        }
    }

    validateForm();
});

function setMinDateGST() {
    var now = new Date();

    // Convert to GST (UTC+4)
    var gstNow = new Date(now.toLocaleString("en-US", { timeZone: "Asia/Dubai" }));

    var year = gstNow.getFullYear();
    var month = String(gstNow.getMonth() + 1).padStart(2, '0');
    var day = String(gstNow.getDate()).padStart(2, '0');

    var minDate = year + "-" + month + "-" + day;

    document.getElementById("meetingDate").setAttribute("min", minDate);
}

// Initial Load
window.addEventListener("load", function () {
    timeSlot.disabled = true;
    //timeSlot.classList.add("readonly");
    disableButton();
    setMinDateGST();
});