// @TASK P2-S3-T2 - Image Lightbox Controller
// @SPEC Blog Post Detail - Click to expand generated images with overlay

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image"]
  
  connect() {
    this.setupKeyboardListener()
  }

  setupKeyboardListener() {
    this.handleKeyDown = (e) => {
      if (e.key === "Escape") {
        this.closeLightbox()
      }
    }
  }

  openLightbox(event) {
    event.preventDefault()
    
    const img = event.currentTarget
    const src = img.src
    const alt = img.alt

    // Create overlay
    const overlay = document.createElement("div")
    overlay.className = "lightbox-overlay"
    overlay.setAttribute("data-controller", "image-lightbox")
    
    // Create lightbox container
    const lightbox = document.createElement("div")
    lightbox.className = "lightbox-container"
    
    // Create close button
    const closeBtn = document.createElement("button")
    closeBtn.className = "lightbox-close"
    closeBtn.innerHTML = "✕"
    closeBtn.setAttribute("aria-label", "라이트박스 닫기")
    closeBtn.addEventListener("click", (e) => {
      e.stopPropagation()
      this.closeLightbox()
    })
    
    // Create image element
    const expandedImg = document.createElement("img")
    expandedImg.className = "lightbox-image"
    expandedImg.src = src
    expandedImg.alt = alt
    
    // Create caption if alt text exists
    const caption = document.createElement("div")
    caption.className = "lightbox-caption"
    caption.textContent = alt || ""
    if (!alt) {
      caption.style.display = "none"
    }
    
    // Assemble lightbox
    lightbox.appendChild(closeBtn)
    lightbox.appendChild(expandedImg)
    lightbox.appendChild(caption)
    overlay.appendChild(lightbox)
    
    // Add to body
    document.body.appendChild(overlay)
    
    // Trigger animation
    setTimeout(() => {
      overlay.classList.add("visible")
    }, 0)
    
    // Add keyboard listener
    document.addEventListener("keydown", this.handleKeyDown)
    
    // Close on overlay click (but not on image/caption)
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) {
        this.closeLightbox()
      }
    })
  }

  closeLightbox() {
    const overlay = document.querySelector(".lightbox-overlay")
    
    if (!overlay) return
    
    // Remove keyboard listener
    document.removeEventListener("keydown", this.handleKeyDown)
    
    // Fade out
    overlay.classList.remove("visible")
    
    // Remove from DOM after animation
    setTimeout(() => {
      overlay.remove()
    }, 300)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeyDown)
  }
}
