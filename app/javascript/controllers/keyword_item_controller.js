// @TASK T3.1 - Keyword item Stimulus controller
// @SPEC REQ-SET-01: Keyword item interactions

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Add fade-in animation when keyword is added
    this.element.classList.add("animate-fade-in")
  }

  // Optional: Add confirmation for delete action
  confirmDelete(event) {
    const keyword = this.element.querySelector(".keyword-text")?.textContent

    if (!confirm(`정말로 '${keyword}' 키워드를 삭제하시겠습니까?`)) {
      event.preventDefault()
      return false
    }
  }
}
