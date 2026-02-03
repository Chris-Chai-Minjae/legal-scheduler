// @TASK T9.2 - Onboarding Stimulus Controller
// Handles multi-step onboarding navigation

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    currentStep: Number
  }

  nextStep() {
    if (this.currentStepValue < 4) {
      window.location.href = `/onboarding?step=${this.currentStepValue + 1}`
    }
  }

  prevStep() {
    if (this.currentStepValue > 1) {
      window.location.href = `/onboarding?step=${this.currentStepValue - 1}`
    }
  }

  complete() {
    window.location.href = "/dashboard"
  }
}
