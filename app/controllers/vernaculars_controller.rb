class VernacularsController < ApplicationController
  def prefer
    name = Vernacular.find(params[:id])
    authorize name, :update?
    VernacularPreference.user_preferred(current_user, name)
    flash[:notice] = I18n.t("names.preferred_in_language_for_page", language: I18n.t("languages.#{name.language.locale&.code}"), page: name.page.scientific_name, name: name.string)
    redirect_to(page_names_path(name.page))
  end
end
