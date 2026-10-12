# tulasisolutionssite

A new Flutter project.

## Removed Weekly Reports

- Weekly Reports is removed from desktop/mobile navigation and routing, along
	with its screen, report model, provider, and Firestore service methods.
- Deploy the updated Firestore rules to remove app access to historical reports.
	Existing Firebase documents are not deleted. The duplicate-client maintenance
	tool retains its historical report-reference check to protect those records.
- Rebuild and deploy the web app to remove the panel from the hosted portal.

## Recording Payments

- Record payment opens immediately without waiting for the client fetch.
	The popup shows Loading clients, or an explicit error with Retry. Empty client
	lists explain that a client must be added; saving stays disabled until clients
	are available. Rapid clicks cannot open duplicate popups.
- Record payment requires a client, a positive finite amount entered manually,
	and a transaction/reference ID. There is no plan selector or plan requirement.
	Changing the selected client preserves the entered amount.
- Client and payment-method dropdowns fit the dialog width and truncate long names
	instead of overflowing on narrow screens.
- Existing plan-linked payment records retain their historical plan details.
	New payments have no plan link, and their UPI messages omit the plan line.

## Removed Clients Panel

- The separate plan-based Clients panel is removed from desktop/mobile navigation,
	staff panel options, and dashboard navigation. Manage customers in Sales Pipeline;
	the Total leads and Active clients dashboard tiles now open Sales Pipeline.
- Old Clients, Setup, and Subscription URLs redirect to Sales Pipeline, with its
	existing access checks. No new staff permissions are granted by these redirects.
- The dedicated Clients screen and obsolete consultation scheduling screen, model,
	providers, service methods, and access rules are removed. Publish the updated
	Firestore rules and rebuild/deploy the app to apply the removal.
- Client records, plans, task links, payments, and historical consultation records
	are not deleted. Existing `clients` permissions remain recognized only for
	shared client-record operations, and are retained when editing staff accounts.

## Signed-in Web Loading

- Web staff-profile checks use authenticated Firestore HTTPS reads directly,
	avoiding the WebChannel timeout before an HTTPS fallback. Native apps retain
	the SDK lookup and HTTPS fallback.
- Email-based staff profiles still take precedence over UID-based profiles.
	Permission errors never fall through to another profile or grant access.
- Profile loading retries transient failures at most three times and has a
	20-second overall limit. The auth guard shows the error and a Retry button
	instead of leaving a spinner running indefinitely.
- Rebuild and deploy the web app for these changes to reach the hosted portal.

## Sales Workflow

- Customer lifecycle stages are Leads → Pitch → Follow Up → Sale → Retain → Refer,
	with Closed for inactive opportunities. Retain and Refer are separate stages.
	Existing `retain` records stay Retain; `refer` records now resolve to Refer.
	Legacy reach/click and followUp/consult aliases keep their existing mappings.
	No records, contact history, payments or delivery plans are migrated or deleted.
- Main stage and Update are explicit dropdowns in the customer record.
	Each stage has its own options; changing stage clears incompatible progress.
	Older progress remains unchanged until a new Update is selected, and is visible
	in Customer details. Save logs both
	the previous/current stage and progress with staff name and time. Ordinary
	profile edits preserve current progress and referral provenance. Pipeline stage
	changes also log authorship and clear old progress.
	Leads: Not contacted / No response / Interested / Not suitable.
	Pitch: Discussion pending / Details sent / Proposal sent / Awaiting response.
	Follow Up: No response / Considering / Changes requested / Ready to proceed / Not interested.
	Sale: Confirmed / Awaiting payment / Onboarding pending / Onboarding complete.
	Retain: Check-in pending / Satisfied / Needs help / Renewal pending / Renewed / Not renewing.
	Refer: Not asked / Referral requested / Referral promised / Referral received / Thanked.
	Closed: Not interested / Not suitable / Cancelled / Duplicate / Invalid contact.
