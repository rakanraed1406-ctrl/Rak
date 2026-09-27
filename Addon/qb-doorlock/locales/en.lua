local Translations = {
    texts = {
        unlocked = "Unlocked",
        locked = "Locked"
    },
    notify = {
        door_registered = "This door is already registered",
        lockpick_success  = "Success",
        lockpick_fail = "Failed",
        door_identifier_exists = "A door with this identifier already exists in the config. (%s)",
        door_not_found = "Did not receive a model hash, if the door is transparent, make sure you aim at the frame of the door",
        door_registered = "This door is already registered",
        same_entity = "Both doors can't be the same entity"
    },
    general = {
        keymapping_description = "Interact with door locks",
        keymapping_remotetriggerdoor = "Remote trigger a door",
        warning = "Warning",
        warn_no_permission_newdoor = "%{player} (%{license}) tried to add a new door without permission (source: %{source})",
        warn_no_authorisation = "%{player} (%{license}) attempted to open a door without authorisation (Sent: %{doorID})",
        warn_wrong_doorid = "%{player} (%{license}) attempted to update invalid door (Sent: %{doorID})",
        warn_wrong_state = "%{player} (%{license}) attempted to update to an invalid state (Sent: %{state})",
        warn_wrong_doorid_type = "%{player} (%{license}) didn't send an appropriate doorID (Sent: %{doorID})",
        warn_admin_privilege_used = "%{player} (%{license}) opened a door using admin privileges",
        created_by = "created by",
        newdoor_menu_title = "Add a new door",
        newdoor_command_description = "Add a new door to the doorlock system"
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
