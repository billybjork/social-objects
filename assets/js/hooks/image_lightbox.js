// Image Lightbox Hook
// Captures Escape key to close lightbox without closing parent modal
// Only intercepts when attached to an active lightbox element (has .lightbox class and is visible)

const ImageLightbox = {
  mounted() {
    this.handleKeydown = (e) => {
      if (e.key === "Escape") {
        // Only intercept if this element is an active lightbox (visible lightbox container)
        const isLightboxContainer = this.el.classList.contains("lightbox")
        const isVisible = this.el.offsetParent !== null

        if (isLightboxContainer && isVisible) {
          // Stop the event from reaching the modal's handler
          e.stopImmediatePropagation()
          e.preventDefault()
          // Push the close event to LiveView
          this.pushEvent("close_lightbox", {})
        }
        // Otherwise, let the event propagate normally
      }
    }

    // Use capture phase to intercept before other handlers
    document.addEventListener("keydown", this.handleKeydown, true)
  },

  destroyed() {
    document.removeEventListener("keydown", this.handleKeydown, true)
  }
}

export default ImageLightbox
