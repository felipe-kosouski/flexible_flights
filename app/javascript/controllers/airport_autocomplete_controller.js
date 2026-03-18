import { Controller } from "@hotwired/stimulus"
import airports from "data/airports"

const MAX_RESULTS = 8

export default class extends Controller {
  static targets = ["display", "code", "dropdown"]

  connect() {
    this._onDocumentClick = this._onDocumentClick.bind(this)
    document.addEventListener("click", this._onDocumentClick)
    this._activeIndex = -1
  }

  disconnect() {
    document.removeEventListener("click", this._onDocumentClick)
  }

  search() {
    const query = this.displayTarget.value.trim()

    if (query.length < 1) {
      this._close()
      this.codeTarget.value = ""
      return
    }

    const results = this._filter(query)

    if (results.length === 0) {
      this._close()
      return
    }

    this._renderDropdown(results)
    this._activeIndex = -1
  }

  navigate(event) {
    const items = this.dropdownTarget.querySelectorAll("[data-airport]")
    if (items.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this._activeIndex = Math.min(this._activeIndex + 1, items.length - 1)
      this._highlightActive(items)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this._activeIndex = Math.max(this._activeIndex - 1, 0)
      this._highlightActive(items)
    } else if (event.key === "Enter") {
      event.preventDefault()
      if (this._activeIndex >= 0) {
        this._selectItem(items[this._activeIndex])
      }
    } else if (event.key === "Escape") {
      this._close()
    }
  }

  select(event) {
    this._selectItem(event.currentTarget)
  }

  // private

  _filter(query) {
    const q = query.toUpperCase()
    const ql = query.toLowerCase()

    const exact   = []
    const starts  = []
    const rest    = []

    for (const airport of airports) {
      if (airport.iata === q) {
        exact.push(airport)
      } else if (
        airport.iata.startsWith(q) ||
        airport.city.toLowerCase().startsWith(ql) ||
        airport.name.toLowerCase().startsWith(ql)
      ) {
        starts.push(airport)
      } else if (
        airport.city.toLowerCase().includes(ql) ||
        airport.name.toLowerCase().includes(ql)
      ) {
        rest.push(airport)
      }

      if (exact.length + starts.length + rest.length >= MAX_RESULTS * 3) break
    }

    return [...exact, ...starts, ...rest].slice(0, MAX_RESULTS)
  }

  _renderDropdown(results) {
    this.dropdownTarget.innerHTML = results.map((airport, i) => `
      <div
        data-airport="${airport.iata}"
        data-action="click->airport-autocomplete#select mouseenter->airport-autocomplete#highlight"
        data-index="${i}"
        class="flex items-center gap-3 px-3 py-2.5 cursor-pointer hover:bg-indigo-50 rounded-md transition-colors"
      >
        <span class="shrink-0 w-10 text-xs font-bold text-indigo-600 font-mono">${airport.iata}</span>
        <span class="min-w-0">
          <span class="block text-sm font-medium text-gray-900 truncate">${airport.city}</span>
          <span class="block text-xs text-gray-400 truncate">${airport.name}</span>
        </span>
      </div>
    `).join("")

    this.dropdownTarget.classList.remove("hidden")
  }

  _highlightActive(items) {
    items.forEach((item, i) => {
      item.classList.toggle("bg-indigo-50", i === this._activeIndex)
    })
    if (this._activeIndex >= 0) {
      items[this._activeIndex].scrollIntoView({ block: "nearest" })
    }
  }

  highlight(event) {
    const items = this.dropdownTarget.querySelectorAll("[data-airport]")
    this._activeIndex = parseInt(event.currentTarget.dataset.index, 10)
    this._highlightActive(items)
  }

  _selectItem(item) {
    const iata = item.dataset.airport
    const city = item.querySelector(".text-gray-900").textContent.trim()
    this.codeTarget.value = iata
    this.displayTarget.value = `${city} (${iata})`
    this._close()
  }

  _close() {
    this.dropdownTarget.classList.add("hidden")
    this.dropdownTarget.innerHTML = ""
    this._activeIndex = -1
  }

  _onDocumentClick(event) {
    if (!this.element.contains(event.target)) {
      this._close()
    }
  }
}
