/*

    Copyright (C) 2024 Rohith Namboothiri

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs

Item {
    id: qsoTab
    width: 400
    height: 600

 property MainTab mainTab: null
    property int dmrID: -1
    property int tgid: -1
    property string logFileName: "logs.json"
    property string savedFilePath: ""
    property int latestSerialNumber: 0
    property bool isLoading: true



       signal firstRowDataChanged(string serialNumber, string callsign, string handle, string country)
       signal secondRowDataChanged(string serialNumber, string callsign, string handle, string country)

    ListModel {
        id: logModel
    }


    // Update the first and second row data in a single function
       function updateRowData() {
           if (logModel.count > 0) {
               var firstRow = logModel.get(0);
               firstRowDataChanged(firstRow.serialNumber, firstRow.callsign, firstRow.fname, firstRow.country);
           } else {
               firstRowDataChanged("N/A", "N/A", "N/A", "N/A");
           }

           if (logModel.count > 1) {
               var secondRow = logModel.get(1);
               secondRowDataChanged(secondRow.serialNumber, secondRow.callsign, secondRow.fname, secondRow.country);
           } else {
               secondRowDataChanged("N/A", "N/A", "N/A", "N/A");
           }
       }

       // Connections to update row data whenever the model changes
      Connections {
       target: logModel
       onCountChanged: {
           updateRowData();
       }
   }

          Component.onCompleted: {
              mainTab.dataUpdated.connect(onDataUpdated);
              updateRowData();
              loadSettings();
              if (mainTab === null) {
                  console.error("mainTab is null. Ensure it is passed correctly from the parent.");
              }
          }


          function saveSettings() {
               var logData = [];
               for (var i = 0; i < logModel.count; i++) {
                   logData.push(logModel.get(i));
               }
               logHandler.saveLog(logFileName, logData);
           }

          function loadSettings() {
              isLoading = true;
           var savedData = logHandler.loadLog(logFileName);
           for (var i = 0; i < savedData.length; i++) {
               savedData[i].checked = false;
               logModel.append(savedData[i]);
               latestSerialNumber = Math.max(latestSerialNumber, savedData[i].serialNumber + 1);
              
           }
           isLoading = false;
       }

    function clearSettings() {
        logModel.clear();
        logHandler.clearLog(logFileName);
        latestSerialNumber = 0;
    }

    function exportLog() {
        saveFileNameDialog.open(); 
    }

    Text {
        id: headerText
        text: "This page logs lastheard stations in descending order. An upgrade to a native Log book is coming soon."
        wrapMode: Text.WordWrap
        font.bold: true
        font.pointSize: 12
        color: "white"
        width: parent.width - 50
        x: 20
        y: 10
    }

    Button {
        id: clearButton
        text: "Clear"
        x: 20
        y: headerText.y + headerText.height + 12
        onClicked: {
            clearSettings()
        }

        background: Rectangle {
            color: "red"  
            radius: 4  
        }

        contentItem: Text {
            text: clearButton.text
            color: "white" 
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            anchors.centerIn: parent
            font.bold: true
        }
    }

   
    Button {
        id: exportButton
        text: "Export Log"
        x: clearButton.x + clearButton.width + 10
        y: headerText.y + headerText.height + 12
        onClicked: exportLog()

        background: Rectangle {
            color: "green"  
            radius: 4  
        }

        contentItem: Text {
            text: exportButton.text
            color: "white"  
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            anchors.centerIn: parent
            font.bold: true
        }
    }


   
    Button {
        id: clonedButton
        visible: mainTab.buttonTX.visible
        enabled: mainTab.buttonTX.enabled
        x: exportButton.x + exportButton.width + 10
        y: exportButton.y
        width: exportButton.width * 1.5  
        height: exportButton.height
        background: Rectangle {
            color: mainTab.buttonTX.tx ? "#800000" : "steelblue"
            radius: 4

           
            Text {
                id: clonedText
                anchors.centerIn: parent
                font.pointSize: 20  
                text: mainTab.buttonTX.tx ? "TX" : "TX"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Ensure cloned button follows the same behavior as the original
        onClicked: mainTab.buttonTX.clicked()
        onPressed: mainTab.buttonTX.pressed()
        onReleased: mainTab.buttonTX.released()
        onCanceled: mainTab.buttonTX.canceled()
    }




    // Dialog to prompt for file name
    Dialog {
        id: saveFileNameDialog
        title: "Enter File Name and Choose Format"
        standardButtons: Dialog.Ok | Dialog.Cancel
        modal: true

        contentItem: Column {
            spacing: 10

            TextField {
                id: fileNameInput
                placeholderText: "Enter file name"
                width: parent.width - 20
            }

            Row {
                spacing: 10
                RadioButton {
                    id: csvRadioButton
                    text: "CSV"
                    checked: true  // Default to CSV
                }
                RadioButton {
                    id: adifRadioButton
                    text: "ADIF"
                }
            }
        }

        onAccepted: {
            var fileName = fileNameInput.text.trim();
            if (fileName === "") {
                      errorDialog.open(); // Show error dialog if the file name is empty
                      return; // Prevent further execution
                  }
            var logData = [];
            var hasSelection = false;
            for (var i = 0; i < logModel.count; i++) {
                var entry = logModel.get(i);
                if (entry.checked) {
                    logData.push(entry);
                    hasSelection = true;
                }
            }

            if (!hasSelection) { // If no selections, export all
                for (var i = 0; i < logModel.count; i++) {
                    logData.push(logModel.get(i));
                }
            }


            var filePath = logHandler.getDSLogPath() + "/" + fileName;

            if (csvRadioButton.checked) {
                fileName += ".csv";
                filePath += ".csv";

                if (logHandler.exportLogToCsv(filePath, logData)) {
                    savedFilePath = logHandler.getFriendlyPath(filePath);
                    fileSavedDialog.open();
                } else {
                    console.error("Failed to save the CSV file.");
                }
            } else if (adifRadioButton.checked) {
                fileName += ".adi";
                filePath += ".adi";

                if (logHandler.exportLogToAdif(filePath, logData)) {
                    savedFilePath = logHandler.getFriendlyPath(filePath);
                    fileSavedDialog.open();
                } else {
                    console.error("Failed to save the ADIF file.");
                }
            }
        }
    }

    // Error Dialog to show if file name is empty
   
// Error Dialog to show if file name is empty
Dialog {
    id: errorDialog
    title: "Error"
    standardButtons: Dialog.Ok
    modal: true
    width: 300 

    contentItem: Text {
        text: "Empty/Invalid File Name."
        wrapMode: Text.WordWrap
        color: "red"
        width: parent.width * 0.9 
    }
}


/* 
//Binding loop Error
Dialog {
        id: errorDialog
        title: "Error"
        standardButtons: Dialog.Ok
        modal: true

        contentItem: Text {
            text: "Empty/Invalid File Name."
            wrapMode: Text.WordWrap
            color: "red"
            width: parent.width * 0.9
        }
    }
*/

