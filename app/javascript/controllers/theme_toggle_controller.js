import { Controller } from "@hotwired/stimulus"

// Manages light/dark theme preference.
// Reads from localStorage on connect; falls back to OS preference.
// Writes chosen theme to localStorage for persistence across sessions.
// Sets [data-theme] on <html> — CSS dark: variant targets this attribute.
export default class extends Controller {
  static targets = ["icon"]

  connect() {
    const saved = localStorage.getItem("theme")
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    this.applyTheme(saved ?? (prefersDark ? "dark" : "light"))
  }

  toggle() {
    const next = this.currentTheme === "dark" ? "light" : "dark"
    this.applyTheme(next)
    localStorage.setItem("theme", next)
  }

  applyTheme(theme) {
    document.documentElement.dataset.theme = theme
    if (this.hasIconTarget) {
      this.iconTarget.innerHTML = theme === "dark" ? this.#sunPaths : this.#moonPaths
    }
  }

  get currentTheme() {
    return document.documentElement.dataset.theme ?? "light"
  }

  // Sun icon — shown in dark mode (click to go light)
  get #sunPaths() {
    return `<path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386-1.591 1.591M21 12h-2.25m-.386 6.364-1.591-1.591M12 18.75V21m-4.773-4.227-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z" />`
  }

  // Moon icon — shown in light mode (click to go dark)
  get #moonPaths() {
    return `<path stroke-linecap="round" stroke-linejoin="round" d="M21.752 15.002A9.72 9.72 0 0 1 18 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 0 0 3 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 0 0 9.002-5.998Z" />`
  }
}
