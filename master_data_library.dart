class MasterDataLibrary {
  // --- TOP 100 PHARMA COMPANIES ---
  static List<String> topCompanies = [
    "CIPLA LTD", "MANKIND PHARMA", "SUN PHARMA", "ABBOTT INDIA", "ALKEM LABORATORIES",
    "LUPIN LTD", "DR REDDYS LAB", "ZYDUS CADILA", "GLAXOSMITHKLINE", "PFIZER",
    "INTAS PHARMACEUTICALS", "TORRENT PHARMA", "GLENMARK PHARMA", "ARISTO PHARMA",
    "MICRO LABS", "IPCA LABORATORIES", "USV PVT LTD", "JB CHEMICALS", "ERIS LIFESCIENCES",
    "AJANTA PHARMA", "BLUE CROSS LABS", "LEEFORD HEALTHCARE", "LIFESTAR PHARMA",
    "CADILA PHARMA", "FDC LTD", "HETERO HEALTHCARE", "ZYDUS WELLNESS", "PIRAMAL PHARMA",
    "NATCO PHARMA", "AUROBINDO PHARMA", "WOCKHARDT LTD", "ALEMBIC PHARMA", "APOLLO",
    "LA RENON HEALTHCARE", "MACLEODS PHARMA", "SANOFI INDIA", "MEYER ORGANICS",
    "WALLACE PHARMA", "WIN-MEDICARE", "CORONA REMEDIES", "ZUVENTUS HEALTHCARE",
    "INDoco REMEDIES", "FRANCO-INDIAN", "TROIKAA PHARMA", "FOURRTS INDIA", "WALKER",
    "MERCURY PHARMA", "BIOCON LTD", "EMCURE PHARMA", "BLUE CROSS", "LUPIN", "WOCKHARDT",
    // ... Baki aap dukan ki list ke hisab se aur bhi add kar sakte hain
  ];

  // --- TOP 100 SALTS (Mono, Duo, Multi) ---
  static List<Map<String, String>> topSalts = [
    // MONO SALTS
    {"name": "PARACETAMOL 500MG", "type": "Mono"},
    {"name": "PARACETAMOL 650MG", "type": "Mono"},
    {"name": "AMOXICILLIN 500MG", "type": "Mono"},
    {"name": "AZITHROMYCIN 500MG", "type": "Mono"},
    {"name": "PANTOPRAZOLE 40MG", "type": "Mono"},
    {"name": "OMEPRAZOLE 20MG", "type": "Mono"},
    {"name": "CETIRIZINE 10MG", "type": "Mono"},
    {"name": "TELMISARTAN 40MG", "type": "Mono"},
    {"name": "METFORMIN 500MG", "type": "Mono"},
    {"name": "ATORVASTATIN 10MG", "type": "Mono"},
    
    // DUO COMBINATIONS (Two Salts)
    {"name": "AMOXICILLIN + CLAVULANIC ACID", "type": "Duo"},
    {"name": "PANTOPRAZOLE + DOMPERIDONE", "type": "Duo"},
    {"name": "DICLOFENAC + PARACETAMOL", "type": "Duo"},
    {"name": "ACECLOFENAC + PARACETAMOL", "type": "Duo"},
    {"name": "METFORMIN + GLIMEPIRIDE", "type": "Duo"},
    {"name": "PARACETAMOL + DOMPERIDONE", "type": "Duo"},
    {"name": "NIMESULIDE + PARACETAMOL", "type": "Duo"},
    {"name": "LEVOCETIRIZINE + MONTELUKAST", "type": "Duo"},
    {"name": "OFLOXACIN + ORNIDAZOLE", "type": "Duo"},
    {"name": "ALBENDAZOLE + IVERMECTIN", "type": "Duo"},

    // MULTI COMBINATIONS (3 or more)
    {"name": "ACECLOFENAC + PARACETAMOL + CHLORZOXAZONE", "type": "Multi"},
    {"name": "PARACETAMOL + PHENYLEPHRINE + CHLORPHENIRAMINE", "type": "Multi"},
    {"name": "AMOXICILLIN + CLAVULANATE + LACTOBACILLUS", "type": "Multi"},
    {"name": "B-COMPLEX + VITAMIN C + ZINC", "type": "Multi"},
    {"name": "MAGNESIUM + ALUMINIUM + SIMETHICONE", "type": "Multi"},
    {"name": "IRON + FOLIC ACID + VITAMIN B12", "type": "Multi"},
    {"name": "MULTIVITAMIN + MULTIMINERAL + ANTIOXIDANTS", "type": "Multi"},
  ];

  // --- STANDARD DRUG TYPES ---
  static List<String> drugTypes = [
    "GENERAL / OTC", "SCHEDULE H", "SCHEDULE H1", "SCHEDULE G", "NARCOTIC (NDPS)", "TB MEDICINE"
  ];
}
