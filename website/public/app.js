import { initializeApp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js";
import { getFirestore, doc, onSnapshot, updateDoc, increment, collection, addDoc, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";

// Firebase configuration from registered Web App
const firebaseConfig = {
  projectId: "aura-bervos",
  appId: "1:1026476263463:web:52f0b2e7874dd3760de602",
  storageBucket: "aura-bervos.firebasestorage.app",
  apiKey: "AIzaSyBIHruWn-Y3HJ-tZxjVMkfBTmKCEY1m8DM",
  authDomain: "aura-bervos.firebaseapp.com",
  messagingSenderId: "1026476263463",
  projectNumber: "1026476263463"
};

// Initialize Firebase with resilience
let db = null;
try {
  const app = initializeApp(firebaseConfig);
  db = getFirestore(app);
} catch (error) {
  console.error("Firebase failed to initialize:", error);
}

// App Version Placeholder (Stamped dynamically by GitHub Actions compiler during deploy)
const APP_VERSION = "__AURA_VERSION__";

// Asynchronously pre-fetch user's public IP address for download metadata logging
let userIpAddress = "unknown";
async function fetchUserIp() {
  try {
    const response = await fetch("https://api.ipify.org?format=json");
    if (response.ok) {
      const data = await response.json();
      userIpAddress = data.ip || "unknown";
    }
  } catch (error) {
    console.warn("Could not pre-fetch public IP address:", error);
  }
}

document.addEventListener("DOMContentLoaded", () => {
  initThemeSwitcher();
  initDownloadTracker();
  fetchUserIp(); // Begin fetching IP in the background
  initAppVersion(); // Inject version information
});

/**
 * Injects the active Aura version into the Hero section version view
 */
function initAppVersion() {
  const versionTextEl = document.getElementById("app-version-text");
  if (versionTextEl && APP_VERSION !== "__AURA_VERSION__") {
    versionTextEl.textContent = APP_VERSION;
  }
}

/**
 * Handles toggling between Music and Photos modes
 */
function initThemeSwitcher() {
  const musicTab = document.getElementById("tab-music");
  const photosTab = document.getElementById("tab-photos");
  const body = document.body;

  if (!musicTab || !photosTab) return;

  musicTab.addEventListener("click", () => {
    if (!body.classList.contains("music-mode")) {
      musicTab.classList.add("active");
      photosTab.classList.remove("active");
      body.classList.add("music-mode");
      body.classList.remove("photos-mode");
      updateMockup("music");
    }
  });

  photosTab.addEventListener("click", () => {
    if (!body.classList.contains("photos-mode")) {
      photosTab.classList.add("active");
      musicTab.classList.remove("active");
      body.classList.add("photos-mode");
      body.classList.remove("music-mode");
      updateMockup("photos");
    }
  });
}

/**
 * Programmatically updates mockup values to ensure robust, fluid, and squish-free layouts
 */
function updateMockup(mode) {
  const t1 = document.getElementById("mockup-title-1");
  const v1 = document.getElementById("mockup-val-1");
  const u1 = document.getElementById("mockup-unit-1");
  
  const t2 = document.getElementById("mockup-title-2");
  const l1 = document.getElementById("mockup-row-1-label");
  const p1 = document.getElementById("mockup-row-1-pct");
  const f1 = document.getElementById("mockup-row-1-fill");
  
  const l2 = document.getElementById("mockup-row-2-label");
  const p2 = document.getElementById("mockup-row-2-pct");
  const f2 = document.getElementById("mockup-row-2-fill");
  
  const l3 = document.getElementById("mockup-row-3-label");
  const p3 = document.getElementById("mockup-row-3-pct");
  const f3 = document.getElementById("mockup-row-3-fill");
  
  const t3Text = document.getElementById("mockup-title-3-text");
  const musicBody = document.getElementById("mockup-music-body");
  const photosBody = document.getElementById("mockup-photos-body");

  if (mode === "music") {
    if (t1) t1.textContent = "Lifetime Listening Time";
    if (v1) {
      // Retain the unit span
      v1.innerHTML = '82,410 <span style="font-size: 16px; font-weight: 500; color:var(--text-muted);" id="mockup-unit-1">min</span>';
    }
    
    if (t2) t2.textContent = "Genre Composition";
    if (l1) l1.textContent = "Alternative & Indie";
    if (p1) p1.textContent = "85%";
    if (f1) f1.style.width = "85%";
    
    if (l2) l2.textContent = "Electronic & House";
    if (p2) p2.textContent = "60%";
    if (f2) f2.style.width = "60%";
    
    if (l3) l3.textContent = "Classical";
    if (p3) p3.textContent = "45%";
    if (f3) f3.style.width = "45%";
    
    if (t3Text) t3Text.textContent = "💎 Forgotten Gem";
    if (musicBody) musicBody.classList.remove("hidden");
    if (photosBody) photosBody.classList.add("hidden");
  } else {
    if (t1) t1.textContent = "Total Photo Catalog";
    if (v1) {
      // Retain the unit span
      v1.innerHTML = '14,832 <span style="font-size: 16px; font-weight: 500; color:var(--text-muted);" id="mockup-unit-1">items</span>';
    }
    
    if (t2) t2.textContent = "Camera Gear Distribution";
    if (l1) l1.textContent = "Fujifilm X-T5";
    if (p1) p1.textContent = "75%";
    if (f1) f1.style.width = "75%";
    
    if (l2) l2.textContent = "iPhone 15 Pro Max";
    if (p2) p2.textContent = "55%";
    if (f2) f2.style.width = "55%";
    
    if (l3) l3.textContent = "Sony A7R V";
    if (p3) p3.textContent = "40%";
    if (f3) f3.style.width = "40%";
    
    if (t3Text) t3Text.textContent = "🔮 Photography Persona";
    if (musicBody) musicBody.classList.add("hidden");
    if (photosBody) photosBody.classList.remove("hidden");
  }
}

/**
 * Listens to Firestore download statistics and updates the DOM in real-time
 */
function initDownloadTracker() {
  const counterEl = document.getElementById("download-counter");
  const counterTextEl = document.getElementById("counter-text");
  const downloadBtn = document.getElementById("download-btn");

  if (downloadBtn) {
    downloadBtn.addEventListener("click", (e) => {
      e.preventDefault();
      handleDownload();
    });
  }

  if (!db) {
    console.warn("Firestore not initialized. Realtime counter disabled.");
    return;
  }

  // Set up real-time listener for the aggregate download count
  try {
    const docRef = doc(db, "stats", "aura");
    onSnapshot(docRef, (snapshot) => {
      if (snapshot.exists()) {
        const data = snapshot.data();
        const count = data.download_count || 0;
        
        if (counterEl && counterTextEl) {
          counterTextEl.textContent = count.toLocaleString();
          counterEl.classList.add("visible");
        }
      }
    }, (error) => {
      console.warn("Firestore listener warning:", error);
    });
  } catch (error) {
    console.error("Error establishing Firestore listener:", error);
  }
}

/**
 * Performs atomic updates in Firestore (incrementing aggregate counter and logging session metadata)
 * and initiates the DMG file download.
 */
async function handleDownload() {
  // 1. Instantly trigger the DMG download for zero user-perceived lag
  const downloadUrl = "/assets/Aura.dmg";
  const link = document.createElement("a");
  link.href = downloadUrl;
  
  // Use active version in downloaded filename (e.g. Aura-1.0.57.dmg)
  const versionSuffix = APP_VERSION !== "__AURA_VERSION__" ? `-${APP_VERSION}` : "";
  link.setAttribute("download", `Aura${versionSuffix}.dmg`);
  
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);

  // 2. Perform background analytical logging to Firestore
  if (!db) return;

  try {
    // A. Increment aggregate counter document
    const docRef = doc(db, "stats", "aura");
    const updatePromise = updateDoc(docRef, {
      download_count: increment(1)
    });

    // B. Log detailed event metadata document for historical analysis (IP, version, and server timestamp)
    const logCollection = collection(db, "downloads");
    const logPromise = addDoc(logCollection, {
      ip: userIpAddress,
      version: APP_VERSION,
      timestamp: serverTimestamp()
    });

    // Run both writes concurrently in the background
    await Promise.all([updatePromise, logPromise]);
    console.log("Download analytic logs and counter updated successfully.");
  } catch (error) {
    console.warn("Could not log download analytics:", error);
  }
}
