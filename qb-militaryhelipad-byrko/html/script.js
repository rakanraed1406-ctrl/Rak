const resourceName = GetParentResourceName ? GetParentResourceName() : 'qb-militaryhelipad-byrko';
let isOpened = false;

window.addEventListener('message', function(event) {
    let data = event.data;

    if (data.action === "open") {
        isOpened = true;
        let $app = $('#app');
        $app.css('display', 'block');
        setTimeout(() => { $app.addClass('active'); }, 10);
        
        // Shop Render
        let shopHtml = '';
        if (data.shopHelis && data.shopHelis.length > 0) {
            data.shopHelis.forEach(heli => {
                shopHtml += `
                    <div class="card">
                        <div class="card-info">
                            <h4>${heli.label}</h4>
                            <p>Price: $${heli.price.toLocaleString()}</p>
                        </div>
                        <button class="action-btn" onclick="buyHeli('${heli.model}', ${heli.price})">Purchase</button>
                    </div>
                `;
            });
        }
        $('#shop-list').html(shopHtml);

        // Nearby Helicopters Render
        let nearbyHtml = '';
        if (data.nearbyHelis && data.nearbyHelis.length > 0) {
            data.nearbyHelis.forEach(heli => {
                nearbyHtml += `
                    <div class="card" style="border-color: #3b82f6;">
                        <div class="card-info">
                            <h4>Model: ${heli.model.toUpperCase()}</h4>
                            <p>Plate: ${heli.plate}</p>
                        </div>
                        <button class="action-btn store-btn" onclick="storeSpecificHeli('${heli.plate}')">Store</button>
                    </div>
                `;
            });
        } else {
            nearbyHtml = '<div class="empty-msg">No nearby helicopters found.</div>';
        }
        $('#nearby-list').html(nearbyHtml);

        // Garage Render
        let garageHtml = '';
        if (data.ownedHelis && data.ownedHelis.length > 0) {
            data.ownedHelis.forEach(heli => {
                garageHtml += `
                    <div class="card">
                        <div class="card-info">
                            <h4>Model: ${heli.vehicle.toUpperCase()}</h4>
                            <p>Plate: ${heli.plate}</p>
                        </div>
                        <button class="action-btn" onclick="spawnOwnedHeli('${heli.plate}', '${heli.vehicle}')">Spawn</button>
                    </div>
                `;
            });
        } else {
            garageHtml = '<div class="empty-msg">You do not own any stored helicopters.</div>';
        }
        $('#garage-list').html(garageHtml);
    }
});

function switchTab(tabName) {
    $('.tab-btn').removeClass('active');
    $('.tab-content').removeClass('active');

    if (tabName === 'shop') {
        $('.tab-btn:eq(0)').addClass('active');
        $('#shop-content').addClass('active');
    } else {
        $('.tab-btn:eq(1)').addClass('active');
        $('#garage-content').addClass('active');
    }
}

function buyHeli(model, price) {
    $.post(`https://${resourceName}/buyHeli`, JSON.stringify({
        model: model,
        price: price
    }));
    closeMenu();
}

function spawnOwnedHeli(plate, vehicle) {
    $.post(`https://${resourceName}/spawnOwnedHeli`, JSON.stringify({
        plate: plate,
        vehicle: vehicle
    }));
    closeMenu();
}

function storeSpecificHeli(plate) {
    $.post(`https://${resourceName}/storeSpecificHeli`, JSON.stringify({
        plate: plate
    }));
    closeMenu();
}

function closeMenu() {
    if (!isOpened) return;
    isOpened = false;

    let $app = $('#app');
    $.post(`https://${resourceName}/close`, JSON.stringify({}));
    
    $app.removeClass('active');
    setTimeout(() => {
        $app.css('display', 'none');
    }, 300);
}

// زر الإغلاق
$(document).on('click', '#close-btn', function() {
    closeMenu();
});

// إغلاق بـ ESC
document.onkeyup = function(data) {
    if (data.key === "Escape") {
        closeMenu();
    }
};

// وظيفة البحث
function filterHelicopters() {
    let input = $('#search-input').val().toLowerCase();
    $('.card').each(function() {
        let text = $(this).text().toLowerCase();
        if (text.includes(input)) {
            $(this).show();
        } else {
            $(this).hide();
        }
    });
}