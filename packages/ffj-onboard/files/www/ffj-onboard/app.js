/* Freifunk Jena onboard UI — talks to rpcd via /ubus (null session) */

const NULL_SESSION = "00000000000000000000000000000000";

/* Leaflet is loaded from a CDN so the package stays small; the map needs
   internet for tiles anyway. The form works without it. */
const LEAFLET_CSS_URL = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css";
const LEAFLET_CSS_SRI = "sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=";
const LEAFLET_JS_URL = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js";
const LEAFLET_JS_SRI = "sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=";
const LEAFLET_TIMEOUT_MS = 8000;

const TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
const TILE_ATTRIBUTION =
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>';
const NOMINATIM_URL = "https://nominatim.openstreetmap.org/search";
const SEARCH_LIMIT = 5;
const SEARCH_TIMEOUT_MS = 10000;

const DEFAULT_LAT = 50.927;
const DEFAULT_LON = 11.589;
const DEFAULT_ZOOM = 13;
const PICKED_ZOOM = 16;

function showMsg(text, kind) {
  const el = document.getElementById("status-msg");
  el.hidden = false;
  el.className = "msg" + (kind ? " " + kind : "");
  el.textContent = text;
}

async function ubusCall(object, method, params) {
  const body = {
    jsonrpc: "2.0",
    id: Date.now(),
    method: "call",
    params: [NULL_SESSION, object, method, params || {}],
  };
  const res = await fetch("/ubus", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error("HTTP " + res.status);
  }
  const data = await res.json();
  if (data.error) {
    throw new Error(data.error.message || JSON.stringify(data.error));
  }
  // ubus result: [statusCode, payload]
  const result = data.result;
  if (!Array.isArray(result)) {
    throw new Error("Unexpected ubus response");
  }
  if (result[0] !== 0) {
    throw new Error("ubus access denied or object missing (code " + result[0] + ")");
  }
  return result[1] || {};
}

function parseCoords(latText, lonText) {
  const lat = Number.parseFloat(latText);
  const lon = Number.parseFloat(lonText);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    return null;
  }
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
    return null;
  }
  return { lat: lat, lon: lon };
}

function readCoords() {
  return parseCoords(
    document.getElementById("lat").value,
    document.getElementById("lon").value
  );
}

function writeCoords(lat, lon) {
  document.getElementById("lat").value = lat.toFixed(6);
  document.getElementById("lon").value = lon.toFixed(6);
}

function loadStylesheet(url, integrity) {
  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = url;
  link.integrity = integrity;
  link.crossOrigin = "anonymous";
  document.head.appendChild(link);
}

function loadScript(url, integrity, timeoutMs) {
  return new Promise(function (resolve, reject) {
    const script = document.createElement("script");
    const timer = setTimeout(function () {
      reject(new Error("timeout"));
    }, timeoutMs);
    script.src = url;
    script.integrity = integrity;
    script.crossOrigin = "anonymous";
    script.addEventListener("load", function () {
      clearTimeout(timer);
      resolve();
    });
    script.addEventListener("error", function () {
      clearTimeout(timer);
      reject(new Error("load failed"));
    });
    document.head.appendChild(script);
  });
}

function createLocationMap(container, start, onPick) {
  const map = L.map(container).setView([start.lat, start.lon], DEFAULT_ZOOM);
  L.tileLayer(TILE_URL, { maxZoom: 19, attribution: TILE_ATTRIBUTION }).addTo(map);

  const marker = L.marker([start.lat, start.lon], { draggable: true }).addTo(map);
  marker.on("dragend", function () {
    const pos = marker.getLatLng();
    onPick(pos.lat, pos.lng);
  });
  map.on("click", function (ev) {
    marker.setLatLng(ev.latlng);
    onPick(ev.latlng.lat, ev.latlng.lng);
  });

  return function moveTo(lat, lon, zoom) {
    marker.setLatLng([lat, lon]);
    map.setView([lat, lon], zoom || map.getZoom());
  };
}

async function searchPlaces(query) {
  const url =
    NOMINATIM_URL +
    "?format=json&limit=" +
    SEARCH_LIMIT +
    "&accept-language=de&q=" +
    encodeURIComponent(query);
  const res = await fetch(url, {
    headers: { Accept: "application/json" },
    signal: AbortSignal.timeout(SEARCH_TIMEOUT_MS),
  });
  if (!res.ok) {
    throw new Error("HTTP " + res.status);
  }
  const hits = await res.json();
  return Array.isArray(hits) ? hits : [];
}

