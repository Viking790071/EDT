#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region Public

// Function determines whether files access groups are used or not.
//
//	Returns:
//		Boolean - If TRUE, it means that access groups are used
//
Function AccessGroupsAreUsed() Export
	
	Return GetFunctionalOption("LimitAccessAtRecordLevel") And GetFunctionalOption("UseFilesAccessGroups");
	
EndFunction

#EndRegion

#EndIf