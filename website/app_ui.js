// =============================================================================
// PHAROAH ERP - UI & MODAL CONTROLLER (CONNECTED WITH ENGINE & NO-FREEZE UI)
// =============================================================================

let activeSaleSession = {
    billNo: "INV-1001",
    billDate: "",
    paymentMode: "CASH",
    selectedParty: null,
    cartItems: [],
    extraDiscount: 0.0,
    roundOff: 0.0,
    grandTotal: 0.0
};

let activePurchaseCart = [];
let activeEditingMed = null;
let lastSavedDoc = null;

document.addEventListener("DOMContentLoaded", async () => {
    loadLocalState();
    window.erpEngine.rebuildAllInventory();
    populateAllDatalists();
    updateDashboardStats();
    
    // Set default dates
    const today = new Date().toISOString().split('T')[0];
    ["saleBillDate", "purBillDate", "purEntryDate", "chDate", "retDate", "vouchDate", "daybookDate"].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.value = today;
    });

    // Auto pull from Google Drive
    if (window.GoogleDriveSync && GoogleDriveSync.config.apiUrl) {
        const cloud = await GoogleDriveSync.pullFromDrive();
        if (cloud) {
            Object.assign(window.erpEngine, cloud);
            window.erpEngine.rebuildAllInventory();
            saveLocalState();
            populateAllDatalists();
            updateDashboardStats();
        }
    }
});

// View Navigation Switcher
function showScreen(screenId) {
    document.querySelectorAll("main > section").forEach(sec => sec.style.display = "none");
    document.querySelectorAll(".nav-chip").forEach(btn => btn.classList.remove("active"));

    const sec = document.getElementById(screenId);
    if (sec) sec.style.display = "block";

    if (screenId === 'view-daybook') renderDaybook();
    if (screenId === 'view-ledgers') renderLedgers();
    if (screenId === 'view-stock') renderStock();
    if (screenId === 'view-challans') renderChallans();
    if (screenId === 'view-returns') renderReturns();
    if (screenId === 'view-masters') renderMastersList();
}

function returnToDashboard() {
    showScreen('view-dashboard');
}

// =============================================================================
// SALE INVOICE FLOW (STEP 1 & STEP 2)
// =============================================================================

function startSaleWorkflow() {
    const nextNo = window.erpEngine.getNextNumber('SALE');
    activeSaleSession = {
        billNo: nextNo,
        billDate: new Date().toISOString().split('T')[0],
        paymentMode: "CASH",
        selectedParty: null,
        cartItems: [],
        extraDiscount: 0.0,
        roundOff: 0.0,
        grandTotal: 0.0
    };

    document.getElementById("saleBillNo").value = nextNo;
    document.getElementById("saleBillDate").value = activeSaleSession.billDate;
    document.getElementById("salePartySearch").value = "";
    document.getElementById("selectedPartyCard").style.display = "none";
    setSaleMode('CASH');

    showScreen('view-sale-step1');
}

function setSaleMode(mode) {
    activeSaleSession.paymentMode = mode;
    document.getElementById("modeCashBtn")?.classList.toggle("active", mode === "CASH");
    document.getElementById("modeCreditBtn")?.classList.toggle("active", mode === "CREDIT");
}

function onSalePartySelected(name) {
    const p = window.erpEngine.parties.find(x => x.name.toUpperCase() === name.trim().toUpperCase());
    if (p) {
        activeSaleSession.selectedParty = p;
        document.getElementById("previewPartyName").innerText = p.name;
        document.getElementById("previewPartyMeta").innerText = `City: ${p.city} | GST: ${p.gst || 'N/A'} | Balance: ₹ ${p.opBal.toFixed(2)}`;
        document.getElementById("selectedPartyCard").style.display = "flex";
    }
}

function clearSaleParty() {
    activeSaleSession.selectedParty = null;
    document.getElementById("salePartySearch").value = "";
    document.getElementById("selectedPartyCard").style.display = "none";
}

