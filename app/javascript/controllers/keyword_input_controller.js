// @TASK T3.1 - Keyword input Stimulus controller
// @SPEC REQ-SET-01: Submit keyword on Enter key

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]

  connect() {
    // Auto-focus on input when form loads
    if (this.hasInputTarget) {
      this.inputTarget.focus()
    }
  }

  submit(event) {
    // Validate input before submission
    const keyword = this.inputTarget.value.trim()

    if (!keyword) {
      event.preventDefault()
      this.inputTarget.focus()
      return
    }

    // Allow form submission
  }

  // Optional: Submit on Enter key
  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.submitTarget.click()
    }
  }
}
