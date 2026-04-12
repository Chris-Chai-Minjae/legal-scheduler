import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["analyzeBtn", "modal", "modalTitle", "modalBefore", "modalAfter", "modalReasoning"]
  static values = {
    postId: Number,
    analyzeUrl: String,
    optimizeUrl: String
  }

  connect() {
    this.currentOptimization = null
    this.autoAnalyze()
  }

  async autoAnalyze() {
    if (!this.element.querySelector('.seo-score-circle')) {
      await this.analyze()
    }
  }

  async analyze(event) {
    if (event) event.preventDefault()

    const btn = this.hasAnalyzeBtnTarget ? this.analyzeBtnTarget : null
    if (btn) {
      btn.disabled = true
      btn.textContent = "분석 중..."
    }

    try {
      const response = await fetch(this.analyzeUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error("SEO analyze error:", error)
    } finally {
      if (btn) {
        btn.disabled = false
        btn.textContent = "분석 실행"
      }
    }
  }

  async optimize(event) {
    event.preventDefault()
    const itemId = event.params.item
    const btn = event.target
    btn.disabled = true
    btn.textContent = "..."

    try {
      const url = this.optimizeUrlValue.replace("__ITEM__", itemId)
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.csrfToken,
          "Content-Type": "application/json"
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.currentOptimization = data
        this.showComparisonModal(data)
      }
    } catch (error) {
      console.error("SEO optimize error:", error)
    } finally {
      btn.disabled = false
      btn.textContent = "최적화"
    }
  }

  async optimizeAll(event) {
    event.preventDefault()
    const buttons = this.element.querySelectorAll('.seo-optimize-btn')
    for (const btn of buttons) {
      btn.click()
      await new Promise(r => setTimeout(r, 500))
    }
  }

  showComparisonModal(data) {
    this.modalTitleTarget.textContent = `${data.item_name} 최적화`
    this.modalBeforeTarget.textContent = data.current_value || "(없음)"
    this.modalAfterTarget.textContent = data.suggested_value || "(없음)"
    this.modalReasoningTarget.textContent = data.ai_reasoning
    this.modalTarget.style.display = "flex"
  }

  closeModal() {
    this.modalTarget.style.display = "none"
    this.currentOptimization = null
  }

  async applyOptimization(event) {
    event.preventDefault()
    if (!this.currentOptimization) return

    const data = this.currentOptimization

    const fieldMap = {
      title_keyword: "title",
      meta_description: "description",
      url_slug: "slug"
    }

    const fieldName = fieldMap[data.item_id]
    if (!fieldName) {
      alert("이 항목은 자동 적용이 지원되지 않습니다. 본문에서 직접 수정해주세요.")
      this.closeModal()
      return
    }

    try {
      const response = await fetch(`/blog/posts/${this.postIdValue}/seo/apply`, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": this.csrfToken,
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({
          item_id: data.item_id,
          field_name: fieldName,
          new_value: data.suggested_value
        })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        this.closeModal()
      }
    } catch (error) {
      console.error("SEO apply error:", error)
    }
  }

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
