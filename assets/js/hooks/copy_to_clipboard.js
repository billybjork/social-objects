// CopyToClipboard hook - copies text from data-copy-text attribute
const CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      const text = this.el.dataset.copyText
      if (text) {
        navigator.clipboard.writeText(text).then(() => {
          // Show temporary feedback
          const originalText = this.el.innerText
          this.el.innerText = "Copied!"
          setTimeout(() => {
            this.el.innerText = originalText
          }, 1500)
        })
      }
    })
  }
}

export default CopyToClipboard
