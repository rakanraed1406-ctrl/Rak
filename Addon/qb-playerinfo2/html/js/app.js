Floky = {}

window.addEventListener('message', function(event) {
    switch(event.data.action) {
      case "open":
        OpenUI(event.data.PlayerData)
        break;
    }
})

OpenUI = function (PlayerData) {
    $('.playername').html('')
    $('.playername').html('Welcome ' + PlayerData.charinfo.firstname + ' ' + PlayerData.charinfo.lastname )

    var PlayerPhoneNumber = PlayerData.charinfo.phone;
    var PlayerBankAcc = PlayerData.charinfo.account;
    var PlayerBankMoney = PlayerData.money.bank;
    var PlayerCashMoney = PlayerData.money.cash;
    var PlayerStateID = PlayerData.citizenid;
    var PlayerJob = PlayerData.job.name;
    var PlayerGrade = PlayerData.job.grade.name;
    var PlayerPayment = PlayerData.job.payment;
    var PlayerTotal = PlayerData.metadata.paycheck.amount;
    var PlayerMeta = PlayerData.metadata;

    JobsIcons = {
        ["police"]: "fa-solid fa-user-police-tie",
        ["sheriff"]: "fa-solid fa-badge-sheriff",
        ["tow"]: "fa-solid fa-truck-tow",
        ["garbage"]: "fa-solid fa-trash-can-list",
        ["taxi"]: "fa-solid fa-taxi",
    }
    CompanyIcons = {
        ["beanmachine"]: "fa-solid fa-cup-togo",
        ["atom"]: "fa-solid fa-burger",
    }

    if (PlayerJob == 'police' || PlayerJob == 'sheriff' || PlayerJob == 'ambulance') {
        $(".details-dutyh-class").show();
        $(".details-dispatchhors-class").show();
        $(".details-dutyh").show();
        $(".details-dispatchhors").show();
        $(".details-callsign").show();
        $(".details-callsign-class").show();
        $(".details-onduty-class").show();
        $(".details-onduty").show();
        $(".details-isdispatch-class").show();
        $(".details-isdispatch").show();
        $(".details-joblevel-class").hide();
        $(".details-joblevel").hide();
        $(".details-jobprogress-class").hide();
        $(".details-jobprogress").hide();

        if (PlayerJob == 'ambulance') {
            $(".details-phone").html(PlayerPhoneNumber)
            $(".details-bankserial").html(PlayerBankAcc)
            $(".details-bankmoney").html("$"+Math.floor(PlayerBankMoney))
            $(".details-cashmoney").html("$"+Math.floor(PlayerCashMoney))
            $(".details-stateid").html(PlayerStateID)
            $(".details-job").html(PlayerJob)
            $(".details-grade").html(PlayerGrade)
            $(".details-payment").html(PlayerPayment)
            $(".details-paycheck").html(PlayerTotal)
            $(".details-dutyh").html(PlayerMeta.ems.dutyhours)
            $(".details-dispatchhors").html(PlayerMeta.ems.dispatchpoints)
            if (PlayerMeta.ems.dispatch) {
                $(".details-isdispatch").html('<div class="details-license-icon-class"><i style="color: #87fadf;" class="fas fa-check-circle"></i></div>')
            } else {
                $(".details-isdispatch").html('<div class="details-license-icon-class"><i style="color: #fa745f;" class="fa-solid fa-circle-xmark"></i></div>')
            }
        } else {
            $(".details-phone").html(PlayerPhoneNumber)
            $(".details-bankserial").html(PlayerBankAcc)
            $(".details-bankmoney").html("$"+Math.floor(PlayerBankMoney))
            $(".details-cashmoney").html("$"+Math.floor(PlayerCashMoney))
            $(".details-stateid").html(PlayerStateID)
            $(".details-job").html(PlayerJob)
            $(".details-grade").html(PlayerGrade)
            $(".details-payment").html(PlayerPayment)
            $(".details-paycheck").html(PlayerTotal)
            $(".details-dutyh").html(PlayerMeta.cops.dutyhours)
            $(".details-dispatchhors").html(PlayerMeta.cops.dispatchpoints)
            if (PlayerMeta.cops.dispatch) {
                $(".details-isdispatch").html('<div class="details-license-icon-class"><i style="color: #87fadf;" class="fas fa-check-circle"></i></div>')
            } else {
                $(".details-isdispatch").html('<div class="details-license-icon-class"><i style="color: #fa745f;" class="fa-solid fa-circle-xmark"></i></div>')
            }
        }
        $(".details-callsign").html(PlayerMeta.callsign)
        if (PlayerData.job.onduty) {
            $(".details-onduty").html('<div class="details-license-icon-class"><i style="color: #87fadf;" class="fas fa-check-circle"></i></div>')
        } else {
            $(".details-onduty").html('<div class="details-license-icon-class"><i style="color: #fa745f;" class="fa-solid fa-circle-xmark"></i></div>')
        }
    } else {
        $(".details-dutyh-class").hide();
        $(".details-dispatchhors-class").hide();
        $(".details-dutyh").hide();
        $(".details-dispatchhors").hide();
        $(".details-callsign").hide();
        $(".details-callsign-class").hide();
        $(".details-onduty-class").hide();
        $(".details-onduty").hide();
        $(".details-isdispatch-class").hide();
        $(".details-isdispatch").hide();
        
        $(".details-phone").html(PlayerPhoneNumber)
        $(".details-bankserial").html(PlayerBankAcc)
        $(".details-bankmoney").html("$"+Math.floor(PlayerBankMoney))
        $(".details-cashmoney").html("$"+Math.floor(PlayerCashMoney))
        $(".details-stateid").html(PlayerStateID)
        $(".details-job").html(PlayerJob)
        $(".details-grade").html(PlayerGrade)
        $(".details-payment").html(PlayerPayment)
        $(".details-paycheck").html(PlayerTotal)
    }

    if (PlayerMeta.timeplayedh <= 9) {
        PlayerMeta.timeplayedh = "0"+ PlayerMeta.timeplayedh +""
    }
    if (PlayerMeta.timeplayedm <= 9) {
        PlayerMeta.timeplayedm = "0"+ PlayerMeta.timeplayedm +""
    }

    $(".details-timeplayed").html("H "+ PlayerMeta.timeplayedh +" : M "+ PlayerMeta.timeplayedm +"")
    $(".details-company").html(PlayerData.company.name)

    if (JobsIcons[PlayerJob]) {
        $(".details-job-icon").html('<i class="'+JobsIcons[PlayerJob]+'"></i>');
    } else {
        $(".details-job-icon").html('<i class="fa-solid fa-briefcase"></i>');
    }
    if (CompanyIcons[PlayerData.company.name]) {
        $(".details-company-icon").html('<i class="'+CompanyIcons[PlayerData.company.name]+'"></i>');
    } else {
        $(".details-company-icon").html('<i class="fa-solid fa-briefcase-blank"></i>');
    }

    $("#jobsinfo-tow").html('<i style="color: #f3f3f3;" class="fa-light fa-truck-tow"></i>');
    $("#jobsinfo-header-progress-tow").html("Current Progress : " + Math.floor(PlayerData.metadata.jobrep.tow.progress) + " %");
    $("#jobsinfo-header-tier-tow").html("Level : " + Math.floor(PlayerData.metadata.jobrep.tow.grade));
    $(".jobsinfo-header-progress-fill-tow").css("width", Math.floor(PlayerData.metadata.jobrep.tow.progress) + "%");
    
    $("#jobsinfo-taxi").html('<i style="color: #f3f3f3;" class="fa-regular fa-taxi"></i>');
    $("#jobsinfo-header-progress-taxi").html("Current Progress : " + Math.floor(PlayerData.metadata.jobrep.taxi.progress) + " %");
    $("#jobsinfo-header-tier-taxi").html("Level : " + Math.floor(PlayerData.metadata.jobrep.taxi.grade));
    $(".jobsinfo-header-progress-fill-taxi").css("width", Math.floor(PlayerData.metadata.jobrep.taxi.progress) + "%");
    
    $("#jobsinfo-garbage").html('<i style="color: #f3f3f3;" class="fa-duotone fa-trash-can-list"></i>');
    $("#jobsinfo-header-progress-garbage").html("Current Progress : " + Math.floor(PlayerData.metadata.jobrep.garbage.progress) + " %");
    $("#jobsinfo-header-tier-garbage").html("Level : " + Math.floor(PlayerData.metadata.jobrep.garbage.grade));
    $(".jobsinfo-header-progress-fill-garbage").css("width", Math.floor(PlayerData.metadata.jobrep.garbage.progress) + "%");

    $("#jobsinfo-recycle").html('<i style="color: #f3f3f3;" class="fas fa-recycle"></i>');
    $("#jobsinfo-header-progress-recycle").html("Current Progress : " + Math.floor(PlayerData.metadata.recycle.progress) + " %");
    $("#jobsinfo-header-tier-recycle").html("Level : " + Math.floor(PlayerData.metadata.recycle.grade));
    $(".jobsinfo-header-progress-fill-recycle").css("width", Math.floor(PlayerData.metadata.recycle.progress) + "%");


    $("#lester-moneywash").html('Money wash');
    $("#lester-header-progress-moneywash").html("Current Progress : " + Math.floor(PlayerData.metadata.crime.smallmoneywash.progress) + " %");
    $("#lester-header-tier-moneywash").html("Level : " + Math.floor(PlayerData.metadata.crime.smallmoneywash.grade));
    $(".lester-header-progress-fill-moneywash").css("width", Math.floor(PlayerData.metadata.crime.smallmoneywash.progress) + "%");

    $("#lester-storerobbery").html('Store Robbery');
    $("#lester-header-progress-storerobbery").html("Current Progress : " + Math.floor(PlayerData.metadata.crime.storerobbery.progress) + " %");
    $("#lester-header-tier-storerobbery").html("Level : " + Math.floor(PlayerData.metadata.crime.storerobbery.grade));
    $(".lester-header-progress-fill-storerobbery").css("width", Math.floor(PlayerData.metadata.crime.storerobbery.progress) + "%");

    $("#lester-moneystorm").html('Money Storm');
    $("#lester-header-progress-moneystorm").html("Current Progress : " + Math.floor(PlayerData.metadata.crime.lester.moneystorm.progress) + " %");
    $("#lester-header-tier-moneystorm").html("Level : " + Math.floor(PlayerData.metadata.crime.lester.moneystorm.grade));
    $(".lester-header-progress-fill-moneystorm").css("width", Math.floor(PlayerData.metadata.crime.lester.moneystorm.progress) + "%");

    $('[data-toggle="tooltip"]').tooltip();

    $('.maincontainer').fadeIn(120)
}

$('#exitvendors').click(function () { 
    CloseUI()
});

CloseUI = function () {
    $('.maincontainer').fadeOut(120)
    $.post(`https://`+GetParentResourceName()+'/close', JSON.stringify({}));
};

$(document).on('click', '#icon', function(event){
    event.preventDefault();
    var location = $(this).attr('data');
    $.post('https://qb-playerinfo/SetLocation', JSON.stringify({
        location: location,
    }));
});

$(document).on('keydown', function(){
    switch(event.keyCode) {
    case 27: // control
        CloseUI()
    }
});