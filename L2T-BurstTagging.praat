# Include the auxiliary code files.
include ../Utilities/L2T-Utilities.praat
include ../StartupForm/L2T-StartupForm.praat
include ../Audio/L2T-Audio.praat
include ../WordList/L2T-WordList.praat
include ../L2T-SegmentationTextGrid/L2T-SegmentationTextGrid.praat
include ../BurstLog/L2T-BurstLog.praat
include ../BurstTextGrid/L2T-BurstTextGrid.praat

# Set the session parameters.
defaultExpTask = 2
defaultTestwave = 1
defaultActivity = 7


# Check whether all the objects that are necessary for burst tagging have
# been loaded to the Praat Objects list, and hence that the script is [ready]
# [.to_tag_burst_events].
procedure ready
	if (audio.praat_obj$ <> "") & 
		... (wordlist.praat_obj$ <> "") &
		... (segmentation_textgrid.praat_obj$ <> "") &
		... (burst_log.praat_obj$ <> "") &
		... (burst_textgrid.praat_obj$ <> "")
		.to_tag_burst_events = 1
	else
		.to_tag_burst_events = 0
	endif
endproc

# A procedure that sets the spectrogram settings for burst tagging.
# View range (Hz): 0.0 -- 15000.0
# Window size (s): 0.005
# Dynamic range (dB): 40.0
procedure spectrogram_settings
	editor 'burst_textgrid.praat_obj$'
		Spectrogram settings... 0.0 15000.0 0.005 40.0
		Pitch settings... 2000.0 2500.0 Hertz autocorrelation automatic
		Intensity settings... 25.0 100.0 "mean energy" 1
		beginPause: "Spectrogram settings for Burst Tagging"
			comment: "Before you begin burst tagging, make sure that Intensity is shown in the spectrogram."
			comment: "(Check 'Show intensity' in the Intensity menu.)"
		endPause: "", "Start burst tagging", 2, 1
	endeditor
endproc

# Information about the current trial being tagged.
procedure current_trial
	# Determine the [.row_on_wordlist] that designates the current trial.
	select 'burst_log.praat_obj$'
	.row_on_wordlist = Get value... 1 'burst_log_columns.tagged_trials$'
	.row_on_wordlist = .row_on_wordlist + 1
	# Consult the WordList table to look-up the current trial's...
	select 'wordlist.praat_obj$'
	# ... Trial Number
	.trial_number$ = Get value... '.row_on_wordlist'
	... 'wordlist_columns.trial_number$'
	# ... Target Word
	.target_word$ = Get value... '.row_on_wordlist'
                           ... 'wordlist_columns.word$'
	# ... Target Consonant
	.target_c$ = Get value... '.row_on_wordlist'
                        ... 'wordlist_columns.target_c$'
	# ... Target Vowel
	.target_v$ = Get value... '.row_on_wordlist'
                        ... 'wordlist_columns.target_v$'
	# Determine the xmin, xmid, and xmax of the [interval] on the 'TrialNumber' 
	# tier of the segmented TextGrid that corresponds to the current trial.
	@interval: segmentation_textgrid.praat_obj$,
 		... segmentation_textgrid_tiers.trial,
		... .trial_number$
	.xmin = interval.xmin
	.xmid = interval.xmid
	.xmax = interval.xmax
	.zoom_xmin = .xmin - 0.5
	.zoom_xmax = .xmax + 0.5
endproc

