const SPREADSHEET_ID = "1T4GbMaZj41pBXn2RVzZzLrL8BISopmOWbIk7l_3EPc4"; //[cite: 3]
const SabhaReports_ID = "1mI5X_vIUfp30hDrs7wbaxv1NPVVffGcV1MLRI--xl9M"; //[cite: 3]
const DRIVE_FOLDER_ID = "1LEarQ68-0qa2FkCaVan7gw8IA14WWMnA"; // Drive Folder ID[cite: 3]
const MASTER_SPREADSHEET_ID = "19WYnyUPYA2BOyd1ZD8jf8QsFTnjg3fnc02BlZMo-Suw";

// Web App Routing
// 1. doGet Route Update
function doGet(e) {
  let page = e.parameter.page || 'index';
  let template;
  let title = 'Anoopam Mission';

  if (page === 'attendance') {
    template = HtmlService.createTemplateFromFile('Attendance');
    title = 'Anoopam Mission - Attendance';
  } 
  else if (page === 'attendance-report') {
    template = HtmlService.createTemplateFromFile('AttendanceReport');
    title = 'Anoopam Mission - Attendance Report';
  }
  else if (page === 'report') {
    template = HtmlService.createTemplateFromFile('Report');
    title = 'Anoopam Mission - Report';
  }
  else {
    page = 'index';
    template = HtmlService.createTemplateFromFile('Index');
    title = 'Anoopam Mission - Sabha Form';
  }

  // ⚠️ આ લાઈન ખાસ ઉમેરો: આનાથી Templated HTML ને 'page' વેરીએબલ મળી જશે
  template.page = page;

  return template.evaluate()
    .setTitle(title)
    .addMetaTag('viewport', 'width=device-width, initial-scale=1.0')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

// Helper Function: Date ને સરખી રીતે YYYY-MM-DD ફોર્મેટમાં કન્વર્ટ કરવા માટે
function normalizeDateString(dateVal) {
  if (!dateVal) return "";
  
  if (dateVal instanceof Date) {
    const year = dateVal.getFullYear();
    const month = String(dateVal.getMonth() + 1).padStart(2, '0');
    const day = String(dateVal.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
  
  const str = String(dateVal).trim();
  if (str.includes("T")) {
    return str.split("T")[0];
  }
  
  return str;
}

// 1. Fetch Unique Sabha Dates List for Dropdown
function getSabhaDatesList() {
  try {
    const ss = SpreadsheetApp.openById(MASTER_SPREADSHEET_ID);
    const sheet = ss.getSheetByName("AttendanceLogs");
    if (!sheet) return [];

    const data = sheet.getDataRange().getValues();
    if (data.length <= 1) return []; // Header સિવાય ડેટા ન હોય તો

    const datesSet = new Set();

    for (let i = 1; i < data.length; i++) {
      const rawDate = data[i][1]; // Column B (Sabha Date)
      const formattedDate = normalizeDateString(rawDate);
      if (formattedDate) {
        datesSet.add(formattedDate);
      }
    }

    // લેટેસ્ટ તારીખ પહેલા આવે એ રીતે શોર્ટ કરો
    return Array.from(datesSet).sort().reverse();
  } catch (err) {
    Logger.log("Error in getSabhaDatesList: " + err.toString());
    return [];
  }
}

// ૧. haribhakta Master ડેટા મેળવવાનું ફંક્શન
function getharibhaktaMasterData() {
  try {
    const ss = SpreadsheetApp.openById(MASTER_SPREADSHEET_ID);
    const sheet = ss.getSheetByName("Master List - Family");
    
    if (!sheet) {
      throw new Error("Sheet 'Master List - Family' મળી નથી!");
    }
    
    const lastRow = sheet.getLastRow();
    if (lastRow < 2) return [];
    
    // Range B2:F (Col B = ID, Col C = Name, Col F = Gender)
    const range = sheet.getRange(2, 2, lastRow - 1, 5);
    const values = range.getValues();
    
    const masterList = [];
    
    for (let i = 0; i < values.length; i++) {
      const id = String(values[i][0]).trim();
      const name = String(values[i][1]).trim();
      const gender = String(values[i][4]).trim(); // Col F is Index 4 in 5-col range
      
      // Header કે ખાલી નામ અટકાવવા માટે Filter
      if (name !== "" && name.toLowerCase() !== "name" && id.toLowerCase() !== "id") {
        masterList.push({
          id: id,
          name: name,
          gender: gender || "M" // Gender ખાલી હોય તો Default M
        });
      }
    }
      
    return masterList;
  } catch (error) {
    Logger.log("Error in getharibhaktaMasterData: " + error.toString());
    throw error;
  }
}

// 1. Corrected Submit Attendance (Matches Sheet Columns Perfectly)
function submitAttendance(payload) {
  try {
    const ss = SpreadsheetApp.openById(MASTER_SPREADSHEET_ID);
    let sheet = ss.getSheetByName("AttendanceLogs");
    
    // 1. શીટ ના હોય તો 6 કોલમના હેડર સાથે બનાવો
    if (!sheet) {
      sheet = ss.insertSheet("AttendanceLogs");
      sheet.appendRow(["Timestamp", "Sabha Date", "Haribhakto ID", "Haribhakto Name", "Gender", "Status"]);
    }

    const sabhaDate = payload.sabhaDate;
    const selectedList = payload.selectedHaribhaktos || [];

    const data = sheet.getDataRange().getDisplayValues();
    const rowsToKeep = [];
    
    // 2. 6 કોલમ વાળું હેડર
    const headerRow = ["Timestamp", "Sabha Date", "Haribhakto ID", "Haribhakto Name", "Gender", "Status"];
    rowsToKeep.push(headerRow);

    // સભા તારીખે ઓલરેડી સબમિટ થયેલા Haribhakto IDs યાદ રાખવા માટે Set
    const existingIdsForDate = new Set();

    // 3. જૂની એન્ટ્રીઝ રીડ કરીને કલેક્ટ કરો
    if (data.length > 1) {
      for (let i = 1; i < data.length; i++) {
        // હેડર સ્કીપ કરો
        if (data[i][0] === "Timestamp" || data[i][0] === "LOG-ID") continue;

        const rowDate = data[i][1] ? data[i][1].trim() : "";
        const rowId = data[i][2] ? data[i][2].trim() : "";

        let existingRow = data[i];
        // જો 5 કોલમ હોય તો 6 માં કન્વર્ટ કરી લેવું
        if (existingRow.length === 5) {
          existingRow.splice(4, 0, "M");
        }

        // બધો જ જૂનો ડેટા જાળવી રાખો
        rowsToKeep.push(existingRow);

        // જો આ જ તારીખનો ડેટા હોય તો ID નોંધી લો જેથી ડુપ્લિકેટ ન થાય
        if (rowDate === sabhaDate) {
          existingIdsForDate.add(rowId);
        }
      }
    }

    // 4. ફક્ત એવા જ હરિભક્તો ઉમેરો જે આ તારીખે અગાઉ ઉમેરાયા ન હોય
    let addedCount = 0;
    selectedList.forEach(item => {
      const itemId = String(item.id).trim();

      if (!existingIdsForDate.has(itemId)) {
        const logId = "LOG-" + Math.floor(100000 + Math.random() * 900000);
        rowsToKeep.push([
          logId,              // Col A: Timestamp / Log ID
          sabhaDate,          // Col B: Sabha Date
          itemId,             // Col C: Haribhakto ID
          item.name,          // Col D: Haribhakto Name
          item.gender || "M", // Col E: Gender
          "Present"           // Col F: Status
        ]);
        existingIdsForDate.add(itemId);
        addedCount++;
      }
    });

    // 5. શીટ અપડેટ કરો
    sheet.clearContents();
    
    const numRows = rowsToKeep.length;
    const numCols = rowsToKeep[0].length;

    sheet.getRange(1, 1, numRows, numCols).setValues(rowsToKeep);

    if (addedCount === 0) {
      return { success: true, message: "આ સિલેક્ટ કરેલા બધા જ હરિભક્તોની હાજરી આ તારીખ માટે ઓલરેડી પૂરાઈ ગયેલી છે!" };
    }

    return { success: true, message: `${addedCount} નવા હરિભક્તોની હાજરી સફળતાપૂર્વક ઉમેરાઈ ગઈ છે!` };
  } catch (err) {
    return { success: false, message: err.toString() };
  }
}

// Helper Function for Date Format
function formatDateString(dateVal) {
  if (!dateVal) return "";
  if (dateVal instanceof Date) {
    return dateVal.toISOString().split('T')[0];
  }
  return String(dateVal).trim();
}

// 2. Corrected Fetch Analytics Function
function getAttendanceAnalytics(selectedDate) {
  try {
    const ss = SpreadsheetApp.openById(MASTER_SPREADSHEET_ID);
    const sheet = ss.getSheetByName("AttendanceLogs");
    if (!sheet) {
      return { success: false, message: "AttendanceLogs sheet not found." };
    }

    const data = sheet.getDataRange().getDisplayValues();
    const attendees = [];
    let maleCount = 0;
    let femaleCount = 0;

    for (let i = 1; i < data.length; i++) {
      const rowDate = data[i][1].trim();
      
      if (!selectedDate || rowDate === selectedDate.trim()) {
        const gender = data[i][4] ? data[i][4].trim().toUpperCase() : "M";
        
        if (gender === "F" || gender === "FEMALE") {
          femaleCount++;
        } else {
          maleCount++;
        }

        attendees.push({
          logId: data[i][0],
          sabhaDate: data[i][1],
          id: data[i][2],
          name: data[i][3],
          gender: gender,
          status: data[i][5] || "Present"
        });
      }
    }

    return {
      success: true,
      count: attendees.length,
      maleCount: maleCount,
      femaleCount: femaleCount,
      attendees: attendees
    };
  } catch (err) {
    return { success: false, message: err.toString() };
  }
}

// Partial HTML (Styles, Header) Include કરવા માટેનું Helper Function
function include(filename, extraParams) {
  var template = HtmlService.createTemplateFromFile(filename);
  
  // ડિફોલ્ટ વેરીએબલ્સ સેટ કરવા જેથી 'page' ઇઝ નોટ ડિફાઇન્ડ એરર ન આવે
  template.page = ''; 
  
  if (extraParams) {
    Object.keys(extraParams).forEach(function(key) {
      template[key] = extraParams[key];
    });
  }
  return template.evaluate().getContent();
}

function testDriveAccess() {
  var folder = DriveApp.getFolderById(DRIVE_FOLDER_ID); //[cite: 3]
  Logger.log("Folder Name: " + folder.getName()); //[cite: 3]
}

function forceFullDrivePermission() {
  var folder = DriveApp.getFolderById(DRIVE_FOLDER_ID); //[cite: 3]
  var testFile = folder.createFile("test_permission.txt", "Test Content"); //[cite: 3]
  Logger.log("File Created Successfully: " + testFile.getName()); //[cite: 3]
  testFile.setTrashed(true); //[cite: 3]
}

function authorizeDrive() {
  var folder = DriveApp.getFolderById(DRIVE_FOLDER_ID); //[cite: 3]
  Logger.log("Folder Name: " + folder.getName()); //[cite: 3]
}

function getVachanamrutMasterData() {
  try {
    var ss = SpreadsheetApp.openById(SPREADSHEET_ID); //[cite: 3]
    var sheet = ss.getSheetByName("VachanamrutMaster"); //[cite: 3]
    if (!sheet) throw new Error("Sheet 'VachanamrutMaster' not found."); //[cite: 3]
    
    var lastRow = sheet.getLastRow(); //[cite: 3]
    if (lastRow < 1) return []; //[cite: 3]
    
    var data = sheet.getRange(1, 1, lastRow, 3).getValues(); //[cite: 3]
    if (data.length > 0 && isNaN(parseInt(data[0][1]))) {
      data.shift(); //[cite: 3]
    }
    return data; //[cite: 3]
  } catch (e) {
    throw new Error("Backend Error: " + e.message); //[cite: 3]
  }
}

function getSabhaReportsData() {
  try {
    var ss = SpreadsheetApp.openById(SabhaReports_ID); //[cite: 3]
    var sheet = ss.getSheetByName("Sabha Reports"); //[cite: 3]
    if (!sheet) return []; //[cite: 3]
    
    var lastRow = sheet.getLastRow(); //[cite: 3]
    if (lastRow <= 1) return []; //[cite: 3]
    
    var data = sheet.getRange(2, 1, lastRow - 1, 18).getValues(); //[cite: 3]
    
    return data.map(function(row) {
      return {
        createdOn: row[0] ? Utilities.formatDate(new Date(row[0]), Session.getScriptTimeZone(), "dd-MM-yyyy HH:mm") : "", //[cite: 3]
        sabhaDate: row[1] ? Utilities.formatDate(new Date(row[1]), Session.getScriptTimeZone(), "yyyy-MM-dd") : "", //[cite: 3]
        displayDate: row[1] ? Utilities.formatDate(new Date(row[1]), Session.getScriptTimeZone(), "dd-MM-yyyy") : "", //[cite: 3]
        totalBhaktos: row[2], //[cite: 3]
        theme: row[3], //[cite: 3]
        kirtans: row[4], //[cite: 3]
        vachanamrut: row[5], //[cite: 3]
        swaminiVato: row[6], //[cite: 3]
        otherReadings: row[7], //[cite: 3]
        prasad: row[8], //[cite: 3]
        alpahar: row[9], //[cite: 3]
        mahaprasad: row[10], //[cite: 3]
        santo: row[11], //[cite: 3]
        guest: row[12], //[cite: 3]
        announcement: row[13], //[cite: 3]
        duration: row[14], //[cite: 3]
        takeaways: row[15], //[cite: 3]
        mediaLink: row[16], //[cite: 3]
        uploadedPhotos: row[17] ? String(row[17]).split(",") : [] //[cite: 3]
      };
    }).reverse(); //[cite: 3]
  } catch (e) {
    throw new Error("Error fetching reports: " + e.message); //[cite: 3]
  }
}

// Single Photo Upload Helper (Async processing inside front-end loop)
function uploadSinglePhoto(photoObj, dateStr, index) {
  try {
    if (!photoObj || !photoObj.base64) return ""; //
    
    var folder = DriveApp.getFolderById(DRIVE_FOLDER_ID); //
    var base64Clean = photoObj.base64.includes(",") ? photoObj.base64.split(",")[1] : photoObj.base64; //
    var decodedData = Utilities.base64Decode(base64Clean); //
    
    var fileName = "Sabha_" + (dateStr || "Report") + "_Img" + (index + 1) + "_" + new Date().getTime(); //
    var blob = Utilities.newBlob(decodedData, photoObj.mimeType || "image/jpeg", fileName); //
    
    var file = folder.createFile(blob); //
    
    // View access set કહી દઈએ જેથી Dashboard માં સહેલાઈથી દેખાય
    try {
      file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW); //[cite: 3]
    } catch(e) {
      // Ignore if sharing policy restricts
    }
    
    return "https://lh3.googleusercontent.com/d/" + file.getId(); //
  } catch(err) {
    Logger.log("Photo Upload Error: " + err.message); //
    throw new Error("Photo " + (index + 1) + " Upload Failed: " + err.message); //
  }
}

function processForm(formData) {
  try {
    var inputDate = new Date(formData.date); //[cite: 3]
    var today = new Date(); //[cite: 3]
    today.setHours(23, 59, 59, 999); //[cite: 3]
    if (inputDate > today) {
      return { status: "error", message: "Sabha Date cannot be in the future!" }; //[cite: 3]
    }

    var ss = SpreadsheetApp.openById(SabhaReports_ID); //[cite: 3]
    var sheet = ss.getSheetByName("Sabha Reports"); //[cite: 3]
    
    if (!sheet) {
      sheet = ss.insertSheet("Sabha Reports"); //[cite: 3]
      sheet.appendRow([
        "Created On", "Sabha Date", "Total Bhaktos", "Theme", "Kirtans", 
        "Vachanamrut", "Swamini Vato", "Other Readings", "Prasad", 
        "Alpahar", "Mahaprasad", "Santo", "Guest", "Announcement", 
        "Sabha Duration", "Takeaways", "Media Link", "Uploaded Photos"
      ]); //[cite: 3]
    }

    var male = parseInt(formData.maleBhaktos) || 0; //[cite: 3]
    var female = parseInt(formData.femaleBhaktos) || 0; //[cite: 3]
    var grandTotal = male + female; //[cite: 3]
    var bhaktosFormatted = grandTotal + " (M: " + male + ", F: " + female + ")"; //[cite: 3]

    var vachanamrutFull = ""; //[cite: 3]
    if (formData.vachChapter) {
      vachanamrutFull = formData.vachChapter + " - " + formData.vachNumber; //[cite: 3]
      if (formData.vachTitle) vachanamrutFull += " : " + formData.vachTitle; //[cite: 3]
    }

    var swamiNiVatoFull = ""; //[cite: 3]
    if (formData.swamiPrakaran) {
      swamiNiVatoFull = formData.swamiPrakaran + (formData.swamiVatNo ? " (Vat No: " + formData.swamiVatNo + ")" : ""); //[cite: 3]
    }

    var prasadFormatted = formData.prasadItem || formData.prasadSewa ? (formData.prasadItem + " (Sewa From: " + formData.prasadSewa + ")") : ""; //[cite: 3]
    var alpaharFormatted = formData.alpaharItem || formData.alpaharSewa ? (formData.alpaharItem + " (Sewa From: " + formData.alpaharSewa + ")") : ""; //[cite: 3]
    var mahaprasadFormatted = formData.mahaprasadItem || formData.mahaprasadSewa ? (formData.mahaprasadItem + " (Sewa From: " + formData.mahaprasadSewa + ")") : ""; //[cite: 3]

    // Frontend માંથી આવેલ Photo URLs
    var photoUrlsString = formData.photoUrls ? formData.photoUrls.join(",") : ""; //

    sheet.appendRow([
      new Date(), //[cite: 3]
      formData.date, //[cite: 3]
      bhaktosFormatted, //[cite: 3]
      formData.specialEvent, //[cite: 3]
      formData.kirtans, //[cite: 3]
      vachanamrutFull, //[cite: 3]
      swamiNiVatoFull, //[cite: 3]
      formData.otherReadings, //[cite: 3]
      prasadFormatted, //[cite: 3]
      alpaharFormatted, //[cite: 3]
      mahaprasadFormatted, //[cite: 3]
      formData.santo, //[cite: 3]
      formData.guest, //[cite: 3]
      formData.specialAnnouncement, //[cite: 3]
      formData.durationHr + "h " + formData.durationMin + "m " + formData.durationSec + "s", //[cite: 3]
      formData.importantTakeaways, //[cite: 3]
      formData.mediaLink, //[cite: 3]
      photoUrlsString //
    ]);

    return { status: "success", message: "Report submitted successfully with all photos!" }; //
  } catch (error) {
    return { status: "error", message: error.message }; //[cite: 3]
  }
}