function renderResults(list, hits, onSelect) {
  list.textContent = "";
  list.hidden = hits.length === 0;
  hits.forEach(function (hit) {
    const coords = parseCoords(hit.lat, hit.lon);
    if (!coords) {
      return;
    }
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = hit.display_name;
    button.addEventListener("click", function () {
      list.hidden = true;
      onSelect(coords.lat, coords.lon);
    });
    const item = document.createElement("li");
    item.appendChild(button);
    list.appendChild(item);
  });
}

function initSearch(onPick) {
  const queryInput = document.getElementById("place-query");
  const searchBtn = document.getElementById("search-btn");
  const list = document.getElementById("search-results");

  async function runSearch() {
    const query = queryInput.value.trim();
    if (!query) {
      return;
    }
    searchBtn.disabled = true;
    try {
      const hits = await searchPlaces(query);
      renderResults(list, hits, onPick);
      if (hits.length === 0) {
        showMsg("Keine Treffer / No results", "info");
      }
    } catch (err) {
      list.hidden = true;
      showMsg("Suche fehlgeschlagen / Search failed: " + err.message, "error");
    } finally {
      searchBtn.disabled = false;
    }
  }

  searchBtn.addEventListener("click", runSearch);
  queryInput.addEventListener("keydown", function (ev) {
    if (ev.key === "Enter") {
      ev.preventDefault();
      runSearch();
    }
  });
}

async function initMap() {
  const container = document.getElementById("map");
  loadStylesheet(LEAFLET_CSS_URL, LEAFLET_CSS_SRI);
  await loadScript(LEAFLET_JS_URL, LEAFLET_JS_SRI, LEAFLET_TIMEOUT_MS);

  container.hidden = false;
  const start = readCoords() || { lat: DEFAULT_LAT, lon: DEFAULT_LON };
  const moveTo = createLocationMap(container, start, writeCoords);

  ["lat", "lon"].forEach(function (id) {
    document.getElementById(id).addEventListener("change", function () {
      const coords = readCoords();
      if (coords) {
        moveTo(coords.lat, coords.lon);
      }
    });
  });

  return moveTo;
}

async function init() {
  const form = document.getElementById("onboard-form");
  try {
    const st = await ubusCall("ffj-onboard", "status", {});
    if (st.done) {
      showMsg("Bereits eingerichtet – weiter zur LimeApp… / Already done – opening LimeApp…", "info");
      form.hidden = true;
      setTimeout(function () {
        location.href = "/app/";
      }, 1200);
      return;
    }
    if (st.hostname) {
      document.getElementById("hostname").value = st.hostname;
    }
  } catch (err) {
    showMsg("Status fehlgeschlagen / Status failed: " + err.message, "error");
  }

  // The map loads in the background so a blocked CDN never stalls the form.
  let moveMapTo = null;
  initMap().then(
    function (moveTo) {
      moveMapTo = moveTo;
    },
    function () {
      // No map (offline or CDN blocked) — manual coordinates and search still work.
    }
  );

  function pickCoords(lat, lon) {
    writeCoords(lat, lon);
    if (moveMapTo) {
      moveMapTo(lat, lon, PICKED_ZOOM);
    }
  }

  initSearch(pickCoords);

  document.getElementById("geo-btn").addEventListener("click", function () {
    if (!navigator.geolocation) {
      showMsg("Geolocation nicht verfügbar / Geolocation unavailable", "error");
      return;
    }
    navigator.geolocation.getCurrentPosition(
      function (pos) {
        pickCoords(pos.coords.latitude, pos.coords.longitude);
        showMsg("Standort übernommen / Location filled", "info");
      },
      function (err) {
        showMsg("Geolocation: " + err.message, "error");
      },
      { enableHighAccuracy: true, timeout: 15000 }
    );
  });

  form.addEventListener("submit", async function (ev) {
    ev.preventDefault();
    const hostname = document.getElementById("hostname").value.trim();
    const password = document.getElementById("password").value;
    const password2 = document.getElementById("password2").value;
    const lat = document.getElementById("lat").value.trim();
    const lon = document.getElementById("lon").value.trim();

    if (password !== password2) {
      showMsg("Passwörter stimmen nicht überein / Passwords do not match", "error");
      return;
    }

    const btn = document.getElementById("submit-btn");
    btn.disabled = true;
    showMsg("Speichern… / Saving…", "info");

    try {
      const out = await ubusCall("ffj-onboard", "complete", {
        hostname: hostname,
        password: password,
        lat: lat,
        lon: lon,
      });
      if (out.status === "error") {
        showMsg(out.msg || "Fehler / Error", "error");
        btn.disabled = false;
        return;
      }
      showMsg("Fertig – Neustart… / Done – rebooting…", "info");
      form.hidden = true;
    } catch (err) {
      showMsg(err.message, "error");
      btn.disabled = false;
    }
  });
}

init();
