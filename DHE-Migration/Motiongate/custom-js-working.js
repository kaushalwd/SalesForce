// <!--for display box on unsubscribe button click-->
function unsubscribeClick() {
  document.getElementById("unsubscribe-reason").style.display = "block";
}

$('.close-button').click(function(e) {
  document.getElementById("unsubscribe-reason").style.display = "none";
});

$('.unsubscribe-btn').click(function(e) {
  document.getElementById("channel-preference").style.display = "none";
  document.getElementById("unsubscribe-all-reason").style.display = "none";
});

function unsubscribeAllClick() {
  document.getElementById("unsubscribe-all-reason").style.display = "block";
}

$('.close-buttonAll').click(function(e) {
  document.getElementById("unsubscribe-all-reason").style.display = "none";
});

$('.unsubscribe-all-btn').click(function(e) {
  document.getElementById("channel-preference").style.display = "none";
  document.getElementById("unsubscribe-reason").style.display = "none";
});


function channelPreference() {
document.getElementById("channel-preference").style.display = "block";
}
$('.close-buttonCM').click( function(e) { 
document.getElementById("channel-preference").style.display = "none";
});
 
$('.channelPreference-btn').click( function(e) { 
document.getElementById("unsubscribe-reason").style.display = "none";
document.getElementById("unsubscribe-all-reason").style.display = "none";
});


// <!--for display Textarea on other checkbox click-->
function addbox1() {
  if (document.getElementById("myCheck1").checked) {
    document.getElementById("area1").style.display = "block";
  } else {
    document.getElementById("area1").style.display = "none";
  }
}
addbox1();

// <!--for display Textarea on other checkbox click-->
function addbox_1() {
if (document.getElementById("myCheck_1").checked) {
  document.getElementById("area_1").style.display = "block";
} else {
  document.getElementById("area_1").style.display = "none";
}
}

addbox_1();

//<!--Future date restricting Validation-->


  var today = new Date().toJSON().slice(0, 10);
  var date = $('input[type=date]');
  date.attr('max', today);
  

// <!--Make Email non- editable if not empty-->
 if ($("input[type=email]").val().length > 0){
  $("input[type=email]").prop('disabled', true);
}
// <!--Make country code field required if phone field not empty-->


// for valid value
var inputs = document.querySelectorAll('input[list]');
for (var i = 0; i < inputs.length; i++) {
inputs[i].addEventListener('input', function() {
  var optionFound = false,
    datalist = this.list;

  if (this.value === '') {
    // If the value is empty, clear the custom validity message
    this.setCustomValidity('');
  } else {
    for (var j = 0; j < datalist.options.length; j++) {
      if (this.value == datalist.options[j].value) {
        optionFound = true;
        break;
      }
    }

    if (optionFound) {
      this.setCustomValidity('');
    } else {
      this.setCustomValidity('Please select a valid value.');
    }
  }
});
}



//for page refresh show from top

window.onbeforeunload = function () {
window.scrollTo(0, 0);
}


//Loader Script


    $('form').submit(function(event) {

      $(".loader1").show();

      setTimeout(function() {
        $(".loader1").hide();   
      }, 20000);
    });





      // Function to toggle the disabled attribute of #nationality
      function toggleNationalityField() {
          var value = $("#profileCountry").val();
          $("#nationality").prop('disabled', value !== "United Arab Emirates");
      }
  
      // Initially set the disabled attribute based on the selected option
      toggleNationalityField();
      if ($("#profileCountry").val() !== "United Arab Emirates") {
        $("#nationality").val('');
    }

      // Add an event listener to #profileCountry
      $("#profileCountry").on("change", function() {
          // Call the function to toggle the disabled attribute
          toggleNationalityField();
              // Reset nationality field if the selected country is not UAE
      if ($(this).val() !== "United Arab Emirates") {
          $("#nationality").val('');
      }
      });


// Function to toggle the disabled attribute of #city
      function toggleCityField() {
        var value = $("#profileCountry").val();
        $("#city").prop('disabled', value !== "United Arab Emirates");
    }

    // Initially set the disabled attribute based on the selected option
    toggleCityField();
    if ($("#profileCountry").val() !== "United Arab Emirates") {
      $("#city").val('');
  }

    // Add an event listener to #profileCountry
    $("#profileCountry").on("change", function() {
        // Call the function to toggle the disabled attribute
        toggleCityField();
            // Reset nationality field if the selected country is not UAE
    if ($(this).val() !== "United Arab Emirates") {
        $("#city").val('');
    }
    });
  