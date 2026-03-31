import { Controller } from "@hotwired/stimulus"

// Manages the credit chip dropdown in the nav.
// The dropdown is server-rendered and toggled with CSS (hidden class).
// Click-outside closes the dropdown via a window-level listener.
// Escape key also closes the dropdown.
export default class extends Controller {
  static targets = ["dropdown"]

  toggle(event) {
    event.stopPropagation()
    this.dropdownTarget.classList.toggle("hidden")
  }

  hide(event) {
    if (!this.element.contains(event.target)) {
      this.dropdownTarget.classList.add("hidden")
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.dropdownTarget.classList.add("hidden")
    }
  }
}
