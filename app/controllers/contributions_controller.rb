# frozen_string_literal: true

class ContributionsController < ApplicationController
  include NotUsingPunditYet

  before_action :authenticate_user!, except: %i[thank_you], unless: :peer_to_peer_mode?
  before_action :set_contribution, only: %i[respond triage]

  layout 'without_navbar', only: [:thank_you]

  def index
    @filter_types = FilterTypeBlueprint.render([ContributionType, Category, ServiceArea, UrgencyLevel, ContactMethod])
    filter = BrowseFilter.new(filter_params)
    @contributions = ContributionBlueprint.render(filter.contributions, contribution_blueprint_options)
    respond_to do |format|
      format.html
      format.json { render inline: @contributions }
    end
  end

  def show
    contribution = Listing.find(params[:id])

    render(
      :show,
      locals: {
        contribution: contribution,
      }
    )
  end

  def combined_form; end

  def respond
    @communication_logs = CommunicationLog.where(person: @contribution.person).order(sent_at: :desc)
  end

  def thank_you; end

  def triage; end

  def triage_update
    @contribution = Listing.find(params[:id])
    contribution_params = params[@contribution.type.downcase.to_sym]
    title = contribution_params[:title]
    description = contribution_params[:description]
    inexhaustible = contribution_params[:inexhaustible]

    if @contribution.update(title: title, description: description, inexhaustible: inexhaustible)
      # CommunicationLog.create!(person: @contribution.person,
      #                          sent_at: Time.current,
      #                          subject: "triaged by #{current_user.name}",
      #                          delivery_status: "connected",
      #                          delivery_method: @contribution.person.preferred_contact_method)
      redirect_to respond_contribution_path(@contribution), notice: 'Contribution was successfully updated.'
    else
      render triage_contribution_path(@contribution)
    end
  end

  private

  def peer_to_peer_mode?
    @system_setting.peer_to_peer?
  end

  def contribution_blueprint_options
    options = {}
    options[:respond_path] = ->(id) { respond_contribution_path(id)} if current_user
    options[:view_path] = ->(id) { contribution_path(id) } if SystemSetting.current_settings.peer_to_peer?
    options
  end

  def filter_params
    return {} unless allowed_params&.to_h.any?

    allowed_params.to_h.filter { |key, _v| BrowseFilter::ALLOWED_PARAMS.keys.include? key}.tap do |hash|
      hash.each_key { |key| hash[key] = hash[key].keys}
    end
  end

  def allowed_params
    @allowed_params ||= params.permit(:format, **BrowseFilter::ALLOWED_PARAMS)
  end

  def set_contribution
    @contribution = Listing.find(params[:id])
  end
end