# Grab the segmentations of the current trial.
procedure segmentations_of_current_trial
	# Extract the Trial from the Segmentation TextGrid, and export the name
	# of the new TextGrid.
	.textgrid$ = segmentation_textgrid.praat_obj$
	@extract_interval: .textgrid$,
		... current_trial.xmin,
		... current_trial.xmax
	.trial_textgrid$ = extract_interval.praat_obj$

	# Transform the extracted TextGrid down to a Table, and export the name 
	# of the new Table.
	@textgrid2table: .trial_textgrid$
	.trial_table$ = textgrid2table.praat_obj$

	# Subset the [.trial_table$] to just the rows on the Context tier.
	select '.trial_table$'
	Extract rows where column (text)... tier "is equal to" Context
	.segmentations_table$ = selected$()

	# Rename the [.segmentations_table$]
	@participant: burst_textgrid.write_to$,
		... session_parameters.participant_number$
	.table_obj$ = participant.id$ + "_" +
		... current_trial.trial_number$ + "_" +
		... "Segmentations"
	select '.segmentations_table$'
	Rename... '.table_obj$'
 	.praat_obj$ = selected$()

	# Get the number of segmentations of the current trial.
	select '.praat_obj$'
	.n_segmentations = Get number of rows

 	# Create string variables for identifiers of the segmentations.
	for i to .n_segmentations
		select '.praat_obj$'
		.context'i'$ = Get value... 'i' text
		.segmentation'i'$ = "'i'" + "--" + .context'i'$
	endfor

	# Clean up all of the intermediary Praat Objects.
	@remove: .trial_textgrid$
	@remove: .trial_table$
endproc

# A vector-procedure for the [consonant_types] available while burst tagging.
procedure consonant_types
	.stop$      = "Stop"
	.affricate$ = "Affricate"
	.malaprop$  = "Malaprop"
	.other$     = "Other"

	# Gather the Consonant Types into a vector.
	.slot1$ = .stop$
	.slot2$ = .affricate$
	.slot3$ = .malaprop$
	.slot4$ = .other$
	.length = 4
endproc

