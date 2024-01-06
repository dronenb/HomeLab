# Budget killswitch pubsub topic
resource "google_pubsub_topic" "homelab_budget_killswitch" {
  #checkov:skip=CKV_GCP_83:I don't want to manage the keys
  name    = "budget-killswitch"
  project = google_project.ben_homelab.project_id
}


# Budget
resource "google_billing_budget" "homelab_budget" {
  billing_account = google_project.ben_homelab.billing_account
  display_name    = "budget-killswitch"
  amount {
    specified_amount {
      currency_code = "USD"
      units         = "50"
    }
  }
  threshold_rules {
    threshold_percent = 1
  }
  all_updates_rule {
    disable_default_iam_recipients = false
    pubsub_topic                   = google_pubsub_topic.homelab_budget_killswitch.id
  }
}

