let hData = [];
let hDataType = [];
let inputStates = {
    ['1']: false,
    ['2']: false,
    ['3']: false,
    ['4']: false,
};
menuOpen = false;
dropDownOpen = false;
currentDoorType = null;
currentNetId = 0;
window.addEventListener('message', function(event) {
    ed = event.data;
	if (ed.action === "audio") {
        var volume = (ed.audio['volume'] / 10) * ed.sfx
        if (ed.distance !== 0) volume /= ed.distance;
        if (volume > 1.0) volume = 1.0;
        const sound = new Audio('sounds/' + ed.audio['file']);
        sound.volume = volume;
        sound.play();
    } else if (ed.action === "openCreateDoorMenu") {
        menuOpen = true;
        document.getElementById("createDoorDiv").style.display = "flex";
        currentDoorType = null;
        if (ed.netId) {
            currentNetId = ed.netId;
        }
        if (ed.type === "double") {
            document.getElementById("createDoorDiv").style.height = "91%";
            document.getElementById("createDoorDiv").innerHTML = `
            <div id="CDDDivType2DropdownMain" style="top: 25%;">
                <div class="CDDDivType2DropdownMainInside" id="CDDDivType2DropdownMainInside-double" onclick="clFunc('chooseDoorType', 'double', 'Double Door')"><span>Double Door</span></div>
                <div class="CDDDivType2DropdownMainInside" id="CDDDivType2DropdownMainInside-doublesliding" onclick="clFunc('chooseDoorType', 'doublesliding', 'Double Sliding Door')"><span>Double Sliding Door</span></div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="far fa-fingerprint"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Config File Name</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-ConfigFileName" placeholder="Write here config file name...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="far fa-fingerprint"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Door Name</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-ConfigDoorName" placeholder="Write here door name...">
                </div>
            </div>
            <div id="CDDDivType3">
                <div id="CDDDivType1" style="height: 100%; width: 48.5%;">
                    <div id="CDDDivType1Left" style="width: 30%;">
                        <i class="far fa-fingerprint"></i>
                    </div>
                    <div id="CDDDivType1Right" style="width: 60%;">
                        <h4>Door Hash 1</h4>
                        <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-UniqueIdentifier" placeholder="Write here door hash 1">
                    </div>
                </div>
                <div id="CDDDivType1" style="height: 100%; width: 48.5%;">
                    <div id="CDDDivType1Left" style="width: 30%;">
                        <i class="far fa-fingerprint"></i>
                    </div>
                    <div id="CDDDivType1Right" style="width: 60%;">
                        <h4>Door Hash 2</h4>
                        <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-UniqueIdentifier2" placeholder="Write here door hash 2">
                    </div>
                </div>
            </div>
            <div id="CDDDivType2">
                <div id="CDDDivType2Inside">
                    <span>Door Type</span>
                    <div id="CDDDivType2DropdownDiv" onclick="clFunc('dropDown')">
                        <span style="width: 85%; padding-left: 0.3vw;" id="CDDDivType2DoorType">Select door type...</span>
                        <div id="CDDDT2DDIconDiv">
                            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" fill="none" id="CDDDT2DDIcon">
                                <path d="M10.0002 9.02329L5.87523 13.1483L4.6969 11.97L10.0002 6.66663L15.3036 11.97L14.1252 13.1483L10.0002 9.02329Z" fill="white" fill-opacity="0.62"/>
                            </svg>
                        </div>
                    </div>
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-door-closed"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Door Password</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-PassCode" placeholder="Write here the door's password...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-briefcase"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Job Authorisation</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-JobAuthorisation" placeholder="Write here the job that can access door...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-hockey-mask"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Gang Authorisation</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-GangAuthorisation" placeholder="Write here the gang that can access door...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-users"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Citizen ID (Identifier) Authorisation</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-CitizenAuthorisation" placeholder="Write here the identifiers that can access door...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-sitemap"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Item Authorisation</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-ItemAuthorisation" placeholder="Write here the items that require to access door...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-people-arrows"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>SVG (Icon) Distance</h4>
                    <input type="number" class="CDDDivType1RightInput" id="CDDDivType1RightInput-SvgDistance" placeholder="Write here the svg (icon) distance to see door text..." onkeydown="return event.keyCode !== 69" min="0" oninput="this.value = Math.abs(this.value)">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-people-arrows"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Interact Distance</h4>
                    <input type="number" class="CDDDivType1RightInput" id="CDDDivType1RightInput-InteractDistance" placeholder="Write here the interact distance to see door text..." onkeydown="return event.keyCode !== 69" min="0" oninput="this.value = Math.abs(this.value)">
                </div>
            </div>
            <div id="CDDDivType2">
                <div id="CDDDivType2Inside" style="flex-direction: row;">
                    <div class="CDDDivType2DropdownDivInput">
                        <span>Locked</span>
                        <div class="CDDT2DDIDiv" id="CDDT2DDIDiv1" onclick="clFunc('changeInputState', '1')">
                            <div id="CDDT2DDIDivInsideRed"></div>
                        </div>
                    </div>
                    <div class="CDDDivType2DropdownDivInput">
                        <span>Lockpickable</span>
                        <div class="CDDT2DDIDiv" id="CDDT2DDIDiv2" onclick="clFunc('changeInputState', '2')">
                            <div id="CDDT2DDIDivInsideRed"></div>
                        </div>
                    </div>
                    <div class="CDDDivType2DropdownDivInput">
                        <span>Can't Unlock</span>
                        <div class="CDDT2DDIDiv" id="CDDT2DDIDiv3" onclick="clFunc('changeInputState', '3')">
                            <div id="CDDT2DDIDivInsideRed"></div>
                        </div>
                    </div>
                    <div class="CDDDivType2DropdownDivInput">
                        <span>Fix Text</span>
                        <div class="CDDT2DDIDiv" id="CDDT2DDIDiv4" onclick="clFunc('changeInputState', '4')">
                            <div id="CDDT2DDIDivInsideRed"></div>
                        </div>
                    </div>
                </div>
            </div>
            <div id="CDDDivButton" onclick="clFunc('createDoor')"><h4>Submit</h4></div>`;
            document.getElementById("CDDDivType1RightInput-UniqueIdentifier").value=ed.hash1;
            document.getElementById("CDDDivType1RightInput-UniqueIdentifier2").value=ed.hash2;
        } else {
            document.getElementById("createDoorDiv").style.height = "86%";
            document.getElementById("createDoorDiv").innerHTML = `
            <div id="CDDDivType2DropdownMain" style="top: 25.2%;">
                <div class="CDDDivType2DropdownMainInside" id="CDDDivType2DropdownMainInside-door" onclick="clFunc('chooseDoorType', 'door', 'Single Door')"><span>Single Door</span></div>
                <div class="CDDDivType2DropdownMainInside" id="CDDDivType2DropdownMainInside-sliding" onclick="clFunc('chooseDoorType', 'sliding', 'Single Sliding Door')"><span>Single Sliding Door</span></div>
                <div class="CDDDivType2DropdownMainInside" id="CDDDivType2DropdownMainInside-garage" onclick="clFunc('chooseDoorType', 'garage', 'Garage Door')"><span>Garage Door</span></div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="far fa-fingerprint"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Config File Name</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-ConfigFileName" placeholder="Write here config file name...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="far fa-fingerprint"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Door Name</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-ConfigDoorName" placeholder="Write here door name...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="far fa-fingerprint"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Door Hash</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-UniqueIdentifier" placeholder="Write here door hash">
                </div>
            </div>
            <div id="CDDDivType2">
                <div id="CDDDivType2Inside">
                    <span>Door Type</span>
                    <div id="CDDDivType2DropdownDiv" onclick="clFunc('dropDown')">
                        <span style="width: 85%; padding-left: 0.3vw;" id="CDDDivType2DoorType">Select door type...</span>
                        <div id="CDDDT2DDIconDiv">
                            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" fill="none" id="CDDDT2DDIcon">
                                <path d="M10.0002 9.02329L5.87523 13.1483L4.6969 11.97L10.0002 6.66663L15.3036 11.97L14.1252 13.1483L10.0002 9.02329Z" fill="white" fill-opacity="0.62"/>
                            </svg>
                        </div>
                    </div>
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-door-closed"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Door Password</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-PassCode" placeholder="Write here the door's password...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-briefcase"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Job Authorisation</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-JobAuthorisation" placeholder="Write here the job that can access door...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-hockey-mask"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Gang Authorisation</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-GangAuthorisation" placeholder="Write here the gang that can access door...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-users"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Citizen ID (Identifier) Authorisation</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-CitizenAuthorisation" placeholder="Write here the identifiers that can access door...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-sitemap"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Item Authorisation</h4>
                    <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-ItemAuthorisation" placeholder="Write here the items that require to access door...">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-people-arrows"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>SVG (Icon) Distance</h4>
                    <input type="number" class="CDDDivType1RightInput" id="CDDDivType1RightInput-SvgDistance" placeholder="Write here the svg (icon) distance to see door text..." onkeydown="return event.keyCode !== 69" min="0" oninput="this.value = Math.abs(this.value)">
                </div>
            </div>
            <div id="CDDDivType1">
                <div id="CDDDivType1Left">
                    <i class="fas fa-people-arrows"></i>
                </div>
                <div id="CDDDivType1Right">
                    <h4>Interact Distance</h4>
                    <input type="number" class="CDDDivType1RightInput" id="CDDDivType1RightInput-InteractDistance" placeholder="Write here the interact distance to see door text..." onkeydown="return event.keyCode !== 69" min="0" oninput="this.value = Math.abs(this.value)">
                </div>
            </div>
            <div id="CDDDivType2">
                <div id="CDDDivType2Inside" style="flex-direction: row;">
                    <div class="CDDDivType2DropdownDivInput">
                        <span>Locked</span>
                        <div class="CDDT2DDIDiv" id="CDDT2DDIDiv1" onclick="clFunc('changeInputState', '1')">
                            <div id="CDDT2DDIDivInsideRed"></div>
                        </div>
                    </div>
                    <div class="CDDDivType2DropdownDivInput">
                        <span>Lockpickable</span>
                        <div class="CDDT2DDIDiv" id="CDDT2DDIDiv2" onclick="clFunc('changeInputState', '2')">
                            <div id="CDDT2DDIDivInsideRed"></div>
                        </div>
                    </div>
                    <div class="CDDDivType2DropdownDivInput">
                        <span>Can't Unlock</span>
                        <div class="CDDT2DDIDiv" id="CDDT2DDIDiv3" onclick="clFunc('changeInputState', '3')">
                            <div id="CDDT2DDIDivInsideRed"></div>
                        </div>
                    </div>
                    <div class="CDDDivType2DropdownDivInput">
                        <span>Fix Text</span>
                        <div class="CDDT2DDIDiv" id="CDDT2DDIDiv4" onclick="clFunc('changeInputState', '4')">
                            <div id="CDDT2DDIDivInsideRed"></div>
                        </div>
                    </div>
                </div>
            </div>
            <div id="CDDDivButton" onclick="clFunc('createDoor')"><h4>Submit</h4></div>`;
            document.getElementById("CDDDivType1RightInput-UniqueIdentifier").value=ed.hash1;
        }
    } else if (ed.action === "openPassCodeMenu") {
        document.getElementById("createDoorDiv").style.height = "10%";
        menuOpen = true;
        document.getElementById("createDoorDiv").style.display = "flex";
        document.getElementById("createDoorDiv").innerHTML = `
        <div id="CDDDivType1" style="height: 100%;">
            <div id="CDDDivType1Left">
                <i class="fas fa-door-closed"></i>
            </div>
            <div id="CDDDivType1Right">
                <h4>Door Password</h4>
                <input type="text" class="CDDDivType1RightInput" id="CDDDivType1RightInput-PassCode2" placeholder="Write here the door's password...">
            </div>
        </div>
        <div id="CDDDivButton" style="height: 35%;" onclick="clFunc('submitDoorPass', '${ed.passcode}')"><h4>Submit</h4></div>`;
    } else if (ed.action === "textUI") {
        if (ed.show) {
			$("#textUI").show().css({bottom: "-10%", position:'absolute', display:'flex'}).animate({bottom: "4%"}, 800, function() {});
		} else {
			$("#textUI").show().css({bottom: "4%", position:'absolute', display:'flex'}).animate({bottom: "-10%"}, 800, function() {});
		}
    }
    document.onkeyup = function(data) {
		if (data.which == 27 && menuOpen) {
            menuOpen = false;
            document.getElementById("createDoorDiv").style.display = "none";
			var xhr = new XMLHttpRequest();
            xhr.open("POST", `https://${GetParentResourceName()}/callback`, true);
			xhr.setRequestHeader('Content-Type', 'application/json');
			xhr.send(JSON.stringify({action: "nuiFocus"}));
		}
	}
})