function proceedToSaleStep2() {
    if (!activeSaleSession.selectedParty) {
        const cashP = window.erpEngine.parties.find(p => p.name.includes("CASH")) || window.erpEngine.parties[0];
        activeSaleSession.selectedParty = cashP;
    }

    document.getElementById("billingHeaderTitle").innerText = `TAX INVOICE: ${activeSaleSession.billNo}`;
    document.getElementById("billingHeaderParty").innerText = `Party: ${activeSaleSession.selectedParty.name} | Date: ${activeSaleSession.billDate} | Mode: ${activeSaleSession.paymentMode}`;

    renderSaleCart();
    showScreen('view-sale-step2');
}

// Product Search & Selection (No prompt!)
function openProductSearchModal() {
    renderProductSearchList("");
    document.getElementById("productSearchModal").classList.add("active");
    document.getElementById("prodLiveSearchInput").focus();
}

function closeProductSearchModal() {
    document.getElementById("productSearchModal").classList.remove("active");
}

function filterProductSearchList(query) {
    renderProductSearchList(query.toLowerCase());
}

function renderProductSearchList(query) {
    const listEl = document.getElementById("productSearchListContainer");
    if (!listEl) return;
    listEl.innerHTML = "";

    window.erpEngine.medicines.filter(m => m.name.toLowerCase().includes(query) || m.systemId.toLowerCase().includes(query)).forEach(m => {
        listEl.innerHTML += `
            <div class="picker-item-row" onclick="selectProductForBilling('${m.id}')">
                <div>
                    <strong style="color:var(--text-light);">${m.name}</strong>
                    <div style="font-size:0.75rem; color:var(--text-muted);">${m.packing} | Code: ${m.systemId}</div>
                </div>
                <div style="text-align:right;">
                    <div style="color:var(--accent-emerald); font-weight:bold;">Stock: ${m.stock}</div>
                    <div style="font-size:0.75rem; color:var(--text-muted);">MRP: ₹ ${m.mrp.toFixed(2)}</div>
                </div>
            </div>
        `;
    });
}

function selectProductForBilling(medId) {
    closeProductSearchModal();
    const med = window.erpEngine.medicines.find(m => m.id === medId);
    if (!med) return;

    activeEditingMed = med;
    const batches = window.erpEngine.batchHistory[med.systemId || med.id] || [];

    document.getElementById("entryModalProdTitle").innerText = `${med.name} (${med.packing})`;
    document.getElementById("eBatch").value = batches.length > 0 ? batches[0].batch : "DL-101";
    document.getElementById("eExp").value = batches.length > 0 ? batches[0].exp : "12/28";
    document.getElementById("eMrp").value = med.mrp.toFixed(2);
    document.getElementById("eRate").value = med.rateA.toFixed(2);
    document.getElementById("eGst").value = med.gst;
    document.getElementById("eQty").value = 1;
    document.getElementById("eFree").value = 0;
    document.getElementById("eDiscPer").value = 0.0;
    document.getElementById("eDiscAmt").value = 0.0;
    document.getElementById("eRateTier").value = "A";
    document.getElementById("eRateCDiscBox").style.display = "none";

    syncDiscountInputs('percent');
    document.getElementById("itemEntryModal").classList.add("active");
}

function closeItemEntryModal() {
    document.getElementById("itemEntryModal").classList.remove("active");
}

function onRateTierChanged(tier) {
    if (!activeEditingMed) return;
    const cBox = document.getElementById("eRateCDiscBox");
    if (tier === "A") {
        document.getElementById("eRate").value = activeEditingMed.rateA.toFixed(2);
        cBox.style.display = "none";
    } else if (tier === "B") {
        document.getElementById("eRate").value = activeEditingMed.rateB.toFixed(2);
        cBox.style.display = "none";
    } else if (tier === "C") {
        cBox.style.display = "block";
        calculateRateCFormula();
    }
    syncDiscountInputs('percent');
}

