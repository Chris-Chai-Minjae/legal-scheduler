// @TASK T9.2 - Toggle Switch Stimulus Controller
// Handles toggle switch interactions

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  toggle() {
    const currentValue = this.inputTarget.value === "1"
    const newValue = !currentValue

    this.inputTarget.value = newValue ? "1" : "0"
    this.element.classList.toggle("active", newValue)
  }
}