# Prompt the user to judge the consonant type of the response and add any
# supplementary notes.
procedure tagging_form
 	.no_taggable_response$ = "No response is taggable"
	.missing_data$         = "MissingData"
	@consonant_types
	beginPause: "Tagging Form" + " :: " + current_trial.trial_number$ + " :: " +
		... current_trial.target_word$
		#comment: "Please listen to the current trial in its entirety."
		# Determine the taggable response.
		comment: "Which response would you like to tag?"

			optionMenu: "Response", 1
			for i to segmentations_of_current_trial.n_segmentations
				option: segmentations_of_current_trial.segmentation'i'$
			endfor
			option: .no_taggable_response$

		# Determine Consonant Type of the taggable response
		comment: "If there is a taggable response, what type of consonant was produced?"

			optionMenu: "Consonant type", 1
			for i to consonant_types.length
				option: consonant_types.slot'i'$
			endfor

		# Transcribe a stop.
		comment: "If the consonant is a stop, please transcribe its Place."
			if current_trial.target_c$ == "t"
				optionMenu: "Stop place", 1
				option: "t"
				option: "t:$k"
				option: "$k:t"
				option: "$k"
				option: "other"
			elif current_trial.target_c$ == "d"
				optionMenu: "Stop place", 1
				option: "d"
				option: "d:$g"
				option: "$g:d"
				option: "$g"
 				option: "other"
			elif current_trial.target_c$ == "k"
				optionMenu: "Stop place", 4
				option: "$t"
				option: "$t:k"
				option: "k:$t"
				option: "k"
				option: "other"
			elif current_trial.target_c$ == "g"
				optionMenu: "Stop place", 4
				option: "$d"
 				option: "$d:g"
				option: "g:$d"
				option: "g"
				option: "other"
			endif

		# Allow the tagger to record notes about the trial.
		comment: "Would you like to record any notes for this trial?"
			boolean: "Quiet", 0
			boolean: "Clipping", 0
			boolean: "BackgroundNoise", 0
			boolean: "OverlappingResponse", 0
			boolean: "Malaprop", 0
			boolean: "Short VOT", 0
			boolean: "Whispered vowel", 0
			sentence: "Malaprop word", ""
			sentence: "Additional comment", ""
	.button = endPause: "Save progress & quit", "Tag it!", 2, 1

	if .button == 2
		# Export variables to the [response_to_tag] namespace.
		# Check to see if this trial had a taggable response.
			if response$ <> .no_taggable_response$
				# If this trial had a taggable response, then that segmentation is tagged
				# with the consonant label provided by the tagger.
				response_to_tag.repetition = response
				# Store the consonant_type$
				response_to_tag.consonant_type$ = consonant_type$
				# Set the [response_to_tag.consonant_label$]...
			if consonant_type$ == consonant_types.stop$
				# If the target consonant was produced as a STOP, then the
				# [.consonant_label$] is Stop;<transcription>.
				response_to_tag.consonant_label$ = consonant_type$ + ";" + stop_place$
			elif consonant_type$ == consonant_types.malaprop$
				# If the target consonant was produced within a MALAPROP, then the 
				# [.consonant_label$] is Malaprop:<malapropism>;<transcription>.
				while malaprop_word$ == ""
					@prompt_for_malaprop_word
				endwhile
				response_to_tag.consonant_label$ = consonant_type$ + ":" +
					... malaprop_word$ + ";" +
					... stop_place$
			else
				# Otherwise, [.consonant_label$] is the same as [consonant_type$]
				response_to_tag.consonant_label$ = consonant_type$
			endif
		else
			# If this trial had no taggable response, then the FIRST segmentation is
 			# tagged with the label: "MissingData"
			response_to_tag.repetition = 1
			response_to_tag.consonant_label$ = .missing_data$
			response_to_tag.consonant_type$  = .missing_data$
		endif

		# Concatenate the Notes together.
		response_to_tag.notes$ = ""

		# Quiet
 		if quiet
			if response_to_tag.notes$ == ""
				response_to_tag.notes$ = "Quiet"
			else
				response_to_tag.notes$ = response_to_tag.notes$ + ";" + 
					... "Quiet"
			endif
		endif

		# Clipping
		if clipping
			if response_to_tag.notes$ == ""
				response_to_tag.notes$ = "Clipping"
			else
				response_to_tag.notes$ = response_to_tag.notes$ + ";" + 
					... "Clipping"
			endif
		endif

		# BackgroundNoise
		if backgroundNoise
			if response_to_tag.notes$ == ""
				response_to_tag.notes$ = "BackgroundNoise"
			else
				response_to_tag.notes$ = response_to_tag.notes$ + ";" + 
					... "BackgroundNoise"
			endif
		endif

		# OverlappingResponse
		if overlappingResponse
			if response_to_tag.notes$ == ""
				response_to_tag.notes$ = "OverlappingResponse"
			else
				response_to_tag.notes$ = response_to_tag.notes$ + ";" + 
					... "OverlappingResponse"
			endif
		endif

		if malaprop
			while malaprop_word$ == ""
				@prompt_for_malaprop_word
			endwhile

			if response_to_tag.notes$ == ""
				response_to_tag.notes$ = "Malaprop" + ":" + malaprop_word$
			else
				response_to_tag.notes$ = response_to_tag.notes$ + ";" + 
					... "Malaprop" + ":" + malaprop_word$
			endif
		endif

		# Short VOT
		if short_VOT
			if response_to_tag.notes$ == ""
				response_to_tag.notes$ = "Short VOT"
			else
				response_to_tag.notes$ = response_to_tag.notes$ + ";" + 
					... "Short VOT"
			endif
		endif

		# Whispered Vowel
		if whispered_vowel
			if response_to_tag.notes$ == ""
				response_to_tag.notes$ = "Whispered Vowel"
			else
				response_to_tag.notes$ = response_to_tag.notes$ + ";" + 
					... "Whispered Vowel"
			endif
		endif

		#Add additional notes manually
		if additional_comment$ != ""
			response_to_tag.notes$ = response_to_tag.notes$ + ";" + additional_comment$
		endif
	endif
endproc

