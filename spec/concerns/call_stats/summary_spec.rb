require "spec_helper"

describe CallStats::Summary do
  include ApplicationHelper::TimeUtils

  describe "overview" do

    describe "dialed_and_complete_count" do

      it "should include all successful call attempts" do
        @campaign = create(:predictive)
        voter1 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter2 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter3 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)

        call_attempt1 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter1)
        voter1.update_attributes(last_call_attempt_time: call_attempt1.created_at)
        call_attempt2 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter2)
        voter2.update_attributes(last_call_attempt_time: call_attempt2.created_at)
        call_attempt3 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3)
        voter3.update_attributes(last_call_attempt_time: call_attempt3.created_at)
        call_attempt4 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4)
        voter4.update_attributes(last_call_attempt_time: call_attempt4.created_at)

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.dialed_and_complete_count).to eq(2)
      end

      it "should include all failed call attempts" do
        @campaign = create(:predictive)
        voter1 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now)
        voter2 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now)
        voter3 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)

        call_attempt1 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now, voter: voter1)
        voter1.update_attributes(last_call_attempt_time: call_attempt1.created_at)
        call_attempt2 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now, voter: voter2)
        voter2.update_attributes(last_call_attempt_time: call_attempt2.created_at)
        call_attempt3 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3)
        voter3.update_attributes(last_call_attempt_time: call_attempt3.created_at)
        call_attempt4 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4)
        voter4.update_attributes(last_call_attempt_time: call_attempt4.created_at)

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.dialed_and_complete_count).to eq(2)
      end

      it "should include all successful failed call attempts" do
        @campaign = create(:predictive)
        voter1 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter2 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now)
        voter3 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)

        call_attempt1 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter1)
        voter1.update_attributes(last_call_attempt_time: call_attempt1.created_at)
        call_attempt2 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now, voter: voter2)
        voter2.update_attributes(last_call_attempt_time: call_attempt2.created_at)
        call_attempt3 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3)
        voter3.update_attributes(last_call_attempt_time: call_attempt3.created_at)
        call_attempt4 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4)
        voter4.update_attributes(last_call_attempt_time: call_attempt4.created_at)

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.dialed_and_complete_count).to eq(2)
      end
    end

    describe "dialed_and_available_for_retry_count" do

      it "should consider available and abandoned calls" do
        @campaign = create(:predictive, recycle_rate: 1)
        voter1 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, last_call_attempt_time: 2.hours.ago)
        voter2 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS)
        voter3 = create(:realistic_voter, campaign: @campaign, last_call_attempt_time: 2.hours.ago, status: CallAttempt::Status::HANGUP)
        voter5 = create(:realistic_voter, campaign: @campaign, last_call_attempt_time: 3.hours.ago, status: CallAttempt::Status::ABANDONED)

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.dialed_and_available_for_retry_count).to eq(2)
      end
    end

    describe "dialed_and_not_available_for_retry_count" do

      before do
        @campaign = create(:predictive, recycle_rate: 3)
        voter1 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, last_call_attempt_time: Time.now - 2.hours)
        voter2 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS)
        voter3 = create(:realistic_voter, campaign: @campaign, last_call_attempt_time: 2.hours.ago, status: CallAttempt::Status::HANGUP)
        voter4 = create(:realistic_voter, campaign: @campaign, last_call_attempt_time: 1.hours.ago, status: CallAttempt::Status::HANGUP)
        voter7 = create(:realistic_voter, campaign: @campaign, last_call_attempt_time: 4.hours.ago, status: CallAttempt::Status::ABANDONED)
        @dial_report = CallStats::Summary.new(@campaign)
      end

      it "returns count of voters who may be retried but are not currently available (dialed & not available & not completed)" do
        expect(@dial_report.dialed_and_not_available_for_retry_count).to eq 3
      end

      it 'considers the remaining as available for retry' do
        expect(@dial_report.dialed_and_available_for_retry_count).to eq 1
      end
    end

    describe "leads_not_dialed" do

      it "counts Voters w/ blank last_call_attempt_time and w/ statuses not in 'ringing', 'ready' or 'in-progress'" do
        @campaign = create(:predictive, recycle_rate: 3)
        voter1 = create(:realistic_voter, campaign: @campaign, status: 'not called')
        voter2 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS)
        voter3 = create(:realistic_voter, campaign: @campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
        voter4 = create(:realistic_voter, campaign: @campaign, :scheduled_date => 2.minutes.ago, :status => CallAttempt::Status::SCHEDULED)
        voter5 = create(:realistic_voter, campaign: @campaign, :status => CallAttempt::Status::ABANDONED)
        voter6 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::READY)
        voter7 = create(:realistic_voter, campaign: @campaign, status: CallAttempt::Status::RINGING)

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.not_dialed_count).to eq(1)
      end

    end

    describe 'the math' do
      include FakeCallData

      let(:admin){ create(:user) }
      let(:account){ admin.account }

      let(:not_recently_dialed){ create_list(:realistic_voter, :not_recently_dialed, 10, campaign: @campaign) }
      let(:recently_dialed){ create_list(:realistic_voter, :recently_dialed, 10, campaign: @campaign) }

      before do
        @campaign = create_campaign_with_script(:bare_predictive, account).last
        voter_attrs = {campaign: @campaign, account: account}

        @completed = create_list(:realistic_voter, 5, :not_recently_dialed, :success, voter_attrs)
        @completed += create_list(:realistic_voter, 5, :not_recently_dialed, :failed, voter_attrs)
        @completed += create_list(:realistic_voter, 5, :recently_dialed, :success, voter_attrs)
        @completed += create_list(:realistic_voter, 5, :recently_dialed, :failed, voter_attrs)

        @available = create_list(:realistic_voter, 5, :not_recently_dialed, :busy, voter_attrs)
        @available += create_list(:realistic_voter, 5, :not_recently_dialed, :abandoned, voter_attrs)
        @available += create_list(:realistic_voter, 5, :not_recently_dialed, :no_answer, voter_attrs)
        @available += create_list(:realistic_voter, 5, :not_recently_dialed, :skipped, voter_attrs)
        @available += create_list(:realistic_voter, 5, :not_recently_dialed, :hangup, voter_attrs)
        @available += create_list(:realistic_voter, 5, :not_recently_dialed, :call_back, voter_attrs)
        @available += create_list(:realistic_voter, 5, :not_recently_dialed, :voicemail, voter_attrs)
        @available += create_list(:realistic_voter, 5, :not_recently_dialed, :retry, voter_attrs)

        @not_available = create_list(:realistic_voter, 5, :recently_dialed, :ringing, voter_attrs)
        @not_available += create_list(:realistic_voter, 5, :not_recently_dialed, :ringing, voter_attrs)
        @not_available += create_list(:realistic_voter, 5, :recently_dialed, :queued, voter_attrs)
        @not_available += create_list(:realistic_voter, 5, :not_recently_dialed, :queued, voter_attrs)
        @not_available += create_list(:realistic_voter, 5, :recently_dialed, :in_progress, voter_attrs)
        @not_available += create_list(:realistic_voter, 5, :recently_dialed, :busy, voter_attrs)
        @not_available += create_list(:realistic_voter, 5, :recently_dialed, :abandoned, voter_attrs)
        @not_available += create_list(:realistic_voter, 5, :recently_dialed, :no_answer, voter_attrs)
        @not_available += create_list(:realistic_voter, 5, :recently_dialed, :skipped, voter_attrs)
        @not_available += create_list(:realistic_voter, 5, :recently_dialed, :hangup, voter_attrs)
        @not_available += create_list(:realistic_voter, 5, :recently_dialed, :call_back, voter_attrs)
        @not_available += create_list(:realistic_voter, 5, :recently_dialed, :voicemail, voter_attrs)
        @not_available += create_list(:realistic_voter, 5, :recently_dialed, :retry, voter_attrs)

        @not_dialed = create_list(:realistic_voter, 5, :skipped, voter_attrs)
        @not_dialed += create_list(:realistic_voter, 5, voter_attrs)

        @dialed = @completed + @available + @not_available
      end

      it 'not dialed + dialed = all voters' do
        summary = CallStats::Summary.new(@campaign)

        expect( summary.not_dialed_count + @campaign.all_voters.dialed.count ).to eq @campaign.all_voters.count
      end

      it 'available + not available + completed = dialed' do
        summary = CallStats::Summary.new(@campaign)

        expect( summary.dialed_and_available_for_retry_count + summary.dialed_and_not_available_for_retry_count + summary.dialed_and_complete_count ).to eq @campaign.all_voters.dialed.count
      end
    end
  end
end