- Sales Tasks uses search, assignee and reminder queues without stage-filter
	chips. Cards still show the customer's funnel stage and stage-specific progress.
	Pipeline combines stage and search filters and shows a current overview of
	Sale & after customers, renewals due, renewed customers, and referred leads.
	These are current record counts, not historical conversion or revenue metrics.
- The popup focuses on labelled dropdowns and reminder controls, without repeated
	status summaries or explanatory paragraphs. Verified payments, previous sales
	notes and the customer activity log are not shown in the popup; stored data
	is preserved and saving still appends activity.
	There are no separate Action, Outcome, Customer response, completion, or
	Next step selections. Stage changes remain manual.
- Payment records and verification remain in the Payments panel, not the customer
	Sales popup. Stage updates cannot mark a payment verified.
- Retain and Refer customers can Create referred lead: enter the new customer
	name and phone, creating a separate Leads record with an assigned Call referred
	lead action and `referredByClientId`. Both customers receive named referral logs;
	the existing customer stage, progress, service and reminder are unchanged.
	New-customer identity needs entry; optional sales notes can be entered in the popup.
	Referral creation is a separate explicit save, not part of unsaved popup edits.
	Renewal and check-in updates use calendar reminders on the same record.
	Closed records reject reminders until explicitly reopened.
- Sales Pipeline and Sales Tasks are separate sidebar panels. Pipeline retains
	customer stage chips, search, lead creation, import/export, customer actions,
	next action/due time, and archive/restore. Customers without tasks remain visible.
	Existing Leads permissions and URLs are retained; task queues do not filter Pipeline.
- Create sales task on a Pipeline customer now opens that customer's single Sales record.
	Open sales tasks navigates to the separate task panel filtered to that customer's
	record; Show all customers clears the filter. Open customer record offers a
	searchable customer picker. Clicking a card opens the record and full history.
- The customer Sales popup uses Main stage, Update (four to six choices per stage),
	and Reminder (No reminder / Set date & time), plus an optional multiline Notes
	field. Existing sales notes load for editing; Save record persists changes and
	Cancellation leaves them unchanged. Prior note versions remain stored.
	No task titles need typing.
	Save record logs the update on the same customer record. No new Plan task is
	created and existing Plan tasks are not completed or modified.
	After the database confirms a save, Pipeline and Sales Tasks immediately use
	the committed record, including when reopened before the background customer
	refresh finishes. Pending or failed saves are never shown as confirmed.
	Server-confirmed refreshes replace the temporary saved-record view; cached
	refreshes cannot roll it back to older values.
- Set date & time opens the calendar date picker followed by the clock time picker.
	The exact local date/time is shown before saving, and new past reminders are
	rejected. Existing reminders, including overdue and non-half-hour times, are
	preserved until changed. Canceling either picker leaves the reminder unchanged;
	Clear reminder removes it. Days/weeks and fixed-time dropdowns are not used.
- Sales actions use a zero-price Sales Tasks plan, separate from delivery
	plans. Sales tasks appear in Assign Tasks and the separate Sales Tasks panel,
	not in My Tasks. My Tasks excludes sales rows from its active and archived
	lists and all filter counts.
- Sales Tasks shows one clickable card per customer, with a large bold customer
	name and current funnel stage on the left, and the current task to do on the
	right (stacked below on narrow screens). Completed records label the action
	Completed task. Due time, workflow status, and any Do not contact flag remain
	visible. Tap anywhere on the card to open
	the exact Sales record; customer code and other profile details stay in the record
	rather than the list. Its default Today & Overdue
	queue sorts overdue tasks first; Upcoming, Unscheduled, All active, and Completed
	count customers, not individual tasks. Existing multiple tasks are grouped,
	using the nearest active reminder until the customer record is saved.
	Legacy reminders are also included. Existing tasks, contact entries, notes,
	and tracking remain accessible in Preserved task history / Previous contacts.
	Customers without a record, task, or reminder appear only in the picker.
