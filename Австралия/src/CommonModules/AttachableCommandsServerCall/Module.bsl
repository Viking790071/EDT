#Region Private

// Returns command details by form item name.
Function CommandDetails(CommandNameInForm, SettingsAddress) Export
	Return AttachableCommands.CommandDetails(CommandNameInForm, SettingsAddress);
EndFunction

// Analyzes the document array for posting and for rights to post them.
Function DocumentsInfo(RefsArray) Export
	Result = New Structure;
	Result.Insert("Unposted", Common.CheckDocumentsPosting(RefsArray));
	Result.Insert("HasRightToPost", StandardSubsystemsServer.HasRightToPost(Result.Unposted));
	Return Result;
EndFunction

#EndRegion