# A procedure that prompts the user for the malapropism that the child
# produced.
procedure prompt_for_malaprop_word
	beginPause: "Malapropism" + " :: " + current_trial.trial_number$ + " :: " +
		... current_trial.target_word$
		comment: "What malapropism did the child produce?"
		sentence: "Malaprop word", ""
	endPause: "", "Continue", 2, 1
endproc


# A procedure for setting information about the response to tag.
procedure response_to_tag
	# The following variables are set by the procedure @tagging_form.
	#   .repetition
	#   .consonant_label$
	#   .consonant_type$
	#   .notes$
	# Determine whether the produced consonant has a burst
	# [consonant_type$] is a global variable whose value is set when the user
	# judges the trial.
	if (.consonant_type$ == consonant_types.stop$) |
		... (.consonant_type$ == consonant_types.affricate$) |
		... (.consonant_type$ == consonant_types.malaprop$)
		.has_burst = 1
	else
		.has_burst = 0
	endif

	# Determine the [boundary_times] of the response to tag.
	@boundary_times: segmentations_of_current_trial.praat_obj$,
		... .repetition,
		... segmentation_textgrid.praat_obj$,
		... segmentation_textgrid_tiers.context

	# Import the times from the [boundary_times] namespace.
	.xmin = boundary_times.xmin
	.xmid = boundary_times.xmid
	.xmax = boundary_times.xmax
	.duration = .xmax - .xmin

	# Set the limits of the zoom window.
	.zoom_xmin = .xmin - 0.25
	.zoom_xmax = .xmax + 0.25
endproc


# A procedure for inserting boundaries, which mark the extent of the response
# to tag, on an Interval [.tier] of the TextGrid that is displayed in the 
# Editor window during burst tagging.
procedure insert_boundaries .tier
	select 'burst_textgrid.praat_obj$'
	Insert boundary... '.tier'
		... 'response_to_tag.xmin'
	Insert boundary... '.tier'
		... 'response_to_tag.xmax'
endproc

# Add to the TextGrid, the ConsType information for the current response.
# A procedure for adding to the Burst Tagging TextGrid, the ConsType
# information for the response to tag.
procedure add_consonant_type
	# Insert the interval boundaries.
	@insert_boundaries: burst_textgrid_tiers.cons_type
	# Determine the interval number on the ConsType tier.
	@interval_at_time: burst_textgrid.praat_obj$,
		... burst_textgrid_tiers.cons_type,
		... response_to_tag.xmid

	# Label the interval.
	@label_interval: burst_textgrid.praat_obj$,
		... burst_textgrid_tiers.cons_type,
		... interval_at_time.interval,
		... response_to_tag.consonant_label$
endproc

# A procedure that adds, to the Burst Tagging TextGrid, the BurstNotes of
# the response to tag.
procedure add_burst_notes
	if response_to_tag.notes$ <> ""
		@insert_point: burst_textgrid.praat_obj$,
			... burst_textgrid_tiers.burst_notes,
			... response_to_tag.xmid,
			... response_to_tag.notes$
	endif
endproc

# A procedure that adds, to the Burst Tagging TextGrid, the ConsType,
# BurstEvents, and BurstNotes of the response to tag.
procedure transcribe_response
	# Add the ConsType.
	@add_consonant_type

	# Add the BurstNotes.
	@add_burst_notes
endproc

