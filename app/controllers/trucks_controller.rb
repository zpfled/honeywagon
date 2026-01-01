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
    params.require(:truck).permit(:name, :number, :clean_water_capacity_gal, :waste_capacity_gal, :miles_per_gallon)
  end
end