- Sales task cards use action icons and local-time Today, Tomorrow, and Overdue
	labels. Colour highlights urgency rather than sales priority; completed tasks
	do not show an overdue warning. Admins can filter Everyone / My tasks and
	select an assignee; counts follow the customer, search, and assignment filters.
	Assignees are shown only in the admin team view.
- Use Preview examples (the eye icon in Sales Tasks) to explore sample overdue,
	upcoming, unscheduled, completed, and archived tasks and contact history.
	The fullscreen preview uses isolated, in-memory data. Saving, deletion, task
	creation, and external contact actions are disabled; closing it discards edits.
- Opening a card shows Sales record with Call customer and WhatsApp shortcuts
	when a phone number exists. These open external apps and never send a message
	automatically. Task history, older contact entries, and customer details are
	collapsed. Named and dated updates continue to be stored without displaying
	the customer activity log in this popup.
	Stage changes stay explicit in Main stage.
- A separate Do not contact switch clears reminders and blocks contact shortcuts.
	Turn it off and save before using contact shortcuts for a blocked customer.
	Updates never create or verify payments. Actual payments remain in the Payments panel.
- Save record logs the staff UID/name, time, previous/current update, previous/next
	reminders, contact permission changes, and customer stage. Older sales notes
	remain stored, but their popup section is hidden. Preserved task history and
	Previous contacts remain available read-only.
	Removing a reminder does not complete the record; active records become
	Unscheduled. Selecting Closed completes the customer record and clears its
	reminder without changing legacy Plan tasks. Updating a completed record
	without a new reminder does not reopen it; a new reminder or reopening Closed
	makes it active. New logs use clients/{id}/salesActivity,
	are immutable, and are not truncated to the legacy 50-contact limit.
- Open customer record lets you choose any non-archived customer, including leads,
	searching names, codes, and phone numbers. Existing ownership is retained;
	new records belong to the signed-in user.
	Existing task-read permissions still apply. Users with only the legacy Leads
	permission retain full Pipeline visibility but do not see the Sales Tasks sidebar
	entry. Direct task-panel links show an access explanation without loading tasks.
	No permission is automatically expanded. The picker still requires Assign Tasks access.
	These are in-app
	reminders; task creation does not send a message or a push notification.
- Sales Pipeline and Assign Tasks Sales-record actions open the same customer
	record. Editing requires existing Leads or Clients write access. Completing a
	legacy Plan task also requires Assign Tasks access; task-only users can read
	the customer record. Existing task workflow editing remains in Assign Tasks.
	Conflicting record changes require reopening; failed saves keep the popup edits.
	Web transaction failures retain their original Dart error and stack trace rather
	than a generic converted-Future message. Conflicts offer Reopen latest record;
	this explicitly discards unsaved selections and loads the latest record for review.
	Stage changes remain explicit. Cancel saves nothing. Deploy the updated
	Firestore rules to enable the append-only salesActivity collection.

## Staff-created Tasks

- Staff can create a task for themselves from My Tasks, including internal practice.
	Staff without Assign Tasks or Plans management access create a separate zero-price
	Custom Tasks or Practice (Internal) plan; existing shared/delivery plans are not modified.
- My Tasks and My Completed Tasks resolve client names from the saved client ID for
	all task categories, including archived tasks. Internal tasks show Practice (Internal);
	missing client records show Unknown client. Client-loading errors offer a retry.
- The task-creation client dropdown lists Practice (Internal) and only non-archived
	Sale, Retain or Refer clients, regardless of task category or existing plans.
	Sales task creation uses its own customer picker, including leads.
- Firestore validates one self-assigned task, no package template, no price or completed
	progress, and a valid customer or the internal-practice marker. Assigning another user,
	appending to shared plans, deleting plans, and creating Sales tasks still require
	the existing management permissions. Completion controls remain in Assign Tasks.
- Publish both the updated app and Firestore rules to enable this workflow in production.
	Rule tests use only the demo Firestore emulator: `npm --prefix functions run test:rules`.

## Task Approval Badges

- Task status is read-only and shown as a separate badge on list cards, including
	Completed cards. Task Details has no manual status dropdown. Assignment,
	Start work, New draft, review submission, and completion actions set status.
