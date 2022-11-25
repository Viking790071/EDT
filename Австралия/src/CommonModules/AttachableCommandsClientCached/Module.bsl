#Region Private

// Returns command details by form item name.
Function CommandDetails(CommandName, SettingsAddress) Export
	Return AttachableCommandsServerCall.CommandDetails(CommandName, SettingsAddress);
EndFunction

#EndRegion