function calculateRateCFormula() {
    const mrp = parseFloat(document.getElementById("eMrp").value) || 0;
    const gst = parseFloat(document.getElementById("eGst").value) || 12;
    const cDisc = parseFloat(document.getElementById("eRateCDisc").value) || 0;

    const baseTaxable = mrp / (1 + (gst / 100));
    const rateC = baseTaxable - (baseTaxable * (cDisc / 100));
    document.getElementById("eRate").value = rateC.toFixed(2);
    syncDiscountInputs('percent');
}

function syncDiscountInputs(source) {
    const qty = parseFloat(document.getElementById("eQty").value) || 1;
    const rate = parseFloat(document.getElementById("eRate").value) || 0;
    const gst = parseFloat(document.getElementById("eGst").value) || 0;
    const gross = qty * rate;

    let discAmt = 0;
    if (source === 'percent') {
        const discPer = parseFloat(document.getElementById("eDiscPer").value) || 0;
        discAmt = gross * (discPer / 100);
        document.getElementById("eDiscAmt").value = discAmt.toFixed(2);
    } else {
        discAmt = parseFloat(document.getElementById("eDiscAmt").value) || 0;
        const discPer = gross > 0 ? (discAmt / gross) * 100 : 0;
        document.getElementById("eDiscPer").value = discPer.toFixed(2);
    }

    const taxable = gross - discAmt;
    const total = taxable * (1 + (gst / 100));
    document.getElementById("eNetTotalDisplay").innerText = `₹ ${total.toFixed(2)}`;
}

function confirmAndAddItemToCart() {
    if (!activeEditingMed) return;

    const batch = document.getElementById("eBatch").value.trim() || "DL-101";
    const exp = document.getElementById("eExp").value.trim() || "12/28";
    const mrp = parseFloat(document.getElementById("eMrp").value) || 0;
    const rate = parseFloat(document.getElementById("eRate").value) || 0;
    const qty = parseFloat(document.getElementById("eQty").value) || 1;
    const free = parseFloat(document.getElementById("eFree").value) || 0;
    const discPer = parseFloat(document.getElementById("eDiscPer").value) || 0;
    const discAmt = parseFloat(document.getElementById("eDiscAmt").value) || 0;
    const gst = parseFloat(document.getElementById("eGst").value) || 0;

    const gross = qty * rate;
    const taxable = gross - discAmt;
    const total = taxable * (1 + (gst / 100));

    activeSaleSession.cartItems.push({
        srNo: activeSaleSession.cartItems.length + 1,
        medicineID: activeEditingMed.systemId || activeEditingMed.id,
        name: activeEditingMed.name,
        packing: activeEditingMed.packing,
        batch, exp, hsn: activeEditingMed.hsnCode || "3004",
        mrp, rate, qty, freeQty: free, gstRate: gst,
        discountPer: discPer, discountRupees: discAmt, total
    });

    closeItemEntryModal();
    renderSaleCart();
}

