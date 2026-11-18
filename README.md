# Ruth's Makeup — GitHub Pages + Supabase starter

**Brand:** Ruth's Makeup | **Artist:** Rupar Htun | **Location:** Victory Monument area, Bangkok.

Two separate interfaces:
- `index.html` — public customer website.
- `admin/index.html` — Ruth's private admin interface (Supabase-authorized).

## Setup (do in order)

1. Create a NEW **Supabase** project at https://supabase.com. Save its database password privately.
2. In Supabase **SQL Editor**, paste and run `supabase/schema.sql` ONCE. Do not rerun the seed script without reviewing duplicate inserts.
3. In Supabase **Project Settings → API** (or Connect), copy the **Project URL** and **publishable / anon** key. Edit `assets/config.js` and paste both. **Never use a secret or service_role key in browser files.**
4. In **Authentication → URL Configuration**, add the final GitHub Pages URL as Site URL and redirect URL (for example `https://USERNAME.github.io/ruths-makeup/`). For local testing add your localhost URL. Enable email confirmation for real users.
5. Create Ruth's admin user in Supabase **Authentication → Users** (invite by email or register through the customer site). Copy Ruth's **auth user UUID**. In SQL Editor run: `insert into public.admins(user_id) values ('UUID_HERE');` replacing the placeholder. Only do this for Ruth's verified account.
6. Create a GitHub repository, e.g. `ruths-makeup`. Upload **all contents** of this folder, including `.github/workflows/pages.yml`, `admin/`, `assets/`, and `supabase/`. Commit to the `main` branch.
7. In GitHub **Settings → Pages → Build and deployment**, choose **GitHub Actions**. The included workflow deploys on each push. Wait for the green deployment check.
8. Visit `https://USERNAME.github.io/ruths-makeup/` for customers and `https://USERNAME.github.io/ruths-makeup/admin/` for Ruth.
9. Log in as Ruth and configure prices, contact details, photos, class availability and sessions. Test with separate customer and admin accounts.

## What works in this starter

- Supabase customer registration/sign-in and private admin authorization.
- Editable class/service pricing, active status, content, social links, photo URL, and travel fees.
- Booking requests stored centrally, visible to Ruth and the customer.
- Admin confirmation with a database transaction preventing overlapping confirmed appointments and full group sessions.
- Published group/online sessions and admin open/close controls.
- Customer reviews after a confirmed booking, with admin moderation.
- Portfolio image upload to Supabase Storage (URL available to use in content).
- Responsive pink/rose-gold public website; four-language **key marketing text**.

## Important limits before real public launch

This is a **deployment-ready starter**, NOT a fully tested production booking platform. Do not collect live customer information until you finish QA, privacy/legal review and configure policies. In particular:
- Full Thai, Burmese and Hindi translation of forms, admin content and database descriptions is incomplete.
- Service prices default to **0 = request a quote**, travel fees default to zero until configured.
- Booking duration uses a **fixed two-hour conflict window** for unscheduled appointments; Ruth must define real service/class durations and travel buffers before relying on this.
- Private class requests are accepted for any time, then checked on confirmation. Admin must manually resolve pending duplicates.
- Group sessions do not auto-create the next session; Ruth can create it from Admin Studio.
- Payment collection, payment proof, invoices, reminders, cancellation/refund policy, automatic emails, and online shop checkout are NOT implemented.
- Customer accounts and photos require privacy policy, consent and retention procedures appropriate for Thailand (PDPA).
- Confirmed bookings are not automatically synchronized to Google Calendar.
- The demo uses public sample imagery. Replace it with authorized Ruth's Makeup photography.
- User-supplied HTML is escaped in displayed dynamic text; nevertheless review any added integrations for security.
- The `design-reference.html` file is the **old insecure local prototype** and is excluded from the published version; do not deploy it.

## Security

GitHub Pages files are public. `assets/config.js` contains only the public Supabase key; all access is enforced by Supabase Row Level Security. Never commit database passwords, service-role keys or private credentials. Admin privileges are granted only in the database using Ruth's auth UUID. No customer password is stored in localStorage by this new site.

## Testing checklist

- Customer sign-up, email verification, sign-in and sign-out.
- Non-admin cannot open Admin Studio or change pricing/bookings.
- Admin can update content and see it on a different device.
- Two customers request the same time; admin cannot confirm both.
- Group class seventh confirmed seat is rejected.
- Review can only be submitted by a confirmed customer and is hidden until approved.
- Upload a real licensed photo and verify public display.
- Test phone/tablet layout and all four languages.
