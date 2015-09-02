class CallFlow::Persistence::Leads < CallFlow::Persistence
  attr_reader :dispositioned_voter

private
  def redis_household
    presented_households.find(phone)
  end

  def active_redis_leads
    redis_household['leads']
  end

  def active_new_redis_leads
    redis_household['leads'].select{|lead| lead['sql_id'].blank?}
  end

  def active_persisted_redis_leads
    redis_household['leads'].select{|lead| lead['sql_id'].present?}
  end

  def any_leads_persisted?
    active_persisted_redis_leads.any?
  end

  def any_leads_not_persisted?
    active_new_redis_leads.any?
  end

  def leads_without_target
    active_redis_leads.select{|ld| ld['uuid'] != call_data[:lead_uuid]}
  end

  def new_leads_without_target
    leads_without_target.select{|ld| ld['sql_id'].blank?}
  end

  def build_voter_attributes(lead)
    voter_attrs = {}
    voter_system_fields.each do |field|
      voter_attrs[field] = lead[field]
    end

    voter_attrs.merge!({
      account_id: campaign.account_id,
      campaign_id: campaign.id
    })
    return voter_attrs
  end
  
  def create_voter_record(voter_attributes)
    household_record.voters.create(voter_attributes)
  end

  def custom_voter_fields
    return @custom_voter_fields if defined?(@custom_voter_fields)
    @custom_voter_fields = {}
    campaign.account.custom_voter_fields.select([:id, :name]).each do |field|
      @custom_voter_fields[field.name.strip] = field.id
    end
    @custom_voter_fields
  end

  def custom_voter_fields_by_id
    return @custom_voter_fields_by_id if defined?(@custom_voter_fields_by_id)
    @custom_voter_fields_by_id = {}
    campaign.account.custom_voter_fields.select([:id, :name]).each do |field|
      @custom_voter_fields_by_id[field.id] = field.name.strip
    end
    @custom_voter_fields_by_id
  end

  def custom_lead_attrs(lead, &block)
    custom_attrs = lead.stringify_keys.keys - (voter_system_fields + ['sequence', 'uuid'])
    custom_attrs.each do |field|
      custom_voter_field_id = custom_voter_fields[field.strip]
      next if custom_voter_field_id.blank?
      yield field, custom_voter_field_id
    end
  end

  def create_custom_voter_field_value_records(voter_record, lead)
    custom_field_values = []
    custom_lead_attrs(lead) do |field, custom_voter_field_id|
      next if voter_record.custom_voter_field_values.where(value: lead[field]).count > 0
      custom_field_values << {
        custom_voter_field_id: custom_voter_field_id,
        voter_id: voter_record.id,
        value: lead[field]
      }
    end

    CustomVoterFieldValue.import_hashes(custom_field_values)
  end

  def build_custom_voter_field_values(leads)
    voter_record_ids    = leads.map{|lead| lead['sql_id']}
    voter_records       = Voter.where(id: voter_record_ids).includes(:custom_voter_field_values)
    custom_field_values = []
    voter_records.each do |voter_record|
      lead = leads.detect{|lead| lead['sql_id'].to_i == voter_record.id}
      voter_record.custom_voter_field_values.each do |custom_voter_field_value|
        target_field = custom_voter_fields_by_id[custom_voter_field_value.custom_voter_field_id]
        custom_field_values << {
          id: custom_voter_field_value.id,
          voter_id: voter_record.id,
          custom_voter_field_id: custom_voter_field_value.custom_voter_field_id,
          value: lead[target_field]
        }
      end
    end
    custom_field_values
  end

  def update_all_voter_records_and_custom_field_values(leads)
    updated_voter_attributes = []
    updated_custom_values    = build_custom_voter_field_values(leads)
    leads.each do |lead|
      new_voter_attrs = build_voter_attributes(lead)
      new_voter_attrs.merge!({
        id: lead['sql_id'],
        household_id: household_record.id
      })
      updated_voter_attributes << new_voter_attrs
    end
    
    Voter.import_hashes(updated_voter_attributes)
    CustomVoterFieldValue.import_hashes(updated_custom_values)
  end

public
  def import_records
    leads               = active_redis_leads
    @dispositioned_voter = nil
    uuid_to_id_map      = {}

    if campaign.using_custom_ids? and any_leads_persisted?
      update_all_voter_records_and_custom_field_values(active_persisted_redis_leads)
    end

    if dialed_call.dispositioned?
      # create 1 voter record & attach to call attempt
      @dispositioned_voter, uuid_to_id_map = create_or_update_dispositioned_voter_record(target_lead)
    end

    not_called_uuid_to_id_map = create_voter_records(new_leads_without_target)

    if active_new_redis_leads.any?
      uuid_to_id_map.merge!(not_called_uuid_to_id_map)
      active_households.update_leads_with_sql_ids(phone, uuid_to_id_map)
    end

    @dispositioned_voter
  end

  def target_lead
    active_redis_leads.detect{|ld| ld['uuid'] == call_data[:lead_uuid]}
  end

  def create_voter_records(leads)
    uuid_to_id_map = {}
    
    return uuid_to_id_map if leads.empty?

    leads.each do |lead|
      voter_record = create_voter_record(build_voter_attributes(lead))
      create_custom_voter_field_value_records(voter_record, lead)
      uuid_to_id_map[lead[:uuid]] = voter_record.id
    end

    uuid_to_id_map
  end

  def create_or_update_dispositioned_voter_record(lead)
    if lead['sql_id'].blank?
      create_dispositioned_voter_record(lead)
    else
      update_dispositioned_voter_record(lead)
    end
  end

  def update_dispositioned_voter_record(lead)
    voter_record = Voter.find(lead['sql_id'])
    voter_record.update_attributes!({
      status: household_status
    })

    [
      voter_record,
      {
        lead[:uuid] => voter_record.id
      }
    ]
  end

  def create_dispositioned_voter_record(lead)
    voter_attrs = build_voter_attributes(lead)
    voter_attrs.merge!({
      status: household_status
    })

    voter_record = create_voter_record(voter_attrs)
    create_custom_voter_field_value_records(voter_record, lead)

    [
      voter_record,
      {
        lead[:uuid] => voter_record.id
      }
    ]
  end
end

