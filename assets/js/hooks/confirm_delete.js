// Hook to handle native browser confirm dialogs with dynamic messages
const ConfirmDelete = {
  mounted() {
    this.handleEvent("confirm_delete_tag", ({tag_id, message}) => {
      if (window.confirm(message)) {
        this.pushEvent("confirm_delete_tag", {tag_id})
      }
    })
  }
}

export default ConfirmDelete
