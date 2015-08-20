class CallFlow::Jobs::Persistence
  include Sidekiq::Worker

  attr_reader :dialed_call, :campaign, :household_record

  sidekiq_options({
    queue: :persistence,
    retry: true,
    failures: true,
    backtrace: true
  })

  def perform(account_sid, call_sid)
    @dialed_call = CallFlow::Call::Dialed.new(account_sid, call_sid)
    @campaign    = Campaign.find(dialed_call.storage['campaign_id'])
    @household_record   = campaign.households.where(phone: dialed_call.storage['phone']).first

    if household_record.present? # subsequent dial
      dialed_call_persistence.update_household_record
    else # first dial
      @household_record = dialed_call_persistence.create_household_record
    end

    leads.import_records

    call_attempt_record = dialed_call_persistence.create(leads.dispositioned_voter)

    survey_responses.save(leads.dispositioned_voter, call_attempt_record)
  end

  def dialed_call_persistence
    @dialed_call_persistence ||= CallFlow::Persistence::DialedCall.new(dialed_call, campaign, household_record)
  end

  def leads
    @leads ||= CallFlow::Persistence::Leads.new(dialed_call, campaign, household_record)
  end

  def survey_responses
    @answers ||= CallFlow::Persistence::SurveyResponses.new(dialed_call, campaign, household_record)
  end
end
