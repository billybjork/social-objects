// Hook to handle CSV file downloads
const CsvDownload = {
  mounted() {
    this.handleEvent("download_csv", ({ content, filename }) => {
      // Create a Blob with UTF-8 BOM for Excel compatibility
      const BOM = '\uFEFF'
      const blob = new Blob([BOM + content], { type: 'text/csv;charset=utf-8;' })

      // Create download link and trigger click
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.setAttribute('href', url)
      link.setAttribute('download', filename)
      link.style.visibility = 'hidden'
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)

      // Clean up the URL object
      URL.revokeObjectURL(url)
    })
  }
}

export default CsvDownload
