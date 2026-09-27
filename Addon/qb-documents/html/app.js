window.addEventListener('message', function(event) {
  	var data = event.data
  	switch (data.action) {
    	case 'open':
			if (data.documentInfos) {

				$(".document").fadeIn(285)

				$("#info-1").html(`Name`)
				$("#infoDescription-1").css("color", `${data.documentOptions.color}`)
				$("#infoDescription-1").html(`${data.documentInfos.firstname} ${data.documentInfos.lastname}`)
				$("#info-2").html(`Date of birth`)
				$("#infoDescription-2").css("color", `${data.documentOptions.color}`)
				$("#infoDescription-2").html(`${data.documentInfos.dob}`)

				if (data.type == "id_card") {
					$("#info-3").html(`Nationality`)
					$("#infoDescription-3").css("color", `${data.documentOptions.color}`)
					$("#infoDescription-3").html(`${data.documentInfos.nationality}`)
					$("#info-4").html(`Sex`)
					$("#infoDescription-4").css("color", `${data.documentOptions.color}`)
					$("#infoDescription-4").html(`${data.documentInfos.sex}`)
				}
				if (data.type == "id_drive") {
					$("#info-3").html(`Sex`)
					$("#infoDescription-3").css("color", `${data.documentOptions.color}`)
					$("#infoDescription-3").html(`${data.documentInfos.sex}`)
					$("#info-4").html(`Approved licenses`)
					$("#infoDescription-4").css("color", `${data.documentOptions.color}`)
					$("#infoDescription-4").html(`${data.documentInfos.drive_bike} ${data.documentInfos.drive} ${data.documentInfos.drive_truck}`)
				}
				if (data.type == "id_fly") {
					$("#info-3").html(`Sex`)
					$("#infoDescription-3").css("color", `${data.documentOptions.color}`)
					$("#infoDescription-3").html(`${data.documentInfos.sex}`)
					$("#info-4").html(`Approved licenses`)
					$("#infoDescription-4").css("color", `${data.documentOptions.color}`)
					$("#infoDescription-4").html(`${data.documentInfos.flying_helicopter} ${data.documentInfos.flying_plane}`)
				}
				if (data.type == "id_boat") {
					$("#info-3").html(`Sex`)
					$("#infoDescription-3").css("color", `${data.documentOptions.color}`)
					$("#infoDescription-3").html(`${data.documentInfos.sex}`)
					$("#info-4").html(`Approved licenses`)
					$("#infoDescription-4").css("color", `${data.documentOptions.color}`)
					$("#infoDescription-4").html(`${data.documentInfos.drive_boat}`)
				}
				if (data.type == "id_weapon") {
					$("#info-3").html(`Sex`)
					$("#infoDescription-3").css("color", `${data.documentOptions.color}`)
					$("#infoDescription-3").html(`${data.documentInfos.sex}`)
					$("#info-4").html(`License statusa`)
					$("#infoDescription-4").css("color", `${data.documentOptions.color}`)
					$("#infoDescription-4").html(`${data.documentInfos.weapon}`)
				}
				if (data.type == "id_law") {
					$("#info-3").html(`Sex`)
					$("#infoDescription-3").css("color", `${data.documentOptions.color}`)
					$("#infoDescription-3").html(`${data.documentInfos.sex}`)
					$("#info-4").html(`License statusa`)
					$("#infoDescription-4").css("color", `${data.documentOptions.color}`)
					$("#infoDescription-4").html(`${data.documentInfos.jaber}`)
				}
				$(".gradient").css("background", `radial-gradient(transparent 70%, ${data.documentOptions.color} 280%)`)

				$(".image").html(`<image class="playerMugshot" src="${data.playerImage}"></image>`)

				$(".documentName").css("color", `${data.documentOptions.color}`)
				$(".documentName").html(`${data.documentOptions.header}`)

				$(".material-symbols-outlined").css("color", `${data.documentOptions.color}`)
				$(".material-symbols-outlined").html(`${data.documentOptions.icon}`)

				$(".topWavePath").css("fill", `${data.documentOptions.color}94`)
				$(".bottomWavePath").css("fill", `${data.documentOptions.color}94`)
			} 
			
		break;
		case 'close':
			$(".document").fadeOut(285)
		break;
  	}
})