// Dialog to show that the file was saved
    Dialog {
        id: fileSavedDialog
        title: "File Saved"
        standardButtons: Dialog.Ok
        width: 300  // Set a fixed width for the dialog to avoid binding loops

        onAccepted: {
            console.log("File saved successfully!");
        }

        background: Rectangle {
            color: "#80c342"
            radius: 8  // Optional: Add rounded corners
        }

        contentItem: Column {
            spacing: 10  // Add some spacing between the text and buttons

            // Text to display the success message
            Text {
                text: "File saved successfully to " + savedFilePath
                font.pointSize: 14
                color: "black"
                wrapMode: Text.WordWrap  // Enable text wrapping
                width: parent.width * 0.9  // Ensure some padding from the edges
            }

            // Row for the buttons
            Row {
                spacing: 10  // Add some spacing between the buttons
                anchors.horizontalCenter: parent.horizontalCenter  // Center the buttons horizontally

                Button {
                    text: "Cancel"
                    onClicked: fileSavedDialog.accept()  // Handle the Ok button click
                }

                Button {
                    text: "Share"
                    onClicked: {
                        logHandler.shareFile(savedFilePath);
                    }
                }
            }
        }
    }


    Row {
        id: tableHeader
        width: parent.width
        height: 25  
        y: clearButton.y + clearButton.height + 10
        spacing: 4

        Rectangle {
            width: parent.width / 8
            height: parent.height
            color: "darkgrey"
            Text {
                anchors.centerIn: parent
                text: "Sr.No"
                font.bold: true
                font.pixelSize: 12  
            }
        }
        Rectangle {
            width: parent.width / 6
            height: parent.height
            color: "darkgrey"
            Text {
                anchors.centerIn: parent
                text: "Callsign"
                font.bold: true
                font.pixelSize: 12  
            }
        }
        Rectangle {
            width: parent.width / 6
            height: parent.height
            color: "darkgrey"
            Text {
                anchors.centerIn: parent
                text: "DMR ID"
                font.bold: true
                font.pixelSize: 12  
            }
        }
        Rectangle {
            width: parent.width / 6
            height: parent.height
            color: "darkgrey"
            Text {
                anchors.centerIn: parent
                text: "TGID"
                font.bold: true
                font.pixelSize: 12  
            }
        }
        Rectangle {
            width: parent.width / 6
            height: parent.height
            color: "darkgrey"
            Text {
                anchors.centerIn: parent
                text: "Handle"
                font.bold: true
                font.pixelSize: 12 
            }
        }
        Rectangle {
            width: parent.width / 6
            height: parent.height
            color: "darkgrey"
            Text {
                anchors.centerIn: parent
                text: "Country"
                font.bold: true
                font.pixelSize: 12  
            }
        }
    }

  
    TableView {
        id: tableView
        x: 0
        y: tableHeader.y + tableHeader.height + 10
        width: parent.width
        height: parent.height - (tableHeader.y + tableHeader.height + 30)
        model: logModel

        delegate: Rectangle {
            width: tableView.width
            implicitWidth: tableView.width
            implicitHeight: 100 
            height: implicitHeight
            color: checkBox.checked ? "#b9fbd7" : (index % 2 === 0 ? "lightgrey" : "white")  

            Row {
                width: parent.width
                height: 40  

                Rectangle {
                    width: parent.width / 8
                    height: parent.height
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: serialNumber  
                        font.pixelSize: 12
                    }
                }
                Rectangle {
                    width: parent.width / 6
                    height: parent.height
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: callsign 
                        font.pixelSize: 12
                    }
                }
                Rectangle {
                    width: parent.width / 6
                    height: parent.height
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: dmrID  
                        font.pixelSize: 12
                    }
                }
                Rectangle {
                    width: parent.width / 6
                    height: parent.height
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: tgid  
                        font.pixelSize: 12
                    }
                }
                Rectangle {
                    width: parent.width / 6
                    height: parent.height
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: fname  
                        font.pixelSize: 12
                    }
                }
                Rectangle {
                    width: parent.width / 6
                    height: parent.height
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: country 
                        font.pixelSize: 12
                    }
                }
            }


            Row {
                width: parent.width - 20
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                y: 40

                CheckBox {
                    id: checkBox
                    checked: model.checked !== undefined ? model.checked : false
                    onCheckedChanged: {
                        model.checked = checked;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: model.currentTime
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                    width: parent.width - checkBox.width - 50
                    anchors.verticalCenter: checkBox.verticalCenter
                    elide: Text.ElideRight
                }


                Text {
                               id: menuIcon
                               text: "\uf0c9"  
                               font.family: "FontAwesome"
                               font.pixelSize: 20
                               anchors.verticalCenter: parent.verticalCenter
                               color: "black"
                               MouseArea {
                                   anchors.fill: parent
                                   onClicked: {
                                       if (contextMenu.visible) {
                                           contextMenu.close();
                                       } else {
                                           contextMenu.x = menuIcon.x + menuIcon.width
                                                           contextMenu.y = menuIcon.y
                                                           contextMenu.open()
                                       }
                                   }
                               }
                           }
                       }

                       Menu {
                           id: contextMenu
                           title: "Lookup Options"
                           visible: false 
                           MenuItem {
                               text: "Lookup QRZ"
                               onTriggered: Qt.openUrlExternally("https://qrz.com/lookup/" + model.callsign)
                           }
                           MenuItem {
                               text: "Lookup BM"
                               onTriggered: Qt.openUrlExternally("https://brandmeister.network/index.php?page=profile&call=" + model.callsign)
                           }
                           MenuItem {
                               text: "Lookup APRS"
                               onTriggered: Qt.openUrlExternally("https://aprs.fi/#!call=a%2F" + model.callsign)
                           }
                          // onClosed: visible = false

                       }
                   }
               }

    function onDataUpdated(receivedDmrID, receivedTGID) {
        console.log("Received dmrID:", receivedDmrID, "and TGID:", receivedTGID);
        qsoTab.dmrID = receivedDmrID;  
        qsoTab.tgid = receivedTGID;    
        fetchData(receivedDmrID, receivedTGID);
    }

    function fetchData(dmrID, tgid) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://radioid.net/api/dmr/user/?id=" + dmrID, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText);
                    if (response.count > 0) {
                        var result = response.results[0];
                        var data = {
                            callsign: result.callsign,
                            dmrID: result.id,
                            tgid: tgid, 
                            country: result.country,
                            fname: result.fname,
                            currentTime: Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")  // Current local time
                        };
                        addEntry(data);
                    }
                } else {
                    console.error("Failed to fetch data. Status:", xhr.status);
                }
            }
        };
        xhr.send();
    }

    function addEntry(data) {
            console.log("Processing data in QsoTab:", JSON.stringify(data));

            if (!data || typeof data !== 'object') {
                console.error("Invalid data received:", data);
                return;
            }

          
            if (data.country === "United States") {
                data.country = "USA";
            } else if (data.country === "United Kingdom") {
                data.country = "UK";
            }

            latestSerialNumber += 1;
            isLoading = false;

           
            logModel.insert(0, {
                serialNumber: latestSerialNumber,
                callsign: data.callsign,
                dmrID: data.dmrID,
                tgid: data.tgid,
                country: data.country,
                fname: data.fname,
                currentTime: data.currentTime,
                checked: false
            });

            saveSettings();
            const maxEntries = 250;
            while (logModel.count > maxEntries) {
                logModel.remove(logModel.count - 1);  
            }
        }
    }
