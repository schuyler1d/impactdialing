require Rails.root.join("jobs/heroku_resque_auto_scale")
class ReportDownloadJob 
  extend ::HerokuResqueAutoScale
  @queue = :report_download_worker_job


   def self.perform(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job = NewReportJob.new(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy)
     report_job.perform     
   end
   
   def on_failure_report(exception, *args)
     campaign = Campaign.find(args[0])
     user = User.find(args[1])
     strategy = args[7]     
     account_id = campaign.account_id
     callback_url = args[6]
     response_strategy = strategy == 'webui' ?  ReportWebUIStrategy.new("failure", user, campaign, account_id, exception) : ReportApiStrategy.new("failure", campaign.id, account_id, callback_url)
     response_strategy.response({})
   end 
   
   def self.after_perform_scale_down(*args)
     HerokuResqueAutoScale::Scaler.workers('report_download_worker_job',1) if HerokuResqueAutoScale::Scaler.working_job_count('report_download_worker_job') == 1
   end
   
   def self.after_enqueue_scale_up(*args)
      workers_to_scale = HerokuResqueAutoScale::Scaler.working_job_count('report_download_worker_job') + HerokuResqueAutoScale::Scaler.pending_job_count('report_download_worker_job') - HerokuResqueAutoScale::Scaler.worker_count('report_download_worker_job')
      if workers_to_scale > 0 && HerokuResqueAutoScale::Scaler.working_job_count('report_download_worker_job') < 6
        HerokuResqueAutoScale::Scaler.workers('report_download_worker_job', (HerokuResqueAutoScale::Scaler.working_job_count('report_download_worker_job') + HerokuResqueAutoScale::Scaler.pending_job_count('report_download_worker_job')))
      end
    end
   
end