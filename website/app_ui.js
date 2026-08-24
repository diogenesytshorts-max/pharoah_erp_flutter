// =============================================================================
// PHAROAH ERP - RELIABLE IPAD-TOUCH COMPLIANT UI & ITEM SELECTION CONTROLLER
// =============================================================================

const DB_VERSION_KEY = "pharoah_erp_v10_touch_fixed_db";

let activeSaleSession = {
    billNo: "INV-1001",
    billDate: "",
    paymentMode: "CASH",
    seriesPrefix: "INV-",
    selectedParty: null,
    cartItems: [],
    extraDiscount: 0.0,
    roundOff: 0.0,
    grandTotal: 0.0
};

let activePurchaseCart = [];
let activeEditingMed = null;
let lastSavedDoc = null;
let syncIntervalId = null;

let stitcherSelectedParty = null;
let stitcherSelectedChallanIds = [];

document.addEventListener("DOMContentLoaded", async () => {
    try {
        purgeCorruptedLegacyStorage();
        loadLocalState();
        window.erpEngine.rebuildAllInventory();
        populateAllDatalists();
        initNewSaleSession();
        initNewPurchaseSession();
        initNewChallanSession();
        updateDashboardStats();
        syncCompanyHeaderWithAppState();

        const todayStr = new Date().toISOString().split('T')[0];
        const thirtyDaysAgo = new Date(Date.now() - 30*24*60*60*1000).toISOString().split('T')[0];

        const sFrom = document.getElementById("saleRegFromDate");
        const sTo = document.getElementById("saleRegToDate");
        const pFrom = document.getElementById("purRegFromDate");
        const pTo = document.getElementById("purRegToDate");
        const stDate = document.getElementById("stitcherBillDate");
        const dDate = document.getElementById("daybookFilterDate");

        if (sFrom) sFrom.value = thirtyDaysAgo;
        if (sTo) sTo.value = todayStr;
        if (pFrom) pFrom.value = thirtyDaysAgo;
        if (pTo) pTo.value = todayStr;
        if (stDate) stDate.value = todayStr;
        if (dDate) dDate.value = todayStr;

        await pullLatestFromDrive(true);

        if (syncIntervalId) clearInterval(syncIntervalId);
        syncIntervalId = setInterval(async () => {
            if (window.GoogleDriveSync && GoogleDriveSync.config.apiUrl) {
                await pullLatestFromDrive(true);
            }
        }, 30000);
    } catch (err) {
        console.error("DOM Init Error:", err);
    }
});

function syncCompanyHeaderWithAppState() {
    const comp = window.erpEngine.activeCompany || {
        id: "PH-C-101",
        name: "PHAROAH ERP",
        businessType: "WHOLESALE",
        fy: "2026-27"
    };

    const nameEl = document.getElementById("headerCompanyName");
    const idEl = document.getElementById("headerCompanyId");
    const typeEl = document.getElementById("headerBusinessType");
    const fyEl = document.getElementById("headerFyLabel");

    if (nameEl) nameEl.innerText = comp.name.toUpperCase();
    if (idEl) idEl.innerText = `ID: ${comp.id}`;
    if (typeEl) typeEl.innerText = comp.businessType.toUpperCase();
    if (fyEl) fyEl.innerText = `FY: ${comp.fy || '2026-27'}`;
}

function purgeCorruptedLegacyStorage() {
    const savedVer = localStorage.getItem("pharoah_version_check");
    if (savedVer !== DB_VERSION_KEY) {
        localStorage.removeItem("pharoah_web_state");
        localStorage.removeItem("pharoah_erp_v4_db");
        localStorage.removeItem("pharoah_erp_v7_locked_db");
        localStorage.removeItem("pharoah_erp_v8_billing_hub_db");
        localStorage.removeItem("pharoah_erp_v9_live_picker_db");
        localStorage.setItem("pharoah_version_check", DB_VERSION_KEY);
        window.erpEngine = new PharoahWebEngine();
        saveLocalState();
    }
}

function showScreen(screenId) {
    document.querySelectorAll("main > section").forEach(sec => sec.style.display = "none");
    const targetSec = document.getElementById(screenId);
    if (targetSec) targetSec.style.display = "block";

    if (screenId === 'view-sale-register') renderSaleRegister();
    if (screenId === 'view-purchase-register') renderPurchaseRegister();
    if (screenId === 'view-daybook') renderDaybook();
    if (screenId === 'view-ledgers') renderLedgers();
    if (screenId === 'view-stock') renderStock();
    if (screenId === 'view-challans') renderChallansRegister();
    if (screenId === 'view-returns') renderReturnsRegister();
}

function returnToDashboard() {
    showScreen('view-dashboard');
}

function startSaleWorkflow() {
    initNewSaleSession();
    renderSalePartyLiveList("");
    showScreen('view-sale-step1');
}

function initNewSaleSession() {
    const nextNo = window.erpEngine.getNextNumber('SALE');
    activeSaleSession = {
        billNo: nextNo,
        billDate: new Date().toISOString().split('T')[0],
        paymentMode: "CASH",
        seriesPrefix: "INV-",
        selectedParty: null,
        cartItems: [],
        extraDiscount: 0.0,
        roundOff: 0.0,
        grandTotal: 0.0
    };

    const billNoEl = document.getElementById("saleBillNo");
    const billDateEl = document.getElementById("saleBillDate");
    if (billNoEl) billNoEl.value = nextNo;
    if (billDateEl) billDateEl.value = activeSaleSession.billDate;

    clearSaleParty();
}

function updateSaleSeriesPrefix(prefix) {
    activeSaleSession.seriesPrefix = prefix;
    const seq = Math.floor(1000 + Math.random() * 9000);
    const billNo = `${prefix}${seq}`;
    activeSaleSession.billNo = billNo;
    const billNoEl = document.getElementById("saleBillNo");
    if (billNoEl) billNoEl.value = billNo;
}