function renderSaleCart() {
    const tbody = document.getElementById("saleCartTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";

    activeSaleSession.cartItems.forEach((it, idx) => {
        it.srNo = idx + 1;
        tbody.innerHTML += `
            <tr>
                <td>${it.srNo}</td>
                <td><strong>${it.name}</strong></td>
                <td>${it.packing}</td>
                <td>${it.batch}</td>
                <td>${it.exp}</td>
                <td>${it.qty} + ${it.freeQty}</td>
                <td>₹ ${it.rate.toFixed(2)}</td>
                <td>${it.discountPer.toFixed(1)}%</td>
                <td>${it.gstRate}%</td>
                <td><strong>₹ ${it.total.toFixed(2)}</strong></td>
                <td><button class="btn btn-danger-sm" onclick="removeSaleCartRow(${idx})">✕</button></td>
            </tr>
        `;
    });

    recalculateBillTotals();
}

function removeSaleCartRow(idx) {
    activeSaleSession.cartItems.splice(idx, 1);
    renderSaleCart();
}

function recalculateBillTotals() {
    const itemsTotal = activeSaleSession.cartItems.reduce((sum, it) => sum + it.total, 0);
    const extraDisc = parseFloat(document.getElementById("saleExtraDiscount")?.value) || 0.0;
    
    const rawTotal = itemsTotal - extraDisc;
    const grandTotal = Math.round(rawTotal);
    const roundOff = grandTotal - rawTotal;

    activeSaleSession.extraDiscount = extraDisc;
    activeSaleSession.roundOff = roundOff;
    activeSaleSession.grandTotal = grandTotal;

    document.getElementById("sumItemsTotal").innerText = `₹ ${itemsTotal.toFixed(2)}`;
    document.getElementById("sumRoundOff").innerText = `₹ ${roundOff.toFixed(2)}`;
    document.getElementById("sumGrandTotal").innerText = `₹ ${grandTotal.toFixed(2)}`;
}

// Save Sale Bill & Open Non-Blocking Print Modal
function saveSaleBill() {
    if (activeSaleSession.cartItems.length === 0) {
        alert("Cart is empty! Please add at least 1 item.");
        return;
    }

    const saleRecord = {
        id: "SALE_" + Date.now(),
        billNo: activeSaleSession.billNo,
        partyId: activeSaleSession.selectedParty?.id || "p_cash",
        partyName: activeSaleSession.selectedParty?.name || "CASH CUSTOMER",
        partyGstin: activeSaleSession.selectedParty?.gst || "N/A",
        partyState: activeSaleSession.selectedParty?.state || "Rajasthan",
        date: activeSaleSession.billDate,
        paymentMode: activeSaleSession.paymentMode,
        items: [...activeSaleSession.cartItems],
        totalAmount: activeSaleSession.grandTotal,
        extraDiscount: activeSaleSession.extraDiscount,
        roundOff: activeSaleSession.roundOff,
        status: "Active"
    };

    window.erpEngine.sales.push(saleRecord);
    window.erpEngine.rebuildAllInventory();

    saveLocalState();
    updateDashboardStats();

    if (window.GoogleDriveSync) {
        GoogleDriveSync.pushToDrive(window.erpEngine);
    }

    lastSavedDoc = saleRecord;

    document.getElementById("successModalTitle").innerText = `INVOICE ${saleRecord.billNo} SAVED!`;
    document.getElementById("successModalSub").innerText = `Total: ₹ ${saleRecord.totalAmount.toFixed(2)} | Live Synced with Google Drive`;
    document.getElementById("billSuccessModal").classList.add("active");
}

function triggerDirectPrint(format) {
    if (!lastSavedDoc) return;
    const printArea = document.getElementById("printArea");
    printArea.innerHTML = `
        <div style="padding: 20px; font-family: sans-serif; max-width: ${format === 'Thermal' ? '300px' : '800px'}; margin: 0 auto;">
            <h2 style="text-align: center; margin-bottom: 2px;">PHAROAH ERP - TAX INVOICE</h2>
            <p style="text-align: center; font-size: 11px; margin-bottom: 10px;">ARCHITECT INVOICING SERIES</p>
            <hr/>
            <p><strong>Invoice No:</strong> ${lastSavedDoc.billNo} | <strong>Date:</strong> ${lastSavedDoc.date}</p>
            <p><strong>Customer:</strong> ${lastSavedDoc.partyName} (GST: ${lastSavedDoc.partyGstin})</p>
            <hr/>
            <table style="width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 11px;">
                <thead>
                    <tr style="border-bottom: 1px solid #000;">
                        <th style="text-align: left;">Item</th><th>Batch</th><th>Qty</th><th>Rate</th><th>Total</th>
                    </tr>
                </thead>
                <tbody>
                    ${lastSavedDoc.items.map(i => `
                        <tr>
                            <td>${i.name} (${i.packing})</td>
                            <td style="text-align: center;">${i.batch}</td>
                            <td style="text-align: center;">${i.qty}+${i.freeQty}</td>
                            <td style="text-align: right;">₹${i.rate.toFixed(2)}</td>
                            <td style="text-align: right;">₹${i.total.toFixed(2)}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
            <hr/>
            <div style="text-align: right; font-size: 12px; line-height: 1.5;">
                <p>Extra Discount: -₹${lastSavedDoc.extraDiscount.toFixed(2)}</p>
                <p>Round Off: ₹${lastSavedDoc.roundOff.toFixed(2)}</p>
                <h3 style="font-size: 15px;">NET PAYABLE: ₹${lastSavedDoc.totalAmount.toFixed(2)}</h3>
            </div>
        </div>
    `;
    window.print();
}

function dismissSuccessAndNewBill() {
    document.getElementById("billSuccessModal").classList.remove("active");
    startSaleWorkflow();
}

// =============================================================================
// PURCHASES, CHALLANS, RETURNS, VOUCHERS, DAYBOOK, LEDGERS & MASTERS
// =============================================================================

function initNewPurchaseSession() {
    const nextNo = window.erpEngine.getNextNumber('PURCHASE');
    document.getElementById("purInternalNo").value = nextNo;
    activePurchaseCart = [];
    renderPurCart();
}

function addPurchaseCartItem() {
    const name = document.getElementById("purItemName").value.trim();
    const batch = document.getElementById("purBatch").value.trim() || "B-01";
    const exp = document.getElementById("purExp").value.trim() || "12/28";
    const mrp = parseFloat(document.getElementById("purMrp").value) || 0;
    const rate = parseFloat(document.getElementById("purRate").value) || 0;
    const qty = parseFloat(document.getElementById("purQty").value) || 1;
    const free = parseFloat(document.getElementById("purFree").value) || 0;
    const gst = parseFloat(document.getElementById("purGst").value) || 12;

    if (!name || rate <= 0) { alert("Please enter valid product and rate!"); return; }

    const gross = qty * rate;
    const total = gross * (1 + (gst / 100));

    activePurchaseCart.push({
        srNo: activePurchaseCart.length + 1,
        name, batch, exp, mrp, purchaseRate: rate, qty, freeQty: free, gstRate: gst, total
    });

    renderPurCart();
    document.getElementById("purItemName").value = "";
}

function renderPurCart() {
    const tbody = document.getElementById("purCartTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";
    let grandTotal = 0;

    activePurchaseCart.forEach((it, idx) => {
        grandTotal += it.total;
        tbody.innerHTML += `
            <tr>
                <td>${idx + 1}</td>
                <td><strong>${it.name}</strong></td>
                <td>${it.batch}</td>
                <td>${it.exp}</td>
                <td>₹ ${it.mrp.toFixed(2)}</td>
                <td>₹ ${it.purchaseRate.toFixed(2)}</td>
                <td>${it.qty} + ${it.freeQty}</td>
                <td>${it.gstRate}%</td>
                <td><strong>₹ ${it.total.toFixed(2)}</strong></td>
                <td><button class="btn btn-danger-sm" onclick="activePurchaseCart.splice(${idx},1); renderPurCart();">✕</button></td>
            </tr>
        `;
    });

    document.getElementById("purGrandTotal").innerText = `₹ ${grandTotal.toFixed(2)}`;
}

function savePurchaseInward() {
    const supplier = document.getElementById("purSupplierSearch").value.trim();
    const billNo = document.getElementById("purBillNo").value.trim();
    if (!supplier || !billNo || activePurchaseCart.length === 0) {
        alert("Please enter Supplier, Bill No and at least 1 item.");
        return;
    }

    const purRecord = {
        id: "PUR_" + Date.now(),
        internalNo: document.getElementById("purInternalNo").value,
        billNo, distributorName: supplier,
        date: document.getElementById("purBillDate").value,
        entryDate: document.getElementById("purEntryDate").value,
        paymentMode: document.getElementById("purPayMode").value,
        items: [...activePurchaseCart],
        totalAmount: activePurchaseCart.reduce((sum, i) => sum + i.total, 0)
    };

    window.erpEngine.purchases.push(purRecord);
    window.erpEngine.rebuildAllInventory();

    saveLocalState();
    updateDashboardStats();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(window.erpEngine);

    alert("✅ Inward Stock Saved and Live Inventory Updated!");
    initNewPurchaseSession();
    returnToDashboard();
}

function renderDaybook() {
    const tbody = document.getElementById("daybookTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";
    const filterDate = document.getElementById("daybookFilterDate").value || new Date().toISOString().split('T')[0];

    window.erpEngine.sales.filter(s => s.date === filterDate && s.status === 'Active').forEach(s => {
        tbody.innerHTML += `<tr><td>${s.date}</td><td><span style="color:var(--accent-emerald); font-weight:bold;">SALE</span></td><td>${s.partyName}</td><td>${s.billNo}</td><td>₹ ${s.totalAmount.toFixed(2)}</td><td>-</td></tr>`;
    });
    window.erpEngine.purchases.filter(p => p.date === filterDate).forEach(p => {
        tbody.innerHTML += `<tr><td>${p.date}</td><td><span style="color:var(--accent-orange); font-weight:bold;">PURCHASE</span></td><td>${p.distributorName}</td><td>${p.billNo}</td><td>-</td><td>₹ ${p.totalAmount.toFixed(2)}</td></tr>`;
    });
    window.erpEngine.vouchers.filter(v => v.date === filterDate && v.status === 'Active').forEach(v => {
        const isRec = v.type === "RECEIPT";
        tbody.innerHTML += `<tr><td>${v.date}</td><td><span style="color:${isRec ? 'var(--accent-emerald)' : 'var(--accent-red)'}; font-weight:bold;">${v.type}</span></td><td>${v.partyName}</td><td>${v.voucherNo}</td><td>${isRec ? '₹ ' + v.amount.toFixed(2) : '-'}</td><td>${!isRec ? '₹ ' + v.amount.toFixed(2) : '-'}</td></tr>`;
    });
}

function renderLedgers() {
    const tbody = document.getElementById("ledgerTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";
    const query = document.getElementById("ledgerSearchParty").value.toLowerCase().trim();

    window.erpEngine.sales.filter(s => s.partyName.toLowerCase().includes(query) && s.status === 'Active').forEach(s => {
        tbody.innerHTML += `<tr><td>${s.date}</td><td>Sale Invoice #${s.billNo}</td><td>SALE</td><td>₹ ${s.totalAmount.toFixed(2)}</td><td>-</td><td>₹ ${s.totalAmount.toFixed(2)} Dr</td></tr>`;
    });
    window.erpEngine.vouchers.filter(v => v.partyName.toLowerCase().includes(query) && v.status === 'Active').forEach(v => {
        const isRec = v.type === "RECEIPT";
        tbody.innerHTML += `<tr><td>${v.date}</td><td>${v.type} Voucher #${v.voucherNo}</td><td>${v.type}</td><td>${!isRec ? '₹ ' + v.amount.toFixed(2) : '-'}</td><td>${isRec ? '₹ ' + v.amount.toFixed(2) : '-'}</td><td>-</td></tr>`;
    });
}

