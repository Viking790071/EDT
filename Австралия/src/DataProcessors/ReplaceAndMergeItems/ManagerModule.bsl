#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Returns:
//     String - an event name to notify of replacement.
//
Function ReplacementNotificationEvent() Export
	Return "LinksReplaced";
EndFunction

#EndRegion

#EndIf