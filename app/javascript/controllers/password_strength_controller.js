// @TASK T9.2 - Password Strength Stimulus Controller
// Shows password strength indicator on signup form

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["password", "confirm", "strengthBar", "confirmIcon"]

  checkStrength() {
    const value = this.passwordTarget.value
    const length = value.length
    const bar = this.strengthBarTarget

    bar.className = "password-strength-bar"

    if (length === 0) {
      // No class
    } else if (length < 8) {
      bar.classList.add("weak")
    } else if (length < 12) {
      bar.classList.add("medium")
    } else {
      bar.classList.add("strong")
    }
  }

  checkConfirmation() {
    const password = this.passwordTarget.value
    const confirm = this.confirmTarget.value
    const icon = this.confirmIconTarget

    if (confirm === password && confirm.length > 0) {
      this.confirmTarget.classList.add("valid")
      this.confirmTarget.classList.remove("invalid")
      icon.style.display = "block"
    } else if (confirm.length > 0) {
      this.confirmTarget.classList.remove("valid")
      this.confirmTarget.classList.add("invalid")
      icon.style.display = "none"
    } else {
      this.confirmTarget.classList.remove("valid", "invalid")
      icon.style.display = "none"
    }
  }
}
