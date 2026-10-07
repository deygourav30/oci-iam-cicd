# Live project: create an OCI IAM user with Terraform + GitHub Actions

**Goal:** you change code in Git → GitHub Actions runs Terraform → Terraform creates a user called `cicd-demo-user` in your OCI tenancy. You never click "create user" in the console and never run `terraform apply` on your laptop.

There are **two users** in this project. Do not mix them up:

| User | Who creates it | What it is for |
|---|---|---|
| `terraform-ci` | **You**, by hand, once (Part A) | The "robot" login that GitHub Actions uses to talk to OCI |
| `cicd-demo-user` | **The pipeline** (Part E) | The user this project exists to create |

```
You (git push) ──► GitHub repo ──► GitHub Actions ──► Terraform ──► OCI API ──► cicd-demo-user
                                        │                               ▲
                                        └── logs in as terraform-ci ────┘
                                        └── remembers what it built in the tf-state bucket
```

---

## What's in this project

```
oci-iam-cicd/
├── .github/workflows/terraform.yml   # the pipeline (plan → approval → apply)
├── ci/write-oci-config.sh            # turns GitHub secrets into an OCI login file
├── terraform/
│   ├── versions.tf                   # Terraform + OCI provider versions
│   ├── providers.tf                  # how Terraform logs in to OCI
│   ├── backend.tf                    # where Terraform keeps its memory (state)   ← EDIT
│   ├── variables.tf                  # inputs
│   ├── terraform.tfvars              # values for the inputs                       ← EDIT
│   ├── main.tf                       # THE USER TO CREATE
│   └── outputs.tf                    # prints the new user's OCID after apply
├── .gitignore
└── README.md
```

---

## Part A — OCI console setup (one time, about 20 minutes)

Log in to the OCI console as an administrator.

### A1. Note down three facts about your tenancy

1. Click your **profile icon** (top right) → **Tenancy: <name>**.
2. Copy the **OCID** (starts with `ocid1.tenancy.oc1..`). → call it **TENANCY_OCID**
3. On the same page, copy **Object storage namespace** (a short random word). → **NAMESPACE**
4. Find your **home region**: on the same page, "Home region", e.g. `India West (Mumbai)`. Its identifier looks like `ap-mumbai-1`. (Region identifiers are listed under the region menu → *Manage regions*.) → **HOME_REGION**

> **Why home region?** OCI only lets you create users, groups and policies in the home region. If the pipeline points at any other region, creating the user fails.

### A2. Create the group and the robot user `terraform-ci`

1. ☰ Menu → **Identity & Security** → **Domains** → click **Default**.
2. **Groups** → **Create group** → Name: `TerraformCI` → Create.
3. **Users** → **Create user**:
   - First/last name: `terraform` / `ci`
   - Username / email: `terraform-ci` and an email you own
   - Groups: tick **TerraformCI**
   - Create.
4. Open the new user → **Edit user capabilities** → make sure **API keys** and **Customer secret keys** are ticked → Save.

### A3. Give `terraform-ci` an API key (this is how GitHub logs in)

1. On the `terraform-ci` user page → **API keys** → **Add API key**.
2. Choose **Generate API key pair** → click **Download private key** (save the `.pem` file safely) → **Add**.
3. A box called **Configuration file preview** appears. Copy it somewhere; it looks like:

   ```
   [DEFAULT]
   user=ocid1.user.oc1..aaaa...        ← USER_OCID
   fingerprint=12:34:ab:cd:...         ← FINGERPRINT
   tenancy=ocid1.tenancy.oc1..aaaa...
   region=ap-mumbai-1
   key_file=<path to your private keyfile>
   ```

> The `.pem` file is a password. Never put it in Git.

### A4. Allow `terraform-ci` to manage users and use the state bucket

☰ Menu → **Identity & Security** → **Policies** → make sure compartment is the **root** (your tenancy name) → **Create policy**:

- Name: `terraform-ci-policy`
- Description: `Lets the CI pipeline manage IAM users and Terraform state`
- Click **Show manual editor** and paste:

```
Allow group 'Default'/'TerraformCI' to manage users in tenancy
Allow group 'Default'/'TerraformCI' to read buckets in tenancy
Allow group 'Default'/'TerraformCI' to manage objects in tenancy where target.bucket.name = 'tf-state'
```

(Older tenancies without identity domains: write `group TerraformCI` instead of `group 'Default'/'TerraformCI'`.)

> `manage users` is a powerful permission. That's fine for a learning project. In a real company this robot would be tightly controlled.

### A5. Create the bucket that holds Terraform's memory (state)

1. ☰ Menu → **Storage** → **Buckets** → compartment = **root** → **Create bucket**.
2. Name: `tf-state` · Default storage tier: Standard · tick **Enable object versioning** → Create.

> **Why is this needed?** Each GitHub run starts on a brand-new machine. Terraform writes "I created user X with OCID Y" into a state file. If that file only lived on the runner, the next run would forget and try to create the user again (and fail). The bucket is Terraform's permanent memory.

### A6. Create a Customer Secret Key (lets Terraform read/write the bucket)

1. Go back to user `terraform-ci` → **Customer secret keys** → **Generate secret key** → name `tf-state`.
2. **Copy the secret now**; it is shown only once. → **S3_SECRET_KEY**
3. Close the dialog. In the list, copy the **Access key**. → **S3_ACCESS_KEY**

You now have everything from OCI:

| Name | Example |
|---|---|
| TENANCY_OCID | `ocid1.tenancy.oc1..aaaa...` |
| USER_OCID (of terraform-ci) | `ocid1.user.oc1..aaaa...` |
| FINGERPRINT | `12:34:ab:...` |
| Private key | contents of the downloaded `.pem` file |
| HOME_REGION | `ap-mumbai-1` |
| NAMESPACE | `axabcd1234` |
| S3_ACCESS_KEY | `0a1b2c...` |
| S3_SECRET_KEY | `xYz...` |

---

## Part B — Fill in the two project files

### B1. `terraform/terraform.tfvars`

Replace `ocid1.tenancy.oc1..REPLACE_ME` with your **TENANCY_OCID**. Optionally change `user_name` and `user_email`.

### B2. `terraform/backend.tf`

Replace **all** `<region>` with your **HOME_REGION** and `<namespace>` with your **NAMESPACE**. For example:

```hcl
region = "ap-mumbai-1"
endpoints = {
  s3 = "https://axabcd1234.compat.objectstorage.ap-mumbai-1.oraclecloud.com"
}
```

---

## Part C — GitHub setup

### C1. Create the repository

github.com → **New repository** → Name `oci-iam-cicd` → do **not** add a README → **Create repository**.

> Approval gates (C3) are free on **public** repos. On **private** repos they need a paid GitHub plan. Secrets stay hidden either way, so a public repo is fine for this demo; just don't commit the `.pem` file (the `.gitignore` already blocks it).

### C2. Add 7 secrets

Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**. Add each one exactly with these names:

| Secret name | Value |
|---|---|
| `OCI_TENANCY_OCID` | TENANCY_OCID |
| `OCI_USER_OCID` | USER_OCID of `terraform-ci` |
| `OCI_FINGERPRINT` | FINGERPRINT |
| `OCI_PRIVATE_KEY` | open the `.pem` file in a text editor, copy **everything** including the `-----BEGIN` and `-----END` lines |
| `OCI_REGION` | HOME_REGION |
| `OCI_S3_ACCESS_KEY` | S3_ACCESS_KEY |
| `OCI_S3_SECRET_KEY` | S3_SECRET_KEY |

### C3. Create the approval gate

Repo → **Settings** → **Environments** → **New environment** → name `production` → **Configure environment**:
- Tick **Required reviewers** → add yourself → **Save protection rules**.

Now every apply will wait for you to click **Approve**.

---

## Part D — Push the code

On your computer, in the `oci-iam-cicd` folder:

```bash
git init
git add .
git status                      # check: NO .pem file, NO .tfstate file listed
git commit -m "Create OCI IAM user via Terraform and GitHub Actions"
git branch -M main
git remote add origin https://github.com/<your-github-username>/oci-iam-cicd.git
git push -u origin main
```

