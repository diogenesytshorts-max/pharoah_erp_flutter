// =============================================================================
// PHAROAH ERP - GOOGLE DRIVE CLOUD SERVER SCRIPT (Free Multi-Tenant Webhook)
// =============================================================================
// इस कोड को Google Apps Script (script.google.com) में पेस्ट करके Deploy किया जाता है।

const FOLDER_NAME = "Pharoah_ERP_Cloud_DB";
const FILE_NAME = "pharoah_database.json";

// 1. डेटा फेच करना (Website / App reads from Google Drive)
function doGet(e) {
  try {
    const folder = getOrCreateFolder(FOLDER_NAME);
    const files = folder.getFilesByName(FILE_NAME);
    
    if (files.hasNext()) {
      const file = files.next();
      const content = file.getBlob().getDataAsString();
      return ContentService.createTextOutput(JSON.stringify({
        status: "SUCCESS",
        payload: JSON.parse(content)
      })).setMimeType(ContentService.MimeType.JSON);
    } else {
      return ContentService.createTextOutput(JSON.stringify({
        status: "EMPTY",
        message: "No database found. Creating fresh on first save.",
        payload: null
      })).setMimeType(ContentService.MimeType.JSON);
    }
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      status: "ERROR",
      message: error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

// 2. डेटा सेव करना (Website / App saves directly to Google Drive)
function doPost(e) {
  try {
    const postData = JSON.parse(e.postData.contents);
    const folder = getOrCreateFolder(FOLDER_NAME);
    const files = folder.getFilesByName(FILE_NAME);
    
    const payloadString = JSON.stringify(postData.payload);
    
    if (files.hasNext()) {
      const file = files.next();
      file.setContent(payloadString);
    } else {
      folder.createFile(FILE_NAME, payloadString, MimeType.PLAIN_TEXT);
    }
    
    return ContentService.createTextOutput(JSON.stringify({
      status: "SUCCESS",
      message: "Database successfully saved to Google Drive",
      timestamp: new Date().toISOString()
    })).setMimeType(ContentService.MimeType.JSON);
    
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      status: "ERROR",
      message: error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

// Helper: फोल्डर खोजना या बनाना
function getOrCreateFolder(folderName) {
  const folders = DriveApp.getFoldersByName(folderName);
  if (folders.hasNext()) {
    return folders.next();
  } else {
    return DriveApp.createFolder(folderName);
  }
}
