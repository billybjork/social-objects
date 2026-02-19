const HoverDropdown = {
  mounted() {
    this.trigger = this.el.querySelector(".hover-dropdown__trigger")
    this.menu = this.el.querySelector(".hover-dropdown__menu")

    if (!this.trigger || !this.menu) {
      return
    }

    this.handleTriggerClick = this.handleTriggerClick.bind(this)
    this.handleDocumentClick = this.handleDocumentClick.bind(this)
    this.handleMenuClick = this.handleMenuClick.bind(this)
    this.handleEscape = this.handleEscape.bind(this)
    this.handleSearchInput = this.handleSearchInput.bind(this)
    this.handleSearchKeydown = this.handleSearchKeydown.bind(this)

    this.trigger.addEventListener("click", this.handleTriggerClick)
    this.menu.addEventListener("click", this.handleMenuClick)
    document.addEventListener("click", this.handleDocumentClick)
    document.addEventListener("keydown", this.handleEscape)

    this.wasOpen = this.el.classList.contains("is-open")
    this.refreshSearchElements()
  },

  updated() {
    if (!this.trigger || !this.menu) {
      return
    }

    this.refreshSearchElements()
    this.syncOpenState()
  },

  destroyed() {
    if (this.trigger) {
      this.trigger.removeEventListener("click", this.handleTriggerClick)
    }

    if (this.menu) {
      this.menu.removeEventListener("click", this.handleMenuClick)
    }

    document.removeEventListener("click", this.handleDocumentClick)
    document.removeEventListener("keydown", this.handleEscape)
    this.teardownSearchInput()
  },

  handleTriggerClick(event) {
    if (this.trigger.hasAttribute("phx-click")) {
      return
    }

    if (event.target.closest(".hover-dropdown__clear")) {
      return
    }

    event.preventDefault()
    this.el.classList.toggle("is-open")
    this.syncOpenState()
  },

  handleMenuClick(event) {
    if (event.target.closest(".hover-dropdown__item")) {
      this.el.classList.remove("is-open")
      this.resetSearch()
      this.wasOpen = false
    }
  },

  handleDocumentClick(event) {
    if (!this.el.contains(event.target)) {
      this.closeMenu()
    }
  },

  handleEscape(event) {
    if (event.key == "Escape") {
      this.closeMenu()
    }
  },

  handleSearchInput(event) {
    this.filterOptions(event.target.value || "")
  },

  handleSearchKeydown(event) {
    if (event.key == "Escape") {
      this.closeMenu()

      if (this.trigger) {
        this.trigger.focus()
      }
    }
  },

  closeMenu() {
    this.el.classList.remove("is-open")
    this.resetSearch()
    this.wasOpen = false
  },

  syncOpenState() {
    const isOpen = this.el.classList.contains("is-open")

    if (isOpen && !this.wasOpen) {
      this.focusSearchInput()
    }

    if (!isOpen && this.wasOpen) {
      this.resetSearch()
    }

    this.wasOpen = isOpen
  },

  refreshSearchElements() {
    const nextInput = this.el.querySelector("[data-hover-dropdown-search]")
    const nextEmptyState = this.el.querySelector("[data-hover-dropdown-empty]")
    this.optionElements = Array.from(this.el.querySelectorAll("[data-hover-dropdown-option]"))

    if (this.searchInput && this.searchInput !== nextInput) {
      this.teardownSearchInput()
    }

    this.searchInput = nextInput
    this.emptyState = nextEmptyState

    if (!this.searchInput) {
      return
    }

    this.searchInput.removeEventListener("input", this.handleSearchInput)
    this.searchInput.removeEventListener("keydown", this.handleSearchKeydown)
    this.searchInput.addEventListener("input", this.handleSearchInput)
    this.searchInput.addEventListener("keydown", this.handleSearchKeydown)

    this.filterOptions(this.searchInput.value || "")
  },

  teardownSearchInput() {
    if (!this.searchInput) {
      return
    }

    this.searchInput.removeEventListener("input", this.handleSearchInput)
    this.searchInput.removeEventListener("keydown", this.handleSearchKeydown)
  },

  resetSearch() {
    if (!this.searchInput) {
      return
    }

    if (this.searchInput.value != "") {
      this.searchInput.value = ""
    }

    this.filterOptions("")
  },

  focusSearchInput() {
    if (!this.searchInput) {
      return
    }

    window.requestAnimationFrame(() => {
      if (!this.el.classList.contains("is-open")) {
        return
      }

      this.searchInput.focus()
      this.searchInput.select()
    })
  },

  filterOptions(rawQuery) {
    if (!this.searchInput || !this.optionElements) {
      return
    }

    const query = rawQuery.trim().toLowerCase()
    let visibleCount = 0

    this.optionElements.forEach(option => {
      const label = option.dataset.label || option.textContent.toLowerCase()
      const matches = query == "" || label.includes(query)
      option.hidden = !matches

      if (matches) {
        visibleCount += 1
      }
    })

    if (this.emptyState) {
      this.emptyState.hidden = visibleCount > 0
    }
  }
}

export default HoverDropdown
