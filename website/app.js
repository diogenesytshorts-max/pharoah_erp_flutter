let appState = {
    sales: [],
    purchases: [],
    challans: [],
    returns: [],
    vouchers: [],
    medicines: [
        { id: "1", name: "DOLO 650 MG", batch: "DL-101", exp: "12/28", mrp: 30.91, rate: 28.50, stock: 150, gst: 12 },
        { id: "2", name: "PAN 40 MG", batch: "PN-202", exp: "05/27", mrp: 120.00, rate: 95.00, stock: 80, gst: 12 },
        { id: "3", name: "AZITHRAL 500", batch: "AZ-303", exp: "08/26", mrp: 115.00, rate: 88.00, stock: 45, gst: 12 }
    ],
    parties: [
        { id: "p1", name: "CASH CUSTOMER", city: "LOCAL", phone: "", gst: "" },
        { id: "p2", name: "SHARMA MEDICALS", city: "JAIPUR", phone: "9876543210", gst: "08ABCDE1234F1Z5" }
    ],
    currentCart: []
};

// Periodic polling interval ID
let syncIntervalId = null;

document.addEventListener("DOMContentLoaded", async () => {
    loadLocalData();
    generateNewBillNumber();
    generateNewChallanNumber();
    document.getElementById("billDate").value = new Date().toISOString().split('T')[0];
    updateDashboardKpis();

    // Initial Pull from Drive
    await pullLatestFromDrive();

    // Start 30-second live background auto-sync from Drive
    if (syncIntervalId) clearInterval(syncIntervalId);
    syncIntervalId = setInterval(async () => {
        if (window.GoogleDriveSync && GoogleDriveSync.config.apiUrl) {
            await pullLatestFromDrive(true);
        }
    }, 30000);
});

async function pullLatestFromDrive(isSilent = false) {
    if (window.GoogleDriveSync && GoogleDriveSync.config.apiUrl) {
        const cloudData = await GoogleDriveSync.pullFromDrive();
        if (cloudData) {
            Object.assign(appState, cloudData);
            saveLocalData();
            updateDashboardKpis();
            if (!isSilent) console.log("☁️ Drive data synchronized with local memory.");
        }
    }
}

function switchTab(tabId) {
    document.querySelectorAll("main > section").forEach(sec => sec.style.display = "none");
    document.querySelectorAll(".nav-btn").forEach(btn => btn.classList.remove("active"));
    
    const target = document.getElementById(`tab-${tabId}`);
    if (target) target.style.display = "block";
    
    const activeBtn = Array.from(document.querySelectorAll(".nav-btn")).find(b => b.getAttribute("onclick")?.includes(tabId));
    if (activeBtn) activeBtn.classList.add("active");

    if (tabId === 'ledger') renderLedger();
    if (tabId === 'daybook') renderDaybook();
    if (tabId === 'stock') renderStock();
}

function openGuideModal() { document.getElementById("guideModal").classList.add("active"); }
function closeGuideModal() { document.getElementById("guideModal").classList.remove("active"); }
function openDriveSettings() {
    if (window.GoogleDriveSync) {
        document.getElementById("driveUserEmail").value = GoogleDriveSync.config.userEmail || "";
        document.getElementById("driveApiUrl").value = GoogleDriveSync.config.apiUrl || "";
    }
    document.getElementById("driveSettingsModal").classList.add("active");
}
function closeDriveSettings() { document.getElementById("driveSettingsModal").classList.remove("active"); }

function saveDriveSettingsFromModal() {
    const email = document.getElementById("driveUserEmail").value.trim();
    const url = document.getElementById("driveApiUrl").value.trim();
    if (!url) { alert("कृपया Webhook URL भरें!"); return; }
    if (window.GoogleDriveSync) { GoogleDriveSync.saveConfig(url, email); }
    closeDriveSettings();
    pullLatestFromDrive();
    alert("✅ Google Drive 2-Way Sync कनेक्ट हो गया!");
}

