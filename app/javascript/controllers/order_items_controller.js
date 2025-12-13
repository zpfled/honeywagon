import { Controller } from "@hotwired/stimulus"

// Manages the interactive "Add item" flow on the order form.
export default class extends Controller {
  static targets = [
    "rows",
    "form",
    "unitType",
    "quantity",
    "ratePlan",
    "addButton",
    "rowTemplate",
    "error",
    "emptyState"
  ]

  static values = {
    unitTypes: Array,
    ratePlans: Object,
    existing: Array,
    nextIndex: Number
  }

  connect() {
    if (!this.hasNextIndexValue) this.nextIndexValue = 0
    this.hideForm()
    this.populateRatePlanOptions()
    this.populateExistingRows()
    this.updateEmptyState()
  }

  showForm(event) {
    event.preventDefault()
    this.clearError()
    this.formTarget.hidden = false
    this.addButtonTarget.classList.add("hidden")
    this.unitTypeTarget.focus()
  }

  cancelForm(event) {
    event.preventDefault()
    this.resetFormFields()
    this.hideForm()
  }

  unitTypeChanged() {
    this.populateRatePlanOptions()
  }

  addItem(event) {
    event.preventDefault()
    this.clearError()

    const unitTypeId = this.unitTypeTarget.value
    const quantity = parseInt(this.quantityTarget.value, 10)
    const ratePlanId = this.ratePlanTarget.value

    if (!unitTypeId) {
      return this.showError("Select a unit type.")
    }

    if (!Number.isInteger(quantity) || quantity <= 0) {
      return this.showError("Quantity must be at least 1.")
    }

    if (!ratePlanId) {
      return this.showError("Select a rate plan for this unit type.")
    }

    const unitTypeName = this.lookupUnitTypeName(unitTypeId)
    const ratePlanLabel = this.lookupRatePlanLabel(unitTypeId, ratePlanId)

    if (!unitTypeName || !ratePlanLabel) {
      return this.showError("Invalid line item selection.")
    }

    this.appendRow({
      unitTypeId,
      unitTypeName,
      ratePlanId,
      ratePlanLabel,
      quantity
    })

    this.resetFormFields()
    this.hideForm()
  }

  removeRow(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-role='row']")
    if (row) {
      row.remove()
      this.updateEmptyState()
    }
  }

  // Private helpers

  hideForm() {
    this.formTarget.hidden = true
    this.addButtonTarget.classList.remove("hidden")
  }

  resetFormFields() {
    this.unitTypeTarget.value = ""
    this.quantityTarget.value = 1
    this.populateRatePlanOptions()
  }

  populateRatePlanOptions() {
    if (!this.hasRatePlanTarget) return

    const unitTypeId = this.unitTypeTarget.value
    const plans = this.plansForUnitType(unitTypeId)
    const fragment = document.createDocumentFragment()
    const placeholder = document.createElement("option")
    placeholder.value = ""
    placeholder.textContent = plans.length === 0 ? "Select a unit type first" : "Select rate plan"
    fragment.appendChild(placeholder)

    plans.forEach((plan) => {
      const option = document.createElement("option")
      option.value = String(plan.id)
      option.textContent = plan.label
      fragment.appendChild(option)
    })

    this.ratePlanTarget.innerHTML = ""
    this.ratePlanTarget.appendChild(fragment)
    this.ratePlanTarget.disabled = plans.length === 0
  }

  populateExistingRows() {
    if (!this.hasExistingValue || this.existingValue.length === 0) return

    this.existingValue.forEach((item) => {
      const unitTypeId = item.unit_type_id || item["unit_type_id"]
      const ratePlanId = item.rate_plan_id || item["rate_plan_id"]
      const unitTypeName = this.lookupUnitTypeName(unitTypeId)
      const ratePlanLabel = this.lookupRatePlanLabel(unitTypeId, ratePlanId)
      const quantity = item.quantity || item["quantity"] || 1

      if (!unitTypeName || !ratePlanLabel) return

      this.appendRow({
        unitTypeId,
        unitTypeName,
        ratePlanId,
        ratePlanLabel,
        quantity
      })
    })
  }

  appendRow(payload) {
    const index = this.nextIndexValue++
    const fragment = this.rowTemplateTarget.content.cloneNode(true)
    const row = fragment.querySelector("[data-role='row']")

    row.dataset.index = index
    row.querySelector("[data-role='summary']").textContent = payload.unitTypeName
    row.querySelector("[data-role='details']").textContent = payload.ratePlanLabel
    row.querySelector("[data-role='quantity']").textContent = `Qty: ${payload.quantity}`

    const unitInput = row.querySelector("[data-role='unitTypeInput']")
    unitInput.name = `order[unit_type_requests][${index}][unit_type_id]`
    unitInput.value = payload.unitTypeId

    const rateInput = row.querySelector("[data-role='ratePlanInput']")
    rateInput.name = `order[unit_type_requests][${index}][rate_plan_id]`
    rateInput.value = payload.ratePlanId

    const qtyInput = row.querySelector("[data-role='quantityInput']")
    qtyInput.name = `order[unit_type_requests][${index}][quantity]`
    qtyInput.value = payload.quantity

    this.rowsTarget.appendChild(fragment)
    this.updateEmptyState()
  }

  updateEmptyState() {
    if (!this.hasEmptyStateTarget) return
    const hasRows = this.rowsTarget.children.length > 0
    this.emptyStateTarget.classList.toggle("hidden", hasRows)
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }

  lookupUnitTypeName(id) {
    if (!this.hasUnitTypesValue) return null
    const unitType = this.unitTypesValue.find((ut) => String(ut.id) === String(id))
    return unitType ? unitType.name : null
  }

  lookupRatePlanLabel(unitTypeId, ratePlanId) {
    const plans = this.plansForUnitType(unitTypeId)
    const plan = plans.find((p) => String(p.id) === String(ratePlanId))
    return plan ? plan.label : null
  }

  plansForUnitType(unitTypeId) {
    if (!unitTypeId) return []

    let plans = this.ratePlansValue?.[unitTypeId] || []
    if (plans.length > 0) return plans

    const option = Array.from(this.unitTypeTarget?.options || []).find(
      (opt) => String(opt.value) === String(unitTypeId)
    )

    if (option?.dataset.ratePlans) {
      try {
        plans = JSON.parse(option.dataset.ratePlans)
      } catch (error) {
        plans = []
      }
    }

    return plans || []
  }
}
