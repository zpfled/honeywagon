class TrailersController < ApplicationController
  before_action :set_trailer

  def edit
    render layout: false
  end

  def update
    if @trailer.update(trailer_params)
      redirect_to edit_company_path, notice: 'Trailer updated'
    else
      flash.now[:alert] = @trailer.errors.full_messages.to_sentence
      render :edit, layout: false, status: :unprocessable_content
    end
  end

  private

  def set_trailer
    @trailer = current_user.company.trailers.find(params[:id])
  end

  def trailer_params
    params.require(:trailer).permit(:name, :identifier, :capacity_spots, :preference_rank)
  end
end
