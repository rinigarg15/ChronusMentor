class ChangeDefaultValueOfMentoringOfferNeedsAcceptance< ActiveRecord::Migration[4.2]
  def change
    offer_mentoring_feature = Feature.find_by(name: FeatureName::OFFER_MENTORING)
    prog_ids_with_offer_mentoring = OrganizationFeature.where(feature_id: offer_mentoring_feature).where(enabled: true).pluck(:organization_id)
    Program.where("id NOT IN (?)", prog_ids_with_offer_mentoring).update_all(:mentor_offer_needs_acceptance => true)
    change_column_default(:programs, :mentor_offer_needs_acceptance, true)
  end
end