- Start work advances Assigned to Started. Pausing keeps Started; starting a
	timer on a draft or pending review does not replace its workflow status.
- Every new draft, including Draft 2, 3, and later, repeats the admin then client
	approval flow. Assign Tasks reviewers can submit drafts for admin review too.
	The generic Complete shortcut is only available for tasks without drafts.

- Assign Tasks and My Tasks show an amber Waiting for admin approval or Waiting
	for client approval badge directly on the task card when the latest draft has
	been submitted to that reviewer and is awaiting confirmation.
- The badge is separate from the shortened staff/draft status label. Completed,
	confirmed, and new working drafts do not show a pending approval badge.
- Completed Task Details offers Restore previous stage to users with Assign Tasks
	access, but not in personal task previews. Completed previews are read-only:
	there is no Save changes, New draft, or draft-deletion action. Restore requires
	typing exactly `RESTORE` in the confirmation popup before Restore task is enabled.
	Cancel changes nothing. Restore undoes completion without deleting drafts,
	notes, assignment, or progress; it does not rewrite other task details.
	New completions remember the prior workflow stage; older completed tasks return
	to client approval when they have drafts, otherwise Started if work was recorded,
	or Assigned / Not assigned. Completion dates and confirmation are cleared, and
	the timer stays paused without counting time spent completed. Restored tasks
	return to active lists (archived tasks remain archived). Restore uses the same
	pending-save, retry, and conflict handling as other task edits.
- Open the task card to review it using the existing permission-controlled
	approval actions; the badge does not change task status or permissions.
- Staff can use Send for admin approval on their assigned task, including a task
	with no drafts yet. The action saves the current edits and submits the latest
	draft (or creates the first draft) for review.
- In Assign Tasks, reviewers can Send to client for approval after staff submission.
	An admin review also offers Request changes, but not direct completion. While
	waiting for client approval, Client approved - move to Completed records the
	client's approval and completes the task. Pending reviews cannot be bypassed
	using the status dropdown or the generic Complete button. Review actions save current
	task edits together with the status change.
- Task and plan saves (including drafts, review actions, creation, timers,
	archive/restore, progress, and task-linked Sales records) update lists immediately
	and close the editor without waiting for network acknowledgement. A Saving...
	badge on the affected task remains until Firebase confirms the write.
	Normal saves and successful saves do not show a shared progress banner or a
	Refresh list button. Updates appear automatically; existing Sales and task
	customer lists stay visible during background refreshes. A shared warning
	appears only for unusually slow or failed saves, not routine progress.
	A slow connection shows Still saving, not a success message.
- Active, completed, and personal task lists resolve customers by the plan's
	saved client ID. If phone-based duplicate filtering hides that record, a
	server lookup retrieves the exact customer without changing task ownership
	or merging customer records. Lookup errors show Retry rather than an unknown
	name. Missing client records show No client linked and share one Unlinked tasks
	filter option. Admin task previews keep the saved ID under Client link details
	and offer Link to client, including Practice (Internal). Confirmation applies
	to every task in the plan; only the client ID changes, preserving all history,
	assignments, status, and pricing. The transaction verifies the original client
	is missing, the destination exists, and the plan link/task count is unchanged.
	Staff previews cannot repair links. Internal practice tasks keep their label.
	Client and assigned-staff filters reset to All if the selected option disappears
	after deletion, relinking, or a staff-list update. Category filters retain their
	selection so a temporarily empty category can still be cleared explicitly.
- Assign Tasks offers Today & Overdue, Upcoming, Unscheduled, and Unassigned
	quick filters on the right of its summary card, wrapping below the summary
	on smaller screens. These filters apply to active tasks. Due filters use local calendar days: Today &
	Overdue includes any deadline before tomorrow; Upcoming starts tomorrow.
	Choose one due filter and optionally combine it with Unassigned, client, staff,
	category, and search. Chip counts reflect the other filters. Tap a selected
	chip again to remove it, or use Clear filters to reset everything. Archived
	and completed tasks are excluded from these counts; Completed Tasks keeps its
	existing completion-date filters.
