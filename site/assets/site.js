const weekdays = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"];
const months = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"];

function formatClock(date) {
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");
  return `${weekdays[date.getDay()]} ${date.getDate()} ${months[date.getMonth()]} ${hours}:${minutes}`;
}

function startClock(element) {
  const tick = () => {
    const now = new Date();
    element.textContent = formatClock(now);
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
