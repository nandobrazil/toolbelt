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

function startClock(element) {
  const tick = () => {
    const now = new Date();
    element.textContent = clockFormat.format(now);
    setTimeout(tick, (60 - now.getSeconds()) * 1000 - now.getMilliseconds() + 50);
  };
  tick();
}

function connectBelt(button, panel) {
  const icon = button.querySelector("use");
  button.addEventListener("click", () => {
    const isOpen = button.getAttribute("aria-expanded") !== "true";
    button.setAttribute("aria-expanded", String(isOpen));
    panel.classList.toggle("is-closed", !isOpen);
    icon.setAttribute("href", isOpen ? "#belt-open" : "#belt-closed");
  });
}

const clock = document.getElementById("menubar-clock");
if (clock) {
  startClock(clock);
}

const belt = document.querySelector(".status-item--belt");
const panel = document.getElementById("hero-panel");
if (belt && panel) {
  connectBelt(belt, panel);
}