function setSaleMode(mode) {
    activeSaleSession.paymentMode = mode;
    document.getElementById("modeCashBtn")?.classList.toggle("active", mode === "CASH");
    document.getElementById("modeCreditBtn")?.classList.toggle("active", mode === "CREDIT");
}

function filterSalePartyList(query) {
    renderSalePartyLiveList(query.toLowerCase().trim());
}

function renderSalePartyLiveList(query) {
    const container = document.getElementById("salePartyLiveListContainer");
    if (!container) return;
    container.innerHTML = "";

    const filtered = window.erpEngine.parties.filter(p => p.name.toLowerCase().includes(query) || (p.city && p.city.toLowerCase().includes(query)));

    if (filtered.length === 0) {
        container.innerHTML = `<div style="padding:10px; color:var(--text-muted); font-size:0.8rem; text-align:center;">No party found. Click '+ QUICK ADD PARTY' above.</div>`;
        return;
    }

    filtered.forEach(p => {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "picker-item-row";
        btn.style.width = "100%";
        btn.style.textAlign = "left";
        btn.innerHTML = `
            <div>
                <strong style="color:var(--text-light); font-size:0.9rem;">${p.name}</strong>
                <div style="font-size:0.75rem; color:var(--text-muted);">${p.city || 'LOCAL'} | GST: ${p.gst || 'N/A'}</div>
            </div>
            <div style="text-align:right;">
                <span class="badge-tag">${p.group || 'Sundry Debtors'}</span>
                <div style="font-size:0.75rem; color:var(--accent-cyan); margin-top:2px;">Bal: ₹ ${p.opBal.toFixed(2)}</div>
            </div>
        `;
        btn.onclick = () => selectSalePartyDirectly(p.id);
        container.appendChild(btn);
    });
}

function selectSalePartyDirectly(partyId) {
    const p = window.erpEngine.parties.find(x => x.id === partyId);
    if (!p) return;

    activeSaleSession.selectedParty = p;
    document.getElementById("previewPartyName").innerText = p.name;
    document.getElementById("previewPartyMeta").innerText = `City: ${p.city || 'LOCAL'} | GST: ${p.gst || 'N/A'} | Balance: ₹ ${p.opBal.toFixed(2)}`;
    document.getElementById("selectedPartyCard").style.display = "flex";
    document.getElementById("salePartyListWrapper").style.display = "none";
}

function onSalePartySelected(partyName) {
    const match = window.erpEngine.parties.find(p => p.name.toLowerCase() === partyName.trim().toLowerCase());
    if (match) {
        selectSalePartyDirectly(match.id);
    }
}

function clearSaleParty() {
    activeSaleSession.selectedParty = null;
    document.getElementById("salePartySearch").value = "";
    document.getElementById("selectedPartyCard").style.display = "none";
    document.getElementById("salePartyListWrapper").style.display = "block";
    renderSalePartyLiveList("");
}

function openQuickAddPartyModal(defaultGroup) {
    document.getElementById("qpName").value = "";
    document.getElementById("qpGroup").value = defaultGroup || "Sundry Debtors";
    document.getElementById("qpCity").value = "Jaipur";
    document.getElementById("qpPhone").value = "";
    document.getElementById("qpGst").value = "";
    document.getElementById("qpOpBal").value = "0.00";
    document.getElementById("quickAddPartyModal")?.classList.add("active");
}

function closeQuickAddPartyModal() {
    document.getElementById("quickAddPartyModal")?.classList.remove("active");
}

function saveQuickParty() {
    const name = document.getElementById("qpName").value.trim().toUpperCase();
    const group = document.getElementById("qpGroup").value;
    const city = document.getElementById("qpCity").value.trim().toUpperCase() || "LOCAL";
    const phone = document.getElementById("qpPhone").value.trim();
    const gst = document.getElementById("qpGst").value.trim().toUpperCase();
    const opBal = parseFloat(document.getElementById("qpOpBal").value) || 0.0;

    if (!name) { alert("Party Name is required!"); return; }

    const newParty = {
        id: "p_" + Date.now(),
        name, group, city, state: "Rajasthan", phone, gst, opBal
    };

    window.erpEngine.parties.push(newParty);
    saveLocalState();
    populateAllDatalists();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(window.erpEngine);

    closeQuickAddPartyModal();
    selectSalePartyDirectly(newParty.id);
    alert(`✅ Party ${name} created and selected for billing!`);
}

function proceedToSaleStep2() {
    if (!activeSaleSession.selectedParty) {
        const cashParty = window.erpEngine.parties.find(p => p.name.includes("CASH")) || window.erpEngine.parties[0];
        activeSaleSession.selectedParty = cashParty;
    }

    document.getElementById("billingHeaderTitle").innerText = `TAX INVOICE: ${activeSaleSession.billNo}`;
    document.getElementById("billingHeaderParty").innerText = `Party: ${activeSaleSession.selectedParty.name} | Date: ${activeSaleSession.billDate} | Mode: ${activeSaleSession.paymentMode}`;

    renderSaleCart();
    showScreen('view-sale-step2');
}

// =============================================================================
// MEDICINE SEARCH & SELECTION MODAL (TOUCH FIXED)
// =============================================================================

function openProductSearchModal() {
    const sInput = document.getElementById("prodLiveSearchInput");
    if (sInput) sInput.value = "";
    renderProductSearchList("");
    document.getElementById("productSearchModal")?.classList.add("active");
    setTimeout(() => { sInput?.focus(); }, 150);
}

function closeProductSearchModal() {
    document.getElementById("productSearchModal")?.classList.remove("active");
}

function filterProductSearchList(query) {
    renderProductSearchList(query.toLowerCase().trim());
}

