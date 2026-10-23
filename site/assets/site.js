const clockFormats = {
  pt: {
    weekdays: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"],
    months: ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"],
    format(date) {
      const hours = String(date.getHours()).padStart(2, "0");
      const minutes = String(date.getMinutes()).padStart(2, "0");
      return `${this.weekdays[date.getDay()]} ${date.getDate()} ${this.months[date.getMonth()]} ${hours}:${minutes}`;
    }
  },
  en: {
    weekdays: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
    months: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
    format(date) {
      const hours = date.getHours() % 12 || 12;
      const minutes = String(date.getMinutes()).padStart(2, "0");
      const period = date.getHours() < 12 ? "AM" : "PM";
      return `${this.weekdays[date.getDay()]} ${this.months[date.getMonth()]} ${date.getDate()} ${hours}:${minutes} ${period}`;
    }
  }
};

const clockFormat = document.documentElement.lang.toLowerCase().startsWith("en") ? clockFormats.en : clockFormats.pt;
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const wideLayout = window.matchMedia("(min-width: 901px)");
const sheetLayout = window.matchMedia("(max-width: 700px)");

function startClock(element) {
  const tick = () => {
    const now = new Date();
    element.textContent = clockFormat.format(now);
    setTimeout(tick, (60 - now.getSeconds()) * 1000 - now.getMilliseconds() + 50);
  };
  tick();
}

function connectBelt(button, panel, hero, menubar, dialog) {
  const icon = button.querySelector("use");
  let isOpen = false;
  let closedByScroll = false;
  let heroObserver = null;

  const setOpen = (open) => {
    isOpen = open;
    button.setAttribute("aria-expanded", String(open));
    panel.classList.toggle("is-open", open);
    icon.setAttribute("href", open ? "#belt-open" : "#belt-closed");
  };

  const close = () => {
    const hadFocus = panel.contains(document.activeElement);
    setOpen(false);
    closedByScroll = false;
    if (hadFocus) {
      button.focus();
    }
  };

  const panelBottom = () => {
    const scale = parseFloat(getComputedStyle(panel).getPropertyValue("--panel-scale")) || 1;
    return Math.min(Math.round(menubar.offsetHeight + panel.offsetHeight * scale), window.innerHeight - 1);
  };

  const observeHero = () => {
    if (heroObserver) {
      heroObserver.disconnect();
    }
    heroObserver = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting && isOpen) {
        setOpen(false);
        closedByScroll = wideLayout.matches;
      } else if (entry.isIntersecting && closedByScroll) {
        closedByScroll = false;
        setOpen(true);
      }
    }, { rootMargin: `-${panelBottom()}px 0px 0px 0px` });
    heroObserver.observe(hero);
  };

  button.addEventListener("click", () => {
    closedByScroll = false;
    setOpen(!isOpen);
  });

  document.addEventListener("click", (event) => {
    if (!isOpen || dialog?.open || button.contains(event.target) || panel.contains(event.target) || dialog?.contains(event.target)) {
      return;
    }
    close();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && isOpen && !dialog?.open) {
      close();
    }
  });

  wideLayout.addEventListener("change", () => {
    closedByScroll = false;
    setOpen(wideLayout.matches && window.scrollY < hero.offsetHeight / 2);
    observeHero();
  });

  window.addEventListener("resize", observeHero);

  setOpen(wideLayout.matches);
  observeHero();
}

function connectSettings(dialog, triggers) {
  const tabs = [...dialog.querySelectorAll(".settings-tab")];
  const tabList = dialog.querySelector(".settings-window__tabs");
  const page = dialog.querySelector(".settings-window__page");
  const title = dialog.querySelector(".settings-window__title");
  const detail = dialog.querySelector(".settings-window__detail");
  let opener = null;
  let closeTimer = 0;

  const select = (tab) => {
    for (const other of tabs) {
      const selected = other === tab;
      other.setAttribute("aria-selected", String(selected));
      other.tabIndex = selected ? 0 : -1;
    }
    const label = tab.textContent.trim();
    title.textContent = label;
    detail.setAttribute("aria-labelledby", tab.id);
    page.width = Number(tab.dataset.width);
    page.height = Number(tab.dataset.height);
    page.alt = `${dialog.dataset.altPrefix}${label}`;
    const source = `${dialog.dataset.shots}settings-${tab.dataset.page}.webp?v=${dialog.dataset.shotsVersion}`;
    if (page.getAttribute("src") !== source) {
      page.classList.add("is-loading");
      page.src = source;
    }
    detail.scrollTop = 0;
  };

  const updateOrientation = () => {
    tabList.setAttribute("aria-orientation", sheetLayout.matches ? "horizontal" : "vertical");
  };

  const open = (pageName, trigger) => {
    clearTimeout(closeTimer);
    opener = trigger;
    const tab = tabs.find((candidate) => candidate.dataset.page === pageName) ?? tabs[0];
    select(tab);
    updateOrientation();
    if (!dialog.open) {
      dialog.showModal();
    }
    tab.focus();
    requestAnimationFrame(() => dialog.classList.add("is-visible"));
  };

  const requestClose = () => {
    if (!dialog.open) {
      return;
    }
    dialog.classList.remove("is-visible");
    if (reducedMotion.matches) {
      dialog.close();
      return;
    }
    clearTimeout(closeTimer);
    closeTimer = setTimeout(() => dialog.close(), 180);
  };

  page.addEventListener("load", () => page.classList.remove("is-loading"));
  page.addEventListener("error", () => page.classList.remove("is-loading"));

  dialog.addEventListener("close", () => {
    clearTimeout(closeTimer);
    dialog.classList.remove("is-visible");
    const target = opener?.checkVisibility?.() === false ? document.querySelector(".status-item--belt") : opener;
    opener = null;
    target?.focus();
  });

  dialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    requestClose();
  });

  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) {
      requestClose();
    }
  });

  dialog.querySelector("[data-settings-close]").addEventListener("click", requestClose);

  for (const tab of tabs) {
    tab.addEventListener("click", () => select(tab));
  }

  tabList.addEventListener("keydown", (event) => {
    const index = tabs.indexOf(document.activeElement);
    if (index === -1) {
      return;
    }
    const moves = {
      ArrowDown: index + 1,
      ArrowRight: index + 1,
      ArrowUp: index - 1,
      ArrowLeft: index - 1,
      Home: 0,
      End: tabs.length - 1
    };
    if (!(event.key in moves)) {
      return;
    }
    event.preventDefault();
    const next = tabs[(moves[event.key] + tabs.length) % tabs.length];
    select(next);
    next.focus();
  });

  sheetLayout.addEventListener("change", updateOrientation);

  for (const trigger of triggers) {
    trigger.addEventListener("click", () => open(trigger.dataset.settingsPage, trigger));
  }
}

const clock = document.getElementById("menubar-clock");
if (clock) {
  startClock(clock);
}

const settingsDialog = document.getElementById("settings-dialog");
if (settingsDialog && typeof settingsDialog.showModal === "function") {
  connectSettings(settingsDialog, document.querySelectorAll("[data-settings-page]"));
} else {
  for (const trigger of document.querySelectorAll("[data-settings-page]")) {
    trigger.hidden = true;
  }
}

const belt = document.querySelector(".status-item--belt");
const panel = document.getElementById("hero-panel");
const hero = document.querySelector(".hero");
const menubar = document.querySelector(".menubar");
if (belt && panel && hero && menubar) {
  connectBelt(belt, panel, hero, menubar, settingsDialog);
}
