/**
 * PHAROAH ERP - GOOGLE DRIVE SYNC BACKEND SCRIPT
 * -------------------------------------------------------------
 * Yeh script Google Drive par automatic "Pharoah_ERP_Cloud_Database"
 * folder banati hai aur App/Web ka pura data JSON format me sync karti hai.
 */

const FOLDER_NAME = "Pharoah_ERP_Cloud_Database";
const FILE_NAME = "Pharoah_Main_Database.json";

function getOrCreateDatabaseFile() {
  const folders = DriveApp.getFoldersByName(FOLDER_NAME);
  let folder;
  if (folders.hasNext()) {
    folder = folders.next();
  } else {
    folder = DriveApp.createFolder(FOLDER_NAME);
  }

  const files = folder.getFilesByName(FILE_NAME);
  if (files.hasNext()) {
    return files.next();
  } else {
    return folder.createFile(FILE_NAME, JSON.stringify({
      status: "INIT",
      createdAt: new Date().toISOString(),
      payload: {}
    }), MimeType.PLAIN_TEXT);
  }
}

// 📥 1. GET Request: App ya Web ko Google Drive se data bhejna
function doGet(e) {
  try {
    const file = getOrCreateDatabaseFile();
    const content = file.getBlob().getDataAsString();
    const jsonData = JSON.parse(content);

    return ContentService.createTextOutput(JSON.stringify({
      status: "SUCCESS",
      payload: jsonData.payload || {}
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      status: "ERROR",
      message: error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

// 💾 2. POST Request: App ya Web ka data Google Drive par save karna
function doPost(e) {
  try {
    const postData = JSON.parse(e.postData.contents);
    const file = getOrCreateDatabaseFile();

    const dataToSave = {
      status: "ACTIVE",
      lastUpdated: new Date().toISOString(),
      tenantEmail: postData.tenantEmail || "default",
      payload: postData.payload || {}
    };

    file.setContent(JSON.stringify(dataToSave, null, 2));

    return ContentService.createTextOutput(JSON.stringify({
      status: "SUCCESS",
      message: "Database updated successfully on Google Drive!"
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      status: "ERROR",
      message: error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}