# A procedure that allows the user to tag the burst events of the transcribed
# response.
procedure tag_burst_events
	if response_to_tag.has_burst
		.tagging_burst_events = 1

		while .tagging_burst_events
			beginPause: "Tagging burst events" + " :: " + 
				... current_trial.trial_number$ + " :: " +
 				... current_trial.target_word$

				comment: "In the Editor window, position the cursor where you'd like to tag an event."
				comment: "Select which event you'd like to tag."
				choice: "Burst event", 1
					option: "burst"
					option: "burst2"
					option: "NB (no burst)"
					option: "VOT"
					option: "vOff"
					option: "vOn"
					option: "vEnd"
			.button = endPause: "", "Tag event", "Move on", 2, 1

			if .button == 2
				# Get the cursor position in the Editor window to determine where the
				# burst event should be tagged.
				editor 'burst_textgrid.praat_obj$'
					.event_time = Get cursor
				endeditor

				# Behavior depends on the burst event being tagged...
				# ... event == burst
				if burst_event == 1
					.event_label$ = "burst"
				# ... event == burst2
				elif burst_event == 2
					.event_label$ = "burst2"
				# ... event == no burst
				elif burst_event == 3
					.event_label$ = "NB"
				# ... event == VOT
				elif burst_event == 4
					.event_label$ = "VOT"
				# ... event == vOff
				elif burst_event == 5
					.event_label$ = "vOff"
				# ... event == vOn
				elif burst_event == 6
					.event_label$ = "vOn"
				# ... event == vEnd
				elif burst_event == 7
  					.event_label$ = "vEnd"
				endif

				@insert_point: burst_textgrid.praat_obj$,
					... burst_textgrid_tiers.burst_events,
 					... .event_time,
					... .event_label$
			elif .button == 3
				.tagging_burst_events = 0
			endif
		endwhile
	endif
endproc


# # Set the burst events labels and times for the current response.
# procedure burst_events
#   .burst$     = "burst"
#   .vot$       = "VOT"
#   .vowel_end$ = "vowelEnd"
#   # Gather the burst events into a vector.
#   .slot1$ = .burst$
#   .slot2$ = .vot$
#   .slot3$ = .vowel_end$
#   .length = 3
#   # Determine the times at which the burst event tags should be dropped.
#   .time1 = response_to_tag.xmin + (0.1 * response_to_tag.duration)
#   .time3 = response_to_tag.xmax - (0.1 * response_to_tag.duration)
#   .time2 = (.time1 + .time3) / 2
# endproc
#
#
# # Add to the TextGrid, the BurstEvents information for the current response.
# procedure tag_burst_events
#   @burst_events
#   for i to burst_events.length
#     @insert_point: burst_textgrid.praat_obj$,
#                ... burst_textgrid_tiers.burst_events,
#                ... burst_events.time'i',
#                ... burst_events.slot'i'$
#   endfor
# endproc
#
#
# # A procedure that pauses the script while the user adjusts the events on the
# # BurstEvents tier, and then asks the user to choose what she would like to do
# # next.
# procedure adjust_burst_events
#   .next_trial$ = "Move on to the next trial"
#   .extract$    = "Extract the trial that I just tagged"
#   .save_quit$  = "Save my progress & quit"
#   beginPause: current_trial.trial_number$ + " :: " +
#           ... current_trial.target_word$
#     comment: "Please adjust all of the event-points on the BurstEvents Tier."
#     comment: "Once you've finished that, let me know what you want to do next."
#     choice: "I want to", 1
#       option: .next_trial$
#       #option: .extract$
#       option: .save_quit$
#   endPause: "", "Do it!", 2, 1
#   .what_next$ = i_want_to$
# endproc
#

# A procedure for incrementing the number of trials tagged, as logged on the
# Burst Tagging Log.
procedure increment_trials_tagged
	select 'burst_log.praat_obj$'
	.n_segmented = Get value... 1 'burst_log_columns.tagged_trials$'
	.n_segmented = .n_segmented + 1
	Set numeric value... 1 'burst_log_columns.tagged_trials$' '.n_segmented'
endproc

# A procedure for saving the Burst Tagging Log and the Burst Tagging tiers.
procedure save_progress
	# Save the Burst Tagging Log.
	select 'burst_log.praat_obj$'
	Save as tab-separated file... 'burst_log.write_to$'

	# Save the Burst Tagging tiers.  This procedure is defined in the
	# L2T-BurstTextGrid.praat script.
	@save_burst_tiers
endproc

