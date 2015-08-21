require 'rails_helper'

describe 'CallFlow::Persistence::Leads' do
  include ListHelpers

  let(:redis){ Redis.new }
  let(:account){ create(:account) }
  let(:campaign){ create(:predictive, account: account) }
  let(:voter_list){ create(:voter_list, campaign: campaign) }
  let(:caller_session){ create(:webui_caller_session, campaign: campaign, sid: 'caller-session-sid') }
  let(:households) do
    build_household_hashes(1, voter_list)
  end
  let(:phone) do
    households.keys.first
  end

  before do
    import_list(voter_list, households, 'active', 'presented')
  end

  after do
    redis.flushall
  end

  describe '#import_records' do
    let(:dialed_call_storage) do
      instance_double('CallFlow::Call::Storage')
    end
    let(:dialed_call) do
      instance_double('CallFlow::Call::Dialed', {
        storage: dialed_call_storage,
        completed?: false,
        answered_by_human?: false
      })
    end
    let(:household_record) do
      create(:household, campaign: campaign, account: account, phone: phone)
    end
    let(:dispositioned_voter_record){ nil }
    let(:voter_records){ Voter.all }

    subject{ CallFlow::Persistence::Leads.new(dialed_call, campaign, household_record) }

    shared_examples_for 'every Voter record imported' do
      it 'associates w/ created Household record' do
        subject.import_records
        expect(voter_records.all?{|record| record.household == household_record}).to be_truthy
      end
      it 'associates w/ proper Account record' do
        subject.import_records
        expect(voter_records.all?{|record| record.account == account}).to be_truthy
      end
      it 'associates w/ proper Campaign record' do
        subject.import_records
        expect(voter_records.all?{|record| record.campaign == campaign}).to be_truthy
      end
      it 'associates w/ proper VoterList record' do
        subject.import_records
        expect(voter_records.all?{|record| record.voter_list == voter_list}).to be_truthy
      end
      it 'stores its SQL ID with redis lead data' do
        expect(Wolverine.dial_queue).to receive(:update_leads_with_sql_id)
        subject.import_records
      end

      %w(first_name last_name middle_name suffix
         email address city state zip_code country).each do |field|
        it "w/ #{field}" do
          subject.import_records
          expect(voter_records.last[field]).to eq households[phone][:leads].last[field.to_sym]
        end
      end
    end
    
    context 'initial import (first call just dialed)' do
      before do
        allow(dialed_call_storage).to receive(:attributes).and_return({
          mapped_status: CallAttempt::Status::BUSY,
          sid: 'dialed-call-sid',
          campaign_type: campaign.type,
          phone: phone
        })
      end

      it_behaves_like 'every Voter record imported'

      it 'imports all active leads associated w/ phone/household' do
        expect{ 
          subject.import_records
        }.to change{ Voter.count }.by households[phone][:leads].size
      end
    end

    context 'subsequent import (subsequent call just dialed & new leads uploaded since first call)' do
      let(:leads_two) do
        build_leads_array(2, voter_list, phone)
      end

      before do
        allow(dialed_call_storage).to receive(:attributes).and_return({
          mapped_status: CallAttempt::Status::BUSY,
          sid: 'dialed-call-sid',
          campaign_type: campaign.type,
          phone: phone
        })
        subject.import_records
        households[phone][:leads] += leads_two
        add_leads(voter_list, phone, leads_two, 'active', 'presented')
      end

      it_behaves_like 'every Voter record imported'

      it 'imports only the leads lacking `sql_id` property' do
        expect{
          subject.import_records
        }.to change{ Voter.count }.by leads_two.size
      end
    end

    context 'when twilio call status is "completed"' do
      before do
        allow(dialed_call_storage).to receive(:attributes).and_return({
          mapped_status: CallAttempt::Status::SUCCESS,
          sid: 'dialed-call-sid',
          campaign_type: campaign.type,
          phone: phone,
          lead_uuid: households[phone][:leads].first[:uuid]
        })
        allow(dialed_call).to receive(:completed?){ true }
        allow(dialed_call).to receive(:answered_by_human?){ true }
        allow(dialed_call).to receive(:storage){ dialed_call_storage }
      end

      context 'first dial' do
        let(:target_lead) do
          household = JSON.parse(redis.hget("dial_queue:#{campaign.id}:households:active:#{phone[0..-4]}", phone[-3..-1]))
          household['leads'].first
        end
        subject{ CallFlow::Persistence::Leads.new(dialed_call, campaign, household_record) }
        it 'imports each lead in redis not associated w/ dialed call w/ status Voter::Status::NOTCALLED' do
          subject.import_records
          expect(Voter.where(status: Voter::Status::NOTCALLED).count).to eq households[phone][:leads].size - 1
          expect(Voter.where(status: Voter::Status::NOTCALLED).pluck(:id)).to_not include target_lead['sql_id'].to_i
        end

        it 'imports lead in redis associated w/ dialed call w/ status CallAttempt::Status::SUCCESS' do
          subject.import_records
          expect(Voter.where(status: CallAttempt::Status::SUCCESS).pluck(:id)).to eq [target_lead['sql_id'].to_i]
        end
      end

      context 'subsequent dials' do
        let(:leads_two) do
          build_leads_array(2, voter_list, phone)
        end

        before do
          subject.import_records
          households[phone][:leads] += leads_two
          add_leads(voter_list, phone, leads_two, 'active', 'presented')
        end

        context 'new leads uploaded since last dial' do
          subject{ CallFlow::Persistence::Leads.new(dialed_call, campaign, household_record) }
          it 'imports new leads from redis w/ status of Voter::Status::NOTCALLED' do
            subject.import_records
            expect(Voter.order('id desc').limit(leads_two.size).pluck(:status).uniq).to eq [Voter::Status::NOTCALLED]
          end
        end

        context 'dispositioned lead already imported' do
          subject{ CallFlow::Persistence::Leads.new(dialed_call, campaign, household_record) }
          let(:target_lead) do
            target_uuid = households[phone][:leads].first[:uuid]
            household = JSON.parse(redis.hget("dial_queue:#{campaign.id}:households:active:#{phone[0..-4]}", phone[-3..-1]))
            household['leads'].detect{|ld| ld['uuid'] == target_uuid}
          end
          it 'updates Voter record associated w/ dialed call to have status CallAttempt::Status::SUCCESS' do
            Voter.update_all({status: Voter::Status::NOTCALLED})
            subject.import_records
            expect(Voter.find(target_lead['sql_id']).status).to eq CallAttempt::Status::SUCCESS
          end
        end

        context 'dispositioned lead uploaded since last dial' do
          let(:target_lead) do
            household = JSON.parse(redis.hget("dial_queue:#{campaign.id}:households:active:#{phone[0..-4]}", phone[-3..-1]))
            household['leads'].last
          end
          before do
            allow(dialed_call_storage).to receive(:attributes).and_return({
              mapped_status: CallAttempt::Status::SUCCESS,
              sid: 'dialed-call-sid',
              campaign_type: campaign.type,
              phone: phone,
              lead_uuid: households[phone][:leads].last[:uuid]
            })
            allow(dialed_call).to receive(:storage){ dialed_call_storage }
          end
          let(:subject_two){ CallFlow::Persistence::Leads.new(dialed_call, campaign, household_record) }
          it 'imports lead in redis associated w/ dialed call w/ status CallAttempt::Status::SUCCESS' do
            expect{ subject_two.import_records }.to change{ Voter.count }.by 2
            expect(Voter.find(target_lead['sql_id']).status).to eq CallAttempt::Status::SUCCESS
          end

          it 'imports leads in redis not associated w/ dialed call w/ status Voter::Status::NOTCALLED' do
            subject_two.import_records
            expect(Voter.order('id desc').limit(leads_two.size).pluck(:status).first).to eq Voter::Status::NOTCALLED
          end
        end
      end
    end
  end
end
