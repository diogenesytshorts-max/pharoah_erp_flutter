// =============================================================================
// PHAROAH ERP - FULL ENTERPRISE CLIENT ENGINE (AUTO CACHE PURGE & NO-FREEZE UI)
// =============================================================================

const DB_VERSION_KEY = "pharoah_erp_v6_clean_db";

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
let syncIntervalId = null;

// Initial Load Handler with Auto Cache Purge
document.addEventListener("DOMContentLoaded", async () => {
    try {
        // 🧹 1. PURGE OLD CORRUPTED LOCALSTORAGE AUTOMATICALLY
        purgeCorruptedLegacyStorage();

        loadLocalState();
        window.erpEngine.rebuildAllInventory();
        populateAllDatalists();
        initNewSaleSession();
        initNewPurchaseSession();
        initNewChallanSession();
        updateDashboardStats();

        const todayStr = new Date().toISOString().split('T')[0];
        ["vouchDate", "retDate", "chDate"].forEach(id => {
            const el = document.getElementById(id);
            if (el) el.value = todayStr;
        });

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

// Auto-purge legacy storage keys on version mismatch
function purgeCorruptedLegacyStorage() {
    const savedVer = localStorage.getItem("pharoah_version_check");
    if (savedVer !== DB_VERSION_KEY) {
        localStorage.removeItem("pharoah_web_state");
        localStorage.removeItem("pharoah_erp_v4_db");
        localStorage.setItem("pharoah_version_check", DB_VERSION_KEY);
        window.erpEngine = new PharoahWebEngine();
        saveLocalState();
        console.log("🧹 Legacy corrupted cache & old Hindi data purged successfully!");
    }
}

// 1-Click Reset for User
function hardResetAllLocalData() {
    if (confirm("Are you sure you want to clear all local web storage and start fresh?")) {
        localStorage.clear();
        sessionStorage.clear();
        localStorage.setItem("pharoah_version_check", DB_VERSION_KEY);
        window.erpEngine = new PharoahWebEngine();
        saveLocalState();
        alert("✅ All local data cleared! Reloading fresh ERP...");
        location.reload();
    }
}

// Module View Switcher
function showModuleScreen(moduleKey) {
    document.querySelectorAll("main > section").forEach(sec => sec.style.display = "none");
    let targetSectionId = `view-${moduleKey}`;
    if (moduleKey === 'billing') targetSectionId = 'view-sale-step1';

    const targetSec = document.getElementById(targetSectionId);
    if (targetSec) targetSec.style.display = "block";

    if (moduleKey === 'daybook') renderDaybook();
    if (moduleKey === 'ledgers') renderLedgers();
    if (moduleKey === 'stock') renderStock();
    if (moduleKey === 'challans') renderChallansRegister();
    if (moduleKey === 'returns') renderReturnsRegister();
}

function returnToDashboard() {
    showModuleScreen('dashboard');
}

function startNewSaleWorkflow() {
    initNewSaleSession();
    showModuleScreen('billing');
}

function startNewPurchaseWorkflow() {
    initNewPurchaseSession();
    showModuleScreen('purchases');
}

function openGuideModal() { document.getElementById("guideModal")?.classList.add("active"); }
function closeGuideModal() { document.getElementById("guideModal")?.classList.remove("active"); }
function openDriveSettings() {
    if (window.GoogleDriveSync) {
        const uEmail = document.getElementById("driveUserEmail");
        const aUrl = document.getElementById("driveApiUrl");
        if (uEmail) uEmail.value = GoogleDriveSync.config.userEmail || "";
        if (aUrl) aUrl.value = GoogleDriveSync.config.apiUrl || "";
    }
    document.getElementById("driveSettingsModal")?.classList.add("active");
}
function closeDriveSettings() { document.getElementById("driveSettingsModal")?.classList.remove("active"); }

function saveDriveSettingsFromModal() {
    const email = document.getElementById("driveUserEmail")?.value.trim() || "";
    const url = document.getElementById("driveApiUrl")?.value.trim() || "";
    if (!url) { alert("Please enter Webhook URL!"); return; }
    if (window.GoogleDriveSync) { GoogleDriveSync.saveConfig(url, email); }
    closeDriveSettings();
    pullLatestFromDrive();
    alert("✅ Google Drive 2-Way Sync Connected Successfully!");
}

// =============================================================================
// SALE ENTRY & BILLING FLOW (2-STEP MIRROR OF FLUTTER APP)
// =============================================================================

function initNewSaleSession() {
    const seq = Math.floor(1000 + Math.random() * 9000);
    const prefix = document.getElementById("saleSeriesSelect")?.value || "INV-";
    const billNo = `${prefix}${seq}`;

    activeSaleSession = {
        billNo: billNo,
        billDate: new Date().toISOString().split('T')[0],
        paymentMode: "CASH",
        seriesPrefix: prefix,
        selectedParty: null,
        cartItems: [],
        extraDiscount: 0.0,
        roundOff: 0.0,
        grandTotal: 0.0
    };

    const billNoEl = document.getElementById("saleBillNo");
    const billDateEl = document.getElementById("saleBillDate");
    if (billNoEl) billNoEl.value = billNo;
    if (billDateEl) billDateEl.value = activeSaleSession.billDate;

    clearSelectedSaleParty();
}

function updateSaleSeriesPrefix(prefix) {
    activeSaleSession.seriesPrefix = prefix;
    const seq = Math.floor(1000 + Math.random() * 9000);
    const billNo = `${prefix}${seq}`;
    activeSaleSession.billNo = billNo;
    const billNoEl = document.getElementById("saleBillNo");
    if (billNoEl) billNoEl.value = billNo;
}

function setSalePaymentMode(mode) {
    activeSaleSession.paymentMode = mode;
    document.getElementById("modeCashBtn")?.classList.toggle("active", mode === "CASH");
    document.getElementById("modeCreditBtn")?.classList.toggle("active", mode === "CREDIT");
}

function onSalePartySelected(partyName) {
    const match = window.erpEngine.parties.find(p => p.name.toLowerCase() === partyName.trim().toLowerCase());
    if (match) {
        activeSaleSession.selectedParty = match;
        const nameEl = document.getElementById("previewPartyName");
        const metaEl = document.getElementById("previewPartyMeta");
        const cardEl = document.getElementById("selectedPartyCard");
        if (nameEl) nameEl.innerText = match.name;
        if (metaEl) metaEl.innerText = `City: ${match.city || 'LOCAL'} | GST: ${match.gst || 'N/A'} | Balance: ₹ ${match.opBal.toFixed(2)}`;
        if (cardEl) cardEl.style.display = "flex";
    }
}

function clearSelectedSaleParty() {
    activeSaleSession.selectedParty = null;
    const searchEl = document.getElementById("salePartySearch");
    if (searchEl) searchEl.value = "";
    const cardEl = document.getElementById("selectedPartyCard");
    if (cardEl) cardEl.style.display = "none";
}

function proceedToBillingStep2() {
    if (!activeSaleSession.selectedParty) {
        const cashParty = window.erpEngine.parties.find(p => p.name.includes("CASH")) || window.erpEngine.parties[0];
        activeSaleSession.selectedParty = cashParty;
    }

    const titleEl = document.getElementById("billingHeaderTitle");
    const partyEl = document.getElementById("billingHeaderParty");
    if (titleEl) titleEl.innerText = `TAX INVOICE: ${activeSaleSession.billNo}`;
    if (partyEl) partyEl.innerText = `Party: ${activeSaleSession.selectedParty.name} | Mode: ${activeSaleSession.paymentMode}`;

    renderSaleCart();
    document.querySelectorAll("main > section").forEach(sec => sec.style.display = "none");
    document.getElementById("view-sale-step2").style.display = "block";
}

// Product Search & Selection Modal
function openProductSearchModal() {
    renderProductSearchList("");
    document.getElementById("productSearchModal")?.classList.add("active");
    setTimeout(() => { document.getElementById("prodLiveSearchInput")?.focus(); }, 100);
}

function closeProductSearchModal() {
    document.getElementById("productSearchModal")?.classList.remove("active");
}

function filterProductSearchList(query) {
    renderProductSearchList(query.toLowerCase());
}

function renderProductSearchList(query) {
    const listEl = document.getElementById("productSearchListContainer");
    if (!listEl) return;
    listEl.innerHTML = "";

    window.erpEngine.medicines.filter(m => m.name.toLowerCase().includes(query) || (m.systemId && m.systemId.toLowerCase().includes(query))).forEach(m => {
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

    const titleEl = document.getElementById("entryModalProdTitle");
    if (titleEl) titleEl.innerText = `${med.name} (${med.packing})`;

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

// Save Sale Bill & Open Non-Blocking Modal
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
    returnToDashboard();
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
    const partyName = document.getElementById("chParty")?.value.trim() || "CASH";
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
                <td><span class="pill" style="color:var(--accent-cyan);">${ch.status || 'Pending'}</span></td>
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

    if (!name || !pack) { alert("Product name and packing are required!"); return; }

    const sysId = `PH-${10001 + window.erpEngine.medicines.length}`;
    window.erpEngine.medicines.push({
        id: sysId, systemId: sysId, name, packing: pack, drugForm: "TAB", hsn: "3004",
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

function saveLocalState() {
    localStorage.setItem(DB_VERSION_KEY, JSON.stringify(window.erpEngine));
}

function loadLocalState() {
    const saved = localStorage.getItem(DB_VERSION_KEY);
    if (saved) {
        try { Object.assign(window.erpEngine, JSON.parse(saved)); } catch(e) {}
    }
}