# A procedure for clearing Praat's objects list.
procedure clear_objects_list
	@remove: audio.praat_obj$
	@remove: wordlist.praat_obj$
	@remove: segmentation_textgrid.praat_obj$
	@remove: burst_log.praat_obj$
	@remove: burst_textgrid.praat_obj$
endproc

# A procedure for breaking out of the top-level while-loop.
procedure quit_tagging
	continue_tagging = 0
endproc

# A procedure for congratulating a thanking the user once she has finished
# tagging a file in its entirety.
procedure congratulations_on_a_job_well_done
	beginPause: "Congratulations!"
		comment: "You've finished tagging!  Thank you for your hard work!"
		comment: "If you would like to tag another file, just re-run the script."
	endPause: "Don't click me", "Click me", 2, 1
endproc

# A procedure for controlling how the script proceeds once a trial has been
# tagged.
procedure move_on_from_current_trial
	# Increment the number of trials tagged, in order to log the user's progress.
	@increment_trials_tagged
	# Save the user's progress.
 	@save_progress
	# Remove the Table of the current trial's segmentations.
	@remove: segmentations_of_current_trial.praat_obj$

	# If the [current_trial] is the last trial on the WordList, then break out of
	# the top-level while-loop.
	if current_trial.row_on_wordlist == wordlist.n_trials
		# Clean up Praat's Objects list.
		@clear_objects_list
		# Quit tagging.
		@quit_tagging
		# Congratulate the user on finishing a file.
 		@congratulations_on_a_job_well_done
	endif
endproc

################################################################################
#  Main procedure                                                              #
################################################################################

# Set the session parameters.
@session_parameters: defaultExpTask, defaultTestwave, defaultActivity
#printline 'session_parameters.initials$'
#printline 'session_parameters.workstation$'
#printline 'session_parameters.experimental_task$'
#printline 'session_parameters.testwave$'
#printline 'session_parameters.participant_number$'
#printline 'session_parameters.activity$'
#printline 'session_parameters.analysis_directory$'
printline Data directory: 'session_parameters.experiment_directory$'

# Load the audio file
@audio

# Load the WordList.
@wordlist

# Load the checked segmented TextGrid.
@segmentation_textgrid

# Load the Burst Tagging Log.
@burst_log

# Load the Burst Tagging TextGrid.
@burst_textgrid

# Check if the Praat Objects list is [ready] to proceed [.to_tag_burst_events].
@ready
if ready.to_tag_burst_events
	printline Ready to burst tag: 'burst_textgrid.praat_obj$'
	# Open an Editor window, displaying the Sound object and the Burst TextGrid.
	@open_editor: burst_textgrid.praat_obj$,
		... audio.praat_obj$

	# Set the spectrogram settings in the Editor window.
	@spectrogram_settings

	# Enter a while-loop, within which the tagging is performed.
	continue_tagging = 1

	while continue_tagging
		# Set information about the [current_trial].
		@current_trial

		# Determine the segmentations of the current trial.
		@segmentations_of_current_trial

		# Zoom to the current trial.
		@zoom: burst_textgrid.praat_obj$,
			... current_trial.zoom_xmin,
			... current_trial.zoom_xmax

		# Present the user with the [tagging_form], with which she can judge the 
		# trial.
		@tagging_form
		if tagging_form.button == 2
			# Set information about the [response_to_tag]
 			@response_to_tag

			# Transcribe the response.
			@transcribe_response

			# Zoom to the tagged response.
			@zoom: burst_textgrid.praat_obj$,
				... response_to_tag.zoom_xmin,
				... response_to_tag.zoom_xmax

			# Pause the script to allow the user to tag the points on the 
			# BurstEvents tier.
			@tag_burst_events

			# Move on from the current trial.
			@move_on_from_current_trial

		elif tagging_form.button == 1
			@remove: segmentations_of_current_trial.praat_obj$

			# Clean up Praat's Objects list.
			@clear_objects_list

			# Quit tagging.
			@quit_tagging
		endif
	endwhile
endif