function renderProductSearchList(query) {
    const listEl = document.getElementById("productSearchListContainer");
    if (!listEl) return;
    listEl.innerHTML = "";

    const filtered = window.erpEngine.medicines.filter(m => 
        m.name.toLowerCase().includes(query) || 
        (m.systemId && m.systemId.toLowerCase().includes(query)) ||
        (m.packing && m.packing.toLowerCase().includes(query))
    );

    if (filtered.length === 0) {
        listEl.innerHTML = `<div style="padding:15px; color:var(--text-muted); font-size:0.85rem; text-align:center;">No product found. Tap '+ NEW PRODUCT' above to add.</div>`;
        return;
    }

    filtered.forEach(m => {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "picker-item-row";
        btn.style.width = "100%";
        btn.style.textAlign = "left";
        btn.innerHTML = `
            <div>
                <strong style="color:var(--text-light); font-size:0.95rem;">${m.name}</strong>
                <div style="font-size:0.75rem; color:var(--text-muted);">${m.packing} | Code: ${m.systemId || m.id}</div>
            </div>
            <div style="text-align:right;">
                <div style="color:var(--accent-emerald); font-weight:900; font-size:0.95rem;">Stock: ${m.stock}</div>
                <div style="font-size:0.75rem; color:var(--text-muted);">MRP: ₹ ${m.mrp.toFixed(2)}</div>
            </div>
        `;
        btn.onclick = () => selectProductForBilling(m.id || m.systemId || m.name);
        listEl.appendChild(btn);
    });
}

function openQuickAddProductModal() {
    const name = prompt("Enter Product Name (e.g. LIMCEE 500):");
    if (!name) return;
    const pack = prompt("Enter Packing (e.g. 15 TAB):", "15 TAB") || "15 TAB";
    const mrp = parseFloat(prompt("Enter MRP (₹):", "25.00")) || 25.0;
    const purRate = parseFloat(prompt("Enter Pur. Rate (₹):", "18.00")) || 18.0;
    const rateA = parseFloat(prompt("Enter Sale Rate A (₹):", "23.00")) || 23.0;

    const sysId = `PH-${10001 + window.erpEngine.medicines.length}`;
    const newMed = {
        id: sysId, systemId: sysId, name: name.toUpperCase(), packing: pack.toUpperCase(), drugForm: "TAB", hsnCode: "3004",
        batch: "DL-101", exp: "12/28", mrp, purRate, rateA, rateB: rateA * 0.95, rateC: rateA * 0.92, stock: 100, gst: 12
    };

    window.erpEngine.medicines.push(newMed);
    window.erpEngine.rebuildAllInventory();
    saveLocalState();
    populateAllDatalists();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(window.erpEngine);

    selectProductForBilling(newMed.id);
}

// 🎯 UNIVERSAL IDENTIFIER MATCHING (Cannot fail!)
function selectProductForBilling(identifier) {
    closeProductSearchModal();
    const cleanId = String(identifier).trim().toLowerCase();

    const med = window.erpEngine.medicines.find(m => 
        (m.id && String(m.id).toLowerCase() === cleanId) || 
        (m.systemId && String(m.systemId).toLowerCase() === cleanId) ||
        (m.name && m.name.toLowerCase() === cleanId)
    );

    if (!med) {
        console.error("Could not find medicine with identifier:", identifier);
        return;
    }

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
    document.getElementById("itemEntryModal")?.classList.add("active");
}

function closeItemEntryModal() {
    document.getElementById("itemEntryModal")?.classList.remove("active");
}

function onRateTierChanged(tier) {
    if (!activeEditingMed) return;
    const rateCBox = document.getElementById("eRateCDiscBox");
    if (tier === "A") {
        document.getElementById("eRate").value = activeEditingMed.rateA.toFixed(2);
        if (rateCBox) rateCBox.style.display = "none";
    } else if (tier === "B") {
        document.getElementById("eRate").value = activeEditingMed.rateB.toFixed(2);
        if (rateCBox) rateCBox.style.display = "none";
    } else if (tier === "C") {
        if (rateCBox) rateCBox.style.display = "block";
        calculateRateCFormula();
    }
    syncDiscountInputs('percent');
}

function calculateRateCFormula() {
    const mrp = parseFloat(document.getElementById("eMrp")?.value) || 0;
    const gst = parseFloat(document.getElementById("eGst")?.value) || 12;
    const cDisc = parseFloat(document.getElementById("eRateCDisc")?.value) || 0;

    const baseTaxable = mrp / (1 + (gst / 100));
    const finalRateC = baseTaxable - (baseTaxable * (cDisc / 100));
    const rateEl = document.getElementById("eRate");
    if (rateEl) rateEl.value = finalRateC.toFixed(2);
    syncDiscountInputs('percent');
}

function syncDiscountInputs(source) {
    const qty = parseFloat(document.getElementById("eQty")?.value) || 1;
    const rate = parseFloat(document.getElementById("eRate")?.value) || 0;
    const gst = parseFloat(document.getElementById("eGst")?.value) || 0;
    const gross = qty * rate;

    let discAmt = 0;
    if (source === 'percent') {
        const discPer = parseFloat(document.getElementById("eDiscPer")?.value) || 0;
        discAmt = gross * (discPer / 100);
        const dAmtEl = document.getElementById("eDiscAmt");
        if (dAmtEl) dAmtEl.value = discAmt.toFixed(2);
    } else {
        discAmt = parseFloat(document.getElementById("eDiscAmt")?.value) || 0;
        const discPer = gross > 0 ? (discAmt / gross) * 100 : 0;
        const dPerEl = document.getElementById("eDiscPer");
        if (dPerEl) dPerEl.value = discPer.toFixed(2);
    }

    const taxable = gross - discAmt;
    const netTotal = taxable * (1 + (gst / 100));
    const totalEl = document.getElementById("eNetTotalDisplay");
    if (totalEl) totalEl.innerText = `₹ ${netTotal.toFixed(2)}`;
}

