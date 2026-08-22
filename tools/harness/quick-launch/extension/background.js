const NATIVE_HOST = "com.eink.harness";
const HARNESS_URL = "http://127.0.0.1:5175/";
const UI_ACTIONS = new Set(["STATUS", "OPEN", "START", "RESTART", "STOP", "QUICK_OPEN"]);

function nativeAction(action) {
  return new Promise((resolve) => {
    chrome.runtime.sendNativeMessage(NATIVE_HOST, { action }, (response) => {
      if (chrome.runtime.lastError) {
        resolve({ ok: false, state: "OFFLINE", reason: chrome.runtime.lastError.message });
        return;
      }
      resolve(response || { ok: false, state: "OFFLINE", reason: "EMPTY_NATIVE_RESPONSE" });
    });
  });
}

async function focusOrOpenHarnessTab() {
  const tabs = await chrome.tabs.query({ url: `${HARNESS_URL}*` });
  if (tabs.length > 0) {
    const tab = tabs[0];
    await chrome.tabs.update(tab.id, { active: true });
    if (typeof tab.windowId === "number") {
      await chrome.windows.update(tab.windowId, { focused: true });
    }
    return;
  }
  await chrome.tabs.create({ url: HARNESS_URL, active: true });
}

async function runUiAction(action) {
  if (!UI_ACTIONS.has(action)) {
    return { ok: false, state: "OFFLINE", reason: "UI_ACTION_NOT_ALLOWED" };
  }
  if (action === "QUICK_OPEN") {
    let result = await nativeAction("STATUS");
    if (!result.ok || result.state !== "ONLINE") result = await nativeAction("START");
    if (!result.ok || result.state !== "ONLINE") return result;
    result = await nativeAction("OPEN");
    if (result.ok) await focusOrOpenHarnessTab();
    return result;
  }
  if (action === "OPEN") {
    let result = await nativeAction("STATUS");

    if (!result.ok || result.state !== "ONLINE") {
      result = await nativeAction("START");
    }

    if (!result.ok || result.state !== "ONLINE") {
      return result;
    }

    result = await nativeAction("OPEN");

    if (result.ok) {
      await focusOrOpenHarnessTab();
    }

    return result;
  }

  return nativeAction(action);
}

if (typeof document === "undefined") {
  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    const action = message && typeof message.action === "string" ? message.action : "";
    runUiAction(action).then(sendResponse).catch((error) => {
      sendResponse({ ok: false, state: "OFFLINE", reason: String(error) });
    });
    return true;
  });
} else {
  const statusNode = document.getElementById("status");
  const detailNode = document.getElementById("detail");
  const buttons = Array.from(document.querySelectorAll("button[data-action]"));

  function show(result, fallbackState) {
    const state = result && result.state ? result.state : fallbackState;
    statusNode.textContent = state;
    statusNode.dataset.state = state;
    detailNode.textContent = result && result.reason ? result.reason : "127.0.0.1:5175";
  }

  let statusPollBusy = false;

  async function authoritativeStatus() {
    if (statusPollBusy) return null;

    statusPollBusy = true;

    try {
      const result = await chrome.runtime.sendMessage({ action: "STATUS" });
      show(result, "OFFLINE");
      return result;
    } catch (error) {
      const result = {
        ok: false,
        state: "OFFLINE",
        reason: String(error)
      };
      show(result, "OFFLINE");
      return result;
    } finally {
      statusPollBusy = false;
    }
  }

  async function request(action) {
    buttons.forEach((button) => { button.disabled = true; });

    show(
      {
        state: action === "STOP" ? "STARTING" : "STARTING",
        reason: action === "STOP" ? "Stopping Harness..." : `${action}...`
      },
      "STARTING"
    );

    try {
      const result = await chrome.runtime.sendMessage({ action });

      if (!result?.ok && action !== "STOP") {
        show(result, "OFFLINE");
        return result;
      }

      await new Promise((resolve) => setTimeout(resolve, 400));

      return await authoritativeStatus();
    } catch (error) {
      const result = {
        ok: false,
        state: "OFFLINE",
        reason: String(error)
      };
      show(result, "OFFLINE");
      return result;
    } finally {
      buttons.forEach((button) => { button.disabled = false; });
    }
  }

  buttons.forEach((button) => {
    button.addEventListener("click", () => request(button.dataset.action));
  });

  show(
    { state: "STARTING", reason: "Checking Harness..." },
    "STARTING"
  );

  authoritativeStatus();

  const statusPoll = window.setInterval(() => {
    if (document.visibilityState === "visible") {
      authoritativeStatus();
    }
  }, 1500);

  window.addEventListener("unload", () => {
    window.clearInterval(statusPoll);
  });
}