function generateNewBillNumber() {
    const seq = Math.floor(1000 + Math.random() * 9000);
    document.getElementById("billNo").value = `WEB-INV-${seq}`;
    appState.currentCart = [];
    renderCart();
}

function generateNewChallanNumber() {
    const el = document.getElementById("challanNo");
    if (el) el.value = `WEB-CH-${Math.floor(100 + Math.random() * 900)}`;
}

function addItemToCurrentBill() {
    const name = document.getElementById("itemSearch").value.trim();
    const batch = document.getElementById("itemBatch").value.trim();
    const exp = document.getElementById("itemExp").value.trim();
    const qty = parseFloat(document.getElementById("itemQty").value) || 1;
    const rate = parseFloat(document.getElementById("itemRate").value) || 0;
    const gst = parseFloat(document.getElementById("itemGst").value) || 0;

    if (!name) { alert("कृपया आइटम का नाम भरें!"); return; }

    const total = qty * rate * (1 + gst / 100);
    appState.currentCart.push({ srNo: appState.currentCart.length + 1, name, batch, exp, qty, rate, gst, total });
    renderCart();
    document.getElementById("itemSearch").value = "";
}

function renderCart() {
    const tbody = document.getElementById("cartTableBody");
    tbody.innerHTML = "";
    let grandTotal = 0;
    appState.currentCart.forEach((item, index) => {
        grandTotal += item.total;
        tbody.innerHTML += `
            <tr>
                <td>${index + 1}</td><td><strong>${item.name}</strong></td>
                <td>${item.batch} (${item.exp})</td><td>${item.qty}</td>
                <td>₹ ${item.rate.toFixed(2)}</td><td>${item.gst}%</td>
                <td><strong>₹ ${item.total.toFixed(2)}</strong></td>
                <td><button class="btn btn-danger" style="padding:4px 8px; font-size:0.7rem;" onclick="removeCartItem(${index})">X</button></td>
            </tr>
        `;
    });
    document.getElementById("billGrandTotal").innerText = `₹ ${grandTotal.toFixed(2)}`;
}

function removeCartItem(index) { appState.currentCart.splice(index, 1); renderCart(); }

function saveAndPrintBill(format) {
    if (appState.currentCart.length === 0) { alert("बिल खाली है!"); return; }
    const billNo = document.getElementById("billNo").value;
    const billDate = document.getElementById("billDate").value;
    const customer = document.getElementById("customerName").value.trim() || "CASH CUSTOMER";
    const grandTotal = appState.currentCart.reduce((sum, i) => sum + i.total, 0);

    appState.sales.push({ billNo, billDate, customer, items: [...appState.currentCart], totalAmount: grandTotal });
    saveLocalData();
    updateDashboardKpis();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(appState);

    window.print();
    generateNewBillNumber();
    alert("✅ बिल सेव हुआ और Google Drive में सिंक हो गया!");
}

function recordChallanEntry() {
    const cNo = document.getElementById("challanNo").value;
    const party = document.getElementById("challanParty").value.trim();
    const item = document.getElementById("challanItem").value.trim();
    const qty = parseFloat(document.getElementById("challanQty").value) || 1;

    if (!party || !item) { alert("कृपया विवरण भरें!"); return; }
    if (!appState.challans) appState.challans = [];
    appState.challans.push({ cNo, party, item, qty, date: new Date().toISOString() });
    saveLocalData();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(appState);
    alert("✅ चालान सेव हुआ!");
    generateNewChallanNumber();
}

function recordReturnEntry() {
    const type = document.getElementById("returnType").value;
    const party = document.getElementById("returnParty").value.trim();
    const item = document.getElementById("returnItem").value.trim();
    const qty = parseFloat(document.getElementById("returnQty").value) || 1;
    const total = parseFloat(document.getElementById("returnAmt").value) || 0;

    if (!party || !item) { alert("कृपया विवरण भरें!"); return; }
    if (!appState.returns) appState.returns = [];
    appState.returns.push({ type, party, item, qty, total, date: new Date().toISOString() });
    saveLocalData();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(appState);
    alert("✅ रिटर्न (CN/DN) सेव हुआ!");
}