function confirmAndAddItemToCart() {
    if (!activeEditingMed) return;
    const batch = document.getElementById("eBatch")?.value.trim() || "DL-101";
    const exp = document.getElementById("eExp")?.value.trim() || "12/28";
    const mrp = parseFloat(document.getElementById("eMrp")?.value) || 0;
    const rate = parseFloat(document.getElementById("eRate")?.value) || 0;
    const qty = parseFloat(document.getElementById("eQty")?.value) || 1;
    const free = parseFloat(document.getElementById("eFree")?.value) || 0;
    const discPer = parseFloat(document.getElementById("eDiscPer")?.value) || 0;
    const discAmt = parseFloat(document.getElementById("eDiscAmt")?.value) || 0;
    const gst = parseFloat(document.getElementById("eGst")?.value) || 0;

    const gross = qty * rate;
    const taxable = gross - discAmt;
    const total = taxable * (1 + (gst / 100));

    activeSaleSession.cartItems.push({
        srNo: activeSaleSession.cartItems.length + 1,
        medicineID: activeEditingMed.systemId || activeEditingMed.id,
        name: activeEditingMed.name,
        packing: activeEditingMed.packing,
        batch: batch,
        exp: exp,
        hsn: activeEditingMed.hsnCode || "3004",
        mrp: mrp,
        qty: qty,
        freeQty: free,
        rate: rate,
        gstRate: gst,
        discountPer: discPer,
        discountRupees: discAmt,
        total: total
    });

    closeItemEntryModal();
    renderSaleCart();
}

function renderSaleCart() {
    const tbody = document.getElementById("saleCartTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";

    activeSaleSession.cartItems.forEach((item, index) => {
        item.srNo = index + 1;
        tbody.innerHTML += `
            <tr>
                <td>${item.srNo}</td>
                <td><strong>${item.name}</strong></td>
                <td>${item.packing}</td>
                <td>${item.batch}</td>
                <td>${item.exp}</td>
                <td>${item.qty} + ${item.freeQty}</td>
                <td>₹ ${item.rate.toFixed(2)}</td>
                <td>${item.discountPer.toFixed(1)}%</td>
                <td>${item.gstRate}%</td>
                <td><strong>₹ ${item.total.toFixed(2)}</strong></td>
                <td><button class="btn btn-danger-sm" onclick="removeSaleCartRow(${index})">✕</button></td>
            </tr>
        `;
    });

    recalculateBillTotals();
}

function removeSaleCartRow(index) {
    activeSaleSession.cartItems.splice(index, 1);
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

    const sumItemEl = document.getElementById("sumItemsTotal");
    const sumRoundEl = document.getElementById("sumRoundOff");
    const sumGrandEl = document.getElementById("sumGrandTotal");

    if (sumItemEl) sumItemEl.innerText = `₹ ${itemsTotal.toFixed(2)}`;
    if (sumRoundEl) sumRoundEl.innerText = `₹ ${roundOff.toFixed(2)}`;
    if (sumGrandEl) sumGrandEl.innerText = `₹ ${grandTotal.toFixed(2)}`;
}

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

    const titleEl = document.getElementById("successModalTitle");
    const subEl = document.getElementById("successModalSub");
    if (titleEl) titleEl.innerText = `INVOICE ${saleRecord.billNo} SAVED!`;
    if (subEl) subEl.innerText = `Total: ₹ ${saleRecord.totalAmount.toFixed(2)} | Synced with Google Drive`;

    document.getElementById("billSuccessModal")?.classList.add("active");
}

