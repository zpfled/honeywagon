import { Controller } from "@hotwired/stimulus"

const SERVICE_OPTION = "service-only"
const SERVICE_RATE_PLANS = [
  { id: "service-monthly", label: "Monthly service (service-only)", schedule: "monthly" },
  { id: "service-event", label: "Event service (service-only)", schedule: "event" }
]

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
    "emptyState",
    "ratePlanLink",
    "descriptionWrapper",
    "description",
    "quantityLabel"
  ]

  static values = {
    unitTypes: Array,
    ratePlans: Object,
    existing: Array,
    serviceExisting: Array,
    nextIndex: Number,
    serviceNextIndex: Number,
    newRatePlanUrl: String
  }

  connect() {
    if (!this.hasNextIndexValue) this.nextIndexValue = 0
    if (!this.hasServiceNextIndexValue) this.serviceNextIndexValue = 0
    this.ratePlanCreatedHandler = (event) => this.ratePlanCreated(event)
    window.addEventListener("rate-plan-created", this.ratePlanCreatedHandler)

    this.hideForm()
    this.toggleServiceFields()
    this.populateRatePlanOptions()
    this.populateExistingRows()
    this.populateExistingServiceRows()
    this.updateEmptyState()
    this.updateRatePlanLink()
  }

  disconnect() {
    if (this.ratePlanCreatedHandler) {
      window.removeEventListener("rate-plan-created", this.ratePlanCreatedHandler)
    }
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
    this.toggleServiceFields()
    this.populateRatePlanOptions()
    this.updateRatePlanLink()
  }

  addItem(event) {
    event.preventDefault()
    this.clearError()

    if (this.isServiceSelection()) {
      this.addServiceItem()
    } else {
      this.addRentalItem()
    }
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
    if (this.hasDescriptionTarget) this.descriptionTarget.value = ""
    this.toggleServiceFields()
    this.populateRatePlanOptions()
  }

  toggleServiceFields() {
    const serviceMode = this.isServiceSelection()
    if (this.hasDescriptionWrapperTarget) {
      this.descriptionWrapperTarget.hidden = !serviceMode
    }

    if (this.hasQuantityLabelTarget) {
      this.quantityLabelTarget.textContent = serviceMode ? "Units serviced" : "Quantity"
    }
  }

  isServiceSelection() {
    return this.unitTypeTarget.value === SERVICE_OPTION
  }

  addRentalItem() {
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

    this.appendRentalRow({
      unitTypeId,
      unitTypeName,
      ratePlanId,
      ratePlanLabel,
      quantity
    })

    this.resetFormFields()
    this.hideForm()
  }

  addServiceItem() {
    const description = this.descriptionTarget?.value?.trim()
    const quantity = parseInt(this.quantityTarget.value, 10)
    const ratePlanId = this.ratePlanTarget.value

    if (!description) {
      return this.showError("Describe the service work for customer-owned units.")
    }

    if (!Number.isInteger(quantity) || quantity <= 0) {
      return this.showError("Units serviced must be at least 1.")
    }

    const plan = SERVICE_RATE_PLANS.find((p) => p.id === ratePlanId)
    if (!plan) {
      return this.showError("Select a service cadence.")
    }

    this.appendServiceRow({
      description,
      ratePlanLabel: plan.label,
      schedule: plan.schedule,
      quantity
    })

    this.resetFormFields()
    this.hideForm()
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
    const rentals = this.existingValue || []
    rentals.forEach((item) => {
      const unitTypeId = item.unit_type_id || item["unit_type_id"]
      const ratePlanId = item.rate_plan_id || item["rate_plan_id"]
      const unitTypeName = this.lookupUnitTypeName(unitTypeId)
      const ratePlanLabel = this.lookupRatePlanLabel(unitTypeId, ratePlanId)
      const quantity = item.quantity || item["quantity"] || 1

      if (!unitTypeName || !ratePlanLabel) return

      this.appendRentalRow({
        unitTypeId,
        unitTypeName,
        ratePlanId,
        ratePlanLabel,
        quantity
      })
    })
  }

  populateExistingServiceRows() {
    const serviceItems = this.serviceExistingValue || []
    serviceItems.forEach((item) => {
      const schedule = item.service_schedule || item["service_schedule"] || "event"
      const label = `Service-only • ${this.humanize(schedule)}`
      const units = item.units_serviced || item["units_serviced"] || 1
      const description = item.description || item["description"] || "Service-only work"

      this.appendServiceRow({
        description,
        ratePlanLabel: label,
        schedule,
        quantity: units
      })
    })
  }

  appendRentalRow(payload) {
    const index = this.nextIndexValue++
    const fragment = this.rowTemplateTarget.content.cloneNode(true)
    const row = fragment.querySelector("[data-role='row']")
    row.dataset.itemType = "rental"

    row.querySelector("[data-role='summary']").textContent = payload.unitTypeName
    row.querySelector("[data-role='details']").textContent = payload.ratePlanLabel
    row.querySelector("[data-role='quantity']").textContent = `Qty: ${payload.quantity}`

    const container = row.querySelector("[data-role='hiddenContainer']")
    container.appendChild(this.buildHiddenInput(`order[unit_type_requests][${index}][unit_type_id]`, payload.unitTypeId))
    container.appendChild(this.buildHiddenInput(`order[unit_type_requests][${index}][rate_plan_id]`, payload.ratePlanId))
    container.appendChild(this.buildHiddenInput(`order[unit_type_requests][${index}][quantity]`, payload.quantity))

    this.rowsTarget.appendChild(fragment)
    this.updateEmptyState()
  }

  appendServiceRow(payload) {
    const index = this.serviceNextIndexValue++
    const fragment = this.rowTemplateTarget.content.cloneNode(true)
    const row = fragment.querySelector("[data-role='row']")
    row.dataset.itemType = "service"

    row.querySelector("[data-role='summary']").textContent = payload.description
    row.querySelector("[data-role='details']").textContent = payload.ratePlanLabel
    row.querySelector("[data-role='quantity']").textContent = `Units: ${payload.quantity}`

    const container = row.querySelector("[data-role='hiddenContainer']")
    container.appendChild(this.buildHiddenInput(`order[service_line_items][${index}][description]`, payload.description))
    container.appendChild(this.buildHiddenInput(`order[service_line_items][${index}][service_schedule]`, payload.schedule))
    container.appendChild(this.buildHiddenInput(`order[service_line_items][${index}][units_serviced]`, payload.quantity))

    this.rowsTarget.appendChild(fragment)
    this.updateEmptyState()
  }

  buildHiddenInput(name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    return input
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
    if (String(id) === SERVICE_OPTION) {
      return "Service-only (customer-owned units)"
    }

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
    if (unitTypeId === SERVICE_OPTION) return SERVICE_RATE_PLANS

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

  updateRatePlanLink() {
    if (!this.hasRatePlanLinkTarget) return

    const disabled = !this.unitTypeTarget?.value || this.isServiceSelection()
    this.ratePlanLinkTarget.classList.toggle("opacity-50", disabled)
    this.ratePlanLinkTarget.classList.toggle("pointer-events-none", disabled)
  }

  openRatePlanModal(event) {
    event.preventDefault()
    const unitTypeId = this.unitTypeTarget.value
    if (!unitTypeId) {
      this.showError("Select a unit type before adding a rate plan.")
      return
    }

    if (this.isServiceSelection()) {
      this.showError("Service-only items do not use rental rate plans.")
      return
    }

    const frame = document.getElementById("rate_plan_modal")
    if (!frame) return

    const url = new URL(this.newRatePlanUrlValue, window.location.origin)
    url.searchParams.set("unit_type_id", unitTypeId)

    frame.src = url.toString()
    frame.reload()
  }

  ratePlanCreated(event) {
    const data = event.detail || {}
    const unitTypeId = data.unit_type_id || data.unitTypeId
    const planId = data.id
    const label = data.label

    if (!unitTypeId || !planId || !label) return

    const updated = { ...(this.ratePlansValue || {}) }
    const unitPlans = updated[unitTypeId] ? [ ...updated[unitTypeId] ] : []
    unitPlans.push({ id: planId, label })
    updated[unitTypeId] = unitPlans
    this.ratePlansValue = updated

    if (this.unitTypeTarget.value === String(unitTypeId)) {
      this.populateRatePlanOptions()
      if (this.hasRatePlanTarget) {
        this.ratePlanTarget.value = String(planId)
      }
    }
  }

  humanize(value) {
    return String(value || "").replace(/_/g, " ").replace(/\b\w/g, (char) => char.toUpperCase())
  }
}
