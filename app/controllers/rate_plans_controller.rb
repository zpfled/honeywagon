class RatePlansController < ApplicationController
  before_action :set_rate_plan, only: %i[ show edit update destroy ]

  # GET /rate_plans or /rate_plans.json
  def index
    @rate_plans = RatePlan.all
  end

  # GET /rate_plans/1 or /rate_plans/1.json
  def show
  end

  # GET /rate_plans/new
  def new
    @rate_plan = RatePlan.new
  end

  # GET /rate_plans/1/edit
  def edit
  end

  # POST /rate_plans or /rate_plans.json
  def create
    @rate_plan = RatePlan.new(rate_plan_params)

    respond_to do |format|
      if @rate_plan.save
        format.html { redirect_to @rate_plan, notice: 'Rate plan was successfully created.' }
        format.json { render :show, status: :created, location: @rate_plan }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @rate_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /rate_plans/1 or /rate_plans/1.json
  def update
    respond_to do |format|
      if @rate_plan.update(rate_plan_params)
        format.html { redirect_to @rate_plan, notice: 'Rate plan was successfully updated.', status: :see_other }
        format.json { render :show, status: :ok, location: @rate_plan }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @rate_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /rate_plans/1 or /rate_plans/1.json
  def destroy
    @rate_plan.destroy!

    respond_to do |format|
      format.html { redirect_to rate_plans_path, notice: 'Rate plan was successfully destroyed.', status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_rate_plan
      @rate_plan = RatePlan.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def rate_plan_params
      params.expect(rate_plan: [ :unit_type_id, :service_schedule, :billing_period, :price_cents, :active, :effective_on, :expires_on ])
    end
end
