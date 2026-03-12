class TrucksController < ApplicationController
  before_action :set_truck

  def edit
    render layout: false
  end

  def update
    if @truck.update(truck_params)
      redirect_to edit_company_path, notice: 'Truck updated'
    else
      flash.now[:alert] = @truck.errors.full_messages.to_sentence
      render :edit, layout: false, status: :unprocessable_content
    end
  end

  private

  def set_truck
    @truck = current_user.company.trucks.find(params[:id])
  end

  def truck_params
    params.require(:truck).permit(
      :name,
      :number,
      :clean_water_capacity_gal,
      :waste_capacity_gal,
      :miles_per_gallon,
      :preference_rank,
      :waste_yellow_threshold_pct,
      :waste_red_threshold_pct,
      :waste_red_nearby_miles,
      :waste_early_dump_proximity_miles,
      :water_yellow_threshold_pct,
      :water_red_threshold_pct,
      :water_red_nearby_miles,
      :water_early_refill_proximity_miles,
      :water_min_reserve_gal
    )
  end
end