function clFunc(name1, name2, name3) {
    if (name1 === "dropDown") {
        if (dropDownOpen) {
            dropDownOpen = false;
            document.getElementById("CDDDivType2DropdownMain").style.display = "none";
            document.getElementById("CDDDT2DDIcon").style.transform = "";
        } else {
            dropDownOpen = true;
            document.getElementById("CDDDivType2DropdownMain").style.display = "flex";
            document.getElementById("CDDDT2DDIcon").style.transform = "rotate(180deg)";
        }
    } else if (name1 === "changeInputState") {
        if (inputStates[name2]) {
            inputStates[name2] = false;
            document.getElementById("CDDT2DDIDiv" + name2).style.background = "rgba(255, 126, 136, 0.10)";
            document.getElementById("CDDT2DDIDiv" + name2).style.justifyContent = "flex-start";
            document.getElementById("CDDT2DDIDiv" + name2).innerHTML = `<div id="CDDT2DDIDivInsideRed"></div>`;
        } else {
            inputStates[name2] = true;
            document.getElementById("CDDT2DDIDiv" + name2).style.background = "rgba(32, 132, 109, 0.10)";
            document.getElementById("CDDT2DDIDiv" + name2).style.justifyContent = "flex-end";
            document.getElementById("CDDT2DDIDiv" + name2).innerHTML = `<div id="CDDT2DDIDivInsideGreen"></div>`;
        }
    } else if (name1 === "chooseDoorType") {
        if (currentDoorType) {
            document.getElementById("CDDDivType2DropdownMainInside-" + currentDoorType).classList.remove("CDDDivType2DropdownMainInsideChoosen");
        }
        currentDoorType = name2;
        document.getElementById("CDDDivType2DoorType").innerHTML=name3;
        document.getElementById("CDDDivType2DropdownMainInside-" + currentDoorType).classList.add("CDDDivType2DropdownMainInsideChoosen");
        dropDownOpen = false;
        document.getElementById("CDDDivType2DropdownMain").style.display = "none";
        document.getElementById("CDDDT2DDIcon").style.transform = "";
    } else if (name1 === "createDoor") {
        let configFileName = document.getElementById("CDDDivType1RightInput-ConfigFileName");
		if ((configFileName.value == null || configFileName.value == "")) {
			configFileName.focus();
			return;
		}
        let uniqueIdentifier = document.getElementById("CDDDivType1RightInput-UniqueIdentifier");
		if ((uniqueIdentifier.value == null || uniqueIdentifier.value == "")) {
			uniqueIdentifier.focus();
			return;
		}
        let doorName = document.getElementById("CDDDivType1RightInput-ConfigDoorName");
		if ((doorName.value == null || doorName.value == "")) {
			doorName.focus();
			return;
		}

        if (currentDoorType === null) {
            dropDownOpen = true;
            document.getElementById("CDDDivType2DropdownMain").style.display = "flex";
            document.getElementById("CDDDT2DDIcon").style.transform = "rotate(180deg)";
            return;
        }

        let passCode = document.getElementById("CDDDivType1RightInput-PassCode");

        let jobAuthorisation = document.getElementById("CDDDivType1RightInput-JobAuthorisation");
		// if ((jobAuthorisation.value == null || jobAuthorisation.value == "")) {
		// 	jobAuthorisation.focus();
		// 	return;
		// }
        let gangAuthorisation = document.getElementById("CDDDivType1RightInput-GangAuthorisation");
		// if ((gangAuthorisation.value == null || gangAuthorisation.value == "")) {
		// 	gangAuthorisation.focus();
		// 	return;
		// }
        let citizenAuthorisation = document.getElementById("CDDDivType1RightInput-CitizenAuthorisation");
		// if ((citizenAuthorisation.value == null || citizenAuthorisation.value == "")) {
		// 	citizenAuthorisation.focus();
		// 	return;
		// }
        let itemAuthorisation = document.getElementById("CDDDivType1RightInput-ItemAuthorisation");
		// if ((itemAuthorisation.value == null || itemAuthorisation.value == "")) {
		// 	itemAuthorisation.focus();
		// 	return;
		// }

        // if ((jobAuthorisation.value == null || jobAuthorisation.value == "") && (gangAuthorisation.value == null || gangAuthorisation.value == "") && (citizenAuthorisation.value == null || citizenAuthorisation.value == "") && (itemAuthorisation.value == null || itemAuthorisation.value == "")) {
        //     return;
        // }

        let svgDistance = document.getElementById("CDDDivType1RightInput-SvgDistance");
		if (!Number(svgDistance.value)) {
			svgDistance.focus();
			return;
		}

        let interactDistance = document.getElementById("CDDDivType1RightInput-InteractDistance");
		if (!Number(interactDistance.value)) {
			interactDistance.focus();
			return;
		}
        var xhr = new XMLHttpRequest();
        xhr.open("POST", `https://${GetParentResourceName()}/callback`, true);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.send(JSON.stringify({
            action: "createDoor",
            data: {
                configfile: configFileName.value,
                job: jobAuthorisation.value,
                gang: gangAuthorisation.value,
                cid: citizenAuthorisation.value,
                item: itemAuthorisation.value,
                locked: inputStates["1"],
                pickable: inputStates["2"],
                cantunlock: inputStates["3"],
                fixText: inputStates["4"],
                svgDistance: Number(svgDistance.value),
                interactDistance: Number(interactDistance.value),
                dooridentifier: doorName.value,
                netId: Number(currentNetId),
                doortype: currentDoorType,
                passCode: passCode.value
            }
        }));
    } else if (name1 === "submitDoorPass") {
        let passCode = document.getElementById("CDDDivType1RightInput-PassCode2");
        if (passCode.value === name2) {
            menuOpen = false;
            document.getElementById("createDoorDiv").style.display = "none";
            var xhr = new XMLHttpRequest();
            xhr.open("POST", `https://${GetParentResourceName()}/callback`, true);
			xhr.setRequestHeader('Content-Type', 'application/json');
			xhr.send(JSON.stringify({action: "openDoor"}));
        }
    }
}