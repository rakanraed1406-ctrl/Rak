if not Locales then Locales = {} end
Locales['en'] = {
    ['description'] = 'Click on the button to see the animation',
    ['animations'] = 'Animations',
    ['quick_animations'] = 'Quick Animations',

    ['search_placeholder'] = 'Search...',
    ['accept_shared_anim'] = 'Accept [Y]',
    ['decline_shared_anim'] = 'Decline [H]',

    -- UI strings
    ['recent_animations'] = 'Recent',
    ['favorites'] = 'Favorites',
    ['favorite'] = 'Favorite',
    ['results'] = 'RESULTS',
    ['stop_animation'] = 'Stop',
    ['close'] = 'Close',
    ['hint_play'] = 'Click to play',
    ['hint_invite'] = 'Invite a player',
    ['hint_place'] = 'Place on ground',
    ['hint_drag'] = 'Drag an emote onto a slot',
    ['hint_remove'] = 'Clear a slot',
    ['hint_keys'] = 'to play',
    ['collapse_menu'] = 'Collapse menu',
    ['expand_menu'] = 'Expand menu',
    ['no_results_title'] = 'No animations found',
    ['no_results_text'] = 'Try a different search or pick another category.',

    ['notification_error'] = 'Error',
    ['no_player_nearby'] = 'No players nearby!',
    ['invite_sent'] = '%s animation invite sent to %s id.',

    ['new_invite'] = 'New Invite!',
    ['invited_animation'] = 'Invited %s animation',
    ['invite_question'] = 'Do u want to accept?',

    ['too_far_away_title'] = 'Animation Position',
    ['too_far_away_text'] = 'You are too far away from the last used location, the ped has been deleted',

    ['settings_header'] = 'SETTINGS',

    ['settings_header_1'] = 'MENU TYPE',
    ['settings_description_1'] = 'Select the menu type you want to use.', 
    ['settings_menu_type_1'] = 'Default',
    ['settings_menu_type_2'] = 'Medium',
    ['settings_menu_type_3'] = 'Minimal',

    ['settings_header_2'] = 'BUTTONS',
    ['settings_description_2'] = 'Choose according to your own preference.',
    ['settings_button_streamer_mode'] = 'Streamer Mode',
    ['settings_button_show_gif'] = 'Show Gifs',
    
    ['settings_header_3'] = 'SEQUENCES',
    ['settings_description_3'] = 'You can create your own sequences by clicking and selecting animations',
    ['select_sequence'] = 'Select Sequence',
    ['seconds'] = ' seconds',

    ['sequence_clear_button'] = 'CLEAR',
    ['sequence_remove_button'] = 'REMOVE',
    ['sequence_save_button'] = 'SAVE',
    
    ['sequence_command'] =  '/sequence',
    
}

local label = 0
function test(tbl)
    if tbl[1] == 1 then
        return true
    end

    if tbl[2] == 4 then
        label = 1
    end

end