---

## Part E — Watch the pipeline create the user

1. Open the repo → **Actions** tab → click the running **terraform-oci-iam** workflow.
2. **plan** job runs (about 1 minute). Click it to see each step. The summary shows:

   ```
   + resource "oci_identity_user" "demo" {
       + name        = "cicd-demo-user"
       ...
   Plan: 1 to add, 0 to change, 0 to destroy.
   ```
   `+` means "will be created".

3. **apply** job shows **Waiting** with a yellow banner. Click **Review deployments** → tick **production** → **Approve and deploy**.
4. **apply** runs. The last step, **Show what was created**, prints:

   ```
   user_name  = "cicd-demo-user"
   user_ocid  = "ocid1.user.oc1..aaaa..."
   user_state = "ACTIVE"
   ```

5. **Verify in OCI:** ☰ → Identity & Security → Domains → Default → **Users** → `cicd-demo-user` is there.
6. **Verify the state:** ☰ → Storage → Buckets → `tf-state` → you'll see `oci-iam-cicd/terraform.tfstate`.

🎉 The user was created by the pipeline, not by you.

---

## Part F — Make a change the proper way (branch → PR → plan → merge → approve)

This is how all future changes work.

```bash
git checkout -b change-description
```

Edit `terraform/terraform.tfvars`:

```hcl
user_description = "Demo user - updated through a Pull Request"
```

```bash
git add terraform/terraform.tfvars
git commit -m "Update demo user description"
git push -u origin change-description
```

1. On GitHub, click **Compare & pull request** → **Create pull request**.
2. The **plan** job runs on the PR. Open its summary: you'll see `~ description = "..." -> "..."` and `Plan: 0 to add, 1 to change, 0 to destroy.` (`~` = update in place). **Nothing has changed in OCI yet.**
3. Happy with it? **Merge pull request**.
4. The pipeline runs on `main` → **plan** → waits → you **Approve** → **apply** updates the description.
5. Check the user in the OCI console; the description changed.

Clean up your laptop:

```bash
git checkout main
git pull
git branch -d change-description
```

---

## Part G — Remove the user (also through the pipeline)

1. New branch: `git checkout -b remove-demo-user`.
2. Delete everything in `terraform/main.tf` and `terraform/outputs.tf` (leave the files empty).
3. Commit, push, open a PR. The plan shows `- resource "oci_identity_user" "demo"` and `Plan: 0 to add, 0 to change, 1 to destroy.` (`-` = delete).
4. Merge → approve → the user is deleted from OCI.

---

## Troubleshooting

| Error in the job log | Step | Meaning / fix |
|---|---|---|
| `403` / `NoSuchBucket` / `SignatureDoesNotMatch` | Init | Wrong `<namespace>` or `<region>` in `backend.tf`, or wrong `OCI_S3_ACCESS_KEY` / `OCI_S3_SECRET_KEY` |
| `401 NotAuthenticated` | Plan | `OCI_FINGERPRINT` doesn't match the key, wrong `OCI_USER_OCID`, or the PEM was pasted without the BEGIN/END lines |
| `404 NotAuthorizedOrNotFound` on the user | Apply | Policy (A4) missing, or `OCI_REGION` is not your **home** region |
| `409 Conflict` / user already exists | Apply | A user with that `user_name` already exists; pick another name |
| `Terraform exited with code 3` at "Check formatting" | Plan | A `.tf` file isn't formatted; run `terraform fmt -recursive` locally and push |
| Apply job never appears | — | It only runs on `main`, not on PRs; that's intended |
| No "Review deployments" button | — | The `production` environment (C3) isn't set up, or you're not a reviewer |

---

## The idea in one paragraph

Git is the single source of truth: `main.tf` *describes* the user you want. GitHub Actions is the only thing allowed to act on OCI, using the `terraform-ci` robot's key stored as a secret. `plan` shows what would change, a human approves, `apply` makes it so, and the state file in the bucket remembers it. To change or delete the user you change the code, never the console.