- My Tasks also offers Today & Overdue, Upcoming, and Unscheduled chips alongside
	its category filters, wrapping on smaller screens and using the same local-day boundaries. Counts include only
	your active, incomplete tasks in the selected category. Choose one due filter,
	tap it again to show all due dates, or use Clear filters to reset both category
	and due filters. All due dates are shown initially; archived tasks remain in
	their separate section and My Completed Tasks keeps its completion-date filters.
	The All and due-date chips stay visible with zero counts when no tasks are
	assigned, including when only Sales tasks exist.
- Failed saves roll back only their changed fields and retain the submitted edits
	in memory. Newer edits to other tasks, and newer conflicting edits, remain visible.
	Use Retry save for transient failures. Conflicts offer Reopen latest task/plan:
	it fetches fresh server data and shows retained text with copy controls. Review
	and copy the text you want to keep before saving; approval actions are not replayed.
	Canceling recovery keeps the original failed request. Discard unsaved edits
	explicitly abandons it. Only one unfinished save per plan is allowed, including
	across split units.
	Pending saves are isolated by signed-in account; unsaved retry data does not
	survive a page reload or sign-out. While writes are pending or failed, web browsers
	are asked to warn before reload/close (browser support varies), and drawer sign-out
	requires confirmation. Confirmed writes do not trigger an unsaved-edits warning.
	A Sales transaction still saves task/customer
	changes atomically; customer-only Sales edits and permanent deletion still wait
	for confirmation. Ordinary Sales saves do not restart the plan-list stream.
- Task/plan edits use a transaction that writes only changed plan fields, preserving
	other tasks changed concurrently. Conflicting edits are rejected explicitly
	instead of silently overwriting someone else's work.
- A confirmed write waiting for its list snapshot shows Saved - updating list,
	not Saving. It no longer blocks editing or server-confirmed deletion; Refresh
	list is available if the subscription is stalled. Only successful, complete
	server snapshots remove missing plans. Cached, loading, or error results cannot
	remove an optimistic card; client-scoped lists cannot remove other clients' cards.
- Sending to the client records the review status only. It does not send a
	WhatsApp message, email, or notification; confirmation is recorded in Assign Tasks.

## Admin Task Deletion

- Only admins see Delete task inside the opened task preview, including archived
	and completed tasks. The list cards do not show a delete icon.
- My Tasks and My Completed Tasks are staff views: their previews never show
	task or draft deletion, even for admins. Sales previews opened from these
	views also hide task and contact-entry deletion.
	Deletion requires typing exactly `DELETE`; Cancel leaves the task unchanged.
- Deleting a split task removes all its units, drafts, and progress. The plan,
	pricing, customer, and other tasks are preserved, including concurrent updates.
- Firestore rules restrict reducing the task/feature lists to admins. Publish
	the updated rules with the app to enforce this restriction in production.

## Task Tracking Dates

- New tasks record creation and assignment times with the responsible person.
	Editing notes or priority does not change the assignment date. Reassignment
	records the new assignment date. Existing tasks are not backdated.
- First started is recorded once, independently of the resumable work timer.
	Starting work or selecting Started records it; stopping/resuming keeps it.
- Each draft records its own Sent for admin approval and Sent for client approval
	times and people. Editing the draft does not change those submission dates.
- Client approval/completion is one event, recorded with the admin who confirms it.
	Cards show only the current stage's date and time: Created on, Assigned on
	(for reassignment), Started on, Draft N - Created on, Sent for admin/client
	approval on, or Completed on. Due reminders remain badges, not extra dates.
	Unknown historical dates are omitted. Full history stays in the preview.
- Task Details and Sales record previews include a Tracking section with local
	dates/times and responsible people. Draft submission history remains visible.
- Automatic event timestamps are stored in UTC. Publish the updated app and rules
	to allow staff-created tasks to include tracking metadata.
