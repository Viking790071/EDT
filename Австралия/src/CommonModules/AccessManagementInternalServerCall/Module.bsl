#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Management of AccessKinds and AccessValues tables in edit forms.

// For internal use only.
Function GenerateUserSelectionData(Val Text,
                                             Val IncludeGroups = True,
                                             Val IncludeExternalUsers = Undefined,
                                             Val NoUsers = False) Export
	
	Return Users.GenerateUserSelectionData(
		Text,
		IncludeGroups,
		IncludeExternalUsers,
		NoUsers);
	
EndFunction

#EndRegion