function renderStock() {
    const tbody = document.getElementById("stockTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";
    const query = document.getElementById("stockSearchInput").value.toLowerCase().trim();

    window.erpEngine.medicines.filter(m => m.name.toLowerCase().includes(query) || (m.systemId && m.systemId.toLowerCase().includes(query))).forEach(m => {
        tbody.innerHTML += `
            <tr>
                <td><span class="tag-badge">${m.systemId}</span></td>
                <td><strong>${m.name}</strong></td>
                <td>${m.packing}</td>
                <td>${m.batch || 'DL-101'}</td>
                <td>${m.exp || '12/28'}</td>
                <td>₹ ${m.mrp.toFixed(2)}</td>
                <td>₹ ${m.purRate.toFixed(2)}</td>
                <td>₹ ${m.rateA.toFixed(2)}</td>
                <td><strong style="color:var(--accent-emerald); font-size:1.05rem;">${m.stock}</strong></td>
            </tr>
        `;
    });
}

function renderMastersList() {
    populateAllDatalists();
}

function saveNewProductMaster() {
    const name = document.getElementById("mProdName").value.trim().toUpperCase();
    const pack = document.getElementById("mProdPack").value.trim().toUpperCase();
    const mrp = parseFloat(document.getElementById("mProdMrp").value) || 0;
    const purRate = parseFloat(document.getElementById("mProdPurRate").value) || 0;
    const rateA = parseFloat(document.getElementById("mProdRateA").value) || 0;
    const gst = parseFloat(document.getElementById("mProdGst").value) || 12;

    if (!name || !pack) { alert("Product name and packing are required!"); return; }

    const sysId = `PH-${10001 + window.erpEngine.medicines.length}`;
    window.erpEngine.medicines.push({
        id: sysId, systemId: sysId, name, packing: pack, hsnCode: "3004", gst, mrp, purRate, rateA, rateB: rateA * 0.95, rateC: rateA * 0.92, stock: 0
    });

    window.erpEngine.rebuildAllInventory();
    saveLocalState();
    populateAllDatalists();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(window.erpEngine);

    alert(`✅ Product ${name} saved with System ID ${sysId}`);
    document.getElementById("mProdName").value = "";
    document.getElementById("mProdPack").value = "";
}

function saveNewPartyMaster() {
    const name = document.getElementById("mPartyName").value.trim().toUpperCase();
    const group = document.getElementById("mPartyGroup").value;
    const gst = document.getElementById("mPartyGst").value.trim().toUpperCase() || "N/A";
    const city = document.getElementById("mPartyCity").value.trim().toUpperCase() || "LOCAL";
    const phone = document.getElementById("mPartyPhone").value.trim();
    const opBal = parseFloat(document.getElementById("mPartyOpBal").value) || 0.0;

    if (!name) { alert("Party Name is required!"); return; }

    window.erpEngine.parties.push({
        id: "p_" + Date.now(), name, group, gst, city, state: "Rajasthan", phone, opBal
    });

    saveLocalState();
    populateAllDatalists();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(window.erpEngine);

    alert(`✅ Party ${name} registered in ${group}`);
    document.getElementById("mPartyName").value = "";
}

function populateAllDatalists() {
    const pList = document.getElementById("partyDatalist");
    if (pList) pList.innerHTML = window.erpEngine.parties.map(p => `<option value="${p.name}"></option>`).join('');
    const iList = document.getElementById("itemDatalist");
    if (iList) iList.innerHTML = window.erpEngine.medicines.map(m => `<option value="${m.name}"></option>`).join('');
}

function updateDashboardStats() {
    const today = new Date().toISOString().split('T')[0];
    const totalSale = window.erpEngine.sales.filter(s => s.date === today && s.status === 'Active').reduce((sum, s) => sum + s.totalAmount, 0);
    const totalPur = window.erpEngine.purchases.filter(p => p.date === today).reduce((sum, p) => sum + p.totalAmount, 0);
    const stockVal = window.erpEngine.medicines.reduce((sum, m) => sum + (Math.max(0, m.stock) * m.purRate), 0);

    document.getElementById("kpi-sale").innerText = `₹ ${totalSale.toFixed(2)}`;
    document.getElementById("kpi-pur").innerText = `₹ ${totalPur.toFixed(2)}`;
    document.getElementById("kpi-stock").innerText = `₹ ${stockVal.toFixed(2)}`;
}

function saveLocalState() {
    localStorage.setItem("pharoah_erp_v4_db", JSON.stringify(window.erpEngine));
}

function loadLocalState() {
    const saved = localStorage.getItem("pharoah_erp_v4_db");
    if (saved) {
        try { Object.assign(window.erpEngine, JSON.parse(saved)); } catch(e) {}
    }
}

function formatExpiryField(input) {
    let v = input.value.replace(/[^0-9]/g, '');
    if (v.length >= 2 && !input.value.includes('/')) v = v.substring(0, 2) + '/' + v.substring(2);
    if (v.length > 5) v = v.substring(0, 5);
    input.value = v;
}
