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

# Service account to run Cloud Function
resource "google_service_account" "budget_killswitch_sa" {
  project      = google_project.ben_homelab.project_id
  account_id   = "budget-killswitch"
  display_name = "budget-killswitch"
}

# Give the Cloud Function SA permission to manage billing
resource "google_project_iam_binding" "budget_killswitch_iam" {
  project = google_project.ben_homelab.project_id
  role    = "roles/billing.projectManager"

  members = [
    "serviceAccount:${google_service_account.budget_killswitch_sa.email}",
  ]
}

# GCS bucket for killswitch source code
resource "google_storage_bucket" "killswitch_source" {
  #checkov:skip=CKV_GCP_62:I will setup bucket logging later
  project       = google_project.ben_homelab.project_id
  name          = "budget-killswitch"
  location      = "US-CENTRAL1"
  force_destroy = false
  autoclass {
    enabled = true
  }
  versioning {
    enabled = false
  }
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

# Zip up the source code
data "archive_file" "budget_killswitch_source" {
  type        = "zip"
  output_path = "${path.module}/killswitch-source/killswitch-source.zip"

  source {
    content  = file("${path.module}/killswitch-source/index.js")
    filename = "index.js"
  }

  source {
    content  = file("${path.module}/killswitch-source/package.json")
    filename = "package.json"
  }
}

resource "google_storage_bucket_object" "budget_killswitch_source" {
  name   = "killswitch-source.zip"
  bucket = google_storage_bucket.killswitch_source.name
  source = data.archive_file.budget_killswitch_source.output_path # Add path to the zipped function source code
}

# Budget killswitch Cloud Function
resource "google_cloudfunctions2_function" "budget_killswitch" {
  name        = "budget-killswitch"
  location    = "us-central1"
  description = "budget-killswitch"
  project     = google_project.ben_homelab.project_id

  build_config {
    runtime     = "nodejs20"
    entry_point = "killSwitch" # Set the entry point 
    source {
      storage_source {
        bucket = google_storage_bucket.killswitch_source.name
        object = google_storage_bucket_object.budget_killswitch_source.name
      }
    }
  }

  service_config {
    max_instance_count               = 1
    min_instance_count               = 0
    available_memory                 = "256M"
    timeout_seconds                  = 60
    max_instance_request_concurrency = 1
    environment_variables = {
      PROJECT_ID = google_project.ben_homelab.project_id
    }
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.budget_killswitch_sa.email
  }

  event_trigger {
    trigger_region = "us-central1"
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.homelab_budget_killswitch.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}
