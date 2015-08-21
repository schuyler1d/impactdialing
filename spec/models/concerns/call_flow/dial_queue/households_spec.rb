require 'rails_helper'

describe 'CallFlow::DialQueue::Households' do
  include ListHelpers

  let(:campaign){ create(:power) }
  let(:voter_list){ create(:voter_list, campaign: campaign) }
  let(:households) do
    build_household_hashes(10, voter_list)
  end

  subject{ CallFlow::DialQueue::Households.new(campaign) }

  def key(phone)
    subject.send(:hkey, phone)
  end

  before do
    import_list(voter_list, households)
  end

  after do
    redis.flushall
  end

  describe 'automatic message drops' do
    let(:redis_key){ "dial_queue:#{campaign.id}:households:message_drops" }
    let(:phone_one){ households.keys.last }
    let(:sequence_one){ households[phone_one]['sequence'] }

    before do
      subject.record_message_drop(sequence_one)
    end

    describe 'record when a message has been dropped' do
      context 'for a given sequence' do
        it 'sets bit to 1 for given household sequence' do
          expect(redis.getbit(redis_key, sequence_one)).to eq 1
        end
      end
      context 'for a given phone number' do
        let(:phone_two){ households.keys.first }
        let(:sequence_two){ households[phone_two]['sequence'] }

        it 'sets bit to 1 for household sequence of given phone number' do
          subject.record_message_drop_by_phone(phone_two)
          expect(redis.getbit(redis_key, sequence_two)).to eq 1
        end
      end
    end

    describe 'detect if a message has been dropped' do
      context 'for a given sequence' do
        let(:sequence_two){ households[households.keys.first]['sequence'] }

        it 'returns true when bit for household sequence is 1' do
          expect(subject.message_dropped_recorded?(sequence_two)).to be_falsey
        end
        it 'returns false when bit for household sequence is 0' do
          expect(subject.message_dropped_recorded?(sequence_one)).to be_truthy
        end
      end

      context 'for a given phone number' do
        let(:phone_two){ households.keys.first }

        it 'returns true when bit for household sequence is 1' do
          expect(subject.message_dropped?(phone_one)).to be_truthy
        end
        it 'returns false when bit for household sequence is 0' do
          expect(subject.message_dropped?(phone_two)).to be_falsey
        end
      end
    end
  end

  describe 'existence' do
    it 'returns true when any households exist' do
      expect(subject.exists?).to be_truthy
    end

    it 'returns false otherwise' do
      redis.flushall
      expect(subject.exists?).to be_falsey
    end
  end

  describe 'finding data for given phone number(s)' do
    let(:phone_one){ households.keys.first }
    let(:phone_two){ households.keys.last }
    let(:household_one){ HashWithIndifferentAccess.new(households[phone_one]) }
    let(:household_two){ HashWithIndifferentAccess.new(households[phone_two]) }

    describe 'finding a collection of members ids for a given phone number' do
      context 'the redis-key & hash-key of the phone number exist' do
        it 'return an array of members' do
          leads_one = subject.find(phone_one)[:leads]
          leads_two = subject.find(phone_two)[:leads]
          expect(leads_one).to eq household_one[:leads]
          expect(leads_two).to eq household_two[:leads]
        end
      end

      context 'the redis-key & hash-key of the phone number do not exist' do
        it 'return []' do
          actual = subject.find('1234567890')

          expect(actual).to eq []
        end
      end
    end

    describe 'finding one or more collections of member ids for one or more given phone numbers' do
      it 'return a hash where phone numbers are keys with each value a collection of member ids eg {"5554442211" => ["35","42"]}' do
        actual = subject.find_all([phone_one, phone_two])
        expected = {
          phone_one => household_one,
          phone_two => household_two
        }
        expect(actual).to eq expected
      end
    end
  end

  describe 'updating leads w/ persisted Voter SQL IDs' do
    let(:phone){ households.keys.first }
    let(:redis_household){ redis.hgetall("dial_queue:#{campaign.id}:households:active:#{phone[0..-4]}") }
    let(:redis_leads){ JSON.parse(redis_household[phone[-3..-1]])['leads'] }
    let(:household_record) do
      Household.create!({
        phone: phone,
        status: CallAttempt::Status::BUSY,
        campaign: campaign,
        account: campaign.account
      })
    end
    let(:uuid_to_id_map) do
      {}
    end

    before do
      redis_leads.each do |lead|
        attrs = {
          campaign_id: campaign.id,
          account_id: campaign.account_id,
          household_id: household_record.id
        }
        lead.each do |prop,val|
          attrs[prop] = val if prop != 'id' and Voter.column_names.include?(prop)
        end
        voter_record                = Voter.create!(attrs)
        uuid_to_id_map[lead[:uuid]] = voter_record.id
      end

      subject.update_leads_with_sql_ids(phone, uuid_to_id_map)
    end

    it 'stores Voter SQL ID with redis lead data' do
      redis_leads.each do |lead|
        expect(lead['sql_id']).to eq uuid_to_id_map[lead['uuid']]
      end
    end
  end

  describe 'marking leads completed' do
    let(:redis_key){ "dial_queue:#{campaign.id}:households:completed_leads" }
    let(:phone){ households.keys.last }
    let(:redis_household){ redis.hgetall("dial_queue:#{campaign.id}:households:active:#{phone[0..-4]}") }
    let(:redis_leads){ JSON.parse(redis_household[phone[-3..-1]])['leads'] }
    let(:sequence){ redis_leads.first['sequence'] }
    
    before do
      expect(sequence).to be > 0
      subject.mark_lead_completed(sequence)
    end

    describe '#mark_lead_completed' do
      it 'sets bitmap to 1 for given lead.sequence' do
        expect(redis.getbit(redis_key, sequence)).to eq 1
      end
    end

    describe '#lead_completed?' do
      it 'returns true when lead is marked completed' do
        expect(subject.lead_completed?(sequence)).to be_truthy
      end

      it 'returns false when lead is not marked completed' do
        expect(subject.lead_completed?(sequence+1)).to be_falsey
      end
    end
  end
end