function triggerDirectPrint(format) {
    if (!lastSavedDoc) return;
    const printArea = document.getElementById("printArea");
    if (printArea) {
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
}

function dismissSuccessAndNewBill() {
    document.getElementById("billSuccessModal")?.classList.remove("active");
    startSaleWorkflow();
}

// =============================================================================
// PURCHASES, CHALLANS, RETURNS, VOUCHERS, LEDGERS & MASTERS
// =============================================================================

function initNewPurchaseSession() {
    const nextNo = window.erpEngine.getNextNumber('PURCHASE');
    const pInt = document.getElementById("purInternalNo");
    const pDate = document.getElementById("purBillDate");
    const pEntry = document.getElementById("purEntryDate");
    if (pInt) pInt.value = nextNo;
    if (pDate) pDate.value = new Date().toISOString().split('T')[0];
    if (pEntry) pEntry.value = new Date().toISOString().split('T')[0];
    activePurchaseCart = [];
    renderPurCart();
}

function autoFillPurProductDetails(val) {
    const match = window.erpEngine.medicines.find(m => m.name.toLowerCase() === val.toLowerCase());
    if (match) {
        document.getElementById("purBatch").value = match.batch || "B-01";
        document.getElementById("purExp").value = match.exp || "12/28";
        document.getElementById("purMrp").value = match.mrp.toFixed(2);
        document.getElementById("purRate").value = match.purRate.toFixed(2);
        document.getElementById("purGst").value = match.gst;
    }
}

function addPurchaseCartItem() {
    const name = document.getElementById("purItemName")?.value.trim();
    const batch = document.getElementById("purBatch")?.value.trim() || "B-01";
    const exp = document.getElementById("purExp")?.value.trim() || "12/28";
    const mrp = parseFloat(document.getElementById("purMrp")?.value) || 0;
    const rate = parseFloat(document.getElementById("purRate")?.value) || 0;
    const qty = parseFloat(document.getElementById("purQty")?.value) || 1;
    const free = parseFloat(document.getElementById("purFree")?.value) || 0;
    const gst = parseFloat(document.getElementById("purGst")?.value) || 12;

    if (!name || rate <= 0) { alert("Please enter valid product and purchase rate!"); return; }

    const gross = qty * rate;
    const total = gross * (1 + (gst / 100));

    activePurchaseCart.push({
        srNo: activePurchaseCart.length + 1,
        name, batch, exp, mrp, purchaseRate: rate, qty, freeQty: free, gstRate: gst, total
    });

    renderPurCart();
    const pItemEl = document.getElementById("purItemName");
    if (pItemEl) pItemEl.value = "";
}

function renderPurCart() {
    const tbody = document.getElementById("purCartTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";
    let grandTotal = 0;

    activePurchaseCart.forEach((item, index) => {
        grandTotal += item.total;
        tbody.innerHTML += `
            <tr>
                <td>${index + 1}</td>
                <td><strong>${item.name}</strong></td>
                <td>${item.batch}</td>
                <td>${item.exp}</td>
                <td>₹ ${item.mrp.toFixed(2)}</td>
                <td>₹ ${item.purchaseRate.toFixed(2)}</td>
                <td>${item.qty} + ${item.freeQty}</td>
                <td>${item.gstRate}%</td>
                <td><strong>₹ ${item.total.toFixed(2)}</strong></td>
                <td><button class="btn btn-danger-sm" onclick="activePurchaseCart.splice(${index},1); renderPurCart();">✕</button></td>
            </tr>
        `;
    });

    const purTotalEl = document.getElementById("purGrandTotal");
    if (purTotalEl) purTotalEl.innerText = `₹ ${grandTotal.toFixed(2)}`;
}

function savePurchaseInward() {
    const supplier = document.getElementById("purSupplierSearch")?.value.trim();
    const distBillNo = document.getElementById("purBillNo")?.value.trim();
    if (!supplier || !distBillNo || activePurchaseCart.length === 0) {
        alert("Please specify Supplier, Bill No and at least 1 item.");
        return;
    }

    const netTotal = activePurchaseCart.reduce((sum, it) => sum + it.total, 0);

    const purRecord = {
        id: "PUR_" + Date.now(),
        internalNo: document.getElementById("purInternalNo")?.value || "PUR-101",
        billNo: distBillNo,
        distributorName: supplier,
        date: document.getElementById("purBillDate")?.value || new Date().toISOString().split('T')[0],
        entryDate: document.getElementById("purEntryDate")?.value || new Date().toISOString().split('T')[0],
        paymentMode: document.getElementById("purPayMode")?.value || "CREDIT",
        items: [...activePurchaseCart],
        totalAmount: netTotal
    };

    window.erpEngine.purchases.push(purRecord);
    window.erpEngine.rebuildAllInventory();

    saveLocalState();
    updateDashboardStats();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(window.erpEngine);

    alert("✅ Inward Stock Saved and Live Inventory Updated!");
    initNewPurchaseSession();
    showScreen('view-billing-hub');
}

function initNewChallanSession() {
    const nextNo = window.erpEngine.getNextNumber('CHALLAN');
    const chEl = document.getElementById("chBillNo");
    if (chEl) chEl.value = nextNo;
    const chDateEl = document.getElementById("chDate");
    if (chDateEl) chDateEl.value = new Date().toISOString().split('T')[0];
}

function addChallanItem() {
    const billNo = document.getElementById("chBillNo")?.value || "SCH-101";
    const date = document.getElementById("chDate")?.value || new Date().toISOString().split('T')[0];
    const partyName = document.getElementById("chParty")?.value.trim() || "CASH CUSTOMER";
    const itemName = document.getElementById("chItemName")?.value.trim() || "";
    const qty = parseFloat(document.getElementById("chQty")?.value) || 1;
    const rate = parseFloat(document.getElementById("chRate")?.value) || 0;
    const remarks = document.getElementById("chRemarks")?.value.trim() || "";

    if (!itemName) { alert("Please enter Item Name!"); return; }

    const total = qty * rate;
    window.erpEngine.saleChallans.push({
        id: "CH_" + Date.now(),
        billNo, date, partyName, itemName, qty, rate, totalAmount: total, remarks, status: "Pending"
    });

    saveLocalState();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(window.erpEngine);

    alert("✅ Delivery Challan Recorded!");
    initNewChallanSession();
    renderChallansRegister();
}

function renderChallansRegister() {
    const tbody = document.getElementById("challanRegisterTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";

    window.erpEngine.saleChallans.forEach((ch, idx) => {
        tbody.innerHTML += `
            <tr>
                <td>${idx + 1}</td>
                <td><strong>${ch.billNo}</strong></td>
                <td>${ch.date}</td>
                <td>${ch.partyName}</td>
                <td>₹ ${ch.totalAmount.toFixed(2)}</td>
                <td><span class="badge-tag">${ch.status || 'Pending'}</span></td>
            </tr>
        `;
    });
}

function saveReturnEntry() {
    const type = document.getElementById("retType")?.value || "CN";
    const disposition = document.getElementById("retDisposition")?.value || "Sellable";
    const party = document.getElementById("retParty")?.value.trim();
    const item = document.getElementById("retItemName")?.value.trim();
    const qty = parseFloat(document.getElementById("retQty")?.value) || 1;
    const rate = parseFloat(document.getElementById("retRate")?.value) || 0;
    const date = document.getElementById("retDate")?.value || new Date().toISOString().split('T')[0];

    if (!party || !item) { alert("Please specify Party and Product!"); return; }

    const total = qty * rate;
    const noteNo = window.erpEngine.getNextNumber('RETURN');

    if (type === 'CN') {
        window.erpEngine.saleReturns.push({
            id: "RET_" + Date.now(),
            billNo: noteNo, returnType: disposition, partyName: party, items: [{ medicineID: "temp", name: item, batch: "DL-101", exp: "12/28", mrp: rate, rate: rate, qty: qty, freeQty: 0, total: total }], totalAmount: total, date, status: "Active"
        });
    } else {
        window.erpEngine.purchaseReturns.push({
            id: "RET_" + Date.now(),
            billNo: noteNo, returnType: disposition, distributorName: party, items: [{ medicineID: "temp", name: item, batch: "DL-101", exp: "12/28", mrp: rate, purchaseRate: rate, qty: qty, freeQty: 0, total: total }], totalAmount: total, date, status: "Active"
        });
    }

    window.erpEngine.rebuildAllInventory();
    saveLocalState();
    updateDashboardStats();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(window.erpEngine);

    alert(`✅ ${type} #${noteNo} Recorded Successfully!`);
    renderReturnsRegister();
}

function renderReturnsRegister() {
    const tbody = document.getElementById("returnsRegisterTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";

    window.erpEngine.saleReturns.forEach(r => {
        tbody.innerHTML += `<tr><td>${r.date}</td><td><strong>${r.billNo}</strong></td><td><span style="color:var(--accent-red); font-weight:bold;">CN</span></td><td>${r.partyName}</td><td>${r.returnType}</td><td><strong>₹ ${r.totalAmount.toFixed(2)}</strong></td></tr>`;
    });
    window.erpEngine.purchaseReturns.forEach(r => {
        tbody.innerHTML += `<tr><td>${r.date}</td><td><strong>${r.billNo}</strong></td><td><span style="color:var(--accent-orange); font-weight:bold;">DN</span></td><td>${r.distributorName}</td><td>${r.returnType}</td><td><strong>₹ ${r.totalAmount.toFixed(2)}</strong></td></tr>`;
    });
}

function saveVoucherEntry() {
    const type = document.getElementById("vouchType")?.value || "RECEIPT";
    const date = document.getElementById("vouchDate")?.value || new Date().toISOString().split('T')[0];
    const party = document.getElementById("vouchParty")?.value.trim();
    const amount = parseFloat(document.getElementById("vouchAmount")?.value) || 0;
    const depositedIn = document.getElementById("vouchInternalLedger")?.value || "CASH IN HAND";
    const mode = document.getElementById("vouchMode")?.value || "Cash";
    const chequeNo = document.getElementById("vouchChequeNo")?.value.trim() || "";
    const narration = document.getElementById("vouchNarration")?.value.trim() || "";

    if (!party || amount <= 0) { alert("Please enter Party Name and valid Amount!"); return; }

    const vNo = window.erpEngine.getNextNumber(type);
    window.erpEngine.vouchers.push({
        id: "VOUC_" + Date.now(),
        type, voucherNo: vNo, date, partyName: party, amount, paymentMode: mode, depositedIn, chequeNo, narration, status: "Active"
    });

    saveLocalState();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(window.erpEngine);

    alert(`✅ ${type} Voucher #${vNo} Recorded Successfully!`);
    document.getElementById("vouchAmount").value = "";
    document.getElementById("vouchNarration").value = "";
}

function renderDaybook() {
    const tbody = document.getElementById("daybookTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";
    const filterDate = document.getElementById("daybookFilterDate")?.value || new Date().toISOString().split('T')[0];
    const fDateEl = document.getElementById("daybookFilterDate");
    if (fDateEl) fDateEl.value = filterDate;

    window.erpEngine.sales.filter(s => s.date === filterDate && s.status === 'Active').forEach(s => {
        tbody.innerHTML += `<tr><td>${s.date}</td><td><span style="color:var(--accent-emerald); font-weight:bold;">SALE</span></td><td>${s.partyName}</td><td>${s.billNo}</td><td>₹ ${s.totalAmount.toFixed(2)}</td><td>-</td></tr>`;
    });
    window.erpEngine.purchases.filter(p => p.date === filterDate).forEach(p => {
        tbody.innerHTML += `<tr><td>${p.date}</td><td><span style="color:var(--accent-orange); font-weight:bold;">PURCHASE</span></td><td>${p.distributorName}</td><td>${p.billNo}</td><td>-</td><td>₹ ${p.totalAmount.toFixed(2)}</td></tr>`;
    });
    window.erpEngine.vouchers.filter(v => v.date === filterDate && v.status === 'Active').forEach(v => {
        const isRec = v.type === "RECEIPT";
        tbody.innerHTML += `<tr><td>${v.date}</td><td><span style="color:${isRec ? 'var(--accent-emerald)' : 'var(--accent-red)'}; font-weight:bold;">${v.type}</span></td><td>${v.partyName} (${v.depositedIn})</td><td>${v.voucherNo}</td><td>${isRec ? '₹ ' + v.amount.toFixed(2) : '-'}</td><td>${!isRec ? '₹ ' + v.amount.toFixed(2) : '-'}</td></tr>`;
    });
}

function renderLedgers() {
    const tbody = document.getElementById("ledgerTableBody");
    if (!tbody) return;
    const query = document.getElementById("ledgerSearchParty")?.value.toLowerCase().trim() || "";
    tbody.innerHTML = "";

    window.erpEngine.sales.filter(s => s.partyName.toLowerCase().includes(query) && s.status === 'Active').forEach(s => {
        tbody.innerHTML += `<tr><td>${s.date}</td><td>Sale Invoice #${s.billNo}</td><td>SALE</td><td>₹ ${s.totalAmount.toFixed(2)}</td><td>-</td><td>₹ ${s.totalAmount.toFixed(2)} Dr</td></tr>`;
    });
    window.erpEngine.vouchers.filter(v => v.partyName.toLowerCase().includes(query) && v.status === 'Active').forEach(v => {
        const isRec = v.type === "RECEIPT";
        tbody.innerHTML += `<tr><td>${v.date}</td><td>${v.type} Voucher #${v.voucherNo} (${v.paymentMode})</td><td>${v.type}</td><td>${!isRec ? '₹ ' + v.amount.toFixed(2) : '-'}</td><td>${isRec ? '₹ ' + v.amount.toFixed(2) : '-'}</td><td>-</td></tr>`;
    });
}

function renderStock() {
    const tbody = document.getElementById("stockTableBody");
    if (!tbody) return;
    const query = document.getElementById("stockSearchInput")?.value.toLowerCase().trim() || "";
    tbody.innerHTML = "";

    window.erpEngine.medicines.filter(m => m.name.toLowerCase().includes(query) || (m.systemId && m.systemId.toLowerCase().includes(query))).forEach(m => {
        tbody.innerHTML += `
            <tr>
                <td><span class="tag-badge">${m.systemId}</span></td>
                <td><strong>${m.name}</strong></td>
                <td>${m.packing}</td>
                <td>${m.batch || 'DL-101'}</td>
                <td>${m.exp || '12/28'}</td>
                <td>₹ ${(m.mrp || 0).toFixed(2)}</td>
                <td>₹ ${(m.purRate || 0).toFixed(2)}</td>
                <td>₹ ${(m.rateA || 0).toFixed(2)}</td>
                <td><strong style="color:var(--accent-emerald); font-size:1.05rem;">${m.stock}</strong></td>
            </tr>
        `;
    });
}

function saveNewProductMaster() {
    const name = document.getElementById("mProdName")?.value.trim().toUpperCase();
    const pack = document.getElementById("mProdPack")?.value.trim().toUpperCase();
    const mrp = parseFloat(document.getElementById("mProdMrp")?.value) || 0;
    const purRate = parseFloat(document.getElementById("mProdPurRate")?.value) || 0;
    const rateA = parseFloat(document.getElementById("mProdRateA")?.value) || 0;
    const gst = parseFloat(document.getElementById("mProdGst")?.value) || 12;

    if (!name || !pack) { alert("Product name and packing are mandatory!"); return; }

    const sysId = `PH-${10001 + window.erpEngine.medicines.length}`;
    window.erpEngine.medicines.push({
        id: sysId, systemId: sysId, name, packing: pack, drugForm: "TAB", hsnCode: "3004",
        batch: "DL-101", exp: "12/28", mrp, purRate, rateA, rateB: rateA * 0.95, rateC: rateA * 0.92, stock: 0, gst
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
    const name = document.getElementById("mPartyName")?.value.trim().toUpperCase();
    const group = document.getElementById("mPartyGroup")?.value || "Sundry Debtors";
    const gst = document.getElementById("mPartyGst")?.value.trim().toUpperCase() || "N/A";
    const city = document.getElementById("mPartyCity")?.value.trim().toUpperCase() || "LOCAL";
    const phone = document.getElementById("mPartyPhone")?.value.trim() || "";
    const opBal = parseFloat(document.getElementById("mPartyOpBal")?.value) || 0.0;

    if (!name) { alert("Party / Firm Name is required!"); return; }

    window.erpEngine.parties.push({
        id: "p_" + Date.now(), name, group, gst, city, state: "Rajasthan", phone, opBal
    });

    saveLocalState();
    populateAllDatalists();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(window.erpEngine);

    alert(`✅ Party ${name} registered in ${group}`);
    document.getElementById("mPartyName").value = "";
}

function formatExpiryField(input) {
    let v = input.value.replace(/[^0-9]/g, '');
    if (v.length >= 2 && !input.value.includes('/')) v = v.substring(0, 2) + '/' + v.substring(2);
    if (v.length > 5) v = v.substring(0, 5);
    input.value = v;
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

    const kpiSale = document.getElementById("kpi-sale");
    const kpiPur = document.getElementById("kpi-pur");
    const kpiStock = document.getElementById("kpi-stock");

    if (kpiSale) kpiSale.innerText = `₹ ${totalSale.toFixed(2)}`;
    if (kpiPur) kpiPur.innerText = `₹ ${totalPur.toFixed(2)}`;
    if (kpiStock) kpiStock.innerText = `₹ ${stockVal.toFixed(2)}`;
}

async function pullLatestFromDrive(isSilent = false) {
    if (window.GoogleDriveSync && GoogleDriveSync.config.apiUrl) {
        const cloudData = await GoogleDriveSync.pullFromDrive();
        if (cloudData) {
            Object.assign(window.erpEngine, cloudData);
            saveLocalState();
            populateAllDatalists();
            updateDashboardStats();
            if (!isSilent) console.log("☁️ Drive data synchronized.");
        }
    }
}

function saveLocalState() {
    localStorage.setItem(DB_VERSION_KEY, JSON.stringify(window.erpEngine));
}

function loadLocalState() {
    const saved = localStorage.getItem(DB_VERSION_KEY);
    if (saved) {
        try { Object.assign(window.erpEngine, JSON.parse(saved)); } catch(e) {}
    }
}

// Stitcher Wizard Functions
function openStitcherWizardScreen() {
    stitcherSelectedParty = null;
    stitcherSelectedChallanIds = [];
    document.getElementById("stitcherPartySearch").value = "";
    document.getElementById("stitcherChallansTableBody").innerHTML = `<tr><td colspan="6" style="text-align:center; color:var(--text-muted);">Please select a customer to view pending challans.</td></tr>`;
    document.getElementById("stitcherTotalAmount").innerText = `₹ 0.00`;
    showScreen('view-stitcher-wizard');
}

function loadPendingChallansForStitcher(partyName) {
    const party = window.erpEngine.parties.find(p => p.name.toLowerCase() === partyName.trim().toLowerCase());
    const tbody = document.getElementById("stitcherChallansTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";

    if (!party) {
        tbody.innerHTML = `<tr><td colspan="6" style="text-align:center; color:var(--text-muted);">No matching party found.</td></tr>`;
        return;
    }

    stitcherSelectedParty = party;
    stitcherSelectedChallanIds = [];

    const pendingList = window.erpEngine.saleChallans.filter(c => c.partyName.toUpperCase() === party.name.toUpperCase() && c.status === 'Pending');

    if (pendingList.length === 0) {
        tbody.innerHTML = `<tr><td colspan="6" style="text-align:center; color:var(--accent-emerald);">No pending challans for this customer! All billed.</td></tr>`;
        return;
    }

    pendingList.forEach(ch => {
        tbody.innerHTML += `
            <tr>
                <td><input type="checkbox" onchange="toggleStitcherChallan('${ch.id}', this.checked, ${ch.totalAmount})"></td>
                <td><strong>${ch.billNo}</strong></td>
                <td>${ch.date}</td>
                <td>${ch.partyName}</td>
                <td>${ch.remarks || 'Standard'}</td>
                <td>₹ ${ch.totalAmount.toFixed(2)}</td>
            </tr>
        `;
    });
}

function toggleStitcherChallan(chId, isChecked, amount) {
    if (isChecked) {
        stitcherSelectedChallanIds.push(chId);
    } else {
        stitcherSelectedChallanIds = stitcherSelectedChallanIds.filter(id => id !== chId);
    }

    const total = window.erpEngine.saleChallans
        .filter(c => stitcherSelectedChallanIds.includes(c.id))
        .reduce((sum, c) => sum + c.totalAmount, 0);

    document.getElementById("stitcherTotalAmount").innerText = `₹ ${total.toFixed(2)}`;
}

function finalizeStitcherConversion() {
    if (!stitcherSelectedParty || stitcherSelectedChallanIds.length === 0) {
        alert("Please select at least 1 pending challan to convert!");
        return;
    }

    const selectedChallans = window.erpEngine.saleChallans.filter(c => stitcherSelectedChallanIds.includes(c.id));
    const nextBillNo = window.erpEngine.getNextNumber('SALE');
    const billDate = document.getElementById("stitcherBillDate").value || new Date().toISOString().split('T')[0];

    let mergedItems = [];
    selectedChallans.forEach(ch => {
        mergedItems.push({
            srNo: mergedItems.length + 1,
            medicineID: "PH-10001",
            name: `CHALLAN MERGE (${ch.billNo}): ${ch.itemName || 'Consolidated Materials'}`,
            packing: "1 PCS",
            batch: ch.batch || "DL-101",
            exp: "12/28",
            hsn: "3004",
            mrp: ch.totalAmount,
            qty: ch.qty || 1,
            freeQty: 0,
            rate: ch.rate || ch.totalAmount,
            gstRate: 12,
            discountPer: 0,
            discountRupees: 0,
            total: ch.totalAmount
        });
        ch.status = "Billed";
    });

    const grandTotal = selectedChallans.reduce((sum, c) => sum + c.totalAmount, 0);

    const saleRecord = {
        id: "SALE_" + Date.now(),
        billNo: nextBillNo,
        partyId: stitcherSelectedParty.id,
        partyName: stitcherSelectedParty.name,
        partyGstin: stitcherSelectedParty.gst || "N/A",
        partyState: stitcherSelectedParty.state || "Rajasthan",
        date: billDate,
        paymentMode: "CREDIT",
        items: mergedItems,
        totalAmount: grandTotal,
        extraDiscount: 0.0,
        roundOff: 0.0,
        status: "Active",
        sourceTag: "CHALLAN_CONVERT"
    };

    window.erpEngine.sales.push(saleRecord);
    saveLocalState();
    updateDashboardStats();

    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(window.erpEngine);

    alert(`✅ Success! ${selectedChallans.length} Challans converted to GST Tax Invoice #${nextBillNo}`);
    showScreen('view-billing-hub');
}

function renderSaleRegister() {
    const tbody = document.getElementById("saleRegTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";

    const fromDate = document.getElementById("saleRegFromDate")?.value || "2020-01-01";
    const toDate = document.getElementById("saleRegToDate")?.value || "2030-12-31";
    const query = document.getElementById("saleRegSearch")?.value.toLowerCase().trim() || "";

    let totalTaxable = 0;
    let totalGst = 0;
    let totalNet = 0;

    window.erpEngine.sales
        .filter(s => s.status === 'Active' && s.date >= fromDate && s.date <= toDate)
        .filter(s => s.billNo.toLowerCase().includes(query) || s.partyName.toLowerCase().includes(query))
        .forEach(s => {
            const tax = s.items.reduce((sum, i) => sum + (i.total - (i.qty * i.rate)), 0);
            const taxable = s.totalAmount - tax;

            totalTaxable += taxable;
            totalGst += tax;
            totalNet += s.totalAmount;

            tbody.innerHTML += `
                <tr>
                    <td>${s.date}</td>
                    <td><strong>${s.billNo}</strong></td>
                    <td>${s.partyName}</td>
                    <td>${s.partyGstin || 'N/A'}</td>
                    <td><span class="badge-tag">${s.paymentMode}</span></td>
                    <td>₹ ${taxable.toFixed(2)}</td>
                    <td>₹ ${tax.toFixed(2)}</td>
                    <td><strong>₹ ${s.totalAmount.toFixed(2)}</strong></td>
                    <td><button class="btn btn-secondary" style="padding:2px 8px; font-size:0.7rem;" onclick="reprintSaleBill('${s.billNo}')">REPRINT</button></td>
                </tr>
            `;
        });

    document.getElementById("saleRegSumTaxable").innerText = `₹ ${totalTaxable.toFixed(2)}`;
    document.getElementById("saleRegSumGst").innerText = `₹ ${totalGst.toFixed(2)}`;
    document.getElementById("saleRegSumNet").innerText = `₹ ${totalNet.toFixed(2)}`;
}

function reprintSaleBill(billNo) {
    const sale = window.erpEngine.sales.find(s => s.billNo === billNo);
    if (!sale) return;
    lastSavedDoc = sale;
    triggerDirectPrint('A4');
}

function renderPurchaseRegister() {
    const tbody = document.getElementById("purRegTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";

    const fromDate = document.getElementById("purRegFromDate")?.value || "2020-01-01";
    const toDate = document.getElementById("purRegToDate")?.value || "2030-12-31";
    const query = document.getElementById("purRegSearch")?.value.toLowerCase().trim() || "";

    let totalNet = 0;

    window.erpEngine.purchases
        .filter(p => p.date >= fromDate && p.date <= toDate)
        .filter(p => p.billNo.toLowerCase().includes(query) || p.distributorName.toLowerCase().includes(query))
        .forEach(p => {
            totalNet += p.totalAmount;
            tbody.innerHTML += `
                <tr>
                    <td>${p.date}</td>
                    <td><span class="badge-tag">${p.internalNo}</span></td>
                    <td><strong>${p.billNo}</strong></td>
                    <td>${p.distributorName}</td>
                    <td>${p.paymentMode}</td>
                    <td><strong>₹ ${p.totalAmount.toFixed(2)}</strong></td>
                </tr>
            `;
        });

    document.getElementById("purRegSumNet").innerText = `₹ ${totalNet.toFixed(2)}`;
}
