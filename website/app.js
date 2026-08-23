// =============================================================================
// PHAROAH ERP - FULL CLIENT ENGINE (EXACT PARITY WITH FLUTTER APP CODEBASE)
// =============================================================================

let appState = {
    sales: [],
    purchases: [],
    challans: [],
    returns: [],
    vouchers: [],
    medicines: [
        { id: "PH-10001", systemId: "PH-10001", name: "DOLO 650 MG", packing: "15 TAB", batch: "DL-101", exp: "12/28", mrp: 30.91, purRate: 25.40, rateA: 28.50, rateB: 27.00, rateC: 26.50, stock: 150, gst: 12, hsn: "3004" },
        { id: "PH-10002", systemId: "PH-10002", name: "PAN 40 MG", packing: "10 TAB", batch: "PN-202", exp: "05/27", mrp: 120.00, purRate: 95.00, rateA: 110.00, rateB: 105.00, rateC: 100.00, stock: 80, gst: 12, hsn: "3004" },
        { id: "PH-10003", systemId: "PH-10003", name: "AZITHRAL 500", packing: "5 TAB", batch: "AZ-303", exp: "08/26", mrp: 115.00, purRate: 88.00, rateA: 105.00, rateB: 100.00, rateC: 98.00, stock: 45, gst: 12, hsn: "3004" }
    ],
    parties: [
        { id: "p1", name: "CASH CUSTOMER", group: "Sundry Debtors", city: "LOCAL", phone: "", gst: "", state: "Rajasthan", opBal: 0.0 },
        { id: "p2", name: "SHARMA MEDICALS", group: "Sundry Debtors", city: "JAIPUR", phone: "9876543210", gst: "08ABCDE1234F1Z5", state: "Rajasthan", opBal: 4500.0 },
        { id: "p3", name: "ABC DISTRIBUTORS", group: "Sundry Creditors", city: "UDAIPUR", phone: "9123456780", gst: "08FSBPM0623R1ZC", state: "Rajasthan", opBal: -12000.0 }
    ],
    activeSaleSession: {
        billNo: "INV-1001",
        billDate: "",
        paymentMode: "CASH",
        seriesPrefix: "INV-",
        selectedParty: null,
        cartItems: [],
        extraDiscount: 0.0,
        roundOff: 0.0,
        grandTotal: 0.0
    },
    activePurchaseCart: []
};

let syncIntervalId = null;