function recordPurchaseEntry() {
    const supplier = document.getElementById("purSupplier").value.trim();
    const billNo = document.getElementById("purBillNo").value.trim();
    const name = document.getElementById("purItemName").value.trim();
    const qty = parseFloat(document.getElementById("purQty").value) || 0;
    const rate = parseFloat(document.getElementById("purRate").value) || 0;

    if (!supplier || !name) { alert("कृपया विवरण भरें!"); return; }
    appState.purchases.push({ supplier, billNo, name, qty, rate, total: qty * rate, date: new Date().toISOString() });
    saveLocalData();
    updateDashboardKpis();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(appState);
    alert("✅ इनवर्ड परचेज सेव हुआ!");
}

function renderDaybook() {
    const tbody = document.getElementById("daybookTableBody");
    tbody.innerHTML = "";
    appState.sales.forEach(s => {
        tbody.innerHTML += `<tr><td>${s.billDate}</td><td><span style="color:var(--accent-emerald);">SALE</span></td><td>${s.customer}</td><td>₹ ${s.totalAmount.toFixed(2)}</td><td>-</td></tr>`;
    });
    appState.purchases.forEach(p => {
        tbody.innerHTML += `<tr><td>${p.date.split('T')[0]}</td><td><span style="color:var(--accent-orange);">PURCHASE</span></td><td>${p.supplier}</td><td>-</td><td>₹ ${p.total.toFixed(2)}</td></tr>`;
    });
}

function renderLedger() {
    const tbody = document.getElementById("ledgerTableBody");
    const query = document.getElementById("ledgerSearch").value.toLowerCase();
    tbody.innerHTML = "";
    appState.sales.filter(s => s.customer.toLowerCase().includes(query)).forEach(s => {
        tbody.innerHTML += `<tr><td>${s.billDate}</td><td><strong>${s.customer}</strong></td><td>SALE</td><td>₹ ${s.totalAmount.toFixed(2)}</td><td>-</td><td>₹ ${s.totalAmount.toFixed(2)}</td></tr>`;
    });
}

function renderStock() {
    const tbody = document.getElementById("stockTableBody");
    tbody.innerHTML = "";
    appState.medicines.forEach(m => {
        tbody.innerHTML += `<tr><td><strong>${m.name}</strong></td><td>${m.batch}</td><td>${m.exp}</td><td>₹${m.mrp}</td><td>₹${m.rate}</td><td><strong>${m.stock}</strong></td></tr>`;
    });
}

function addNewProductMaster() {
    const name = document.getElementById("mProdName").value.trim();
    const mrp = parseFloat(document.getElementById("mProdMrp").value) || 0;
    const rate = parseFloat(document.getElementById("mProdRate").value) || 0;

    if (!name) { alert("प्रोडक्ट का नाम डालें!"); return; }
    appState.medicines.push({ id: Date.now().toString(), name, batch: "NEW-01", exp: "12/28", mrp, rate, stock: 0, gst: 12 });
    saveLocalData();
    if (window.GoogleDriveSync) GoogleDriveSync.pushToDrive(appState);
    alert("✅ नया प्रोडक्ट मास्टर में जुड़ गया!");
    renderStock();
}

function updateDashboardKpis() {
    const totalSale = appState.sales.reduce((sum, s) => sum + s.totalAmount, 0);
    const totalPur = appState.purchases.reduce((sum, p) => sum + p.total, 0);
    document.getElementById("kpi-sale").innerText = `₹ ${totalSale.toFixed(2)}`;
    document.getElementById("kpi-pur").innerText = `₹ ${totalPur.toFixed(2)}`;
    document.getElementById("kpi-stock").innerText = `₹ ${(totalPur - totalSale + 50000).toFixed(2)}`;
}

function saveLocalData() { localStorage.setItem("pharoah_web_state", JSON.stringify(appState)); }
function loadLocalData() {
    const saved = localStorage.getItem("pharoah_web_state");
    if (saved) { try { Object.assign(appState, JSON.parse(saved)); } catch(e) {} }
}