// Initial Dom Load
document.addEventListener("DOMContentLoaded", async () => {
    try {
        loadLocalData();
        populateDatalists();
        initNewSaleSession();
        initNewPurchaseSession();
        initNewChallanSession();
        updateDashboardKpis();

        const todayStr = new Date().toISOString().split('T')[0];
        const vDateEl = document.getElementById("vouchDate");
        const rDateEl = document.getElementById("retDate");
        const chDateEl = document.getElementById("chDate");
        if (vDateEl) vDateEl.value = todayStr;
        if (rDateEl) rDateEl.value = todayStr;
        if (chDateEl) chDateEl.value = todayStr;

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

// Navigation Function
function navigateToModule(moduleKey) {
    document.querySelectorAll("main > section").forEach(sec => sec.style.display = "none");
    document.querySelectorAll(".nav-chip").forEach(btn => btn.classList.remove("active"));

    let targetSectionId = `view-${moduleKey}`;
    if (moduleKey === 'billing') targetSectionId = 'view-sale-step1';

    const targetSec = document.getElementById(targetSectionId);
    if (targetSec) targetSec.style.display = "block";

    const activeChip = document.getElementById(`nav-chip-${moduleKey}`);
    if (activeChip) activeChip.classList.add("active");

    if (moduleKey === 'daybook') renderDaybook();
    if (moduleKey === 'ledgers') renderLedgers();
    if (moduleKey === 'stock') renderStock();
    if (moduleKey === 'challans') renderChallansRegister();
    if (moduleKey === 'returns') renderReturnsRegister();
}

function switchTab(tabId) {
    if (tabId === 'dashboard') navigateToModule('dashboard');
    else if (tabId === 'sale-entry') navigateToModule('billing');
    else if (tabId === 'sale-step1') {
        document.querySelectorAll("main > section").forEach(sec => sec.style.display = "none");
        document.getElementById("view-sale-step1").style.display = "block";
    }
    else if (tabId === 'billing-cart') {
        document.querySelectorAll("main > section").forEach(sec => sec.style.display = "none");
        document.getElementById("view-sale-step2").style.display = "block";
    }
    else if (tabId === 'purchase-entry') navigateToModule('purchases');
    else if (tabId === 'challans') navigateToModule('challans');
    else if (tabId === 'returns') navigateToModule('returns');
    else if (tabId === 'vouchers') navigateToModule('accounts');
    else if (tabId === 'daybook') navigateToModule('daybook');
    else if (tabId === 'ledgers') navigateToModule('ledgers');
    else if (tabId === 'stock') navigateToModule('stock');
    else if (tabId === 'masters') navigateToModule('masters');
}

function startNewSaleWorkflow() {
    initNewSaleSession();
    switchTab('sale-step1');
}

function startNewPurchaseWorkflow() {
    initNewPurchaseSession();
    navigateToModule('purchases');
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

    appState.activeSaleSession = {
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
    if (billDateEl) billDateEl.value = appState.activeSaleSession.billDate;

    clearSelectedSaleParty();
}

function updateSaleSeriesPrefix(prefix) {
    appState.activeSaleSession.seriesPrefix = prefix;
    const seq = Math.floor(1000 + Math.random() * 9000);
    const billNo = `${prefix}${seq}`;
    appState.activeSaleSession.billNo = billNo;
    const billNoEl = document.getElementById("saleBillNo");
    if (billNoEl) billNoEl.value = billNo;
}

function setSalePaymentMode(mode) {
    appState.activeSaleSession.paymentMode = mode;
    document.getElementById("modeCashBtn")?.classList.toggle("active", mode === "CASH");
    document.getElementById("modeCreditBtn")?.classList.toggle("active", mode === "CREDIT");
}

function onSalePartySelected(partyName) {
    const match = appState.parties.find(p => p.name.toLowerCase() === partyName.trim().toLowerCase());
    if (match) {
        appState.activeSaleSession.selectedParty = match;
        const nameEl = document.getElementById("previewPartyName");
        const metaEl = document.getElementById("previewPartyMeta");
        const cardEl = document.getElementById("selectedPartyPreviewCard");
        if (nameEl) nameEl.innerText = match.name;
        if (metaEl) metaEl.innerText = `City: ${match.city || 'LOCAL'} | GST: ${match.gst || 'N/A'} | Balance: ₹ ${match.opBal.toFixed(2)}`;
        if (cardEl) cardEl.style.display = "flex";
    }
}

function clearSelectedSaleParty() {
    appState.activeSaleSession.selectedParty = null;
    const searchEl = document.getElementById("salePartySearch");
    if (searchEl) searchEl.value = "";
    const cardEl = document.getElementById("selectedPartyPreviewCard");
    if (cardEl) cardEl.style.display = "none";
}

function proceedToBillingStep2() {
    if (!appState.activeSaleSession.selectedParty) {
        const cashParty = appState.parties.find(p => p.name.includes("CASH")) || appState.parties[0];
        appState.activeSaleSession.selectedParty = cashParty;
    }

    const titleEl = document.getElementById("billingHeaderTitle");
    const partyEl = document.getElementById("billingHeaderParty");
    if (titleEl) titleEl.innerText = `TAX INVOICE: ${appState.activeSaleSession.billNo}`;
    if (partyEl) partyEl.innerText = `Party: ${appState.activeSaleSession.selectedParty.name} | Date: ${appState.activeSaleSession.billDate} | Mode: ${appState.activeSaleSession.paymentMode}`;

    renderSaleCart();
    switchTab("billing-cart");
}

// =============================================================================
// ITEM ENTRY MODAL (RATE A / B / C FORMULA & MARG MATH)
// =============================================================================

let activeEditingProduct = null;

function openItemEntryModal() {
    const prodName = prompt("Enter Product Name to add (e.g. DOLO 650 MG):", appState.medicines[0].name);
    if (!prodName) return;

    const match = appState.medicines.find(m => m.name.toLowerCase().includes(prodName.toLowerCase())) || appState.medicines[0];
    activeEditingProduct = match;

    const titleEl = document.getElementById("entryModalProdTitle");
    if (titleEl) titleEl.innerText = `${match.name} (${match.packing})`;

    document.getElementById("eBatch").value = match.batch || "B-01";
    document.getElementById("eExp").value = match.exp || "12/28";
    document.getElementById("eMrp").value = match.mrp.toFixed(2);
    document.getElementById("eRate").value = match.rateA.toFixed(2);
    document.getElementById("eGst").value = match.gst;
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
    if (!activeEditingProduct) return;
    const rateCBox = document.getElementById("eRateCDiscBox");
    if (tier === "A") {
        document.getElementById("eRate").value = activeEditingProduct.rateA.toFixed(2);
        if (rateCBox) rateCBox.style.display = "none";
    } else if (tier === "B") {
        document.getElementById("eRate").value = activeEditingProduct.rateB.toFixed(2);
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
    if (!activeEditingProduct) return;
    const batch = document.getElementById("eBatch")?.value.trim() || "B-01";
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

    appState.activeSaleSession.cartItems.push({
        srNo: appState.activeSaleSession.cartItems.length + 1,
        medicineID: activeEditingProduct.id,
        name: activeEditingProduct.name,
        packing: activeEditingProduct.packing,
        batch: batch,
        exp: exp,
        hsn: activeEditingProduct.hsn || "3004",
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

    appState.activeSaleSession.cartItems.forEach((item, index) => {
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
    appState.activeSaleSession.cartItems.splice(index, 1);
    renderSaleCart();
}

function recalculateBillTotals() {
    const itemsTotal = appState.activeSaleSession.cartItems.reduce((sum, it) => sum + it.total, 0);
    const extraDisc = parseFloat(document.getElementById("saleExtraDiscount")?.value) || 0.0;
    
    const rawTotal = itemsTotal - extraDisc;
    const grandTotal = Math.round(rawTotal);
    const roundOff = grandTotal - rawTotal;

    appState.activeSaleSession.extraDiscount = extraDisc;
    appState.activeSaleSession.roundOff = roundOff;
    appState.activeSaleSession.grandTotal = grandTotal;

    const sumItemEl = document.getElementById("sumItemsTotal");
    const sumRoundEl = document.getElementById("sumRoundOff");
    const sumGrandEl = document.getElementById("sumGrandTotal");

    if (sumItemEl) sumItemEl.innerText = `₹ ${itemsTotal.toFixed(2)}`;
    if (sumRoundEl) sumRoundEl.innerText = `₹ ${roundOff.toFixed(2)}`;
    if (sumGrandEl) sumGrandEl.innerText = `₹ ${grandTotal.toFixed(2)}`;
}

async function finalizeAndSaveSaleBill(format) {
    if (appState.activeSaleSession.cartItems.length === 0) {
        alert("Cart is empty! Please add at least 1 item.");
        return;
    }

    const saleRecord = {
        id: "SALE_" + Date.now(),
        billNo: appState.activeSaleSession.billNo,
        partyId: appState.activeSaleSession.selectedParty?.id || "p1",
        partyName: appState.activeSaleSession.selectedParty?.name || "CASH CUSTOMER",
        partyGstin: appState.activeSaleSession.selectedParty?.gst || "N/A",
        partyState: appState.activeSaleSession.selectedParty?.state || "Rajasthan",
        date: appState.activeSaleSession.billDate,
        paymentMode: appState.activeSaleSession.paymentMode,
        items: [...appState.activeSaleSession.cartItems],
        totalAmount: appState.activeSaleSession.grandTotal,
        extraDiscount: appState.activeSaleSession.extraDiscount,
        roundOff: appState.activeSaleSession.roundOff
    };

    appState.sales.push(saleRecord);

    // Deduct Live Stock
    saleRecord.items.forEach(it => {
        const m = appState.medicines.find(med => med.id === it.medicineID || med.name.toLowerCase() === it.name.toLowerCase());
        if (m) m.stock = Math.max(0, m.stock - (it.qty + it.freeQty));
    });

    saveLocalData();
    updateDashboardKpis();

    if (window.GoogleDriveSync) {
        GoogleDriveSync.pushToDrive(appState);
    }

    // Trigger Print View
    const printArea = document.getElementById("printArea");
    if (printArea) {
        printArea.innerHTML = `
            <div style="padding: 20px; font-family: sans-serif; max-width: ${format === 'Thermal' ? '300px' : '800px'}; margin: 0 auto;">
                <h2 style="text-align: center; margin-bottom: 2px;">PHAROAH ERP - TAX INVOICE</h2>
                <p style="text-align: center; font-size: 11px; margin-bottom: 10px;">ARCHITECT INVOICING SERIES</p>
                <hr/>
                <p><strong>Invoice No:</strong> ${saleRecord.billNo} | <strong>Date:</strong> ${saleRecord.date}</p>
                <p><strong>Customer:</strong> ${saleRecord.partyName} (GST: ${saleRecord.partyGstin})</p>
                <hr/>
                <table style="width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 11px;">
                    <thead>
                        <tr style="border-bottom: 1px solid #000;">
                            <th style="text-align: left;">Item</th><th>Batch</th><th>Qty</th><th>Rate</th><th>Total</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${saleRecord.items.map(i => `
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
                    <p>Extra Discount: -₹${saleRecord.extraDiscount.toFixed(2)}</p>
                    <p>Round Off: ₹${saleRecord.roundOff.toFixed(2)}</p>
                    <h3 style="font-size: 15px;">NET PAYABLE: ₹${saleRecord.totalAmount.toFixed(2)}</h3>
                </div>
                <p style="text-align: center; font-size: 9px; margin-top: 20px;">System Generated Document | Powered by Pharoah ERP Cloud</p>
            </div>
        `;
        window.print();
    }

    initNewSaleSession();
    switchTab("sale-entry");
    alert("✅ Bill Successfully Finalized, Stock Deducted & Synced to Google Drive!");
}

// =============================================================================
// PURCHASE, CHALLANS, RETURNS, VOUCHERS, LEDGERS & MASTERS
// =============================================================================

function initNewPurchaseSession() {
    const seq = Math.floor(100 + Math.random() * 900);
    const pInt = document.getElementById("purInternalNo");
    const pDate = document.getElementById("purBillDate");
    const pEntry = document.getElementById("purEntryDate");
    if (pInt) pInt.value = `PUR-${seq}`;
    if (pDate) pDate.value = new Date().toISOString().split('T')[0];
    if (pEntry) pEntry.value = new Date().toISOString().split('T')[0];
    appState.activePurchaseCart = [];
    renderPurCart();
}

function autoFillPurProductDetails(val) {
    const match = appState.medicines.find(m => m.name.toLowerCase() === val.toLowerCase());
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

    appState.activePurchaseCart.push({
        srNo: appState.activePurchaseCart.length + 1,
        name, batch, exp, mrp, rate, qty, freeQty: free, gstRate: gst, total
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

    appState.activePurchaseCart.forEach((item, index) => {
        grandTotal += item.total;
        tbody.innerHTML += `
            <tr>
                <td>${index + 1}</td>
                <td><strong>${item.name}</strong></td>
                <td>${item.batch}</td>
                <td>${item.exp}</td>
                <td>₹ ${item.mrp.toFixed(2)}</td>
                <td>₹ ${item.rate.toFixed(2)}</td>
                <td>${item.qty} + ${item.freeQty}</td>
                <td>${item.gstRate}%</td>
                <td><strong>₹ ${item.total.toFixed(2)}</strong></td>
                <td><button class="btn btn-danger-sm" onclick="removePurCartRow(${index})">✕</button></td>
            </tr>
        `;
    });

    const purTotalEl = document.getElementById("purGrandTotal");
    if (purTotalEl) purTotalEl.innerText = `₹ ${grandTotal.toFixed(2)}`;
}

function removePurCartRow(index) {
    appState.activePurchaseCart.splice(index, 1);
    renderPurCart();
}

function savePurchaseInward() {
    const supplier = document.getElementById("purSupplierSearch")?.value.trim();
    const distBillNo = document.getElementById("purBillNo")?.value.trim();
    if (!supplier || !distBillNo || appState.activePurchaseCart.length === 0) {
        alert("Please specify Supplier, Bill No and at least 1 item.");
        return;
    }

    const netTotal = appState.activePurchaseCart.reduce((sum, it) => sum + it.total, 0);

    const purRecord = {
        id: "PUR_" + Date.now(),
        internalNo: document.getElementById("purInternalNo")?.value || "PUR-1",
        billNo: distBillNo,
        distributorName: supplier,
        date: document.getElementById("purBillDate")?.value || new Date().toISOString().split('T')[0],
        entryDate: document.getElementById("purEntryDate")?.value || new Date().toISOString().split('T')[0],
        paymentMode: document.getElementById("purPayMode")?.value || "CREDIT",
        items: [...appState.activePurchaseCart],
        totalAmount: netTotal
    };

    appState.purchases.push(purRecord);

    // Increase Live Stock
    purRecord.items.forEach(it => {
        let m = appState.medicines.find(med => med.name.toLowerCase() === it.name.toLowerCase());
        if (m) {
            m.stock += (it.qty + it.freeQty);
            m.purRate = it.rate;
            m.mrp = it.mrp;
        }
    });

    saveLocalData();
    updateDashboardKpis();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(appState);

    alert("✅ Inward Stock Saved and Live Inventory Updated!");
    initNewPurchaseSession();
}

function initNewChallanSession() {
    const chEl = document.getElementById("chBillNo");
    if (chEl) chEl.value = `SCH-${Math.floor(100 + Math.random() * 900)}`;
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
    appState.challans.push({
        id: "CH_" + Date.now(),
        billNo, date, partyName, itemName, qty, rate, totalAmount: total, remarks, status: "Pending"
    });

    saveLocalData();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(appState);

    alert("✅ Delivery Challan Recorded!");
    initNewChallanSession();
    renderChallansRegister();
}

function renderChallansRegister() {
    const tbody = document.getElementById("challanRegisterTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";

    appState.challans.forEach((ch, idx) => {
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
    const noteNo = `${type}-${Math.floor(100 + Math.random() * 900)}`;

    appState.returns.push({
        id: "RET_" + Date.now(),
        type, noteNo, disposition, party, item, qty, rate, totalAmount: total, date, status: "Active"
    });

    if (type === "CN" && disposition === "Sellable") {
        const m = appState.medicines.find(med => med.name.toLowerCase() === item.toLowerCase());
        if (m) m.stock += qty;
    }

    saveLocalData();
    updateDashboardKpis();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(appState);

    alert(`✅ ${type} #${noteNo} Recorded Successfully!`);
    renderReturnsRegister();
}

function renderReturnsRegister() {
    const tbody = document.getElementById("returnsRegisterTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";

    appState.returns.forEach(r => {
        tbody.innerHTML += `
            <tr>
                <td>${r.date}</td>
                <td><strong>${r.noteNo}</strong></td>
                <td><span style="color:${r.type === 'CN' ? 'var(--accent-red)' : 'var(--accent-orange)'}; font-weight:bold;">${r.type}</span></td>
                <td>${r.party}</td>
                <td>${r.disposition}</td>
                <td><strong>₹ ${r.totalAmount.toFixed(2)}</strong></td>
            </tr>
        `;
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

    const vNo = `${type === 'RECEIPT' ? 'RCT' : 'PAY'}-${Math.floor(100 + Math.random() * 900)}`;
    appState.vouchers.push({
        id: "VOUC_" + Date.now(),
        type, voucherNo: vNo, date, partyName: party, amount, paymentMode: mode, depositedIn, chequeNo, narration, status: "Active"
    });

    saveLocalData();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(appState);

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

    appState.sales.filter(s => s.date === filterDate).forEach(s => {
        tbody.innerHTML += `<tr><td>${s.date}</td><td><span style="color:var(--accent-emerald); font-weight:bold;">SALE</span></td><td>${s.partyName}</td><td>${s.billNo}</td><td>₹ ${s.totalAmount.toFixed(2)}</td><td>-</td></tr>`;
    });
    appState.purchases.filter(p => p.date === filterDate).forEach(p => {
        tbody.innerHTML += `<tr><td>${p.date}</td><td><span style="color:var(--accent-orange); font-weight:bold;">PURCHASE</span></td><td>${p.distributorName}</td><td>${p.billNo}</td><td>-</td><td>₹ ${p.totalAmount.toFixed(2)}</td></tr>`;
    });
    appState.vouchers.filter(v => v.date === filterDate).forEach(v => {
        const isRec = v.type === "RECEIPT";
        tbody.innerHTML += `<tr><td>${v.date}</td><td><span style="color:${isRec ? 'var(--accent-emerald)' : 'var(--accent-red)'}; font-weight:bold;">${v.type}</span></td><td>${v.partyName} (${v.depositedIn})</td><td>${v.voucherNo}</td><td>${isRec ? '₹ ' + v.amount.toFixed(2) : '-'}</td><td>${!isRec ? '₹ ' + v.amount.toFixed(2) : '-'}</td></tr>`;
    });
}

function renderLedgers() {
    const tbody = document.getElementById("ledgerTableBody");
    if (!tbody) return;
    const query = document.getElementById("ledgerSearchParty")?.value.toLowerCase().trim() || "";
    tbody.innerHTML = "";

    appState.sales.filter(s => s.partyName.toLowerCase().includes(query)).forEach(s => {
        tbody.innerHTML += `<tr><td>${s.date}</td><td>Sale Invoice #${s.billNo}</td><td>SALE</td><td>₹ ${s.totalAmount.toFixed(2)}</td><td>-</td><td>₹ ${s.totalAmount.toFixed(2)} Dr</td></tr>`;
    });
    appState.vouchers.filter(v => v.partyName.toLowerCase().includes(query)).forEach(v => {
        const isRec = v.type === "RECEIPT";
        tbody.innerHTML += `<tr><td>${v.date}</td><td>${v.type} Voucher #${v.voucherNo} (${v.paymentMode})</td><td>${v.type}</td><td>${!isRec ? '₹ ' + v.amount.toFixed(2) : '-'}</td><td>${isRec ? '₹ ' + v.amount.toFixed(2) : '-'}</td><td>-</td></tr>`;
    });
}

function renderStock() {
    const tbody = document.getElementById("stockTableBody");
    if (!tbody) return;
    const query = document.getElementById("stockSearchInput")?.value.toLowerCase().trim() || "";
    tbody.innerHTML = "";

    appState.medicines.filter(m => m.name.toLowerCase().includes(query) || (m.batch && m.batch.toLowerCase().includes(query))).forEach(m => {
        tbody.innerHTML += `
            <tr>
                <td><span class="badge-tag">${m.systemId || m.id}</span></td>
                <td><strong>${m.name}</strong></td>
                <td>${m.packing}</td>
                <td>${m.batch || 'B-01'}</td>
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

    const nextIdNum = 10001 + appState.medicines.length;
    const sysId = `PH-${nextIdNum}`;

    appState.medicines.push({
        id: sysId, systemId: sysId, name, packing: pack, drugForm: "TAB", hsn: "3004",
        batch: "B-01", exp: "12/28", mrp, purRate, rateA, rateB: rateA * 0.95, rateC: rateA * 0.92, stock: 0, gst
    });

    saveLocalData();
    populateDatalists();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(appState);

    alert(`✅ Product ${name} saved with System ID ${sysId}`);
    document.getElementById("mProdName").value = "";
    renderStock();
}

function saveNewPartyMaster() {
    const name = document.getElementById("mPartyName")?.value.trim().toUpperCase();
    const group = document.getElementById("mPartyGroup")?.value || "Sundry Debtors";
    const gst = document.getElementById("mPartyGst")?.value.trim().toUpperCase() || "N/A";
    const city = document.getElementById("mPartyCity")?.value.trim().toUpperCase() || "LOCAL";
    const phone = document.getElementById("mPartyPhone")?.value.trim() || "";
    const opBal = parseFloat(document.getElementById("mPartyOpBal")?.value) || 0.0;

    if (!name) { alert("Party / Firm Name is required!"); return; }

    appState.parties.push({
        id: "p_" + Date.now(), name, group, gst, city, state: "Rajasthan", phone, opBal
    });

    saveLocalData();
    populateDatalists();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(appState);

    alert(`✅ Party ${name} registered in ${group}`);
    document.getElementById("mPartyName").value = "";
}

function autoExtractPanFromGst(gstVal) {
    if (gstVal.length >= 12) {
        document.getElementById("mPartyPan").value = gstVal.substring(2, 12).toUpperCase();
    }
}

function formatExpiryField(input) {
    let v = input.value.replace(/[^0-9]/g, '');
    if (v.length >= 2 && !input.value.includes('/')) {
        v = v.substring(0, 2) + '/' + v.substring(2);
    }
    if (v.length > 5) v = v.substring(0, 5);
    input.value = v;
}

function populateDatalists() {
    const iList = document.getElementById("itemDatalist");
    if (iList) iList.innerHTML = appState.medicines.map(m => `<option value="${m.name}"></option>`).join('');
    const pList = document.getElementById("partyDatalist");
    if (pList) pList.innerHTML = appState.parties.map(p => `<option value="${p.name}"></option>`).join('');
}

function updateDashboardKpis() {
    const totalSale = appState.sales.reduce((sum, s) => sum + s.totalAmount, 0);
    const totalPur = appState.purchases.reduce((sum, p) => sum + p.totalAmount, 0);
    // Calculated Taxable Inventory Stock Value (Never Negative!)
    const stockVal = appState.medicines.reduce((sum, m) => sum + (Math.max(0, m.stock) * m.purRate), 0);

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
            Object.assign(appState, cloudData);
            saveLocalData();
            populateDatalists();
            updateDashboardKpis();
            if (!isSilent) console.log("☁️ Drive data synchronized.");
        }
    }
}

function saveLocalData() { localStorage.setItem("pharoah_web_state", JSON.stringify(appState)); }
function loadLocalData() {
    const saved = localStorage.getItem("pharoah_web_state");
    if (saved) { try { Object.assign(appState, JSON.parse(saved)); } catch(e) {} }
}
